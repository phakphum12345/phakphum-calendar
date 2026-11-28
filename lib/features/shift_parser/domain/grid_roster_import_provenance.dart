/// Durable, privacy-minimizing evidence for one Grid workbook import.
enum GridRosterImportLifecycle { prepared, committed, aborted }

enum GridRosterReviewDecision { pending, include, exclude }

enum GridRosterShiftRuleKind {
  unresolved,
  configuredTemplate,
  builtInRule,
  ambiguousTemplate,
  unsupportedLabel,
}

enum GridRosterDiagnosticSeverity { info, warning, blocking }

/// Section-level evidence. Dates are ISO calendar dates, not timestamps.
class GridRosterProvenanceSection {
  GridRosterProvenanceSection({
    required this.sectionId,
    required this.title,
    required this.readinessCode,
    required List<String> reasonCodes,
    this.startDate,
    this.endDate,
  }) : reasonCodes = List.unmodifiable(reasonCodes) {
    _requireText(sectionId, 'sectionId');
    _requireText(title, 'title');
    _requireText(readinessCode, 'readinessCode');
    if ((startDate == null) != (endDate == null)) {
      throw ArgumentError('Section dates must both be present or both be null.');
    }
    if (startDate != null && endDate!.isBefore(startDate!)) {
      throw ArgumentError('Section endDate must not precede startDate.');
    }
  }

  final String sectionId;
  final String title;
  final String readinessCode;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> reasonCodes;
}

/// Links one source location to canonical entities without retaining raw cells.
class GridRosterAssignmentProvenance {
  GridRosterAssignmentProvenance({
    required this.sourceAssignmentId,
    required this.sectionId,
    required this.reviewDecision,
    required this.shiftRuleKind,
    this.sourceCellReference,
    this.assignmentDate,
    this.canonicalEmployeeId,
    this.shiftTemplateId,
    this.reviewerId,
    this.reviewedAtUtc,
  }) {
    _requireText(sourceAssignmentId, 'sourceAssignmentId');
    _requireText(sectionId, 'sectionId');
    if (sourceCellReference != null) {
      _requireText(sourceCellReference!, 'sourceCellReference');
    }
    if (canonicalEmployeeId != null) {
      _requireText(canonicalEmployeeId!, 'canonicalEmployeeId');
    }
    if (shiftTemplateId != null) _requireText(shiftTemplateId!, 'shiftTemplateId');
    if (reviewerId != null) _requireText(reviewerId!, 'reviewerId');
    if ((reviewerId == null) != (reviewedAtUtc == null)) {
      throw ArgumentError('Reviewer id and review timestamp must be paired.');
    }
    if (reviewDecision == GridRosterReviewDecision.pending &&
        reviewerId != null) {
      throw ArgumentError('Pending decisions cannot have reviewer evidence.');
    }
    if (reviewDecision != GridRosterReviewDecision.pending &&
        (reviewerId == null || reviewedAtUtc == null)) {
      throw ArgumentError('Final decisions require reviewer evidence.');
    }
    if (reviewDecision == GridRosterReviewDecision.include &&
        canonicalEmployeeId == null) {
      throw ArgumentError('Included assignments require a canonical employee id.');
    }
    if (reviewDecision == GridRosterReviewDecision.include &&
        shiftRuleKind != GridRosterShiftRuleKind.configuredTemplate &&
        shiftRuleKind != GridRosterShiftRuleKind.builtInRule) {
      throw ArgumentError('Included assignments require a resolved shift rule.');
    }
    if (shiftRuleKind == GridRosterShiftRuleKind.configuredTemplate &&
        shiftTemplateId == null) {
      throw ArgumentError('Configured template decisions require a template id.');
    }
    if (shiftRuleKind != GridRosterShiftRuleKind.configuredTemplate &&
        shiftTemplateId != null) {
      throw ArgumentError('Only configured template evidence may carry a template id.');
    }
  }

  final String sourceAssignmentId;
  final String sectionId;
  final String? sourceCellReference;
  final DateTime? assignmentDate;
  final String? canonicalEmployeeId;
  final String? shiftTemplateId;
  final GridRosterReviewDecision reviewDecision;
  final GridRosterShiftRuleKind shiftRuleKind;
  final String? reviewerId;
  final DateTime? reviewedAtUtc;
}

