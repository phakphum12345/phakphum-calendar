import '../../../domain/entities/employee.dart';
import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/schedule_month.dart';
import '../../../domain/entities/shift_assignment.dart';
import '../../../domain/entities/shift_template.dart';
import '../../../domain/entities/shift_type.dart';
import '../../../models/shift.dart' show ShiftCategory, ShiftCategoryInfo;
import '../domain/grid_roster_import_provenance.dart';
import '../domain/monthly_roster_section.dart';
import 'grid_roster_review_session.dart';
import 'monthly_roster_section_parser.dart';
import 'monthly_roster_section_safety.dart';

/// Explicit reviewer decision for one stable source assignment.
class GridRosterAssignmentDecision {
  const GridRosterAssignmentDecision({
    required this.include,
    required this.reviewerId,
    required this.reviewedAtUtc,
    this.employeeId,
    this.shiftTemplateId,
  });

  final bool include;
  final String? employeeId;
  final String? shiftTemplateId;
  final String reviewerId;
  final DateTime reviewedAtUtc;
}

/// Result of converting a fully reviewed Grid session into a canonical
/// Schedule candidate. It is not persisted and does not trigger Calendar sync.
class GridRosterCanonicalConversionResult {
  const GridRosterCanonicalConversionResult({
    required this.schedule,
    required this.preparedProvenance,
    required this.includedAssignmentCount,
    required this.excludedAssignmentCount,
  });

  final Schedule schedule;
  final GridRosterImportProvenance preparedProvenance;
  final int includedAssignmentCount;
  final int excludedAssignmentCount;

  /// Produces the provenance form required by the bundle journal after the
  /// caller has explicitly accepted the Schedule candidate.
  GridRosterImportProvenance committedProvenance({
    required String acceptedScheduleFingerprint,
  }) {
    if (acceptedScheduleFingerprint.trim().isEmpty) {
      throw ArgumentError.value(
        acceptedScheduleFingerprint,
        'acceptedScheduleFingerprint',
        'Must not be empty.',
      );
    }
    return GridRosterImportProvenance(
      importRunId: preparedProvenance.importRunId,
      sourceFingerprint: preparedProvenance.sourceFingerprint,
      parserVersion: preparedProvenance.parserVersion,
      createdAtUtc: preparedProvenance.createdAtUtc,
      targetScheduleId: preparedProvenance.targetScheduleId,
      targetScheduleRevision: preparedProvenance.targetScheduleRevision,
      lifecycle: GridRosterImportLifecycle.committed,
      acceptedScheduleFingerprint: acceptedScheduleFingerprint,
      sourceRevisionId: preparedProvenance.sourceRevisionId,
      sections: preparedProvenance.sections,
      assignments: preparedProvenance.assignments,
      diagnostics: preparedProvenance.diagnostics,
    );
  }
}

/// Fail-closed error raised when review evidence cannot be converted safely.
class GridRosterCanonicalConversionException implements Exception {
  const GridRosterCanonicalConversionException(this.message);

  final String message;

  @override
  String toString() => 'GridRosterCanonicalConversionException: $message';
}

/// Converts an immutable review snapshot using explicit, per-assignment
/// human decisions. Existing Schedule data is preserved; collisions fail
/// closed instead of silently replacing or deduplicating assignments.
class GridRosterCanonicalConverter {
  const GridRosterCanonicalConverter();

