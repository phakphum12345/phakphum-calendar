import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/repositories/conditional_schedule_writer.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_repository.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_revision_source.dart';
import 'package:phakphum_calendar/features/schedule/data/schedule_service.dart';
import 'package:phakphum_calendar/features/schedule/presentation/controllers/schedule_controller.dart';

void main() {
  test('two editors loaded at one revision cannot both overwrite the Schedule', () async {
    final initial = Schedule(id: 'roster-1', name: 'November');
    final repository = _RevisionRepository(initial);
    final first = ScheduleController(
      service: ScheduleService(schedule: initial),
      repository: repository,
    );
    final second = ScheduleController(
      service: ScheduleService(schedule: initial),
      repository: repository,
    );

    final firstSave = await first.saveSchedule();
    final secondSave = await second.saveSchedule();

    expect(firstSave, isA<Success<Schedule>>());
    expect(secondSave, isA<NetworkFailure<Schedule>>());
    expect((secondSave as NetworkFailure<Schedule>).statusCode, 409);
    expect(repository.saveCount, 1);
  });
}

class _RevisionRepository
    implements ScheduleRepository, ConditionalScheduleWriter, ScheduleRevisionSource {
  _RevisionRepository(this.schedule);

  Schedule schedule;
  String revision = 'revision-1';
  int saveCount = 0;

  @override
  String? currentRevisionFor(String scheduleId) =>
      scheduleId == schedule.id ? revision : null;

  @override
  String? revisionForSnapshot(Schedule snapshot) =>
      snapshot.id == schedule.id && snapshot.name == schedule.name
          ? 'revision-1'
          : null;

  @override
  String? revisionForAbsentSchedule(String scheduleId) => null;

  @override
  Future<Result<Schedule?>> findById(String id) async =>
      id == schedule.id ? Success(schedule) : const Success(null);

  @override
  Future<Result<ScheduleMonth?>> loadMonth(String scheduleId, DateTime month) async =>
      const Success(null);

  @override
  Future<Result<Schedule>> save(Schedule value) async =>
      const PersistenceFailure('Unconditional save is disabled in this test.');

  @override
  Future<Result<Schedule>> saveIfRevision(
    Schedule value,
    String expectedRevision,
  ) async {
    if (expectedRevision != revision) {
      return const NetworkFailure(
        'Schedule revision conflict.',
        statusCode: 409,
      );
    }
    saveCount++;
    schedule = value;
    revision = 'revision-2';
    return Success(value);
  }

  @override
  Future<Result<void>> delete(String id) async => const Success(null);
}
