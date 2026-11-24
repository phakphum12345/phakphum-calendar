import '../../../domain/entities/employee.dart';
import '../../../domain/entities/shift_template.dart';
import '../domain/monthly_roster_section.dart';
import 'grid_roster_employee_identity_resolver.dart';
import 'monthly_roster_section_parser.dart';
import 'monthly_roster_section_safety.dart';

/// Read-only review data for one source assignment.
class GridRosterAssignmentReview {
  const GridRosterAssignmentReview({
    required this.source,
    required this.identity,
    required this.shiftRule,
    required this.sectionBlocked,
  });

  final MonthlyRosterAssignment source;
  final EmployeeIdentityResolution identity;
  final MonthlyRosterShiftRuleResolution shiftRule;
  final bool sectionBlocked;

  /// A review item is never directly committable.
  bool get canCommit => false;
}

/// Section review preserves the original assessment and every source row.
class GridRosterSectionReview {
  GridRosterSectionReview({
    required this.assessment,
    required List<GridRosterAssignmentReview> assignments,
  }) : assignments = List.unmodifiable(assignments);

  final MonthlyRosterSectionAssessment assessment;
  final List<GridRosterAssignmentReview> assignments;
}

/// Immutable, source- and target-bound Grid review snapshot.
///
/// This is not an approval or persistence record. It must be rebuilt when the
/// source fingerprint or target schedule revision changes.
class GridRosterReviewSession {
  GridRosterReviewSession({
    required this.sourceFingerprint,
    required this.targetScheduleId,
    required this.targetScheduleRevision,
    required List<GridRosterSectionReview> sections,
    this.sourceSheetCount = 0,
    List<String> warnings = const [],
  }) : sections = List.unmodifiable(sections),
       warnings = List.unmodifiable(warnings);

  final String sourceFingerprint;
  final String targetScheduleId;
  final String targetScheduleRevision;
  final List<GridRosterSectionReview> sections;
  final int sourceSheetCount;
  final List<String> warnings;

  List<GridRosterAssignmentReview> get assignments => [
    for (final section in sections) ...section.assignments,
  ];

  bool get requiresHumanReview => true;

  /// A preview snapshot cannot authorize writes.
  bool get canCommit => false;
}

/// Composes section safety, identity candidates and shift-rule evidence.
///
/// Fingerprints and target revision are supplied by their owning repositories;
/// this builder does not invent them or access persistence.
class GridRosterReviewSessionBuilder {
  const GridRosterReviewSessionBuilder({
    this.sectionClassifier = const MonthlyRosterSectionSafetyClassifier(),
    this.identityResolver = const GridRosterEmployeeIdentityResolver(),
    this.shiftAdapter = const MonthlyRosterShiftAdapter(),
  });

  final MonthlyRosterSectionSafetyClassifier sectionClassifier;
  final GridRosterEmployeeIdentityResolver identityResolver;
  final MonthlyRosterShiftAdapter shiftAdapter;

  GridRosterReviewSession build({
    required MonthlyRosterParseReport report,
    required Iterable<Employee> employees,
    required Iterable<ShiftTemplate> shiftTemplates,
    required String sourceFingerprint,
    required String targetScheduleId,
    required String targetScheduleRevision,
  }) {
    _requireValue(sourceFingerprint, 'sourceFingerprint');
    _requireValue(targetScheduleId, 'targetScheduleId');
    _requireValue(targetScheduleRevision, 'targetScheduleRevision');

    final employeeSnapshot = employees.toList(growable: false);
    final templateSnapshot = shiftTemplates.toList(growable: false);
    final sections = <GridRosterSectionReview>[];

    for (final section in report.sections) {
      final assessment = sectionClassifier.assess(section);
      final blocked =
          assessment.readiness == MonthlyRosterSectionReadiness.blockedDate ||
          assessment.readiness == MonthlyRosterSectionReadiness.unsupported;
      final assignments = section.assignments.map((assignment) {
        return GridRosterAssignmentReview(
          source: assignment,
          identity: identityResolver.resolve(
            sourceName: assignment.workerName,
            employees: employeeSnapshot,
          ),
          shiftRule: shiftAdapter.resolveRuleForLabel(
            assignment.rowLabel,
            shiftTemplates: templateSnapshot,
          ),
          sectionBlocked: blocked,
        );
      }).toList(growable: false);

      sections.add(
        GridRosterSectionReview(
          assessment: assessment,
          assignments: assignments,
        ),
      );
    }

    return GridRosterReviewSession(
      sourceFingerprint: sourceFingerprint,
      targetScheduleId: targetScheduleId,
      targetScheduleRevision: targetScheduleRevision,
      sections: sections,
      sourceSheetCount: report.sourceSheetCount,
      warnings: report.warnings,
    );
  }

  void _requireValue(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'Must not be empty.');
    }
  }
}
