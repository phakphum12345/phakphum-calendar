import '../domain/monthly_roster_section.dart';

/// Readiness of one parsed section for the next human-review stage.
///
/// This is a pure assessment: it does not change parser output, resolve people,
/// map shifts, persist data, or authorize Calendar synchronization.
enum MonthlyRosterSectionReadiness {
  ready,
  blockedDate,
  empty,
  needsReview,
  unsupported,
}

/// Stable, inspectable reasons explaining a section readiness decision.
class MonthlyRosterSectionAssessment {
  const MonthlyRosterSectionAssessment({
    required this.section,
    required this.readiness,
    required this.reasonCodes,
  });

  final MonthlyRosterSection section;
  final MonthlyRosterSectionReadiness readiness;
  final List<String> reasonCodes;

  /// A section can proceed to identity/shift review only when it is structurally
  /// ready or requires human clarification. This never means it can be saved.
  bool get canEnterReview =>
      readiness == MonthlyRosterSectionReadiness.ready ||
      readiness == MonthlyRosterSectionReadiness.needsReview;

  /// The assessment alone never authorizes persistence.
  bool get canCommit => false;
}

/// Pure section-level safety classification for Grid import review.
class MonthlyRosterSectionSafetyClassifier {
  const MonthlyRosterSectionSafetyClassifier();

  MonthlyRosterSectionAssessment assess(MonthlyRosterSection section) {
    if (section.title.trim().isEmpty) {
      return _result(
        section,
        MonthlyRosterSectionReadiness.unsupported,
        const ['SECTION_TITLE_MISSING'],
      );
    }

    if (section.dateAnomalies.isNotEmpty) {
      return _result(
        section,
        MonthlyRosterSectionReadiness.blockedDate,
        section.dateAnomalies
            .map((anomaly) => 'DATE_ANOMALY:${anomaly.code}')
            .toList(growable: false),
      );
    }

    final start = section.startDate;
    final end = section.endDate;
    if (start == null || end == null || _dateOnly(start).isAfter(_dateOnly(end))) {
      return _result(
        section,
        MonthlyRosterSectionReadiness.blockedDate,
        const ['SECTION_DATE_RANGE_UNRESOLVED'],
      );
    }

    if (section.assignments.isEmpty) {
      return _result(
        section,
        MonthlyRosterSectionReadiness.empty,
        const ['NO_ASSIGNMENTS'],
      );
    }

    final reasons = <String>[];
    for (final assignment in section.assignments) {
      if (assignment.workerName.trim().isEmpty) {
        reasons.add('WORKER_IDENTITY_MISSING:${assignment.sourceCell}');
      }
      if (assignment.rowLabel.trim().isEmpty) {
        reasons.add('SHIFT_LABEL_MISSING:${assignment.sourceCell}');
      }
      final date = _dateOnly(assignment.date);
      if (date.isBefore(_dateOnly(start)) || date.isAfter(_dateOnly(end))) {
        reasons.add('ASSIGNMENT_OUTSIDE_SECTION_RANGE:${assignment.sourceCell}');
      }
    }

    if (reasons.isNotEmpty) {
      return _result(
        section,
        MonthlyRosterSectionReadiness.needsReview,
        List.unmodifiable(reasons),
      );
    }

    return _result(
      section,
      MonthlyRosterSectionReadiness.ready,
      const [],
    );
  }

  MonthlyRosterSectionAssessment _result(
    MonthlyRosterSection section,
    MonthlyRosterSectionReadiness readiness,
    List<String> reasons,
  ) {
    return MonthlyRosterSectionAssessment(
      section: section,
      readiness: readiness,
      reasonCodes: List.unmodifiable(reasons),
    );
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
