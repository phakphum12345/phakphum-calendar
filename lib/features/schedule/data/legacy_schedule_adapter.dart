import '../../../domain/entities/department.dart';
import '../../../domain/entities/employee.dart';
import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/schedule_day.dart';
import '../../../domain/entities/schedule_month.dart';
import '../../../domain/entities/shift_assignment.dart';
import '../../../domain/entities/shift_type.dart';
import '../../../models/shift.dart' as legacy;

/// Converts the legacy calendar shift model to the canonical schedule model.
class LegacyScheduleAdapter {
  const LegacyScheduleAdapter();

  static const _department = Department(
    id: 'legacy-unassigned',
    code: 'Unassigned',
    name: 'Unassigned',
  );

  /// Converts [shifts] while retaining metadata needed for a lossless return.
  LegacyScheduleConversion toCanonical(
    Iterable<legacy.Shift> shifts, {
    String id = 'legacy',
    String name = 'Legacy schedule',
  }) {
    final days = <DateTime, List<ShiftAssignment>>{};
    final metadata = <_LegacyAssignmentMetadata>[];

    for (final source in shifts) {
      final date = DateTime(
        source.start.year,
        source.start.month,
        source.start.day,
      );
      final assignments = days.putIfAbsent(date, () => []);
      final assignment = ShiftAssignment(
        employee: _employee(source.assignedName),
        shift: _shiftType(source),
        remark: source.relationshipComment,
      );
      metadata.add(
        _LegacyAssignmentMetadata(
          date: date,
          assignmentIndex: assignments.length,
          sheetTitle: source.sheetTitle,
          cell: source.cell,
          category: source.category,
          excluded: source.excluded,
          generated: source.generated,
          linkedShiftKey: source.linkedShiftKey,
          sourceColorValue: source.sourceColorValue,
          customTitle: source.customTitle,
          calendarColorId: source.calendarColorId,
        ),
      );
      assignments.add(assignment);
    }

    final months = <DateTime, List<ScheduleDay>>{};
    for (final entry in days.entries) {
      final month = DateTime(entry.key.year, entry.key.month);
      months
          .putIfAbsent(month, () => [])
          .add(ScheduleDay(date: entry.key, assignments: entry.value));
    }

    final scheduleMonths = <ScheduleMonth>[];
    for (final entry in months.entries) {
      final completeMonth = ScheduleMonth.empty(entry.key);
      var populatedMonth = completeMonth;
      for (final day in entry.value) {
        populatedMonth = populatedMonth.replaceDay(day);
      }
      scheduleMonths.add(populatedMonth);
    }
    scheduleMonths.sort((left, right) => left.month.compareTo(right.month));

    return LegacyScheduleConversion._(
      schedule: Schedule(id: id, name: name, months: scheduleMonths),
      metadata: metadata,
    );
  }

  /// Wraps a canonical schedule for legacy UI compatibility.
  ///
  /// Existing canonical values remain authoritative. Provider-only legacy
  /// metadata receives neutral defaults because manual assignments have no
  /// source Sheet cell or provider color override.
  LegacyScheduleConversion wrapCanonical(Schedule schedule) {
    final metadata = <_LegacyAssignmentMetadata>[];
    for (final month in schedule.months) {
      for (final day in month.days) {
        for (var index = 0; index < day.assignments.length; index++) {
          metadata.add(
            _LegacyAssignmentMetadata(
              date: day.date,
              assignmentIndex: index,
              sheetTitle: 'Manual',
              cell: '',
              category: legacy.ShiftCategory.own,
              excluded: false,
              generated: false,
              linkedShiftKey: null,
              sourceColorValue: day.assignments[index].shift.color,
              customTitle: null,
              calendarColorId: null,
            ),
          );
        }
      }
    }
    return LegacyScheduleConversion._(schedule: schedule, metadata: metadata);
  }

  Employee _employee(String assignedName) {
    final name = assignedName.trim();
    return Employee(
      id: 'legacy:${_identifier(name)}',
      employeeCode: name,
      firstName: name,
      lastName: '',
      nickname: '',
      department: _department,
      position: '',
    );
  }

  ShiftType _shiftType(legacy.Shift shift) {
    final startTime = _timeOfDay(shift.start);
    final endTime = _timeOfDay(shift.end);
    return ShiftType(
      id:
          'legacy:${_identifier(shift.code)}:'
          '${startTime.inMicroseconds}:${endTime.inMicroseconds}',
      code: shift.code,
      name: shift.rowLabel,
      color: shift.category.colorValue,
      startTime: startTime,
      endTime: endTime,
      workingHours:
          shift.end.difference(shift.start).inMicroseconds /
          Duration.microsecondsPerHour,
    );
  }

  Duration _timeOfDay(DateTime value) {
    return Duration(
      hours: value.hour,
      minutes: value.minute,
      seconds: value.second,
      milliseconds: value.millisecond,
      microseconds: value.microsecond,
    );
  }

  String _identifier(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  }
}

/// Canonical schedule plus metadata required to reconstruct legacy shifts.
class LegacyScheduleConversion {
  LegacyScheduleConversion._({
    required this.schedule,
    required List<_LegacyAssignmentMetadata> metadata,
  }) : _metadata = List.unmodifiable(metadata);

  /// Canonical representation used by new scheduling code.
  final Schedule schedule;

  final List<_LegacyAssignmentMetadata> _metadata;

  /// Reconstructs legacy shifts from the canonical assignments.
  List<legacy.Shift> toLegacyShifts({Schedule? schedule}) {
    final source = schedule ?? this.schedule;
    return List.unmodifiable([
      for (final metadata in _metadata) metadata.toLegacy(source),
    ]);
  }
}

class _LegacyAssignmentMetadata {
  const _LegacyAssignmentMetadata({
    required this.date,
    required this.assignmentIndex,
    required this.sheetTitle,
    required this.cell,
    required this.category,
    required this.excluded,
    required this.generated,
    required this.linkedShiftKey,
    required this.sourceColorValue,
    required this.customTitle,
    required this.calendarColorId,
  });

  final DateTime date;
  final int assignmentIndex;
  final String sheetTitle;
  final String cell;
  final legacy.ShiftCategory category;
  final bool excluded;
  final bool generated;
  final String? linkedShiftKey;
  final int? sourceColorValue;
  final String? customTitle;
  final String? calendarColorId;

  legacy.Shift toLegacy(Schedule schedule) {
    final day = schedule.month(date)?.day(date);
    if (day == null || assignmentIndex >= day.assignments.length) {
      throw StateError('The canonical assignment structure has changed.');
    }
    final assignment = day.assignments[assignmentIndex];
    final start = _atTime(date, assignment.shift.startTime);
    var end = _atTime(date, assignment.shift.endTime);
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }
    return legacy.Shift(
      code: assignment.shift.code,
      rowLabel: assignment.shift.name,
      assignedName: assignment.employee.fullName,
      start: start,
      end: end,
      sheetTitle: sheetTitle,
      cell: cell,
      category: category,
      excluded: excluded,
      generated: generated,
      linkedShiftKey: linkedShiftKey,
      sourceColorValue: sourceColorValue,
      customTitle: customTitle,
      calendarColorId: calendarColorId,
      relationshipComment: assignment.remark,
    );
  }

  DateTime _atTime(DateTime date, Duration time) {
    return DateTime(date.year, date.month, date.day).add(time);
  }
}