  GridRosterCanonicalConversionResult convert({
    required GridRosterReviewSession session,
    required Schedule targetSchedule,
    required Iterable<Employee> employees,
    required Iterable<ShiftTemplate> shiftTemplates,
    required Map<String, GridRosterAssignmentDecision> decisions,
    required String importRunId,
    required String parserVersion,
    required DateTime createdAtUtc,
    String? sourceRevisionId,
  }) {
    _requireText(importRunId, 'importRunId');
    _requireText(parserVersion, 'parserVersion');
    if (targetSchedule.id != session.targetScheduleId) {
      throw const GridRosterCanonicalConversionException(
        'Target Schedule id does not match the review session.',
      );
    }

    _validateTargetSchedule(targetSchedule);
    final employeeById = <String, Employee>{
      for (final employee in employees)
        if (employee.active) employee.id: employee,
    };
    final templateById = <String, ShiftTemplate>{
      for (final template in shiftTemplates)
        if (template.active) template.id: template,
    };
    final assignmentReviews = <String, _ReviewedAssignment>{};
    final sectionIds = <String, String>{};
    final provenanceSections = <GridRosterProvenanceSection>[];
    final diagnostics = <GridRosterProvenanceDiagnostic>[];

    for (final sectionReview in session.sections) {
      final section = sectionReview.assessment.section;
      final sectionId = _sectionId(session.sourceFingerprint, section);
      if (sectionIds.containsKey(sectionId)) {
        throw const GridRosterCanonicalConversionException(
          'Duplicate source section identity.',
        );
      }
      sectionIds[sectionId] = section.title;
      final assessment = sectionReview.assessment;
      provenanceSections.add(
        GridRosterProvenanceSection(
          sectionId: sectionId,
          title: section.title,
          readinessCode: assessment.readiness.name,
          startDate: section.startDate,
          endDate: section.endDate,
          reasonCodes: assessment.reasonCodes,
        ),
      );

      if (assessment.readiness == MonthlyRosterSectionReadiness.empty) {
        diagnostics.add(
          GridRosterProvenanceDiagnostic(
            code: 'SECTION_EMPTY',
            severity: GridRosterDiagnosticSeverity.info,
            sectionId: sectionId,
          ),
        );
      }
      if (assessment.readiness == MonthlyRosterSectionReadiness.blockedDate ||
          assessment.readiness == MonthlyRosterSectionReadiness.unsupported) {
        diagnostics.add(
          GridRosterProvenanceDiagnostic(
            code: 'SECTION_BLOCKED',
            severity: GridRosterDiagnosticSeverity.blocking,
            sectionId: sectionId,
          ),
        );
      }

      for (final review in sectionReview.assignments) {
        final source = review.source;
        final sourceId = assignmentId(session.sourceFingerprint, source);
        if (assignmentReviews.containsKey(sourceId)) {
          throw const GridRosterCanonicalConversionException(
            'Duplicate source assignment identity.',
          );
        }
        final decision = decisions[sourceId];
        if (decision == null) {
          throw GridRosterCanonicalConversionException(
            'Missing explicit reviewer decision for $sourceId.',
          );
        }
        _requireText(decision.reviewerId, 'reviewerId');
        if (review.sectionBlocked && decision.include) {
          throw GridRosterCanonicalConversionException(
            'Assignment $sourceId belongs to a blocked section and cannot be included.',
          );
        }
        if (decision.include &&
            assessment.reasonCodes.contains(
              'ASSIGNMENT_OUTSIDE_SECTION_RANGE:${source.sourceCell}',
            )) {
          throw GridRosterCanonicalConversionException(
            'Assignment $sourceId falls outside its declared section date range.',
          );
        }

        Employee? employee;
        ShiftType? shift;
        String? templateId;
        final rule = review.shiftRule;
        var ruleKind = switch (rule.status) {
          MonthlyRosterShiftRuleStatus.configuredTemplate =>
            GridRosterShiftRuleKind.configuredTemplate,
          MonthlyRosterShiftRuleStatus.builtInRule =>
            GridRosterShiftRuleKind.builtInRule,
          MonthlyRosterShiftRuleStatus.ambiguousTemplate =>
            GridRosterShiftRuleKind.ambiguousTemplate,
          MonthlyRosterShiftRuleStatus.unsupportedLabel =>
            GridRosterShiftRuleKind.unsupportedLabel,
          MonthlyRosterShiftRuleStatus.emptyLabel =>
            GridRosterShiftRuleKind.unresolved,
        };
        if (rule.status == MonthlyRosterShiftRuleStatus.configuredTemplate) {
          templateId = rule.templateId;
        }
        if (decision.shiftTemplateId != null) {
          final selectedTemplate = templateById[decision.shiftTemplateId!];
          if (selectedTemplate == null) {
            throw GridRosterCanonicalConversionException(
              'Selected shift template ${decision.shiftTemplateId} is missing or inactive.',
            );
          }
          templateId = selectedTemplate.id;
          ruleKind = GridRosterShiftRuleKind.configuredTemplate;
        }

        if (decision.include) {
          final employeeId = decision.employeeId;
          if (employeeId == null || employeeId.trim().isEmpty) {
            throw GridRosterCanonicalConversionException(
              'Included assignment $sourceId requires an explicit employee selection.',
            );
          }
          employee = employeeById[employeeId];
          if (employee == null) {
            throw GridRosterCanonicalConversionException(
              'Selected employee $employeeId is missing or inactive.',
            );
          }
          if (templateId != null) {
            final template = templateById[templateId];
            if (template == null) {
              throw GridRosterCanonicalConversionException(
                'Configured shift template for $sourceId is missing or inactive.',
              );
            }
            if (template.id == rule.templateId &&
                (template.code != rule.code ||
                    template.startTime != rule.startTime ||
                    template.endTime != rule.endTime)) {
              throw GridRosterCanonicalConversionException(
                'Configured shift template changed after the review snapshot.',
              );
            }
            shift = template.toShiftType();
          } else {
            if (!rule.isResolved ||
                rule.startTime == null ||
                rule.endTime == null ||
                rule.code == null) {
              throw GridRosterCanonicalConversionException(
                'Included assignment $sourceId has no resolved shift rule or explicit template selection.',
              );
            }
            final start = rule.startTime!;
            final end = rule.endTime!;
            final endForDuration = end <= start
                ? end + const Duration(days: 1)
                : end;
            final category = rule.category ?? ShiftCategory.own;
            final shiftId = _builtInShiftId(rule.code!, start, end);
            shift = ShiftType(
              id: shiftId,
              code: rule.code!,
              name: source.rowLabel,
              color: category.colorValue,
              startTime: start,
              endTime: end,
              workingHours:
                  endForDuration.inMinutes - start.inMinutes <= 0
                      ? 0
                      : (endForDuration.inMinutes - start.inMinutes) / 60,
            );
          }
          _ensureCompatibleShiftType(targetSchedule, shift);
        } else if (decision.employeeId != null &&
            decision.employeeId!.trim().isNotEmpty) {
          employee = employeeById[decision.employeeId!];
          if (employee == null) {
            throw GridRosterCanonicalConversionException(
              'Selected employee ${decision.employeeId} is missing or inactive.',
            );
          }
        }

        assignmentReviews[sourceId] = _ReviewedAssignment(
          sectionId: sectionId,
          sourceId: sourceId,
          source: source,
          decision: decision,
          employee: employee,
          shift: shift,
          templateId: templateId,
          shiftRuleKind: ruleKind,
        );
      }
    }

    final unknownDecisionIds = decisions.keys
        .where((id) => !assignmentReviews.containsKey(id))
        .toList(growable: false);
    if (unknownDecisionIds.isNotEmpty) {
      throw GridRosterCanonicalConversionException(
        'Decisions contain unknown source assignment ids: '
        '${unknownDecisionIds.join(', ')}.',
      );
    }

    final months = <String, ScheduleMonth>{
      for (final month in targetSchedule.months)
        _monthKey(month.month): month,
    };
    var included = 0;
    var excluded = 0;
    final provenanceAssignments = <GridRosterAssignmentProvenance>[];

    for (final reviewed in assignmentReviews.values) {
      final decision = reviewed.decision;
      final source = reviewed.source;
      if (decision.include) {
        final employee = reviewed.employee!;
        final shift = reviewed.shift!;
        final date = DateTime(source.date.year, source.date.month, source.date.day);
        final monthKey = _monthKey(date);
        final month = months[monthKey] ?? ScheduleMonth.empty(date);
        final day = month.day(date);
        if (day == null) {
          throw GridRosterCanonicalConversionException(
            'Target Schedule has no day for ${date.toIso8601String()}.',
          );
        }
        final duplicate = day.assignments.any(
          (assignment) =>
              assignment.employee.id == employee.id &&
              assignment.shift.id == shift.id,
        );
        if (duplicate) {
          throw GridRosterCanonicalConversionException(
            'Assignment collision on ${date.toIso8601String()} for '
            'employee ${employee.id} and shift ${shift.id}.',
          );
        }
        final updatedDay = day.copyWith(
          assignments: [
            ...day.assignments,
            ShiftAssignment(
              employee: employee,
              shift: shift,
              location: reviewed.templateId == null
                  ? null
                  : templateById[reviewed.templateId]?.location,
            ),
          ],
        );
        months[monthKey] = month.replaceDay(updatedDay);
        included++;
      } else {
        excluded++;
      }

      provenanceAssignments.add(
        GridRosterAssignmentProvenance(
          sourceAssignmentId: reviewed.sourceId,
          sectionId: reviewed.sectionId,
          sourceCellReference: source.sourceCell,
          assignmentDate: DateTime(
            source.date.year,
            source.date.month,
            source.date.day,
          ),
          canonicalEmployeeId: decision.include
              ? reviewed.employee!.id
              : reviewed.employee?.id,
          shiftTemplateId: reviewed.templateId,
          reviewDecision: decision.include
              ? GridRosterReviewDecision.include
              : GridRosterReviewDecision.exclude,
          shiftRuleKind: reviewed.shiftRuleKind,
          reviewerId: decision.reviewerId,
          reviewedAtUtc: decision.reviewedAtUtc.toUtc(),
        ),
      );
    }

    final resultSchedule = targetSchedule.copyWith(
      months: months.values.toList()
        ..sort((left, right) => left.month.compareTo(right.month)),
    );
    final provenance = GridRosterImportProvenance(
      importRunId: importRunId,
      sourceFingerprint: session.sourceFingerprint,
      parserVersion: parserVersion,
      createdAtUtc: createdAtUtc.toUtc(),
      targetScheduleId: targetSchedule.id,
      targetScheduleRevision: session.targetScheduleRevision,
      lifecycle: GridRosterImportLifecycle.prepared,
      sourceRevisionId: sourceRevisionId,
      sections: provenanceSections,
      assignments: provenanceAssignments,
      diagnostics: diagnostics,
    );

    return GridRosterCanonicalConversionResult(
      schedule: resultSchedule,
      preparedProvenance: provenance,
      includedAssignmentCount: included,
      excludedAssignmentCount: excluded,
    );
  }

