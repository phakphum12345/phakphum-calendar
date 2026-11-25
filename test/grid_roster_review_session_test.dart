import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_review_session.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_safety.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';

void main() {
  const builder = GridRosterReviewSessionBuilder();

  test('builds an immutable review snapshot with source and target revisions', () {
    final report = _report();
    final session = builder.build(
      report: report,
      employees: [_employee],
      shiftTemplates: const [],
      sourceFingerprint: 'sha256:source-1',
      targetScheduleId: 'schedule-1',
      targetScheduleRevision: 'revision-7',
    );

    expect(session.sourceFingerprint, 'sha256:source-1');
    expect(session.targetScheduleId, 'schedule-1');
    expect(session.targetScheduleRevision, 'revision-7');
    expect(session.sections, hasLength(1));
    expect(session.assignments, hasLength(1));
    expect(
      session.sections.single.assessment.readiness,
      MonthlyRosterSectionReadiness.ready,
    );
    expect(
      session.assignments.single.identity.candidates.single.employee.id,
      'employee-1',
    );
    expect(session.assignments.single.shiftRule.code, 'UG');
    expect(session.requiresHumanReview, isTrue);
    expect(session.canCommit, isFalse);
    expect(session.assignments.single.canCommit, isFalse);
  });

  test('preserves blocked-section assignments but marks them non-committable', () {
    final report = _report(
      dateAnomalies: const [
        MonthlyRosterDateAnomaly(
          code: 'duplicate_day',
          message: 'Duplicate date column.',
          columnIndex: 18,
          displayedDay: 30,
        ),
      ],
    );

    final session = builder.build(
      report: report,
      employees: [_employee],
      shiftTemplates: const [],
      sourceFingerprint: 'source-2',
      targetScheduleId: 'schedule-1',
      targetScheduleRevision: 'revision-7',
    );

    expect(session.assignments, hasLength(1));
    expect(session.assignments.single.sectionBlocked, isTrue);
    expect(
      session.sections.single.assessment.readiness,
      MonthlyRosterSectionReadiness.blockedDate,
    );
    expect(session.canCommit, isFalse);
  });

  test('rejects missing source or target revision evidence', () {
    expect(
      () => builder.build(
        report: _report(),
        employees: [_employee],
        shiftTemplates: const [],
        sourceFingerprint: ' ',
        targetScheduleId: 'schedule-1',
        targetScheduleRevision: 'revision-7',
      ),
      throwsArgumentError,
    );
    expect(
      () => builder.build(
        report: _report(),
        employees: [_employee],
        shiftTemplates: const [],
        sourceFingerprint: 'source-1',
        targetScheduleId: 'schedule-1',
        targetScheduleRevision: ' ',
      ),
      throwsArgumentError,
    );
  });
}

MonthlyRosterParseReport _report({
  List<MonthlyRosterDateAnomaly> dateAnomalies = const [],
}) {
  return MonthlyRosterParseReport(
    sections: [
      MonthlyRosterSection(
        title: 'GEN November 2026',
        headerRowIndex: 1,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
        dateAnomalies: dateAnomalies,
        assignments: [
          MonthlyRosterAssignment(
            sectionTitle: 'GEN November 2026',
            rowLabel: 'GEN',
            rowIndex: 2,
            workerName: 'สมชาย ใจดี',
            date: DateTime(2026, 11, 1),
            sourceCell: 'B3',
          ),
        ],
      ),
    ],
    warnings: const [],
  );
}

const _department = Department(id: 'd1', code: 'D1', name: 'Department');
const _employee = Employee(
  id: 'employee-1',
  employeeCode: '001',
  firstName: 'สมชาย',
  lastName: 'ใจดี',
  nickname: 'ชาย',
  department: _department,
  position: 'Staff',
);
