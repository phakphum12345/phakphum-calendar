import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/repositories/conditional_schedule_writer.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_revision_source.dart';
import 'package:phakphum_calendar/features/schedule/data/shared_preferences_schedule_repository.dart';

import 'support/canonical_schedule_fixture.dart';
import 'support/in_memory_schedule_store.dart';

void main() {
  test(
    'saving then loading returns an equivalent canonical Schedule',
    () async {
      final repository = SharedPreferencesScheduleRepository(
        store: InMemoryScheduleKeyValueStore(),
      );
      final schedule = canonicalScheduleFixture();

      final saved = await repository.save(schedule);
      final loaded = await repository.findById(schedule.id);
      final july = await repository.loadMonth(schedule.id, DateTime(2026, 7));

      expect(saved, isA<Success<Schedule>>());
      expect(loaded, isA<Success<Schedule?>>());
      expect(
        canonicalScheduleValues((loaded as Success<Schedule?>).value!),
        canonicalScheduleValues(schedule),
      );
      expect(july, isA<Success>());
      expect(
        (july as Success).value.day(DateTime(2026, 7, 24))!.assignments,
        hasLength(1),
      );
    },
  );

  test('missing stored data is a successful not-found result', () async {
    final repository = SharedPreferencesScheduleRepository(
      store: InMemoryScheduleKeyValueStore(),
    );

    final result = await repository.findById('missing');

    expect(result, isA<Success<Schedule?>>());
    expect((result as Success<Schedule?>).value, isNull);
  });

  test('malformed active data produces a controlled failure', () async {
    final store = InMemoryScheduleKeyValueStore();
    final repository = SharedPreferencesScheduleRepository(store: store);
    final schedule = canonicalScheduleFixture();
    await repository.save(schedule);
    final keys = store.values.keys;
    final activeKey = keys.singleWhere((key) => key.endsWith('.active'));
    final activeSlot = store.values[activeKey];
    final slotKey = keys.singleWhere(
      (key) => key.endsWith('.slot.$activeSlot'),
    );
    store.values[slotKey] = '{malformed';

    final result = await repository.findById(schedule.id);

    expect(result, isA<ValidationFailure<Schedule?>>());
  });

  test(
    'failed pointer write preserves the previously valid schedule',
    () async {
      final store = InMemoryScheduleKeyValueStore();
      final repository = SharedPreferencesScheduleRepository(store: store);
      final original = canonicalScheduleFixture(name: 'Original');
      expect(await repository.save(original), isA<Success<Schedule>>());
      store.failActivePointerWrites = true;

      final failed = await repository.save(
        canonicalScheduleFixture(name: 'Replacement'),
      );
      final loaded = await repository.findById(original.id);

      expect(failed, isA<PersistenceFailure<Schedule>>());
      expect((loaded as Success<Schedule?>).value!.name, 'Original');
    },
  );

  test(
    'multiple successful saves replace the active schedule predictably',
    () async {
      final repository = SharedPreferencesScheduleRepository(
        store: InMemoryScheduleKeyValueStore(),
      );
      await repository.save(canonicalScheduleFixture(name: 'First'));

      final second = await repository.save(
        canonicalScheduleFixture(name: 'Second'),
      );
      final loaded = await repository.findById('schedule-1');

      expect(second, isA<Success<Schedule>>());
      expect((loaded as Success<Schedule?>).value!.name, 'Second');
    },
  );

  test('conditional writes reject stale revisions after a newer local save', () async {
    final repository = SharedPreferencesScheduleRepository(
      store: InMemoryScheduleKeyValueStore(),
    );
    final revisionSource = repository as ScheduleRevisionSource;
    final writer = repository as ConditionalScheduleWriter;
    await repository.findById('schedule-1');
    final absentRevision = revisionSource.revisionForAbsentSchedule('schedule-1')!;

    final created = await writer.saveIfRevision(
      canonicalScheduleFixture(name: 'First'),
      absentRevision,
    );
    expect(created, isA<Success<Schedule>>());

    final loaded = await repository.findById('schedule-1');
    final snapshot = (loaded as Success<Schedule?>).value!;
    final revision = revisionSource.revisionForSnapshot(snapshot)!;
    final updated = await writer.saveIfRevision(
      canonicalScheduleFixture(name: 'Second'),
      revision,
    );
    final stale = await writer.saveIfRevision(
      canonicalScheduleFixture(name: 'Stale overwrite'),
      revision,
    );

    expect(updated, isA<Success<Schedule>>());
    expect(stale, isA<ValidationFailure<Schedule>>());
    final latest = await repository.findById('schedule-1');
    expect((latest as Success<Schedule?>).value!.name, 'Second');
  });

  test('concurrent writers using one absent revision cannot both create', () async {
    final store = InMemoryScheduleKeyValueStore();
    final firstRepository = SharedPreferencesScheduleRepository(store: store);
    final secondRepository = SharedPreferencesScheduleRepository(store: store);
    final firstWriter = firstRepository as ConditionalScheduleWriter;
    final secondWriter = secondRepository as ConditionalScheduleWriter;
    final revisionSource = firstRepository as ScheduleRevisionSource;
    await firstRepository.findById('schedule-1');
    final absentRevision = revisionSource.revisionForAbsentSchedule('schedule-1')!;

    final results = await Future.wait([
      firstWriter.saveIfRevision(
        canonicalScheduleFixture(name: 'Writer A'),
        absentRevision,
      ),
      secondWriter.saveIfRevision(
        canonicalScheduleFixture(name: 'Writer B'),
        absentRevision,
      ),
    ]);

    expect(results.whereType<Success<Schedule>>(), hasLength(1));
    expect(results.whereType<ValidationFailure<Schedule>>(), hasLength(1));
    final latest = await repository.findById('schedule-1');
    expect(
      ['Writer A', 'Writer B'],
      contains((latest as Success<Schedule?>).value!.name),
    );
  });

  test('delete and recreate advances the absent revision to prevent ABA', () async {
    final repository = SharedPreferencesScheduleRepository(
      store: InMemoryScheduleKeyValueStore(),
    );
    final writer = repository as ConditionalScheduleWriter;
    final revisionSource = repository as ScheduleRevisionSource;
    await repository.findById('schedule-1');
    final originalAbsent = revisionSource.revisionForAbsentSchedule('schedule-1')!;

    expect(
      await writer.saveIfRevision(
        canonicalScheduleFixture(name: 'Original'),
        originalAbsent,
      ),
      isA<Success<Schedule>>(),
    );
    expect(await repository.delete('schedule-1'), isA<Success<void>>());
    await repository.findById('schedule-1');
    final newAbsent = revisionSource.revisionForAbsentSchedule('schedule-1')!;

    expect(newAbsent, isNot(originalAbsent));
    expect(
      await writer.saveIfRevision(
        canonicalScheduleFixture(name: 'Stale recreate'),
        originalAbsent,
      ),
      isA<ValidationFailure<Schedule>>(),
    );
  });

  test('failed pointer switch advances the revision and rejects stale writers', () async {
    final store = InMemoryScheduleKeyValueStore();
    final repository = SharedPreferencesScheduleRepository(store: store);
    final writer = repository as ConditionalScheduleWriter;
    final revisionSource = repository as ScheduleRevisionSource;
    final original = canonicalScheduleFixture(name: 'Original');
    await repository.save(original);
    final loaded = await repository.findById(original.id);
    final snapshot = (loaded as Success<Schedule?>).value!;
    final staleRevision = revisionSource.revisionForSnapshot(snapshot)!;

    store.failActivePointerWrites = true;
    final failed = await writer.saveIfRevision(
      canonicalScheduleFixture(name: 'Replacement'),
      staleRevision,
    );
    store.failActivePointerWrites = false;

    expect(failed, isA<PersistenceFailure<Schedule>>());
    final stillActive = await repository.findById(original.id);
    expect((stillActive as Success<Schedule?>).value!.name, 'Original');
    final latestRevision = revisionSource.revisionForSnapshot(
      (stillActive as Success<Schedule?>).value!,
    )!;
    expect(latestRevision, isNot(staleRevision));
    expect(
      await writer.saveIfRevision(
        canonicalScheduleFixture(name: 'Stale overwrite'),
        staleRevision,
      ),
      isA<ValidationFailure<Schedule>>(),
    );
  });

  test('repository keys use a dedicated non-legacy prefix', () async {
    final store = InMemoryScheduleKeyValueStore();
    final repository = SharedPreferencesScheduleRepository(store: store);

    await repository.save(canonicalScheduleFixture());
    final keys = store.values.keys;

    expect(keys, isNotEmpty);
    expect(
      keys.every(
        (key) => key.startsWith(
          SharedPreferencesScheduleRepository.storageKeyPrefix,
        ),
      ),
      isTrue,
    );
    expect(keys.any((key) => key == 'source_url'), isFalse);
    expect(keys.any((key) => key == 'saved_sheets'), isFalse);
  });
}