/// A diagnostic code and severity; deliberately excludes raw workbook values.
class GridRosterProvenanceDiagnostic {
  GridRosterProvenanceDiagnostic({
    required this.code,
    required this.severity,
    this.sectionId,
    this.sourceCellReference,
  }) {
    _requireText(code, 'code');
    if (sectionId != null) _requireText(sectionId!, 'sectionId');
    if (sourceCellReference != null) {
      _requireText(sourceCellReference!, 'sourceCellReference');
    }
  }

  final String code;
  final GridRosterDiagnosticSeverity severity;
  final String? sectionId;
  final String? sourceCellReference;
}

/// Separate, versioned import evidence; never embedded in Schedule schema v1.
class GridRosterImportProvenance {
  GridRosterImportProvenance({
    required this.importRunId,
    required this.sourceFingerprint,
    required this.parserVersion,
    required DateTime createdAtUtc,
    required this.targetScheduleId,
    required this.targetScheduleRevision,
    required this.lifecycle,
    required List<GridRosterProvenanceSection> sections,
    required List<GridRosterAssignmentProvenance> assignments,
    required List<GridRosterProvenanceDiagnostic> diagnostics,
    this.acceptedScheduleFingerprint,
    this.sourceRevisionId,
  }) : createdAtUtc = _asUtc(createdAtUtc),
       sections = List.unmodifiable(sections),
       assignments = List.unmodifiable(assignments),
       diagnostics = List.unmodifiable(diagnostics) {
    _requireText(importRunId, 'importRunId');
    _requireText(sourceFingerprint, 'sourceFingerprint');
    _requireText(parserVersion, 'parserVersion');
    _requireText(targetScheduleId, 'targetScheduleId');
    _requireText(targetScheduleRevision, 'targetScheduleRevision');
    if (acceptedScheduleFingerprint != null) {
      _requireText(acceptedScheduleFingerprint!, 'acceptedScheduleFingerprint');
    }
    if (sourceRevisionId != null) {
      _requireText(sourceRevisionId!, 'sourceRevisionId');
    }
    final sectionIds = this.sections.map((section) => section.sectionId).toSet();
    if (sectionIds.length != this.sections.length) {
      throw ArgumentError('Section ids must be unique.');
    }
    final assignmentIds =
        this.assignments.map((assignment) => assignment.sourceAssignmentId).toSet();
    if (assignmentIds.length != this.assignments.length) {
      throw ArgumentError('Source assignment ids must be unique.');
    }
    if (this.assignments.any((item) => !sectionIds.contains(item.sectionId))) {
      throw ArgumentError('Every assignment must reference a known section.');
    }
    if (this.diagnostics.any(
      (item) => item.sectionId != null && !sectionIds.contains(item.sectionId),
    )) {
      throw ArgumentError('Diagnostics must reference a known section.');
    }
    if (lifecycle == GridRosterImportLifecycle.committed &&
        acceptedScheduleFingerprint == null) {
      throw ArgumentError('Committed provenance requires an accepted schedule fingerprint.');
    }
    if (lifecycle == GridRosterImportLifecycle.committed &&
        this.assignments.any(
          (item) => item.reviewDecision == GridRosterReviewDecision.pending,
        )) {
      throw ArgumentError('Committed provenance cannot contain pending assignments.');
    }
    if (lifecycle != GridRosterImportLifecycle.committed &&
        acceptedScheduleFingerprint != null) {
      throw ArgumentError('Only committed provenance may carry an accepted fingerprint.');
    }
  }

  static const format = 'shift-tools.grid-roster-import-provenance';
  static const schemaVersion = 1;

  final String importRunId;
  final String sourceFingerprint;
  final String parserVersion;
  final DateTime createdAtUtc;
  final String targetScheduleId;
  final String targetScheduleRevision;
  final GridRosterImportLifecycle lifecycle;
  final String? acceptedScheduleFingerprint;
  final String? sourceRevisionId;
  final List<GridRosterProvenanceSection> sections;
  final List<GridRosterAssignmentProvenance> assignments;
  final List<GridRosterProvenanceDiagnostic> diagnostics;
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}

DateTime _asUtc(DateTime value) => value.toUtc();
