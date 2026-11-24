import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_canonical_converter.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_review_session.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';

void main() {
  const builder = GridRosterReviewSessionBuilder();
  const converter = GridRosterCanonicalConverter();
  final createdAt = DateTime.utc(2026, 11, 24, 12);

  test('converts an explicitly reviewed assignment into canonical Schedule', () {
    final session = _session(builder);
    final source = session.assignments.single.source;
    final sourceId = GridRosterCanonicalConverter.assignmentId(
      session.sourceFingerprint,
      source,
    );

    final result = converter.convert(
      session: session,
      targetSchedule: Schedule(id: 'schedule-1', name: 'November 2026'),
      employees: [_employee],
      shiftTemplates: const [],
      decisions: {
        sourceId: GridRosterAssignmentDecision(
          include: true,
          employeeId: _employee.id,
          reviewerId: 'reviewer-1',
          reviewedAtUtc: createdAt,
        ),
      },
      importRunId: 'run-1',
      parserVersion: 'grid-parser/1',
      createdAtUtc: createdAt,
    );

    final day = result.schedule.month(DateTime(2026, 11, 1))!
        .day(DateTime(2026, 11, 1))!;
    expect(result.includedAssignmentCount, 1);
    expect(result.excludedAssignmentCount, 0);
    expect(day.assignments, hasLength(1));
    expect(day.assignments.single.employee.id, _employee.id);
    expect(day.assignments.single.shift.code, 'UG');
    expect(result.preparedProvenance.lifecycle.name, 'prepared');
    expect(
      result.preparedProvenance.assignments.single.reviewDecision.name,
      'include',
    );

    final committed = result.committedProvenance(
      acceptedScheduleFingerprint: 'sha256:accepted-1',
    );
    expect(committed.lifecycle.name, 'committed');
    expect(committed.acceptedScheduleFingerprint, 'sha256:accepted-1');
  });

  test('requires a decision for every source assignment', () {
    final session = _session(builder);
    expect(
      () => converter.convert(
        session: session,
        targetSchedule: Schedule(id: 'schedule-1', name: 'November 2026'),
        employees: [_employee],
        shiftTemplates: const [],
        decisions: const {},
        importRunId: 'run-2',
        parserVersion: 'grid-parser/1',
        createdAtUtc: createdAt,
      ),
      throwsA(isA<GridRosterCanonicalConversionException>()),
    );
  });

  test('preserves existing months and rejects duplicate canonical assignment', () {
    final session = _session(builder);
    final source = session.assignments.single.source;
    final sourceId = GridRosterCanonicalConverter.assignmentId(
      session.sourceFingerprint,
      source,
    );
    final first = converter.convert(
      session: session,
      targetSchedule: Schedule(id: 'schedule-1', name: 'November 2026'),
      employees: [_employee],
      shiftTemplates: const [],
      decisions: {
        sourceId: GridRosterAssignmentDecision(
          include: true,
          employeeId: _employee.id,
          reviewerId: 'reviewer-1',
          reviewedAtUtc: createdAt,
        ),
      },
      importRunId: 'run-3',
      parserVersion: 'grid-parser/1',
      createdAtUtc: createdAt,
    );

    expect(
      () => converter.convert(
        session: session,
        targetSchedule: first.schedule,
        employees: [_employee],
        shiftTemplates: const [],
        decisions: {
          sourceId: GridRosterAssignmentDecision(
            include: true,
            employeeId: _employee.id,
            reviewerId: 'reviewer-1',
            reviewedAtUtc: createdAt,
          ),
        },
        importRunId: 'run-4',
        parserVersion: 'grid-parser/1',
        createdAtUtc: createdAt,
      ),
      throwsA(isA<GridRosterCanonicalConversionException>()),
    );
  });

  test('blocked section can only be explicitly excluded', () {
    final session = _session(builder, blocked: true);
    final source = session.assignments.single.source;
    final sourceId = GridRosterCanonicalConverter.assignmentId(
      session.sourceFingerprint,
      source,
    );

    expect(
      () => converter.convert(
        session: session,
        targetSchedule: Schedule(id: 'schedule-1', name: 'November 2026'),
        employees: [_employee],
        shiftTemplates: const [],
        decisions: {
          sourceId: GridRosterAssignmentDecision(
            include: true,
            employeeId: _employee.id,
            reviewerId: 'reviewer-1',
            reviewedAtUtc: createdAt,
          ),
        },
        importRunId: 'run-5',
        parserVersion: 'grid-parser/1',
        createdAtUtc: createdAt,
      ),
      throwsA(isA<GridRosterCanonicalConversionException>()),
    );

    final excluded = converter.convert(
      session: session,
      targetSchedule: Schedule(id: 'schedule-1', name: 'November 2026'),
      employees: [_employee],
      shiftTemplates: const [],
      decisions: {
        sourceId: GridRosterAssignmentDecision(
          include: false,
          reviewerId: 'reviewer-1',
          reviewedAtUtc: createdAt,
        ),
      },
      importRunId: 'run-6',
      parserVersion: 'grid-parser/1',
      createdAtUtc: createdAt,
    );
    expect(excluded.includedAssignmentCount, 0);
    expect(excluded.excludedAssignmentCount, 1);
    expect(excluded.schedule.months, isEmpty);
  });
}

GridRosterReviewSession _session(
  GridRosterReviewSessionBuilder builder, {
  bool blocked = false,
}) {
  final report = MonthlyRosterParseReport(
    sections: [
      MonthlyRosterSection(
        title: 'GEN November 2026',
        headerRowIndex: 1,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
        dateAnomalies: blocked
            ? const [
                MonthlyRosterDateAnomaly(
                  code: 'duplicate_day',
                  message: 'Duplicate displayed day.',
                  columnIndex: 18,
                  displayedDay: 30,
                ),
              ]
            : const [],
        assignments: [
          MonthlyRosterAssignment(
            sectionTitle: 'GEN November 2026',
            rowLabel: 'GEN',
            rowIndex: 2,
            workerName: 'Somchai Example',
            date: DateTime(2026, 11, 1),
            sourceCell: 'B3',
          ),
        ],
      ),
    ],
    warnings: const [],
  );
  return builder.build(
    report: report,
    employees: [_employee],
    shiftTemplates: const [],
    sourceFingerprint: 'sha256:source-1',
    targetScheduleId: 'schedule-1',
    targetScheduleRevision: 'revision-1',
  );
}

const _department = Department(id: 'd1', code: 'D1', name: 'Department');
const _employee = Employee(
  id: 'employee-1',
  employeeCode: '001',
  firstName: 'Somchai',
  lastName: 'Example',
  nickname: 'Chai',
  department: _department,
  position: 'Staff',
);
