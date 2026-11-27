import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/repositories/conditional_schedule_writer.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_repository.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_revision_source.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_import_workflow.dart';
import 'package:phakphum_calendar/features/shift_parser/data/backend_grid_roster_import_journal_gateway.dart';
import 'package:phakphum_calendar/features/schedule/data/shared_preferences_schedule_repository.dart';
import 'package:phakphum_calendar/features/shift_parser/data/grid_roster_bundle_journal.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/grid_roster_import_provenance.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';

class _MemoryStore implements ScheduleKeyValueStore, ScheduleKeyEnumerator {
  final Map<String, String> values = {};

  @override
  Future<Set<String>> getKeys() async => values.keys.toSet();

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _MemoryRepository
    implements
        ScheduleRepository,
        ScheduleRevisionSource,
        ConditionalScheduleWriter {
  Schedule? value;
  int generation = 0;

  @override
  String? currentRevisionFor(String scheduleId) =>
      value == null ? 'absent:$scheduleId' : 'v$generation';

  @override
  String? revisionForSnapshot(Schedule schedule) =>
      identical(value, schedule) ? 'v$generation' : null;

  @override
  String? revisionForAbsentSchedule(String scheduleId) =>
      value == null ? 'absent:$scheduleId' : null;

  @override
  Future<Result<Schedule?>> findById(String id) async =>
      Success(value?.id == id ? value : null);

  @override
  Future<Result<Schedule>> saveIfRevision(
    Schedule schedule,
    String expectedRevision,
  ) async {
    if (currentRevisionFor(schedule.id) != expectedRevision) {
      return const ValidationFailure('schedule revision conflict');
    }
    value = schedule;
    generation++;
    return Success(schedule);
  }

  @override
  Future<Result<Schedule>> save(Schedule schedule) async {
    value = schedule;
    generation++;
    return Success(schedule);
  }

  @override
  Future<Result<ScheduleMonth?>> loadMonth(
    String scheduleId,
    DateTime month,
  ) async =>
      Success(value?.id == scheduleId ? value?.month(month) : null);

  @override
  Future<Result<void>> delete(String id) async {
    value = null;
    generation++;
    return const Success(null);
  }
}

class _FailingRemoteJournal implements GridRosterImportJournalGateway {
  @override
  Future<List<String>> discoverScheduleIds() async =>
      throw StateError('remote journal unavailable');

  @override
  Future<void> appendPrepared({
    required String scheduleId,
    required GridRosterImportProvenance provenance,
  }) async =>
      throw StateError('remote journal unavailable');

  @override
  Future<void> appendCommitted({
    required Schedule schedule,
    required GridRosterImportProvenance provenance,
  }) async =>
      throw StateError('remote journal unavailable');