  static String assignmentId(
    String sourceFingerprint,
    MonthlyRosterAssignment sourceAssignment,
  ) {
    _requireText(sourceFingerprint, 'sourceFingerprint');
    final sectionTitle = sourceAssignment.sectionTitle;
    final sourceCell = sourceAssignment.sourceCell;
    final spreadsheetId = sourceAssignment.spreadsheetId;
    final sheetId = sourceAssignment.sheetId;
    return '$sourceFingerprint|$sectionTitle|${spreadsheetId ?? ''}|'
        '${sheetId ?? ''}|${sourceCell.toUpperCase()}';
  }

  static String _sectionId(String fingerprint, MonthlyRosterSection section) =>
      '$fingerprint|section|${section.sourceSpreadsheetId ?? ''}|'
      '${section.sourceSheetId ?? ''}|${section.sourceSheetTitle ?? ''}|'
      '${section.headerRowIndex}|${section.title}';

  static String _builtInShiftId(String code, Duration start, Duration end) =>
      'grid_builtin_${code}_${start.inMinutes}_${end.inMinutes}';

  static String _monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';

  static void _validateTargetSchedule(Schedule schedule) {
    final monthKeys = <String>{};
    for (final month in schedule.months) {
      if (!monthKeys.add(_monthKey(month.month))) {
        throw const GridRosterCanonicalConversionException(
          'Target Schedule contains duplicate months.',
        );
      }
      final dayKeys = <String>{};
      for (final day in month.days) {
        final key = '${day.date.year}-${day.date.month}-${day.date.day}';
        if (day.date.year != month.month.year ||
            day.date.month != month.month.month ||
            !dayKeys.add(key)) {
          throw const GridRosterCanonicalConversionException(
            'Target Schedule contains an invalid or duplicate day.',
          );
        }
      }
    }
  }

  static void _ensureCompatibleShiftType(Schedule target, ShiftType shift) {
    for (final month in target.months) {
      for (final day in month.days) {
        for (final assignment in day.assignments) {
          if (assignment.shift.id != shift.id) continue;
          final existing = assignment.shift;
          if (existing.code != shift.code ||
              existing.name != shift.name ||
              existing.color != shift.color ||
              existing.startTime != shift.startTime ||
              existing.endTime != shift.endTime ||
              existing.workingHours != shift.workingHours) {
            throw GridRosterCanonicalConversionException(
              'Shift type id ${shift.id} conflicts with existing canonical data.',
            );
          }
        }
      }
    }
  }

  static void _requireText(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'Must not be empty.');
    }
  }
}

class _ReviewedAssignment {
  const _ReviewedAssignment({
    required this.sectionId,
    required this.sourceId,
    required this.source,
    required this.decision,
    required this.employee,
    required this.shift,
    required this.templateId,
    required this.shiftRuleKind,
  });

  final String sectionId;
  final String sourceId;
  final MonthlyRosterAssignment source;
  final GridRosterAssignmentDecision decision;
  final Employee? employee;
  final ShiftType? shift;
  final String? templateId;
  final GridRosterShiftRuleKind shiftRuleKind;
}
