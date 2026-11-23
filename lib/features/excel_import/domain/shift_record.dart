import '../../../domain/entities/employee.dart';
import '../../../domain/entities/shift_template.dart';

class ShiftRecord {
  const ShiftRecord({
    required this.date,
    required this.shift,
    required this.employee,
    required this.rowNumber,
    this.department,
    this.location,
    this.notes,
    this.resolvedEmployee,
    this.resolvedShiftTemplate,
  });

  final DateTime? date;
  final String shift;
  final String employee;
  final String? department;
  final String? location;
  final String? notes;
  final int rowNumber;

  /// Canonical directory identity selected during import review.
  final Employee? resolvedEmployee;

  /// Canonical shift definition selected during import review.
  final ShiftTemplate? resolvedShiftTemplate;

  ShiftRecord copyWith({
    DateTime? date,
    String? shift,
    String? employee,
    String? department,
    String? location,
    String? notes,
    Employee? resolvedEmployee,
    bool clearResolvedEmployee = false,
    ShiftTemplate? resolvedShiftTemplate,
    bool clearResolvedShiftTemplate = false,
  }) {
    return ShiftRecord(
      date: date ?? this.date,
      shift: shift ?? this.shift,
      employee: employee ?? this.employee,
      department: department ?? this.department,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      resolvedEmployee: clearResolvedEmployee
          ? null
          : resolvedEmployee ?? this.resolvedEmployee,
      resolvedShiftTemplate: clearResolvedShiftTemplate
          ? null
          : resolvedShiftTemplate ?? this.resolvedShiftTemplate,
      rowNumber: rowNumber,
    );
  }
}
