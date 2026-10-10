import '../../../domain/entities/employee.dart';
import '../../../domain/entities/schedule.dart';

class EmployeeShiftDate {
  const EmployeeShiftDate({
    required this.date,
    required this.shiftCode,
    required this.shiftName,
    required this.start,
    required this.end,
  });

  final DateTime date;
  final String shiftCode;
  final String shiftName;
  final DateTime start;
  final DateTime end;
}

/// Reads employees and dated assignments from a canonical [Schedule].
///
/// Keeping schedule traversal here makes directory discovery independent of
/// presentation widgets.
class EmployeeDirectoryService {
  const EmployeeDirectoryService();

  /// Returns the employee's assignments in chronological date order.
  List<EmployeeShiftDate> assignments(Schedule schedule, String employeeId) {
    final result = <EmployeeShiftDate>[];
    for (final month in schedule.months) {
      for (final day in month.days) {
        for (final assignment in day.assignments) {
          if (assignment.employee.id != employeeId) continue;
          final start = day.date.add(assignment.shift.startTime);
          var end = day.date.add(assignment.shift.endTime);
          if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
          result.add(
            EmployeeShiftDate(
              date: day.date,
              shiftCode: assignment.shift.code,
              shiftName: assignment.shift.name,
              start: start,
              end: end,
            ),
          );
        }
      }
    }
    result.sort((left, right) {
      final dateOrder = left.date.compareTo(right.date);
      return dateOrder != 0 ? dateOrder : left.start.compareTo(right.start);
    });
    return List.unmodifiable(result);
  }

  /// Returns each employee referenced by the schedule exactly once.
  List<Employee> employees(Schedule schedule) {
    final byId = <String, Employee>{};
    for (final month in schedule.months) {
      for (final day in month.days) {
        for (final assignment in day.assignments) {
          byId.putIfAbsent(assignment.employee.id, () => assignment.employee);
        }
      }
    }
    final result = byId.values.toList()
      ..sort((left, right) {
        final department = left.department.name.compareTo(
          right.department.name,
        );
        if (department != 0) return department;
        final name = left.displayName.compareTo(right.displayName);
        if (name != 0) return name;
        return left.id.compareTo(right.id);
      });
    return List.unmodifiable(result);
  }
}
