import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_day.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_assignment.dart';
import 'package:phakphum_calendar/domain/entities/shift_template.dart';
import 'package:phakphum_calendar/features/excel_import/application/import_staging_applier.dart';
import 'package:phakphum_calendar/features/excel_import/application/import_staging_planner.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_staging_plan.dart';
import 'package:phakphum_calendar/features/excel_import/domain/shift_record.dart';

const _employee = Employee(
  id: 'employee-1',
  employeeCode: 'E001',
  firstName: 'Anan',
  lastName: 'Sukjai',
  nickname: '',
  department: Department(id: 'er', code: 'ER', name: 'Emergency'),
  position: 'Nurse',
);
const _template = ShiftTemplate(
  id: 'morning',
  code: 'M',
  name: 'Morning',
  shortName: 'AM',
  startTime: Duration(hours: 8),
  endTime: Duration(hours: 16),
  color: 0xFF1565C0,
  workingHours: 8,
);
final _date = DateTime(2026, 7, 24);

Schedule _schedule({List<ShiftAssignment> assignments = const []}) => Schedule(
  id: 'imported',
  name: 'Roster',
  months: [
    ScheduleMonth(
      month: _date,
      days: [ScheduleDay(date: _date, assignments: assignments)],
    ),
  ],
);

ShiftRecord _record({String? notes}) => ShiftRecord(
  date: _date,
  shift: 'M',
  employee: _employee.fullName,
  rowNumber: 2,
  notes: notes,
  resolvedEmployee: _employee,
  resolvedShiftTemplate: _template,
);

void main() {
  const planner = ImportStagingPlanner();
  const applier = ImportStagingApplier();

  test('applies selected CREATE rows to a new immutable schedule snapshot', () {
    final original = _schedule();
    final plan = planner.plan(existingSchedule: original, records: [_record()]);
    final updated = applier.apply(
      existingSchedule: original,
      plan: plan,
      includedRowNumbers: {2},
    );

    expect(updated.month(_date)!.day(_date)!.assignments, hasLength(1));
    expect(original.month(_date)!.day(_date)!.assignments, isEmpty);
  });

  test('omitted rows are skipped without changing existing assignments', () {
    final existing = _schedule();
    final plan = planner.plan(existingSchedule: existing, records: [_record()]);
    final updated = applier.apply(
      existingSchedule: existing,
      plan: plan,
      includedRowNumbers: const {},
    );

    expect(updated, same(existing));
  });

  test('applies UPDATE only when exactly one matching identity exists', () {
    final existingAssignment = ShiftAssignment(
      employee: _employee,
      shift: _template.toShiftType(),
      remark: 'old',
    );
    final existing = _schedule(assignments: [existingAssignment]);
    final plan = planner.plan(
      existingSchedule: existing,
      records: [_record(notes: 'new')],
    );
    final updated = applier.apply(
      existingSchedule: existing,
      plan: plan,
      includedRowNumbers: {2},
    );

    expect(updated.month(_date)!.day(_date)!.assignments.single.remark, 'new');
    expect(existing.month(_date)!.day(_date)!.assignments.single.remark, 'old');
  });

  test('rejects a blocked row even if selected', () {
    final plan = planner.plan(
      existingSchedule: _schedule(),
      records: [
        ShiftRecord(
          date: null,
          shift: 'M',
          employee: _employee.fullName,
          rowNumber: 2,
        ),
      ],
    );

    expect(
      () => applier.apply(
        existingSchedule: _schedule(),
        plan: plan,
        includedRowNumbers: {2},
      ),
      throwsStateError,
    );
  });

  test('rejects a CREATE that would duplicate an existing assignment', () {
    final existing = _schedule();
    final plan = planner.plan(existingSchedule: existing, records: [_record()]);
    final withDuplicate = _schedule(
      assignments: [
        ShiftAssignment(employee: _employee, shift: _template.toShiftType()),
      ],
    );

    expect(
      () => applier.apply(
        existingSchedule: withDuplicate,
        plan: plan,
        includedRowNumbers: {2},
      ),
      throwsStateError,
    );
  });
}
