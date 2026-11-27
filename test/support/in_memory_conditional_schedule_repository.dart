import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_repository.dart';
import 'package:phakphum_calendar/domain/repositories/conditional_schedule_writer.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_revision_source.dart';

/// Deterministic in-memory CAS repository for tests.
///
/// It models caller-owned snapshot revisions and an absent-state token. It is
/// intentionally single-process and must not be used as evidence of backend
/// or cross-device atomicity.
class InMemoryConditionalScheduleRepository
    implements
        ScheduleRepository,
        ScheduleRevisionSource,
        ConditionalScheduleWriter {
  final Map<String, Schedule> _schedules = {};
  final Map<String, String> _revisions = {};
  final Map<String, String> _absentRevisions = {};
  final Map<Schedule, String> _snapshotRevisions =
      Map<Schedule, String>.identity();

  final List<Schedule> saved = [];
  int _generation = 0;

  void seed(Schedule schedule) {
    final revision = _nextRevision(schedule.id);
    _schedules[schedule.id] = schedule;
    _revisions[schedule.id] = revision;
    _absentRevisions.remove(schedule.id);
    _snapshotRevisions[schedule] = revision;
  }

  String _nextRevision(String scheduleId) =>
      'test:$scheduleId:${++_generation}';

  String _absentRevision(String scheduleId) =>
      _absentRevisions.putIfAbsent(
        scheduleId,
        () => 'absent:$scheduleId:$_generation',
      );

  @override
  String? currentRevisionFor(String scheduleId) =>
      _revisions[scheduleId] ?? _absentRevision(scheduleId);

  @override
  String? revisionForSnapshot(Schedule schedule) =>
      _snapshotRevisions[schedule];

  @override
  String? revisionForAbsentSchedule(String scheduleId) {
    if (_schedules.containsKey(scheduleId)) return null;
    return _absentRevision(scheduleId);
  }

  @override
  Future<Result<Schedule?>> findById(String id) async {
    final schedule = _schedules[id];
    if (schedule == null) {
      _absentRevision(id);
      return const Success<Schedule?>(null);
    }
    final revision = _revisions[id]!;
    _snapshotRevisions[schedule] = revision;
    return Success<Schedule?>(schedule);
  }

  @override
  Future<Result<ScheduleMonth?>> loadMonth(
    String scheduleId,
    DateTime month,
  ) async {
    final result = await findById(scheduleId);
    return switch (result) {
      Success<Schedule?>(value: final schedule) =>
        Success<ScheduleMonth?>(schedule?.month(month)),
      Failure<Schedule?>() => PersistenceFailure<ScheduleMonth?>(
          result.message,
          cause: result,
        ),
    };
  }

  @override
  Future<Result<Schedule>> saveIfRevision(
    Schedule schedule,
    String expectedRevision,
  ) async {
    final currentRevision =
        _revisions[schedule.id] ?? _absentRevision(schedule.id);
    if (currentRevision != expectedRevision) {
      return const PersistenceFailure<Schedule>(
        'Schedule revision conflict in test repository.',
      );
    }
    final revision = _nextRevision(schedule.id);
    _schedules[schedule.id] = schedule;
    _revisions[schedule.id] = revision;
    _absentRevisions.remove(schedule.id);
    _snapshotRevisions[schedule] = revision;
    saved.add(schedule);
    return Success<Schedule>(schedule);
  }

  @override
  Future<Result<Schedule>> save(Schedule schedule) async {
    final expectedRevision = _snapshotRevisions[schedule] ??
        (_schedules.containsKey(schedule.id)
            ? null
            : _absentRevision(schedule.id));
    if (expectedRevision == null) {
      return const PersistenceFailure<Schedule>(
        'A caller-owned Schedule revision is required.',
      );
    }
    return saveIfRevision(schedule, expectedRevision);
  }

  @override
  Future<Result<void>> delete(String id) async =>
      const PersistenceFailure<void>(
        'Unconditional Schedule deletion is disabled in the test repository.',
      );
}
