import 'dart:convert';

import '../../../domain/entities/schedule.dart';
import '../../schedule/data/schedule_json_codec.dart';
import '../../schedule/data/shared_preferences_schedule_repository.dart';
import '../domain/grid_roster_import_provenance.dart';
import 'grid_roster_import_provenance_json_codec.dart';

/// A recovered, committed Schedule + provenance bundle.
class GridRosterBundleJournalSnapshot {
  const GridRosterBundleJournalSnapshot({
    required this.schedule,
    required this.provenance,
    required this.generation,
  });

  final Schedule schedule;
  final GridRosterImportProvenance provenance;
  final int generation;
}

/// A fail-closed journal error. No canonical Schedule is changed by this class.
class GridRosterBundleJournalException implements Exception {
  const GridRosterBundleJournalException(this.message);

  final String message;

  @override
  String toString() => 'GridRosterBundleJournalException: $message';
}

/// Stores Schedule and Grid provenance in one versioned journal record.
///
/// The journal uses two alternating records. It writes and reads back a
/// PREPARED record, then replaces that same inactive slot with COMMITTED.
/// Recovery selects the highest-generation valid COMMITTED record. A crash
/// before the committed record is verified leaves the previous committed
/// slot intact.
///
/// This is a recoverable two-slot protocol, NOT a database transaction and
/// NOT a guarantee of durable/atomic writes from SharedPreferences. The
/// caller must load/revalidate the target revision immediately before commit.
class GridRosterBundleJournal {
  GridRosterBundleJournal({
    required ScheduleKeyValueStore store,
    this.scheduleCodec = const ScheduleJsonCodec(),
    this.provenanceCodec = const GridRosterImportProvenanceJsonCodec(),
  }) : _store = store;

  static const storageKeyPrefix = 'shift_tools.grid_roster_bundle.v1.';
  static const _format = 'shift-tools.grid-roster-bundle-journal';
  static const _version = 1;

  final ScheduleKeyValueStore _store;
  final ScheduleJsonCodec scheduleCodec;
  final GridRosterImportProvenanceJsonCodec provenanceCodec;

  String _baseKey(String id) =>
      '$storageKeyPrefix${base64Url.encode(utf8.encode(id)).replaceAll('=', '')}';

  String _slotKey(String id, String slot) => '${_baseKey(id)}.$slot';

  /// Returns the newest committed bundle, ignoring an incomplete PREPARED
  /// record when an older committed generation is still available.
  Future<GridRosterBundleJournalSnapshot?> recover(String scheduleId) async {
    final records = await _readRecords(scheduleId);
    final committed = records
        .where((record) => record.state == 'committed')
        .toList()
      ..sort((left, right) => right.generation.compareTo(left.generation));
    if (committed.isNotEmpty) {
      final record = committed.first;
      return GridRosterBundleJournalSnapshot(
        schedule: record.schedule,
        provenance: record.provenance,
        generation: record.generation,
      );
    }
    if (records.isEmpty) return null;
    return null; // PREPARED-only journal is intentionally not accepted.
  }

