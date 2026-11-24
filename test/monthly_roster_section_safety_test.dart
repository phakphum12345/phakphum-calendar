import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_safety.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';

void main() {
  const classifier = MonthlyRosterSectionSafetyClassifier();

  test('marks a valid populated section ready for review', () {
    final result = classifier.assess(_section());

    expect(result.readiness, MonthlyRosterSectionReadiness.ready);
    expect(result.canEnterReview, isTrue);
    expect(result.canCommit, isFalse);
    expect(result.reasonCodes, isEmpty);
  });

  test('blocks sections with date anomalies without dropping assignments', () {
    final section = _section(
      dateAnomalies: const [
        MonthlyRosterDateAnomaly(
          code: 'duplicate_day',
          message: 'Duplicate displayed day.',
          columnIndex: 18,
          displayedDay: 30,
        ),
      ],
    );

    final result = classifier.assess(section);

    expect(result.readiness, MonthlyRosterSectionReadiness.blockedDate);
    expect(result.canEnterReview, isFalse);
    expect(result.reasonCodes, ['DATE_ANOMALY:duplicate_day']);
    expect(result.section.assignments, hasLength(1));
  });

  test('blocks a missing or reversed date range', () {
    final missing = classifier.assess(_section(startDate: null));
    final reversed = classifier.assess(
      _section(
        startDate: DateTime(2026, 11, 30),
        endDate: DateTime(2026, 11, 1),
      ),
    );

    expect(missing.readiness, MonthlyRosterSectionReadiness.blockedDate);
    expect(reversed.readiness, MonthlyRosterSectionReadiness.blockedDate);
  });

  test('marks empty but valid section without inventing assignments', () {
    final result = classifier.assess(_section(assignments: const []));

    expect(result.readiness, MonthlyRosterSectionReadiness.empty);
    expect(result.canEnterReview, isFalse);
    expect(result.reasonCodes, ['NO_ASSIGNMENTS']);
  });

  test('requires review for missing identity or shift label', () {
    final result = classifier.assess(
      _section(
        assignments: [
          _assignment(workerName: '', rowLabel: ''),
        ],
      ),
    );

    expect(result.readiness, MonthlyRosterSectionReadiness.needsReview);
    expect(result.canEnterReview, isTrue);
    expect(
      result.reasonCodes,
      containsAll([
        'WORKER_IDENTITY_MISSING:B3',
        'SHIFT_LABEL_MISSING:B3',
      ]),
    );
    expect(result.canCommit, isFalse);
  });

  test('requires review when an assignment falls outside its section range', () {
    final result = classifier.assess(
      _section(
        assignments: [
          _assignment(date: DateTime(2026, 12, 1)),
        ],
      ),
    );

    expect(result.readiness, MonthlyRosterSectionReadiness.needsReview);
    expect(
      result.reasonCodes,
      contains('ASSIGNMENT_OUTSIDE_SECTION_RANGE:B3'),
    );
  });

  test('marks an untitled section unsupported', () {
    final result = classifier.assess(_section(title: '  '));

    expect(result.readiness, MonthlyRosterSectionReadiness.unsupported);
    expect(result.reasonCodes, ['SECTION_TITLE_MISSING']);
  });
}

MonthlyRosterSection _section({
  String title = 'MRI November 2026',
  DateTime? startDate = const DateTime(2026, 11, 1),
  DateTime? endDate = const DateTime(2026, 11, 30),
  List<MonthlyRosterAssignment>? assignments,
  List<MonthlyRosterDateAnomaly> dateAnomalies = const [],
}) {
  return MonthlyRosterSection(
    title: title,
    headerRowIndex: 1,
    assignments: assignments ?? [_assignment()],
    startDate: startDate,
    endDate: endDate,
    dateAnomalies: dateAnomalies,
  );
}

MonthlyRosterAssignment _assignment({
  String workerName = 'Employee A',
  String rowLabel = 'MRI',
  DateTime? date,
}) {
  return MonthlyRosterAssignment(
    sectionTitle: 'MRI November 2026',
    rowLabel: rowLabel,
    rowIndex: 2,
    workerName: workerName,
    date: date ?? DateTime(2026, 11, 1),
    sourceCell: 'B3',
  );
}
