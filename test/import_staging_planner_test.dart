import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_day.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_assignment.dart';
import 'package:phakphum_calendar/domain/entities/shift_template.dart';
import 'package:phakphum_calendar/features/excel_import/application/import_staging_planner.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_staging_plan.dart';
import 'package:phakphum_calendar/features/excel_import/domain/shift_record.dart';

const _employee = Employee(
  id: 'employee-1',
  employeeCode: 'E001',
  firstName: 'Anan',
  lastName: 'Sukjai',
  nickname: 'Nan',
  department: Department(id: 'er', code: 'ER', name: 'Emergency'),
  position: 'Nurse',
);

const _template = ShiftTemplate(
  id: 'shift-morning',
  code: 'M',
  name: 'Morning',
  shortName: 'AM',
  startTime: Duration(hours: 8),
  endTime: Duration(hours: 16),
  color: 0xFF1565C0,
  workingHours: 8,
);

const _changedTemplate = ShiftTemplate(
  id: 'shift-morning',
  code: 'M',
  name: 'Morning',
  shortName: 'AM',
  startTime: Duration(hours: 7),
  endTime: Duration(hours: 15),
  color: 0xFF1565C0,
  workingHours: 8,
);

const _employeeWithDelimiter = Employee(
  id: 'A',
  employeeCode: 'EA',
  firstName: 'First',
  lastName: 'Employee',
  department: Department(id: 'er', code: 'ER', name: 'Emergency'),
  position: 'Nurse',
);

const _employeeWithDelimiterInId = Employee(
  id: 'A|B',
  employeeCode: 'EB',
  firstName: 'Second',
  lastName: 'Employee',
  department: Department(id: 'er', code: 'ER', name: 'Emergency'),
  position: 'Nurse',
);

const _shiftWithDelimiter = ShiftTemplate(
  id: 'B|C',
  code: 'BC',
  name: 'Shift BC',
  shortName: 'BC',
  startTime: Duration(hours: 8),
  endTime: Duration(hours: 16),
  color: 0xFF1565C0,
  workingHours: 8,
);

const _shiftC = ShiftTemplate(
  id: 'C',
  code: 'C',
  name: 'Shift C',
  shortName: 'C',
  startTime: Duration(hours: 8),
  endTime: Duration(hours: 16),
  color: 0xFF1565C0,
  workingHours: 8,
);

ShiftRecord _record({
  int row = 2,
  DateTime? date,
  bool missingDate = false,
  Employee? employee = _employee,
  ShiftTemplate? template = _template,
  String? notes,
  String? location,
}) {
  return ShiftRecord(
    date: missingDate ? null : date ?? DateTime(2026, 7, 24),
    shift: 'M',
    employee: employee?.fullName ?? 'Unknown',
    rowNumber: row,
    notes: notes,
    location: location,
    resolvedEmployee: employee,
    resolvedShiftTemplate: template,
  );
}

Schedule _schedule({List<ShiftAssignment> assignments = const []}) {
  final date = DateTime(2026, 7, 24);
  return Schedule(
    id: 'schedule-imported',
    name: 'Existing roster',
    months: [
      ScheduleMonth(
        month: date,
        days: [ScheduleDay(date: date, assignments: assignments)],
      ),
    ],
  );
}

ShiftAssignment _assignment({
  ShiftTemplate template = _template,
  String? remark,
  String? location,
}) {
  return ShiftAssignment(
    employee: _employee,
    shift: template.toShiftType(),
    remark: remark,
    location: location,
  );
}