  /// Commits a reviewed bundle after checking the caller's target revision.
  ///
  /// [preparedProvenance] must describe the reviewed run before acceptance;
  /// [committedProvenance] must be the same run with committed lifecycle and
  /// an accepted Schedule fingerprint.
  Future<GridRosterBundleJournalSnapshot> commit({
    required Schedule schedule,
    required GridRosterImportProvenance preparedProvenance,
    required GridRosterImportProvenance committedProvenance,
    required String currentTargetRevision,
  }) async {
    if (schedule.id != preparedProvenance.targetScheduleId ||
        schedule.id != committedProvenance.targetScheduleId) {
      throw const GridRosterBundleJournalException(
        'Schedule id does not match provenance target.',
      );
    }
    if (preparedProvenance.lifecycle != GridRosterImportLifecycle.prepared ||
        committedProvenance.lifecycle != GridRosterImportLifecycle.committed) {
      throw const GridRosterBundleJournalException(
        'Expected PREPARED and COMMITTED provenance lifecycle values.',
      );
    }
    if (preparedProvenance.importRunId != committedProvenance.importRunId ||
        preparedProvenance.sourceFingerprint !=
            committedProvenance.sourceFingerprint ||
        preparedProvenance.targetScheduleRevision !=
            committedProvenance.targetScheduleRevision) {
      throw const GridRosterBundleJournalException(
        'Prepared and committed provenance do not describe the same import run.',
      );
    }
    final expectedCommittedProvenance = GridRosterImportProvenance(
      importRunId: preparedProvenance.importRunId,
      sourceFingerprint: preparedProvenance.sourceFingerprint,
      parserVersion: preparedProvenance.parserVersion,
      createdAtUtc: preparedProvenance.createdAtUtc,
      targetScheduleId: preparedProvenance.targetScheduleId,
      targetScheduleRevision: preparedProvenance.targetScheduleRevision,
      lifecycle: GridRosterImportLifecycle.committed,
      acceptedScheduleFingerprint:
          committedProvenance.acceptedScheduleFingerprint,
      sections: preparedProvenance.sections,
      assignments: preparedProvenance.assignments,
      diagnostics: preparedProvenance.diagnostics,
    );
    if (provenanceCodec.encode(expectedCommittedProvenance) !=
        provenanceCodec.encode(committedProvenance)) {
      throw const GridRosterBundleJournalException(
        'Committed provenance must preserve every prepared review decision.',
      );
    }
    if (currentTargetRevision !=
        preparedProvenance.targetScheduleRevision) {
      throw const GridRosterBundleJournalException(
        'Target Schedule revision is stale; reload and review again.',
      );
    }

    final schedulePayload = scheduleCodec.encode(schedule);
    final existing = await recover(schedule.id);
    if (existing != null &&
        existing.provenance.importRunId == committedProvenance.importRunId) {
      final existingPayload = scheduleCodec.encode(existing.schedule);
      if (existingPayload == schedulePayload &&
          existing.provenance.acceptedScheduleFingerprint ==
              committedProvenance.acceptedScheduleFingerprint) {
        return existing; // Idempotent retry of the same accepted import.
      }
      throw const GridRosterBundleJournalException(
        'Import run id already exists with different committed content.',
      );
    }

    final records = await _readRecords(schedule.id);
    final latestGeneration = records.fold<int>(
      0,
      (highest, record) =>
          record.generation > highest ? record.generation : highest,
    );
    final latestCommitted = records
        .where((record) => record.state == 'committed')
        .fold<_JournalRecord?>(
          null,
          (latest, record) => latest == null ||
                  record.generation > latest.generation
              ? record
              : latest,
        );
    final latestPrepared = records
        .where((record) => record.state == 'prepared')
        .fold<_JournalRecord?>(
          null,
          (latest, record) => latest == null ||
                  record.generation > latest.generation
              ? record
              : latest,
        );
    final generation = latestGeneration + 1;
    // Never overwrite the last committed slot before a replacement has
    // itself been committed. Reuse an orphan PREPARED slot when present.
    final targetSlot = latestCommitted != null
        ? (latestCommitted.slot == 'a' ? 'b' : 'a')
        : (latestPrepared?.slot ?? 'a');

    final preparedRecord = _encodeRecord(
      state: 'prepared',
      generation: generation,
      schedulePayload: schedulePayload,
      provenancePayload: provenanceCodec.encode(preparedProvenance),
    );
    final key = _slotKey(schedule.id, targetSlot);
    await _store.setString(key, preparedRecord);
    final staged = await _store.getString(key);
    if (staged == null) {
      throw const GridRosterBundleJournalException(
        'Prepared bundle could not be read back.',
      );
    }
    final stagedRecord = _decodeRecord(staged, targetSlot);
    if (stagedRecord.state != 'prepared' ||
        stagedRecord.generation != generation ||
        stagedRecord.schedule.id != schedule.id) {
      throw const GridRosterBundleJournalException(
        'Prepared bundle read-back verification failed.',
      );
    }

    final committedRecord = _encodeRecord(
      state: 'committed',
      generation: generation,
      schedulePayload: schedulePayload,
      provenancePayload: provenanceCodec.encode(committedProvenance),
    );
    await _store.setString(key, committedRecord);
    final saved = await _store.getString(key);
    if (saved == null) {
      throw const GridRosterBundleJournalException(
        'Committed bundle could not be read back.',
      );
    }
    final verified = _decodeRecord(saved, targetSlot);
    if (verified.state != 'committed' ||
        verified.generation != generation ||
        verified.schedule.id != schedule.id ||
        verified.provenance.importRunId != committedProvenance.importRunId ||
        verified.provenance.acceptedScheduleFingerprint !=
            committedProvenance.acceptedScheduleFingerprint) {
      throw const GridRosterBundleJournalException(
        'Committed bundle read-back verification failed.',
      );
    }
    return GridRosterBundleJournalSnapshot(
      schedule: verified.schedule,
      provenance: verified.provenance,
      generation: verified.generation,
    );
  }

