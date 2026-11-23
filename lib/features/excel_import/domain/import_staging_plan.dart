import '../../../domain/entities/shift_assignment.dart';
import 'shift_record.dart';

/// Suggested mutation for one imported source row.
///
/// This is analysis only. Applying a plan requires a separate explicit
/// confirmation and persistence operation.
enum ImportRowAction { create, update, skip, blocked }

/// Stable reason explaining why a row received its suggested action.
enum ImportRowDecisionReason {
  noMatchingAssignment,
  existingAssignmentUnchanged,
  existingAssignmentChanged,
  identicalDuplicateSourceRow,
  missingDate,
  unresolvedEmployee,
  unresolvedShiftTemplate,
  conflictingDuplicateSourceRows,
  duplicateExistingAssignments,
}

class ImportStagingEntry {
  const ImportStagingEntry({
    required this.record,
    required this.action,
    required this.reason,
    this.candidate,
  });

  final ShiftRecord record;
  final ImportRowAction action;
  final ImportRowDecisionReason reason;
  final ShiftAssignment? candidate;

  int get rowNumber => record.rowNumber;

  bool get isBlocked => action == ImportRowAction.blocked;
}

class ImportStagingPlan {
  ImportStagingPlan({
    required this.scheduleId,
    required List<ImportStagingEntry> entries,
  }) : entries = List.unmodifiable(entries);

  final String scheduleId;
  final List<ImportStagingEntry> entries;

  int get createCount =>
      entries.where((entry) => entry.action == ImportRowAction.create).length;
  int get updateCount =>
      entries.where((entry) => entry.action == ImportRowAction.update).length;
  int get skipCount =>
      entries.where((entry) => entry.action == ImportRowAction.skip).length;
  int get blockedCount =>
      entries.where((entry) => entry.action == ImportRowAction.blocked).length;

  bool get hasBlockingRows => blockedCount > 0;
}
