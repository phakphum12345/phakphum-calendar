import '../../../domain/entities/shift_assignment.dart';

/// One reviewed source row prepared for comparison with a canonical schedule.
class ImportStagingRow {
  const ImportStagingRow({
    required this.sourceRowNumber,
    required this.date,
    required this.assignment,
  });

  /// One-based row number in the source worksheet.
  final int sourceRowNumber;

  /// Null means the source row has not passed date validation.
  final DateTime? date;

  /// Null means employee or shift identity has not been resolved.
  final ShiftAssignment? assignment;
}

/// Suggested action only. Applying a plan remains a separate explicit step.
enum ImportRowDecision { create, update, skip, review }

enum ImportRowDecisionReason {
  newAssignment,
  alreadyPresent,
  existingAssignmentChanged,
  repeatedIdenticalSourceRow,
  conflictingSourceRows,
  unresolvedDateOrIdentity,
  ambiguousExistingAssignment,
}

/// A deterministic, read-only classification for one source row.
class ImportStagingEntry {
  const ImportStagingEntry({
    required this.sourceRowNumber,
    required this.decision,
    required this.reason,
    this.date,
    this.assignment,
  });

  final int sourceRowNumber;
  final DateTime? date;
  final ShiftAssignment? assignment;
  final ImportRowDecision decision;
  final ImportRowDecisionReason reason;

  bool get requiresHumanReview => decision == ImportRowDecision.review;
}

/// Immutable result of comparing imported rows with an existing schedule.
class ImportStagingPlan {
  ImportStagingPlan(Iterable<ImportStagingEntry> entries)
    : entries = List.unmodifiable(entries);

  final List<ImportStagingEntry> entries;

  int get createCount =>
      entries.where((entry) => entry.decision == ImportRowDecision.create).length;
  int get updateCount =>
      entries.where((entry) => entry.decision == ImportRowDecision.update).length;
  int get skipCount =>
      entries.where((entry) => entry.decision == ImportRowDecision.skip).length;
  int get reviewCount =>
      entries.where((entry) => entry.decision == ImportRowDecision.review).length;

  bool get isReadyForExplicitConfirmation => reviewCount == 0;
}
