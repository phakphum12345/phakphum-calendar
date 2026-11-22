import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/schedule_day.dart';
import '../../../domain/entities/schedule_month.dart';
import '../../../domain/entities/shift_assignment.dart';
import '../domain/import_staging_plan.dart';

/// Applies only explicitly selected, non-blocked staging entries to an
/// immutable schedule snapshot. It performs no persistence or Calendar I/O.
class ImportStagingApplier {
  const ImportStagingApplier();

  Schedule apply({
    required Schedule existingSchedule,
    required ImportStagingPlan plan,
    required Set<int> includedRowNumbers,
  }) {
    if (plan.scheduleId != existingSchedule.id) {
      throw StateError('The staging plan belongs to a different schedule.');
    }

    final entriesByRow = <int, ImportStagingEntry>{};
    for (final entry in plan.entries) {
      if (entriesByRow.containsKey(entry.rowNumber)) {
        throw StateError('Source row numbers must be unique.');
      }
      entriesByRow[entry.rowNumber] = entry;
    }
    if (!entriesByRow.keys.toSet().containsAll(includedRowNumbers)) {
      throw StateError('The selection contains an unknown source row.');
    }

    var result = existingSchedule;
    for (final entry in plan.entries) {
      if (!includedRowNumbers.contains(entry.rowNumber)) continue;
      if (entry.action == ImportRowAction.blocked || entry.candidate == null) {
        throw StateError('Blocked rows cannot be applied.');
      }
      if (entry.action == ImportRowAction.skip) continue;

      final date = entry.record.date;
      if (date == null) {\n        throw StateError('Rows without dates cannot be applied.');\n      }
      final month = result.month(date) ?? ScheduleMonth.empty(date);
      final day = month.day(date) ?? ScheduleDay(date: date);
      final matches = day.assignments
          .where((assignment) => _sameIdentity(assignment, entry.candidate!))
          .toList(growable: false);

      switch (entry.action) {
        case ImportRowAction.create:
          if (matches.isNotEmpty) {
            throw StateError('CREATE would duplicate an existing assignment.');
          }
          result = result.replaceMonth(
            month.replaceDay(
              day.copyWith(assignments: [...day.assignments, entry.candidate!]),
            ),
          );
        case ImportRowAction.update:
          if (matches.length != 1) {
            throw StateError('UPDATE requires exactly one existing assignment.');
          }
          result = result.replaceMonth(
            month.replaceDay(
              day.copyWith(
                assignments: [
                  for (final assignment in day.assignments)
                    if (_sameIdentity(assignment, entry.candidate!))
                      entry.candidate!
                    else
                      assignment,
                ],
              ),
            ),
          );
        case ImportRowAction.skip:
          break;
        case ImportRowAction.blocked:
          throw StateError('Blocked rows cannot be applied.');
      }
    }
    return result;
  }

  bool _sameIdentity(ShiftAssignment left, ShiftAssignment right) =>
      left.employee.id == right.employee.id &&
      left.shift.id == right.shift.id;
}
