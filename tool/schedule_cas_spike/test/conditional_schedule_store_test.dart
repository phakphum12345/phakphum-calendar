import 'dart:io';

import 'package:drift/native.dart';
import 'package:schedule_cas_spike/conditional_schedule_store.dart';
import 'package:schedule_cas_spike/spike_database.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDirectory;
  late File databaseFile;
  late SpikeDatabase database;
  late ConditionalScheduleStore store;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('schedule-cas-');
    databaseFile = File('${tempDirectory.path}/schedule.sqlite');
    database = SpikeDatabase(NativeDatabase.createInBackground(databaseFile));
    store = ConditionalScheduleStore(database);
    await database.customStatement('PRAGMA busy_timeout = 5000');
  });

  tearDown(() async {
    await database.close();
    await tempDirectory.delete(recursive: true);
  });

  test('creates from absent and rejects stale create', () async {
    final absent = await store.read('schedule-A');
    expect(
      absent.revision.token,
      ScheduleRevision.absentFor('schedule-A').token,
    );

    final created = await store.compareAndSet(
      scheduleId: 'schedule-A',
      expected: absent.revision,
      replacementPayload: '{"value":"A"}',
    );
    expect(created.status, ConditionalWriteStatus.saved);
    expect(created.current.revision.generation, 1);

    final staleCreate = await store.compareAndSet(
      scheduleId: 'schedule-A',
      expected: ScheduleRevision.absentFor('schedule-A'),
      replacementPayload: '{"value":"intruder"}',
    );
    expect(staleCreate.status, ConditionalWriteStatus.conflict);
    expect(staleCreate.current.payload, '{"value":"A"}');
  });

  test('revision tokens are scoped to their Schedule ID', () async {
    final created = await store.compareAndSet(
      scheduleId: 'schedule-source',
      expected: ScheduleRevision.absentFor('schedule-source'),
      replacementPayload: '{"value":"source"}',
    );
    expect(created.status, ConditionalWriteStatus.saved);
    expect(
      created.current.revision.token,
      isNot(ScheduleRevision.absentFor('schedule-other').token),
    );

    final crossScheduleWrite = await store.compareAndSet(
      scheduleId: 'schedule-other',
      expected: created.current.revision,
      replacementPayload: '{"value":"must-not-write"}',
    );
    expect(crossScheduleWrite.status, ConditionalWriteStatus.conflict);
    expect(crossScheduleWrite.current.revision.state, RevisionState.absent);
    expect(crossScheduleWrite.current.revision.scheduleId, 'schedule-other');

    final crossScheduleDelete = await store.delete(
      scheduleId: 'schedule-other',
      expected: created.current.revision,
    );
    expect(crossScheduleDelete.status, ConditionalWriteStatus.conflict);
    expect(crossScheduleDelete.current.revision.state, RevisionState.absent);
  });

  test('rejects stale update without changing the payload', () async {
    final first = await store.compareAndSet(
      scheduleId: 'schedule-B',
      expected: ScheduleRevision.absentFor('schedule-B'),
      replacementPayload: '{"value":"one"}',
    );
    final staleRevision = first.current.revision;

    final update = await store.compareAndSet(
      scheduleId: 'schedule-B',
      expected: staleRevision,
      replacementPayload: '{"value":"two"}',
    );
    expect(update.status, ConditionalWriteStatus.saved);

    final stale = await store.compareAndSet(
      scheduleId: 'schedule-B',
      expected: staleRevision,
      replacementPayload: '{"value":"stale"}',
    );
    expect(stale.status, ConditionalWriteStatus.conflict);
    expect(stale.current.payload, '{"value":"two"}');
  });

  test('generation prevents ABA and advances on same-content save', () async {
    final a1 = await store.compareAndSet(
      scheduleId: 'schedule-C',
      expected: ScheduleRevision.absentFor('schedule-C'),
      replacementPayload: '{"value":"A"}',
    );
    final b = await store.compareAndSet(
      scheduleId: 'schedule-C',
      expected: a1.current.revision,
      replacementPayload: '{"value":"B"}',
    );
    final a2 = await store.compareAndSet(
      scheduleId: 'schedule-C',
      expected: b.current.revision,
      replacementPayload: '{"value":"A"}',
    );

    expect(a2.current.revision.fingerprint, a1.current.revision.fingerprint);
    expect(a2.current.revision.generation, 3);
    expect(a2.current.revision.token, isNot(a1.current.revision.token));

    final sameContent = await store.compareAndSet(
      scheduleId: 'schedule-C',
      expected: a2.current.revision,
      replacementPayload: '{"value":"A"}',
    );
    expect(sameContent.status, ConditionalWriteStatus.saved);
    expect(sameContent.current.revision.generation, 4);
  });

  test('tombstone blocks stale recreation', () async {
    final created = await store.compareAndSet(
      scheduleId: 'schedule-D',
      expected: ScheduleRevision.absentFor('schedule-D'),
      replacementPayload: '{"value":"live"}',
    );
    final deleted = await store.delete(
      scheduleId: 'schedule-D',
      expected: created.current.revision,
    );
    expect(deleted.status, ConditionalWriteStatus.saved);
    expect(deleted.current.revision.state, RevisionState.deleted);
    expect(deleted.current.payload, isNull);

    final staleRecreate = await store.compareAndSet(
      scheduleId: 'schedule-D',
      expected: created.current.revision,
      replacementPayload: '{"value":"stale-recreate"}',
    );
    expect(staleRecreate.status, ConditionalWriteStatus.conflict);

    final recreated = await store.compareAndSet(
      scheduleId: 'schedule-D',
      expected: deleted.current.revision,
      replacementPayload: '{"value":"new-life"}',
    );
    expect(recreated.status, ConditionalWriteStatus.saved);
    expect(recreated.current.revision.generation, 3);
  });

  test('stale token cannot recreate a missing row', () async {
    final created = await store.compareAndSet(
      scheduleId: 'schedule-missing',
      expected: ScheduleRevision.absentFor('schedule-missing'),
      replacementPayload: '{"value":"created"}',
    );
    await database.customStatement(
      'DELETE FROM schedule_records WHERE schedule_id = ?',
      ['schedule-missing'],
    );

    final stale = await store.compareAndSet(
      scheduleId: 'schedule-missing',
      expected: created.current.revision,
      replacementPayload: '{"value":"must-not-resurrect"}',
    );
    expect(stale.status, ConditionalWriteStatus.conflict);
    expect(stale.current.revision.state, RevisionState.absent);
  });

  test('committed revision survives database close and reopen', () async {
    final saved = await store.compareAndSet(
      scheduleId: 'schedule-reopen',
      expected: ScheduleRevision.absentFor('schedule-reopen'),
      replacementPayload: '{"value":"durable"}',
    );
    expect(saved.status, ConditionalWriteStatus.saved);

    await database.close();
    database = SpikeDatabase(NativeDatabase.createInBackground(databaseFile));
    store = ConditionalScheduleStore(database);

    final reopened = await store.read('schedule-reopen');
    expect(reopened.payload, '{"value":"durable"}');
    expect(reopened.revision.token, saved.current.revision.token);
  });

  test('two independent instances have one CAS winner', () async {
    final secondDatabase = SpikeDatabase(
      NativeDatabase.createInBackground(databaseFile),
    );
    try {
      final secondStore = ConditionalScheduleStore(secondDatabase);
      await secondDatabase.customStatement('PRAGMA busy_timeout = 5000');

      final concurrentCreates = await Future.wait([
        store.compareAndSet(
          scheduleId: 'schedule-F',
          expected: ScheduleRevision.absentFor('schedule-F'),
          replacementPayload: '{"creator":"one"}',
        ),
        secondStore.compareAndSet(
          scheduleId: 'schedule-F',
          expected: ScheduleRevision.absentFor('schedule-F'),
          replacementPayload: '{"creator":"two"}',
        ),
      ]);
      expect(
        concurrentCreates
            .where((r) => r.status == ConditionalWriteStatus.saved)
            .length,
        1,
      );
      expect(
        concurrentCreates
            .where((r) => r.status == ConditionalWriteStatus.conflict)
            .length,
        1,
      );

      final seed = await store.compareAndSet(
        scheduleId: 'schedule-E',
        expected: ScheduleRevision.absentFor('schedule-E'),
        replacementPayload: '{"value":"seed"}',
      );
      final sharedRevision = seed.current.revision;

      final results = await Future.wait([
        store.compareAndSet(
          scheduleId: 'schedule-E',
          expected: sharedRevision,
          replacementPayload: '{"writer":"one"}',
        ),
        secondStore.compareAndSet(
          scheduleId: 'schedule-E',
          expected: sharedRevision,
          replacementPayload: '{"writer":"two"}',
        ),
      ]);

      expect(
        results.where((r) => r.status == ConditionalWriteStatus.saved).length,
        1,
      );
      expect(
        results
            .where((r) => r.status == ConditionalWriteStatus.conflict)
            .length,
        1,
      );
    } finally {
      await secondDatabase.close();
    }
  });
}
