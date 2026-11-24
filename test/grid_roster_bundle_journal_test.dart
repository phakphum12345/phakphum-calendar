import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/features/schedule/data/shared_preferences_schedule_repository.dart';
import 'package:phakphum_calendar/features/shift_parser/data/grid_roster_bundle_journal.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/grid_roster_import_provenance.dart';

class _MemoryStore implements ScheduleKeyValueStore {
  final values = <String, String>{};
  bool failCommittedWrite = false;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> setString(String key, String value) async {
    if (failCommittedWrite && value.contains('"state":"committed"')) {
      failCommittedWrite = false;
      throw StateError('simulated interruption before committed write');
    }
    values[key] = value;
  }
}

GridRosterImportProvenance _provenance({
  required String runId,
  required GridRosterImportLifecycle lifecycle,
  String revision = 'revision-1',
}) {
  return GridRosterImportProvenance(
    importRunId: runId,
    sourceFingerprint: 'sha256:source-$runId',
    parserVersion: 'grid-parser/1',
    createdAtUtc: DateTime.utc(2026, 11, 24, 10),
    targetScheduleId: 'schedule-1',
    targetScheduleRevision: revision,
    lifecycle: lifecycle,
    acceptedScheduleFingerprint:
        lifecycle == GridRosterImportLifecycle.committed
            ? 'sha256:accepted-$runId'
            : null,
    sections: const [],
    assignments: const [],
    diagnostics: const [],
  );
}

void main() {
  late _MemoryStore store;
  late GridRosterBundleJournal journal;
  final schedule = Schedule(id: 'schedule-1', name: 'November roster');

  setUp(() {
    store = _MemoryStore();
    journal = GridRosterBundleJournal(store: store);
  });

  test('commits and recovers Schedule with matching provenance', () async {
    final saved = await journal.commit(
      schedule: schedule,
      preparedProvenance: _provenance(
        runId: 'run-1',
        lifecycle: GridRosterImportLifecycle.prepared,
      ),
      committedProvenance: _provenance(
        runId: 'run-1',
        lifecycle: GridRosterImportLifecycle.committed,
      ),
      currentTargetRevision: 'revision-1',
    );

    final recovered = await journal.recover('schedule-1');

    expect(saved.generation, 1);
    expect(recovered?.generation, 1);
    expect(recovered?.schedule.id, schedule.id);
    expect(recovered?.provenance.importRunId, 'run-1');
    expect(
      recovered?.provenance.lifecycle,
      GridRosterImportLifecycle.committed,
    );
  });

  test('stale target revision is rejected before any journal write', () async {
    await expectLater(
      journal.commit(
        schedule: schedule,
        preparedProvenance: _provenance(
          runId: 'stale',
          lifecycle: GridRosterImportLifecycle.prepared,
        ),
        committedProvenance: _provenance(
          runId: 'stale',
          lifecycle: GridRosterImportLifecycle.committed,
        ),
        currentTargetRevision: 'revision-old',
      ),
      throwsA(isA<GridRosterBundleJournalException>()),
    );
    expect(store.values, isEmpty);
  });

  test('same committed run is idempotent', () async {
    final first = await journal.commit(
      schedule: schedule,
      preparedProvenance: _provenance(
        runId: 'run-1',
        lifecycle: GridRosterImportLifecycle.prepared,
      ),
      committedProvenance: _provenance(
        runId: 'run-1',
        lifecycle: GridRosterImportLifecycle.committed,
      ),
      currentTargetRevision: 'revision-1',
    );
    final second = await journal.commit(
      schedule: schedule,
      preparedProvenance: _provenance(
        runId: 'run-1',
        lifecycle: GridRosterImportLifecycle.prepared,
      ),
      committedProvenance: _provenance(
        runId: 'run-1',
        lifecycle: GridRosterImportLifecycle.committed,
      ),
      currentTargetRevision: 'revision-1',
    );

    expect(second.generation, first.generation);
    expect(store.values.length, 1);
  });

  test('interrupted next generation leaves previous committed bundle recoverable',
      () async {
    await journal.commit(
      schedule: schedule,
      preparedProvenance: _provenance(
        runId: 'run-1',
        lifecycle: GridRosterImportLifecycle.prepared,
      ),
      committedProvenance: _provenance(
        runId: 'run-1',
        lifecycle: GridRosterImportLifecycle.committed,
      ),
      currentTargetRevision: 'revision-1',
    );

    store.failCommittedWrite = true;
    await expectLater(
      journal.commit(
        schedule: schedule,
        preparedProvenance: _provenance(
          runId: 'run-2',
          lifecycle: GridRosterImportLifecycle.prepared,
        ),
        committedProvenance: _provenance(
          runId: 'run-2',
          lifecycle: GridRosterImportLifecycle.committed,
        ),
        currentTargetRevision: 'revision-1',
      ),
      throwsA(isA<StateError>()),
    );

    final recovered = await journal.recover('schedule-1');
    expect(recovered?.generation, 1);
    expect(recovered?.provenance.importRunId, 'run-1');
  });

  test('prepared-only record is never returned as committed', () async {
    final prepared = _provenance(
      runId: 'run-1',
      lifecycle: GridRosterImportLifecycle.prepared,
    );
    final journalKey = store.values;
    journalKey['${GridRosterBundleJournal.storageKeyPrefix}c2NoZWR1bGUtMQ.a'] =
        jsonEncode({
      'format': 'shift-tools.grid-roster-bundle-journal',
      'version': 1,
      'state': 'prepared',
      'generation': 1,
      'schedule': const _SchedulePayloadPlaceholder(),
      'provenance': prepared.importRunId,
    });

    // A malformed PREPARED record is not accepted as a recovered bundle.
    await expectLater(
      journal.recover('schedule-1'),
      throwsA(isA<GridRosterBundleJournalException>()),
    );
  });
}