  Future<List<_JournalRecord>> _readRecords(String scheduleId) async {
    final records = <_JournalRecord>[];
    final errors = <Object>[];
    for (final slot in const ['a', 'b']) {
      final payload = await _store.getString(_slotKey(scheduleId, slot));
      if (payload == null) continue;
      try {
        records.add(_decodeRecord(payload, slot));
      } on Object catch (error) {
        errors.add(error);
      }
    }
    if (records.isEmpty && errors.isNotEmpty) {
      throw GridRosterBundleJournalException(
        'No valid journal slot could be decoded: ${errors.first}',
      );
    }
    return records;
  }

  String _encodeRecord({
    required String state,
    required int generation,
    required String schedulePayload,
    required String provenancePayload,
  }) => jsonEncode({
    'format': _format,
    'version': _version,
    'state': state,
    'generation': generation,
    'schedule': schedulePayload,
    'provenance': provenancePayload,
  });

  _JournalRecord _decodeRecord(String source, String slot) {
    final root = jsonDecode(source);
    if (root is! Map<String, Object?> ||
        root['format'] != _format ||
        root['version'] != _version) {
      throw const GridRosterBundleJournalException(
        'Journal record has an unsupported format or version.',
      );
    }
    final state = root['state'];
    final generation = root['generation'];
    final schedulePayload = root['schedule'];
    final provenancePayload = root['provenance'];
    if ((state != 'prepared' && state != 'committed') ||
        generation is! int ||
        generation < 1 ||
        schedulePayload is! String ||
        provenancePayload is! String) {
      throw const GridRosterBundleJournalException(
        'Journal record is missing valid required fields.',
      );
    }
    final schedule = scheduleCodec.decode(schedulePayload);
    final provenance = provenanceCodec.decode(provenancePayload);
    if (schedule.id != provenance.targetScheduleId ||
        (state == 'prepared' &&
            provenance.lifecycle != GridRosterImportLifecycle.prepared) ||
        (state == 'committed' &&
            provenance.lifecycle != GridRosterImportLifecycle.committed)) {
      throw const GridRosterBundleJournalException(
        'Journal record Schedule/provenance identity or lifecycle mismatch.',
      );
    }
    return _JournalRecord(
      slot: slot,
      state: state,
      generation: generation,
      schedule: schedule,
      provenance: provenance,
    );
  }
}

class _JournalRecord {
  const _JournalRecord({
    required this.slot,
    required this.state,
    required this.generation,
    required this.schedule,
    required this.provenance,
  });

  final String slot;
  final String state;
  final int generation;
  final Schedule schedule;
  final GridRosterImportProvenance provenance;
}
