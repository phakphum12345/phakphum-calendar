import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/features/excel_import/domain/shift_record.dart';
import 'package:phakphum_calendar/features/schedule/data/imported_schedule_adapter.dart';

void main() {
  test('preserves the reviewed canonical employee identity in the schedule', () {
    const employee = Employee(
      id: 'directory-employee-42',
      employeeCode: 'E-042',
      firstName: 'Anan',
      lastName: 'Sukjai',
      nickname: 'Nan',
      department: Department(
        id: 'emergency',
        code: 'ER',
        name: 'Emergency',
      ),
      position: 'Nurse',
    );

    final schedule = const ImportedScheduleAdapter().createSchedule([
      ShiftRecord(
        date: DateTime(2026, 7, 24),
        shift: 'Morning',
        employee: 'Imported alias',
        department: 'Old department label',
        rowNumber: 2,
        resolvedEmployee: employee,
      ),
    ]);

    final assignment = schedule
        .month(DateTime(2026, 7, 24))!
        .day(DateTime(2026, 7, 24))!
        .assignments
        .single;
    expect(assignment.employee.id, employee.id);
    expect(assignment.employee.employeeCode, 'E-042');
    expect(assignment.employee.fullName, 'Anan Sukjai');
    expect(assignment.employee.department.id, 'emergency');
  });

  test('keeps provisional identity behavior for records not yet reviewed', () {
    final schedule = const ImportedScheduleAdapter().createSchedule([
      ShiftRecord(
        date: DateTime(2026, 7, 24),
        shift: 'Morning',
        employee: 'Anan',
        department: 'ER',
        rowNumber: 2,
      ),
    ]);

    final assignment = schedule
        .day(DateTime(2026, 7, 24))!
        .assignments
        .single;
    expect(assignment.employee.firstName, 'Anan');
    expect(assignment.employee.department.name, 'ER');
  });
}
