import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/repositories/employee_repository.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_summary.dart';
import 'package:phakphum_calendar/features/excel_import/domain/shift_record.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/pages/import_summary_page.dart';

void main() {
  testWidgets('ambiguous employee must be explicitly selected before save', (
    tester,
  ) async {
    const emergencyEmployee = Employee(
      id: 'employee-er-1',
      employeeCode: 'ER-001',
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
    const radiologyEmployee = Employee(
      id: 'employee-rad-1',
      employeeCode: 'RAD-001',
      firstName: 'Anan',
      lastName: 'Sukjai',
      nickname: 'An',
      department: Department(
        id: 'radiology',
        code: 'RAD',
        name: 'Radiology',
      ),
      position: 'Technologist',
    );
    final repository = _EmployeeRepository([
      emergencyEmployee,
      radiologyEmployee,
    ]);
    Schedule? savedSchedule;
    final summary = ImportSummary(
      totalRows: 1,
      importedRows: 1,
      skippedRows: 0,
      errorRows: 0,
      issues: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ImportSummaryPage(
          summary: summary,
          records: [
            ShiftRecord(
              date: DateTime(2026, 7, 24),
              shift: 'Morning',
              employee: 'Anan Sukjai',
              rowNumber: 2,
            ),
          ],
          employeeRepository: repository,
          scheduleSaver: (schedule) async {
            savedSchedule = schedule;
            return Success(schedule);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(
      FilledButton,
      'ยืนยันและบันทึกตารางเวร',
    );
    expect(saveButton, findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<Employee>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anan Sukjai (Nan) • Emergency').last);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(savedSchedule, isNotNull);
    final assignment = savedSchedule!
        .month(DateTime(2026, 7, 24))!
        .day(DateTime(2026, 7, 24))!
        .assignments
        .single;
    expect(assignment.employee.id, emergencyEmployee.id);
    expect(assignment.employee.department.id, 'emergency');
    expect(find.text('บันทึกแล้ว'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _EmployeeRepository implements EmployeeRepository {
  const _EmployeeRepository(this.employees);

  final List<Employee> employees;

  @override
  Future<Result<void>> delete(String id) async => const Success(null);

  @override
  Future<Result<List<Employee>>> findAll({bool activeOnly = true}) async =>
      Success(
        employees
            .where((employee) => !activeOnly || employee.active)
            .toList(growable: false),
      );

  @override
  Future<Result<Employee?>> findById(String id) async => Success(
    employees.where((employee) => employee.id == id).firstOrNull,
  );

  @override
  Future<Result<Employee>> save(Employee employee) async => Success(employee);

  @override
  Future<Result<List<Employee>>> saveAll(List<Employee> employees) async =>
      Success(employees);

  @override
  Future<Result<List<Employee>>> search(String query) async => Success(
    employees.where((employee) => employee.matches(query)).toList(),
  );
}