  @override
  Future<GridRosterBundleJournalSnapshot?> recover(String scheduleId) async =>
      throw StateError('remote journal unavailable');
}

void main() {
  const scheduleId = 'schedule-recovery-test';
  final createdAt = DateTime.utc(2026, 11, 27);

  late _MemoryStore store;
  late _MemoryRepository repository;
  late GridRosterBundleJournal journal;
  late GridRosterImportWorkflow workflow;

  setUp(() {
    store = _MemoryStore();
    repository = _MemoryRepository();
    journal = GridRosterBundleJournal(store: store);
    workflow = GridRosterImportWorkflow(
      scheduleRepository: repository,
      journal: journal,
    );
  });

  Future<void> writeCommittedJournal(
    Schedule candidate, {
    String importRunId = 'recovery-run-1',
  }) async {
    final expectedRevision = repository.revisionForAbsentSchedule(scheduleId)!;
    final prepared = GridRosterImportProvenance(
      importRunId: importRunId,
      sourceFingerprint: 'sha256:source',
      parserVersion: 'grid-parser/1',
      createdAtUtc: createdAt,
      targetScheduleId: scheduleId,
      targetScheduleRevision: expectedRevision,
      lifecycle: GridRosterImportLifecycle.prepared,
      sections: const [],
      assignments: const [],
      diagnostics: const [],
    );
    final committed = GridRosterImportProvenance(
      importRunId: prepared.importRunId,
      sourceFingerprint: prepared.sourceFingerprint,
      parserVersion: prepared.parserVersion,
      createdAtUtc: prepared.createdAtUtc,
      targetScheduleId: prepared.targetScheduleId,
      targetScheduleRevision: prepared.targetScheduleRevision,
      lifecycle: GridRosterImportLifecycle.committed,
      acceptedScheduleFingerprint: workflow.scheduleFingerprint(candidate),
      sections: const [],
      assignments: const [],
      diagnostics: const [],
    );
    await journal.commit(
      schedule: candidate,
      preparedProvenance: prepared,
      committedProvenance: committed,
      currentTargetRevision: expectedRevision,
    );
  }

  test('reports an empty journal without writing the canonical Schedule', () async {
    final result = await workflow.inspectRecovery(scheduleId);

    expect(result, isA<Success<GridRosterRecoveryAssessment>>());
    final assessment = (result as Success<GridRosterRecoveryAssessment>).value;
    expect(
      assessment.disposition,
      GridRosterRecoveryDisposition.noCommittedBundle,
    );
    expect(repository.value, isNull);
  });

  test('returns a read-only ready assessment for a committed journal', () async {
    final candidate = Schedule(id: scheduleId, name: 'Recovered roster');
    await writeCommittedJournal(candidate);

    final result = await workflow.inspectRecovery(scheduleId);

    expect(result, isA<Success<GridRosterRecoveryAssessment>>());
    final assessment = (result as Success<GridRosterRecoveryAssessment>).value;
    expect(assessment.disposition, GridRosterRecoveryDisposition.ready);
    expect(assessment.canRecover, isTrue);
    expect(assessment.candidateSchedule?.name, 'Recovered roster');
    expect(assessment.expectedRevision, 'absent:$scheduleId');
    expect(repository.value, isNull);
  });

  test('reports conflict instead of offering stale journal replay', () async {
    final candidate = Schedule(id: scheduleId, name: 'Journal candidate');
    await writeCommittedJournal(candidate);
    await repository.save(
      Schedule(id: scheduleId, name: 'Newer canonical roster'),
    );

    final result = await workflow.inspectRecovery(scheduleId);

    expect(result, isA<Success<GridRosterRecoveryAssessment>>());
    final assessment = (result as Success<GridRosterRecoveryAssessment>).value;
    expect(assessment.disposition, GridRosterRecoveryDisposition.conflict);
    expect(assessment.canRecover, isFalse);
    expect(repository.value?.name, 'Newer canonical roster');
  });

  test('recognizes a journal already applied to canonical storage', () async {
    final candidate = Schedule(id: scheduleId, name: 'Recovered roster');
    await writeCommittedJournal(candidate);
    await repository.save(candidate);

    final result = await workflow.inspectRecovery(scheduleId);

    expect(result, isA<Success<GridRosterRecoveryAssessment>>());
    final assessment = (result as Success<GridRosterRecoveryAssessment>).value;
    expect(
      assessment.disposition,
      GridRosterRecoveryDisposition.alreadyApplied,
    );
    expect(assessment.canRecover, isFalse);
  });

  test('blocks a new import review while a committed journal is unresolved', () async {
    await writeCommittedJournal(
      Schedule(id: scheduleId, name: 'Pending recovery'),
    );

    final result = await workflow.prepareReview(
      report: MonthlyRosterParseReport(
        sections: [
          MonthlyRosterSection(
            title: 'Detected section',
            headerRowIndex: 0,
            assignments: const [],
          ),
        ],
        warnings: const [],
        sourceFingerprint: 'sha256:workbook',
      ),
      targetScheduleId: scheduleId,
      targetScheduleName: 'Replacement import',
      employees: const [],
      shiftTemplates: const [],
    );

    expect(
      result,
      isA<ValidationFailure<GridRosterImportReviewContext>>(),
    );
    expect(repository.value, isNull);
  });

  test('rejects a journal replaced after the reviewer inspected it', () async {
    final reviewedCandidate =
        Schedule(id: scheduleId, name: 'Reviewed candidate');
    await writeCommittedJournal(reviewedCandidate);
    final inspected = await workflow.inspectRecovery(scheduleId);
    expect(inspected, isA<Success<GridRosterRecoveryAssessment>>());
    final assessment =
        (inspected as Success<GridRosterRecoveryAssessment>).value;

    await writeCommittedJournal(
      Schedule(id: scheduleId, name: 'Replacement candidate'),
      importRunId: 'recovery-run-2',
    );

    final recovered = await workflow.recoverAssessment(assessment);

    expect(recovered, isA<ValidationFailure<Schedule?>>());
    expect(repository.value, isNull);
  });

  test('does not treat remote journal failure as an empty journal', () async {
    final failingWorkflow = GridRosterImportWorkflow(
      scheduleRepository: repository,
      journal: journal,
      remoteJournalGateway: _FailingRemoteJournal(),
    );

    final result = await failingWorkflow.inspectRecovery(scheduleId);

    expect(result, isA<ValidationFailure<GridRosterRecoveryAssessment>>());
    expect(repository.value, isNull);
  });
}
