import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/shift_assignment.dart';
import '../domain/import_staging_row.dart';

/// Builds a read-only, deterministic row-level import plan.
///
/// This planner never mutates or persists a Schedule. It deliberately treats
/// multiple existing matches and conflicting duplicate source rows as review
/// cases instead of choosing a destructive resolution automatically.
class ImportStagingPlanner {
  const ImportStagingPlanner();

  ImportStagingPlan build({
    required Iterable<ImportStagingRow> rows,
    required Schedule existingSchedule,
  }) {
    final existingByKey = <String, List<ShiftAssignment>>{};
    for (final month in existingSchedule.months) {
      for (final day in month.days) {
        for (final assignment in day.assignments) {
          final key = _key(day.date, assignment);
          existingByKey.putIfAbsent(key, () => []).add(assignment);
        }
      }
    }

    final seenInSource = <String, ShiftAssignment>{};
    final entries = <ImportStagingEntry>[];
    for (final row in rows) {
      final date = row.date;
      final assignment = row.assignment;
      if (date == null || assignment == null) {
        entries.add(ImportStagingEntry(
          sourceRowNumber: row.sourceRowNumber,
          date: date,
          assignment: assignment,
          decision: ImportRowDecision.review,
          reason: ImportRowDecisionReason.unresolvedDateOrIdentity,
        ));
        continue;
      }

      final key = _key(date, assignment);
      final previousSource = seenInSource[key];
      if (previousSource != null) {
        final identical = previousSource == assignment;
        entries.add(ImportStagingEntry(
          sourceRowNumber: row.sourceRowNumber,
          date: _dateOnly(date),
          assignment: assignment,
          decision: identical
              ? ImportRowDecision.skip
              : ImportRowDecision.review,
          reason: identical
              ? ImportRowDecisionReason.repeatedIdenticalSourceRow
              : ImportRowDecisionReason.conflictingSourceRows,
        ));
        continue;
      }
      seenInSource[key] = assignment;

      final existingMatches = existingByKey[key] ?? const <ShiftAssignment>[];
      if (existingMatches.length > 1) {
        entries.add(ImportStagingEntry(
          sourceRowNumber: row.sourceRowNumber,
          date: _dateOnly(date),
          assignment: assignment,
          decision: ImportRowDecision.review,
          reason: ImportRowDecisionReason.ambiguousExistingAssignment,
        ));
      } else if (existingMatches.isEmpty) {
        entries.add(ImportStagingEntry(
          sourceRowNumber: row.sourceRowNumber,
          date: _dateOnly(date),
          assignment: assignment,
          decision: ImportRowDecision.create,
          reason: ImportRowDecisionReason.newAssignment,
        ));
      } else if (existingMatches.single == assignment) {
        entries.add(ImportStagingEntry(
          sourceRowNumber: row.sourceRowNumber,
          date: _dateOnly(date),
          assignment: assignment,
          decision: ImportRowDecision.skip,
          reason: ImportRowDecisionReason.alreadyPresent,
        ));
      } else {
        entries.add(ImportStagingEntry(
          sourceRowNumber: row.sourceRowNumber,
          date: _dateOnly(date),
          assignment: assignment,
          decision: ImportRowDecision.update,
          reason: ImportRowDecisionReason.existingAssignmentChanged,
        ));
      }
    }
    return ImportStagingPlan(entries);
  }

  String _key(DateTime date, ShiftAssignment assignment) {
    final normalized = _dateOnly(date);
    return '${normalized.year}-${normalized.month}-${normalized.day}|'
        '${assignment.employee.id}|'
        '${assignment.shift.id}';
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
