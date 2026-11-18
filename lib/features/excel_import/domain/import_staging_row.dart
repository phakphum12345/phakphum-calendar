import '../../../domain/entities/shift_assignment.dart';

/// Compatibility input row. New import flows should use ShiftRecord directly.
class ImportStagingRow {
  const ImportStagingRow({
    required this.sourceRowNumber,
    required this.date,
    required this.assignment,
  });

  final int sourceRowNumber;
  final DateTime? date;
  final ShiftAssignment? assignment;
}

/// Legacy output decision retained for callers of the compatibility adapter.
enum LegacyImportRowDecision { create, update, skip, review }

enum LegacyImportRowDecisionReason {
  newAssignment,
  alreadyPresent,
  existingAssignmentChanged,
  repeatedIdenticalSourceRow,
  conflictingSourceRows,
  unresolvedDateOrIdentity,
  ambiguousExistingAssignment,
}

class LegacyImportStagingEntry {
  const LegacyImportStagingEntry({
    required this.sourceRowNumber,
    required this.decision,
    required this.reason,
    this.date,
    this.assignment,
  });

  final int sourceRowNumber;
  final DateTime? date;
  final ShiftAssignment? assignment;
  final LegacyImportRowDecision decision;
  final LegacyImportRowDecisionReason reason;

  bool get requiresHumanReview => decision == LegacyImportRowDecision.review;
}

class LegacyImportStagingPlan {
  LegacyImportStagingPlan(Iterable<LegacyImportStagingEntry> entries)
      : entries = List.unmodifiable(entries);

  final List<LegacyImportStagingEntry> entries;

  int get createCount =>
      entries.where((entry) => entry.decision == LegacyImportRowDecision.create).length;
  int get updateCount =>
      entries.where((entry) => entry.decision == LegacyImportRowDecision.update).length;
  int get skipCount =>
      entries.where((entry) => entry.decision == LegacyImportRowDecision.skip).length;
  int get reviewCount =>
      entries.where((entry) => entry.decision == LegacyImportRowDecision.review).length;

  bool get isReadyForExplicitConfirmation => reviewCount == 0;
}
