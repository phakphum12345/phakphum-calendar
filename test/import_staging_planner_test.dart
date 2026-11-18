import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_day.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_assignment.dart';
import 'package:phakphum_calendar/domain/entities/shift_type.dart';
import 'package:phakphum_calendar/features/excel_import/application/import_staging_planner.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_staging_row.dart';

void main() {
  const planner = ImportStagingPlanner();
  final date = DateTime(2026, 7, 24);
  const employee = Employee(
    id: 'employee-1',
    employeeCode: 'E-001',
    firstName: 'Anan',
    lastName: 'Sukjai',
    nickname: '',
    department: Department(id: 'er', code: 'ER', name: 'Emergency'),
    position: 'Nurse',
  );
  const morning = ShiftType(
    id: 'morning',
    code: 'M',
    name: 'Morning',
    color: 0xFF1565C0,
    startTime: Duration(hours: 8),
    endTime: Duration(hours: 16),
    workingHours: 8,
  );
  const evening = ShiftType(
    id: 'evening',
    code: 'E',
    name: 'Evening',
    color: 0xFF6A1B9A,
    startTime: Duration(hours: 16),
    endTime: Duration(hours: 24),
    workingHours: 8,
  );

  ShiftAssignment assignment({String? remark, String? location}) =>
      ShiftAssignment(
        employee: employee,
        shift: morning,
        remark: remark,
        location: location,
      );

  Schedule scheduleWith(List<ShiftAssignment> assignments) => Schedule(
    id: 'existing',
    name: 'Existing',
    months: [
      ScheduleMonth(
        month: DateTime(2026, 7),
        days: [
          ScheduleDay(date: date, assignments: assignments),
        ],
      ),
    ],
  );

  test('classifies a new row as create without mutating existing schedule', () {
    final existing = scheduleWith(const []);
    final plan = planner.build(
      rows: [
        ImportStagingRow(
          sourceRowNumber: 2,
          date: date,
          assignment: assignment(),
        ),
      ],
      existingSchedule: existing,
    );

    expect(plan.entries.single.decision, ImportRowDecision.create);
    expect(plan.entries.single.reason, ImportRowDecisionReason.newAssignment);
    expect(plan.createCount, 1);
    expect(plan.isReadyForExplicitConfirmation, isTrue);
    expect(existing.month(date)!.day(date)!.assignments, isEmpty);
  });

  test('classifies an exact existing assignment as skip', () {
    final plan = planner.build(
      rows: [
        ImportStagingRow(
          sourceRowNumber: 2,
          date: date,
          assignment: assignment(remark: 'On call', location: 'Ward A'),
        ),
      ],
      existingSchedule: scheduleWith([
        assignment(remark: 'On call', location: 'Ward A'),
      ]),
    );

    expect(plan.entries.single.decision, ImportRowDecision.skip);
    expect(plan.entries.single.reason, ImportRowDecisionReason.alreadyPresent);
  });

  test('classifies changed metadata on the same assignment key as update', () {
    final plan = planner.build(
      rows: [
        ImportStagingRow(
          sourceRowNumber: 3,
          date: date,
          assignment: assignment(remark: 'Updated note'),
        ),
      ],
      existingSchedule: scheduleWith([assignment(remark: 'Old note')]),
    );

    expect(plan.entries.single.decision, ImportRowDecision.update);
    expect(
      plan.entries.single.reason,
      ImportRowDecisionReason.existingAssignmentChanged,
    );
  });

  test('skips a repeated identical row after the first source occurrence', () {
    final row = ImportStagingRow(
      sourceRowNumber: 2,
      date: date,
      assignment: assignment(),
    );
    final plan = planner.build(
      rows: [
        row,
        ImportStagingRow(
          sourceRowNumber: 3,
          date: date,
          assignment: assignment(),
        ),
      ],
      existingSchedule: scheduleWith(const []),
    );

    expect(
      plan.entries.map((entry) => entry.decision),
      [ImportRowDecision.create, ImportRowDecision.skip],
    );
    expect(
      plan.entries.last.reason,
      ImportRowDecisionReason.repeatedIdenticalSourceRow,
    );
  });

  test('requires review for conflicting source rows with the same key', () {
    final plan = planner.build(
      rows: [
        ImportStagingRow(
          sourceRowNumber: 2,
          date: date,
          assignment: assignment(remark: 'First'),
        ),
        ImportStagingRow(
          sourceRowNumber: 3,
          date: date,
          assignment: assignment(remark: 'Second'),
        ),
      ],
      existingSchedule: scheduleWith(const []),
    );

    expect(plan.entries.first.decision, ImportRowDecision.create);
    expect(plan.entries.last.decision, ImportRowDecision.review);
    expect(
      plan.entries.last.reason,
      ImportRowDecisionReason.conflictingSourceRows,
    );
    expect(plan.isReadyForExplicitConfirmation, isFalse);
  });

  test('requires review when date or resolved identity is missing', () {
    final plan = planner.build(
      rows: [
        ImportStagingRow(
          sourceRowNumber: 2,
          date: null,
          assignment: assignment(),
        ),
        const ImportStagingRow(
          sourceRowNumber: 3,
          date: null,
          assignment: null,
        ),
      ],
      existingSchedule: scheduleWith(const []),
    );

    expect(plan.reviewCount, 2);
    expect(
      plan.entries.every(
        (entry) =>
            entry.reason ==
            ImportRowDecisionReason.unresolvedDateOrIdentity,
      ),
      isTrue,
    );
  });

  test('requires review when existing schedule has duplicate assignment keys', () {
    final plan = planner.build(
      rows: [
        ImportStagingRow(
          sourceRowNumber: 2,
          date: date,
          assignment: assignment(),
        ),
      ],
      existingSchedule: scheduleWith([
        assignment(remark: 'One'),
        assignment(remark: 'Two'),
      ]),
    );

    expect(plan.entries.single.decision, ImportRowDecision.review);
    expect(
      plan.entries.single.reason,
      ImportRowDecisionReason.ambiguousExistingAssignment,
    );
  });

  test('different shift IDs on the same employee and date are separate keys', () {
    final otherShift = ShiftAssignment(employee: employee, shift: evening);
    final plan = planner.build(
      rows: [
        ImportStagingRow(
          sourceRowNumber: 2,
          date: date,
          assignment: otherShift,
        ),
      ],
      existingSchedule: scheduleWith([assignment()]),
    );

    expect(plan.entries.single.decision, ImportRowDecision.create);
  });
}
