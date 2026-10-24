import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_day.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_assignment.dart';
import 'package:phakphum_calendar/domain/entities/shift_type.dart';
import 'package:phakphum_calendar/features/dashboard/application/dashboard_summary_service.dart';

void main() {
  const service = DashboardSummaryService();

  Employee employee(String id) => Employee(
    id: id,
    employeeCode: id,
    firstName: 'Test',
    lastName: 'Employee',
    nickname: '',
    department: const Department(id: 'd1', code: 'D1', name: 'Department'),
    position: 'Nurse',
  );

  ShiftAssignment assignment(String id) => ShiftAssignment(
    employee: employee(id),
    shift: ShiftType(
      id: 'shift-$id',
      code: 'D',
      name: 'Day',
      color: 0xFF0F5F5C,
      startTime: const Duration(hours: 8),
      endTime: const Duration(hours: 16),
      workingHours: 8,
    ),
  );

  Schedule scheduleFor(List<ScheduleDay> days) => Schedule(
    id: 'schedule-1',
    name: 'Test schedule',
    months: [
      for (final month in days.map((day) => DateTime(day.date.year, day.date.month)).toSet())
        ScheduleMonth(
          month: month,
          days: days.where((day) => day.date.year == month.year && day.date.month == month.month).toList(),
        ),
    ],
  );

  test('summarizes today, tomorrow, monthly assignments and conflicts', () {
    final now = DateTime(2026, 10, 24, 9);
    final schedule = scheduleFor([
      ScheduleDay(date: DateTime(2026, 10, 24), assignments: [assignment('today-1'), assignment('today-2')]),
      ScheduleDay(date: DateTime(2026, 10, 25), assignments: [assignment('tomorrow-1')]),
      ScheduleDay(date: DateTime(2026, 10, 30), assignments: [assignment('later-1')]),
    ]);

    final summary = service.build(schedule: schedule, now: now, conflictCount: 2);

    expect(summary.todayAssignments, hasLength(2));
    expect(summary.tomorrowAssignments, hasLength(1));
    expect(summary.monthAssignmentCount, 4);
    expect(summary.conflictCount, 2);
    expect(summary.nextAssignment, isNotNull);
    expect(summary.nextAssignmentDate, DateTime(2026, 10, 24));
  });

  test('returns no next assignment for an empty future schedule', () {
    final now = DateTime(2026, 10, 24, 9);
    final schedule = scheduleFor([
      ScheduleDay(date: DateTime(2026, 10, 24)),
      ScheduleDay(date: DateTime(2026, 10, 25)),
    ]);

    final summary = service.build(schedule: schedule, now: now, conflictCount: 0);

    expect(summary.todayAssignments, isEmpty);
    expect(summary.tomorrowAssignments, isEmpty);
    expect(summary.monthAssignmentCount, 0);
    expect(summary.nextAssignment, isNull);
    expect(summary.nextAssignmentDate, isNull);
  });

  test('does not count assignments from other months in monthly total', () {
    final schedule = scheduleFor([
      ScheduleDay(date: DateTime(2026, 9, 30), assignments: [assignment('sep')]),
      ScheduleDay(date: DateTime(2026, 10, 1), assignments: [assignment('oct-1')]),
      ScheduleDay(date: DateTime(2026, 11, 1), assignments: [assignment('nov')]),
    ]);

    final summary = service.build(
      schedule: schedule,
      now: DateTime(2026, 10, 12),
      conflictCount: 0,
    );

    expect(summary.monthAssignmentCount, 1);
  });

  test('returns an immutable snapshot of assignments', () {
    final schedule = scheduleFor([
      ScheduleDay(date: DateTime(2026, 10, 24), assignments: [assignment('today')]),
    ]);

    final summary = service.build(
      schedule: schedule,
      now: DateTime(2026, 10, 24),
      conflictCount: 0,
    );

    expect(
      () => summary.todayAssignments.add(assignment('extra')),
      throwsUnsupportedError,
    );
  });
}