void main() {
  const planner = ImportStagingPlanner();

  test('classifies a new resolved row as create without mutating schedule', () {
    final existing = _schedule();
    final plan = planner.plan(
      existingSchedule: existing,
      records: [_record()],
    );

    expect(plan.scheduleId, existing.id);
    expect(plan.entries.single.action, ImportRowAction.create);
    expect(
      plan.entries.single.reason,
      ImportRowDecisionReason.noMatchingAssignment,
    );
    expect(plan.createCount, 1);
    expect(plan.hasBlockingRows, isFalse);
    expect(existing.month(DateTime(2026, 7))!.day(DateTime(2026, 7, 24))!
        .assignments, isEmpty);
  });

  test('classifies identical existing assignment as skip', () {
    final plan = planner.plan(
      existingSchedule: _schedule(assignments: [_assignment()]),
      records: [_record()],
    );

    expect(plan.entries.single.action, ImportRowAction.skip);
    expect(
      plan.entries.single.reason,
      ImportRowDecisionReason.existingAssignmentUnchanged,
    );
    expect(plan.skipCount, 1);
  });

  test('classifies changed shift details for the same identity as update', () {
    final plan = planner.plan(
      existingSchedule: _schedule(assignments: [_assignment()]),
      records: [_record(template: _changedTemplate)],
    );

    expect(plan.entries.single.action, ImportRowAction.update);
    expect(
      plan.entries.single.reason,
      ImportRowDecisionReason.existingAssignmentChanged,
    );
    expect(plan.updateCount, 1);
  });

  test('blocks rows with missing dates or unresolved identities', () {
    final plan = planner.plan(
      existingSchedule: _schedule(),
      records: [
        _record(row: 2, missingDate: true),
        _record(row: 3, employee: null),
        _record(row: 4, template: null),
      ],
    );

    expect(
      plan.entries.map((entry) => entry.reason),
      [
        ImportRowDecisionReason.missingDate,
        ImportRowDecisionReason.unresolvedEmployee,
        ImportRowDecisionReason.unresolvedShiftTemplate,
      ],
    );
    expect(plan.entries.every((entry) => entry.isBlocked), isTrue);
    expect(plan.blockedCount, 3);
    expect(plan.hasBlockingRows, isTrue);
  });

  test('identical duplicate source rows create once and skip later copies', () {
    final plan = planner.plan(
      existingSchedule: _schedule(),
      records: [_record(row: 2), _record(row: 3)],
    );

    expect(
      plan.entries.map((entry) => entry.action),
      [ImportRowAction.create, ImportRowAction.skip],
    );
    expect(
      plan.entries.last.reason,
      ImportRowDecisionReason.identicalDuplicateSourceRow,
    );
  });

  test('keeps distinct identities separate when IDs contain delimiters', () {
    final plan = planner.plan(
      existingSchedule: _schedule(),
      records: [
        _record(row: 2, employee: _employeeWithDelimiter, template: _shiftWithDelimiter),
        _record(row: 3, employee: _employeeWithDelimiterInId, template: _shiftC),
      ],
    );

    expect(
      plan.entries.map((entry) => entry.action),
      [ImportRowAction.create, ImportRowAction.create],
    );
    expect(plan.createCount, 2);
    expect(plan.hasBlockingRows, isFalse);
  });

  test('conflicting duplicate source rows are both blocked', () {
    final plan = planner.plan(
      existingSchedule: _schedule(),
      records: [
        _record(row: 2, notes: 'first'),
        _record(row: 3, notes: 'different'),
      ],
    );

    expect(plan.entries.every((entry) => entry.isBlocked), isTrue);
    expect(
      plan.entries.map((entry) => entry.reason),
      everyElement(ImportRowDecisionReason.conflictingDuplicateSourceRows),
    );
  });

  test('blocks when the existing schedule already has duplicate identities', () {
    final plan = planner.plan(
      existingSchedule: _schedule(
        assignments: [_assignment(), _assignment()],
      ),
      records: [_record()],
    );

    expect(plan.entries.single.action, ImportRowAction.blocked);
    expect(
      plan.entries.single.reason,
      ImportRowDecisionReason.duplicateExistingAssignments,
    );
  });

  test('preserves source row order and supports an empty staging plan', () {
    final plan = planner.plan(
      existingSchedule: _schedule(),
      records: [_record(row: 9), _record(row: 4, date: null)],
    );
    final empty = planner.plan(existingSchedule: _schedule(), records: []);

    expect(plan.entries.map((entry) => entry.rowNumber), [9, 4]);
    expect(empty.entries, isEmpty);
    expect(empty.createCount, 0);
    expect(empty.blockedCount, 0);
  });
}
