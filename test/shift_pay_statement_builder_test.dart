import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_day.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_assignment.dart';
import 'package:phakphum_calendar/domain/entities/shift_type.dart';
import 'package:phakphum_calendar/domain/services/shift_pay_calculator.dart';
import 'package:phakphum_calendar/domain/services/shift_pay_profile.dart';
import 'package:phakphum_calendar/domain/services/shift_pay_statement_builder.dart';

void main() {
  const builder = ShiftPayStatementBuilder();
  final generatedAt = DateTime.utc(2026, 11, 27, 8);

  test('includes only confirmed assignments in payable totals', () {
    final confirmed = _assignment('employee-a');
    final pending = _assignment('employee-b');
    final schedule = _schedule([
      ScheduleDay(
        date: DateTime(2026, 10, 26),
        assignments: [confirmed, pending],
      ),
    ]);

    final statement = builder.build(
      statementId: 'october-2026',
      schedule: schedule,
      scheduleRevision: 'revision-7',
      profile: _profile([_rule('night-a', 750)]),
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
      generatedAtUtc: generatedAt,
      isConfirmed: (_, assignment) =>
          assignment.employee.id == 'employee-a',
      employmentTypeFor: (_) => EmploymentType.salaried,
    );

    expect(statement.lines, hasLength(2));
    expect(statement.payableCount, 1);
    expect(statement.totalAmount, 750);
    expect(
      statement.lines.singleWhere(
        (line) => line.employeeId == 'employee-b',
      ).status,
      ShiftPayStatementLineStatus.notConfirmed,
    );
  });

  test('requires explicit employment type instead of guessing it', () {
    final statement = builder.build(
      statementId: 'missing-employment-type',
      schedule: _schedule([
        ScheduleDay(
          date: DateTime(2026, 10, 26),
          assignments: [_assignment('employee-a')],
        ),
      ]),
      scheduleRevision: 'revision-7',
      profile: _profile([_rule('night-a', 750)]),
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
      generatedAtUtc: generatedAt,
      isConfirmed: (_, _) => true,
      employmentTypeFor: (_) => null,
    );

    expect(statement.totalAmount, 0);
    expect(statement.unresolvedCount, 1);
    expect(
      statement.lines.single.status,
      ShiftPayStatementLineStatus.employmentTypeRequired,
    );
  });

  test('ambiguous rules create a non-payable line and no double count', () {
    final statement = builder.build(
      statementId: 'ambiguous-rule',
      schedule: _schedule([
        ScheduleDay(
          date: DateTime(2026, 10, 26),
          assignments: [_assignment('employee-a')],
        ),
      ]),
      scheduleRevision: 'revision-7',
      profile: _profile([
        _rule('night-a', 700),
        _rule('night-b', 900),
      ]),
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
      generatedAtUtc: generatedAt,
      isConfirmed: (_, _) => true,
      employmentTypeFor: (_) => EmploymentType.salaried,
    );

    expect(statement.totalAmount, 0);
    expect(statement.payableCount, 0);
    expect(
      statement.lines.single.status,
      ShiftPayStatementLineStatus.ambiguousRule,
    );
    expect(statement.lines.single.amount, isNull);
    expect(statement.lines.single.conflictingRuleIds, ['night-a', 'night-b']);
  });

  test('duplicate assignment identities are excluded from the total', () {
    final assignment = _assignment('employee-a');
    final statement = builder.build(
      statementId: 'duplicate-assignment',
      schedule: _schedule([
        ScheduleDay(
          date: DateTime(2026, 10, 26),
          assignments: [assignment, assignment],
        ),
      ]),
      scheduleRevision: 'revision-7',
      profile: _profile([_rule('night-a', 750)]),
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
      generatedAtUtc: generatedAt,
      isConfirmed: (_, _) => true,
      employmentTypeFor: (_) => EmploymentType.salaried,
    );

    expect(statement.totalAmount, 750);
    expect(statement.payableCount, 1);
    expect(
      statement.lines.where(
        (line) => line.status == ShiftPayStatementLineStatus.duplicateAssignment,
      ),
      hasLength(1),
    );
  });

  test('rounds each result and totals integer minor units', () {
    final statement = builder.build(
      statementId: 'rounding',
      schedule: _schedule([
        ScheduleDay(
          date: DateTime(2026, 10, 26),
          assignments: [_assignment('employee-a')],
        ),
      ]),
      scheduleRevision: 'revision-7',
      profile: _profile([_rule('night-a', 123.456)]),
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
      generatedAtUtc: generatedAt,
      isConfirmed: (_, _) => true,
      employmentTypeFor: (_) => EmploymentType.salaried,
    );

    expect(statement.lines.single.amount, 123.46);
    expect(statement.totalMinorUnits, 12346);
    expect(statement.totalAmount, 123.46);
  });

  test('keeps historical statement values when the profile later changes', () {
    final schedule = _schedule([
      ScheduleDay(
        date: DateTime(2026, 10, 26),
        assignments: [_assignment('employee-a')],
      ),
    ]);
    final firstProfile = _profile([_rule('night-a', 500)]);
    final secondProfile = _profile([_rule('night-a', 800)]);

    final first = builder.build(
      statementId: 'historical',
      schedule: schedule,
      scheduleRevision: 'revision-7',
      profile: firstProfile,
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
      generatedAtUtc: generatedAt,
      isConfirmed: (_, _) => true,
      employmentTypeFor: (_) => EmploymentType.salaried,
    );
    final second = builder.build(
      statementId: 'current',
      schedule: schedule,
      scheduleRevision: 'revision-7',
      profile: secondProfile,
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
      generatedAtUtc: generatedAt,
      isConfirmed: (_, _) => true,
      employmentTypeFor: (_) => EmploymentType.salaried,
    );

    expect(first.totalAmount, 500);
    expect(second.totalAmount, 800);
    expect(first.profileFingerprint, isNot(second.profileFingerprint));
    expect(first.lines.single.amount, 500);
  });
}

Schedule _schedule(List<ScheduleDay> days) => Schedule(
  id: 'schedule-a',
  name: 'October roster',
  months: [
    ScheduleMonth(month: DateTime(2026, 10), days: days),
  ],
);

ShiftAssignment _assignment(String employeeId) => ShiftAssignment(
  employee: Employee(
    id: employeeId,
    employeeCode: employeeId,
    firstName: 'Staff',
    lastName: employeeId,
    nickname: '',
    department: const Department(
      id: 'department-a',
      code: 'RAD',
      name: 'Radiology',
    ),
    position: 'Technician',
  ),
  shift: const ShiftType(
    id: 'night',
    code: 'N',
    name: 'Night',
    color: 0,
    startTime: Duration(hours: 20),
    endTime: Duration(hours: 8),
    workingHours: 12,
  ),
);

ShiftPayProfile _profile(List<ShiftPayRule> rules) => ShiftPayProfile(
  id: 'profile-a',
  mode: ShiftPayMode.personal,
  rules: [
    for (final rule in rules)
      ShiftPayRuleEntry(
        source: ShiftPayRuleSource.personal,
        rule: rule,
      ),
  ],
);

ShiftPayRule _rule(String id, double amount) => ShiftPayRule(
  id: id,
  employmentType: EmploymentType.salaried,
  dayCategory: WorkDayCategory.regularWeekday,
  shiftTypeId: 'night',
  fixedAmount: amount,
);
