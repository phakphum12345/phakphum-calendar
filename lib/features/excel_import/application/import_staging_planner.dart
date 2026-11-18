import '../../../domain/entities/employee.dart';
import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/shift_assignment.dart';
import '../../../domain/entities/shift_type.dart';
import '../domain/import_staging_plan.dart';
import '../domain/shift_record.dart';

/// Produces deterministic, read-only row decisions against a canonical
/// schedule. It never persists data or calls a Calendar provider.
class ImportStagingPlanner {
  const ImportStagingPlanner();

  ImportStagingPlan plan({
    required Schedule existingSchedule,
    required Iterable<ShiftRecord> records,
  }) {
    final sourceRows = records.toList(growable: false);
    final entries = List<ImportStagingEntry?>.filled(sourceRows.length, null);
    final candidatesByKey = <(String, String, String), List<_CandidateRow>>{};

    for (var index = 0; index < sourceRows.length; index++) {
      final record = sourceRows[index];
      if (record.date == null) {
        entries[index] = ImportStagingEntry(
          record: record,
          action: ImportRowAction.blocked,
          reason: ImportRowDecisionReason.missingDate,
        );
        continue;
      }
      final employee = record.resolvedEmployee;
      if (employee == null) {
        entries[index] = ImportStagingEntry(
          record: record,
          action: ImportRowAction.blocked,
          reason: ImportRowDecisionReason.unresolvedEmployee,
        );
        continue;
      }
      final template = record.resolvedShiftTemplate;
      if (template == null) {
        entries[index] = ImportStagingEntry(
          record: record,
          action: ImportRowAction.blocked,
          reason: ImportRowDecisionReason.unresolvedShiftTemplate,
        );
        continue;
      }

      final candidate = ShiftAssignment(
        employee: employee,
        shift: template.toShiftType(),
        remark: record.notes,
        location: record.location,
      );
      final key = _assignmentKey(record.date!, employee.id, template.id);
      candidatesByKey.putIfAbsent(key, () => []).add(
        _CandidateRow(index: index, record: record, assignment: candidate),
      );
    }

    for (final group in candidatesByKey.values) {
      if (!_allEquivalent(group)) {
        for (final row in group) {
          entries[row.index] = ImportStagingEntry(
            record: row.record,
            action: ImportRowAction.blocked,
            reason: ImportRowDecisionReason.conflictingDuplicateSourceRows,
            candidate: row.assignment,
          );
        }
        continue;
      }

      final first = group.first;
      entries[first.index] = _decideAgainstExisting(
        existingSchedule: existingSchedule,
        row: first,
      );

      for (final duplicate in group.skip(1)) {
        entries[duplicate.index] = ImportStagingEntry(
          record: duplicate.record,
          action: ImportRowAction.skip,
          reason: ImportRowDecisionReason.identicalDuplicateSourceRow,
          candidate: duplicate.assignment,
        );
      }
    }

    return ImportStagingPlan(
      scheduleId: existingSchedule.id,
      entries: [
        for (var index = 0; index < entries.length; index++)
          entries[index]!,
      ],
    );
  }

  ImportStagingEntry _decideAgainstExisting({
    required Schedule existingSchedule,
    required _CandidateRow row,
  }) {
    final date = row.record.date!;
    final existingDay = existingSchedule.month(date)?.day(date);
    final matches = existingDay?.assignments
            .where(
              (assignment) =>
                  assignment.employee.id == row.assignment.employee.id &&
                  assignment.shift.id == row.assignment.shift.id,
            )
            .toList(growable: false) ??
        const <ShiftAssignment>[];

    if (matches.length > 1) {
      return ImportStagingEntry(
        record: row.record,
        action: ImportRowAction.blocked,
        reason: ImportRowDecisionReason.duplicateExistingAssignments,
        candidate: row.assignment,
      );
    }
    if (matches.isEmpty) {
      return ImportStagingEntry(
        record: row.record,
        action: ImportRowAction.create,
        reason: ImportRowDecisionReason.noMatchingAssignment,
        candidate: row.assignment,
      );
    }
    if (_sameContent(matches.single, row.assignment)) {
      return ImportStagingEntry(
        record: row.record,
        action: ImportRowAction.skip,
        reason: ImportRowDecisionReason.existingAssignmentUnchanged,
        candidate: row.assignment,
      );
    }
    return ImportStagingEntry(
      record: row.record,
      action: ImportRowAction.update,
      reason: ImportRowDecisionReason.existingAssignmentChanged,
      candidate: row.assignment,
    );
  }

  bool _allEquivalent(List<_CandidateRow> rows) {
    if (rows.length < 2) return true;
    final first = rows.first.assignment;
    return rows.skip(1).every((row) => _sameContent(first, row.assignment));
  }

  bool _sameContent(ShiftAssignment left, ShiftAssignment right) {
    return _sameEmployee(left.employee, right.employee) &&
        _sameShift(left.shift, right.shift) &&
        left.remark == right.remark &&
        left.location == right.location;
  }

  bool _sameEmployee(Employee left, Employee right) {
    return left.id == right.id &&
        left.employeeCode == right.employeeCode &&
        left.firstName == right.firstName &&
        left.lastName == right.lastName &&
        left.nickname == right.nickname &&
        left.department.id == right.department.id &&
        left.department.code == right.department.code &&
        left.department.name == right.department.name &&
        left.position == right.position &&
        left.active == right.active;
  }

  bool _sameShift(ShiftType left, ShiftType right) {
    return left.id == right.id &&
        left.code == right.code &&
        left.name == right.name &&
        left.color == right.color &&
        left.startTime == right.startTime &&
        left.endTime == right.endTime &&
        left.workingHours == right.workingHours;
  }

  (String, String, String) _assignmentKey(
    DateTime date,
    String employeeId,
    String shiftId,
  ) {
    final day =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return (day, employeeId, shiftId);
  }
}

class _CandidateRow {
  const _CandidateRow({
    required this.index,
    required this.record,
    required this.assignment,
  });

  final int index;
  final ShiftRecord record;
  final ShiftAssignment assignment;
}
