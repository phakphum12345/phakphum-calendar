import '../../excel_import/domain/shift_record.dart';
import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/schedule_month.dart';
import '../../../services/shift_time_service.dart';
import '../domain/department.dart';
import '../domain/employee.dart';
import '../domain/shift.dart';
import '../domain/shift_assignment.dart';
import 'schedule_service.dart';

/// Converts imported shift records into the canonical schedule domain.
class ImportedScheduleAdapter {
  const ImportedScheduleAdapter();

  static const _defaultDepartment = Department(
    id: 'unassigned',
    code: 'Unassigned',
    name: 'Unassigned',
  );

  /// Converts imported records into the canonical schedule aggregate.
  ///
  /// A reviewed employee identity is preserved exactly. Records without an
  /// explicit review selection retain the legacy provisional identity.
  Schedule createSchedule(
    Iterable<ShiftRecord> records, {
    String id = 'imported',
    String name = 'Imported schedule',
  }) {
    final recordList = records.toList(growable: false);
    final months = <String, DateTime>{};
    for (final record in recordList) {
      final date = record.date;
      if (date == null) continue;
      months['${date.year}-${date.month}'] = DateTime(date.year, date.month);
    }
    final datedRecords = recordList
        .where((record) => record.date != null)
        .toList(growable: false);
    final departments = <String, Department>{};
    final employees = <String, Employee>{};
    final shifts = <String, Shift>{};

    for (final record in datedRecords) {
      final department = record.resolvedEmployee?.department ??
          _department(record.department);
      departments[department.id] = department;
      final employee = record.resolvedEmployee ??
          _employee(record.employee, department);
      employees[employee.id] = employee;
      final shift = _shift(record.shift);
      shifts[shift.id] = shift;
    }

    final scheduleMonths = [
      for (final month in months.values) ScheduleMonth.empty(month),
    ]..sort((left, right) => left.month.compareTo(right.month));
    final service = ScheduleService(
      schedule: Schedule(id: id, name: name, months: scheduleMonths),
      departments: departments.values.toList(growable: false),
      employees: employees.values.toList(growable: false),
      shifts: shifts.values.toList(growable: false),
    );
    for (final record in datedRecords) {
      final department = record.resolvedEmployee?.department ??
          _department(record.department);
      final employee = employees[
        record.resolvedEmployee?.id ?? _employeeId(record.employee, department)
      ]!;
      final shift = shifts[_identifier(record.shift)]!;
      service.updateAssignment(
        date: record.date!,
        assignment: ShiftAssignment(
          employee: employee,
          shift: shift,
          remark: record.notes,
          location: record.location,
        ),
      );
    }
    return service.schedule;
  }

  /// Creates a compatibility service backed by one canonical schedule.
  ScheduleService createService(Iterable<ShiftRecord> records) {
    return ScheduleService(schedule: createSchedule(records));
  }

  /// Returns the earliest imported month, or the normalized [fallback].
  DateTime initialMonth(Iterable<ShiftRecord> records, {DateTime? fallback}) {
    DateTime? earliest;
    for (final record in records) {
      final date = record.date;
      if (date != null && (earliest == null || date.isBefore(earliest))) {
        earliest = date;
      }
    }
    final selected = earliest ?? fallback ?? DateTime.now();
    return DateTime(selected.year, selected.month);
  }

  Department _department(String? name) {
    final normalized = name?.trim() ?? '';
    if (normalized.isEmpty) {
      return _defaultDepartment;
    }
    return Department(
      id: _identifier(normalized),
      code: normalized,
      name: normalized,
    );
  }

  Employee _employee(String name, Department department) {
    final normalized = name.trim();
    return Employee(
      id: _employeeId(normalized, department),
      employeeCode: normalized,
      firstName: normalized,
      lastName: '',
      nickname: '',
      department: department,
      position: '',
    );
  }

  String _employeeId(String name, Department department) {
    return '${department.id}:${_identifier(name)}';
  }

  Shift _shift(String name) {
    final normalized = name.trim();
    final id = _identifier(normalized);
    final durations =
        ShiftTimeService.parseDurations(normalized) ?? [Duration.zero, Duration.zero];
    return Shift(
      id: id,
      code: normalized,
      name: normalized,
      color: _colorFor(id),
      startTime: durations[0],
      endTime: durations[1],
      workingHours: 0,
    );
  }

  String _identifier(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  }

  int _colorFor(String value) {
    const palette = [
      0xFF00695C,
      0xFF1565C0,
      0xFF6A1B9A,
      0xFFEF6C00,
      0xFF2E7D32,
      0xFFC62828,
    ];
    final hash = value.codeUnits.fold<int>(
      0,
      (result, unit) => (result * 31 + unit) & 0x7FFFFFFF,
    );
    return palette[hash % palette.length];
  }
}
