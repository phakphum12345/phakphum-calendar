import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'spike_database.dart';

enum RevisionState { absent, live, deleted }

class ScheduleRevision {
  const ScheduleRevision({
    required this.scheduleId,
    required this.generation,
    required this.state,
    required this.fingerprint,
  });

  final String scheduleId;
  final int generation;
  final RevisionState state;
  final String? fingerprint;

  String get token =>
      'schedule-revision:v1:${Uri.encodeComponent(scheduleId)}:'
      '$generation:${state.name}:${fingerprint ?? '-'}';

  static ScheduleRevision absentFor(String scheduleId) => ScheduleRevision(
        scheduleId: scheduleId,
        generation: 0,
        state: RevisionState.absent,
        fingerprint: null,
      );
}

class ScheduleSnapshot {
  const ScheduleSnapshot({required this.payload, required this.revision});

  final String? payload;
  final ScheduleRevision revision;
}

enum ConditionalWriteStatus { saved, conflict, storageFailure }

class ConditionalWriteResult {
  const ConditionalWriteResult({
    required this.status,
    required this.current,
    this.error,
  });

  final ConditionalWriteStatus status;
  final ScheduleSnapshot current;
  final String? error;
}

class ConditionalScheduleStore {
  ConditionalScheduleStore(this.database);

  final SpikeDatabase database;

  static String fingerprintOf(String payload) =>
      sha256.convert(utf8.encode(payload)).toString();

  Future<ScheduleSnapshot> _readAfterFailure(
    String scheduleId,
    ScheduleRevision lastKnownRevision,
  ) async {
    try {
      return await read(scheduleId);
    } catch (_) {
      // The status remains storageFailure; this is only the last known token,
      // not a claim that storage currently contains this revision.
      return ScheduleSnapshot(payload: null, revision: lastKnownRevision);
    }
  }

  Future<ScheduleSnapshot> read(String scheduleId) async {
    final rows = await database
        .customSelect(
          'SELECT generation, state, payload, fingerprint '
          'FROM schedule_records WHERE schedule_id = ?',
          variables: [Variable.withString(scheduleId)],
        )
        .get();

    if (rows.isEmpty) {
      return ScheduleSnapshot(
        payload: null,
        revision: ScheduleRevision.absentFor(scheduleId),
      );
    }

    final row = rows.single;
    final state = RevisionState.values.byName(row.read<String>('state'));
    return ScheduleSnapshot(
      payload: row.readNullable<String>('payload'),
      revision: ScheduleRevision(
        scheduleId: scheduleId,
        generation: row.read<int>('generation'),
        state: state,
        fingerprint: row.readNullable<String>('fingerprint'),
      ),
    );
  }

  /// A single SQLite UPSERT is the compare-and-write boundary.
  ///
  /// The conflict branch updates only if every part of the expected revision
  /// still matches. The unique primary key arbitrates concurrent creates.
  /// No read-then-write sequence or process-local mutex is used.
  Future<ConditionalWriteResult> compareAndSet({
    required String scheduleId,
    required ScheduleRevision expected,
    required String replacementPayload,
  }) async {
    if (expected.scheduleId != scheduleId) {
      return ConditionalWriteResult(
        status: ConditionalWriteStatus.conflict,
        current: await read(scheduleId),
      );
    }
    final fingerprint = fingerprintOf(replacementPayload);
    try {
      final rows = await database
          .customSelect(
            '''
        INSERT INTO schedule_records
          (schedule_id, generation, state, payload, fingerprint)
        SELECT ?, ?, 'live', ?, ?
        WHERE (? = 0 AND ? = 'absent')
           OR EXISTS (
             SELECT 1 FROM schedule_records
             WHERE schedule_id = ?
           )
        ON CONFLICT(schedule_id) DO UPDATE SET
          generation = schedule_records.generation + 1,
          state = 'live',
          payload = excluded.payload,
          fingerprint = excluded.fingerprint
        WHERE schedule_records.generation = ?
          AND schedule_records.state = ?
          AND COALESCE(schedule_records.fingerprint, '') = ?
        RETURNING generation, state, payload, fingerprint
        ''',
            variables: [
              Variable.withString(scheduleId),
              Variable.withInt(expected.generation + 1),
              Variable.withString(replacementPayload),
              Variable.withString(fingerprint),
              Variable.withInt(expected.generation),
              Variable.withString(expected.state.name),
              Variable.withString(scheduleId),
              Variable.withInt(expected.generation),
              Variable.withString(expected.state.name),
              Variable.withString(expected.fingerprint ?? ''),
            ],
          )
          .get();

      if (rows.isNotEmpty) {
        final row = rows.single;
        return ConditionalWriteResult(
          status: ConditionalWriteStatus.saved,
          current: ScheduleSnapshot(
            payload: row.readNullable<String>('payload'),
            revision: ScheduleRevision(
              scheduleId: scheduleId,
              generation: row.read<int>('generation'),
              state: RevisionState.values.byName(row.read<String>('state')),
              fingerprint: row.readNullable<String>('fingerprint'),
            ),
          ),
        );
      }

      return ConditionalWriteResult(
        status: ConditionalWriteStatus.conflict,
        current: await read(scheduleId),
      );
    } catch (error) {
      return ConditionalWriteResult(
        status: ConditionalWriteStatus.storageFailure,
        current: await _readAfterFailure(scheduleId, expected),
        error: error.toString(),
      );
    }
  }

  /// Deletion preserves the revision identity as a tombstone.
  Future<ConditionalWriteResult> delete({
    required String scheduleId,
    required ScheduleRevision expected,
  }) async {
    if (expected.scheduleId != scheduleId) {
      return ConditionalWriteResult(
        status: ConditionalWriteStatus.conflict,
        current: await read(scheduleId),
      );
    }
    try {
      final rows = await database
          .customSelect(
            '''
        UPDATE schedule_records
        SET generation = generation + 1,
            state = 'deleted',
            payload = NULL,
            fingerprint = NULL
        WHERE schedule_id = ?
          AND generation = ?
          AND state = 'live'
          AND COALESCE(fingerprint, '') = ?
        RETURNING generation, state, payload, fingerprint
        ''',
            variables: [
              Variable.withString(scheduleId),
              Variable.withInt(expected.generation),
              Variable.withString(expected.fingerprint ?? ''),
            ],
          )
          .get();

      if (rows.isNotEmpty) {
        final row = rows.single;
        return ConditionalWriteResult(
          status: ConditionalWriteStatus.saved,
          current: ScheduleSnapshot(
            payload: row.readNullable<String>('payload'),
            revision: ScheduleRevision(
              scheduleId: scheduleId,
              generation: row.read<int>('generation'),
              state: RevisionState.values.byName(row.read<String>('state')),
              fingerprint: row.readNullable<String>('fingerprint'),
            ),
          ),
        );
      }

      return ConditionalWriteResult(
        status: ConditionalWriteStatus.conflict,
        current: await read(scheduleId),
      );
    } catch (error) {
      return ConditionalWriteResult(
        status: ConditionalWriteStatus.storageFailure,
        current: await _readAfterFailure(scheduleId, expected),
        error: error.toString(),
      );
    }
  }
}
