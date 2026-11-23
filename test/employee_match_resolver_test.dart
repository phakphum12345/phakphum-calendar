import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/features/employees/application/employee_match_resolver.dart';

void main() {
  const resolver = EmployeeMatchResolver();

  final directory = [
    _employee(id: 'e1', code: '001', name: 'Somchai Dee', nickname: 'Chai', department: 'ER'),
    _employee(id: 'e2', code: '002', name: 'Somchai Dee', nickname: 'Som', department: 'Radiology'),
    _employee(id: 'e3', code: '003', name: 'Somsak Dee', nickname: 'Sak', department: 'ER'),
  ];

  test('exact unique employee code resolves to the employee', () {
    final result = resolver.resolve(importedName: ' 001 ', employees: directory);

    expect(result.status, EmployeeMatchStatus.matched);
    expect(result.employee?.id, 'e1');
    expect(result.requiresReview, isFalse);
  });

  test('duplicate exact names remain ambiguous without department context', () {
    final result = resolver.resolve(
      importedName: 'Somchai Dee',
      employees: directory,
    );

    expect(result.status, EmployeeMatchStatus.ambiguous);
    expect(result.employee, isNull);
    expect(result.candidates.map((employee) => employee.id), ['e1', 'e2']);
    expect(result.requiresReview, isTrue);
  });

  test('department narrows an exact duplicate name safely', () {
    final result = resolver.resolve(
      importedName: 'Somchai Dee',
      department: 'ER',
      employees: directory,
    );

    expect(result.status, EmployeeMatchStatus.matched);
    expect(result.employee?.id, 'e1');
    expect(result.reason, 'Exact name and department');
  });

  test('nickname can resolve only when it is unique', () {
    final result = resolver.resolve(
      importedName: 'Chai',
      employees: directory,
    );

    expect(result.status, EmployeeMatchStatus.matched);
    expect(result.employee?.id, 'e1');
  });

  test('partial name produces review suggestions, never auto-matches', () {
    final result = resolver.resolve(
      importedName: 'Somchai',
      employees: directory,
    );

    expect(result.status, EmployeeMatchStatus.ambiguous);
    expect(result.employee, isNull);
    expect(result.candidates.map((employee) => employee.id), ['e1', 'e2']);
  });

  test('unknown and empty names remain unmatched', () {
    final unknown = resolver.resolve(
      importedName: 'Nobody',
      employees: directory,
    );
    final empty = resolver.resolve(importedName: '  ', employees: directory);

    expect(unknown.status, EmployeeMatchStatus.unmatched);
    expect(unknown.candidates, isEmpty);
    expect(empty.status, EmployeeMatchStatus.unmatched);
  });

  test('duplicate names inside the same department are still ambiguous', () {
    final sameDepartment = [
      directory.first,
      _employee(id: 'e4', code: '004', name: 'Somchai Dee', nickname: 'Chai 2', department: 'ER'),
    ];

    final result = resolver.resolve(
      importedName: 'Somchai Dee',
      department: 'ER',
      employees: sameDepartment,
    );

    expect(result.status, EmployeeMatchStatus.ambiguous);
    expect(result.employee, isNull);
    expect(result.candidates, hasLength(2));
  });
}

Employee _employee({
  required String id,
  required String code,
  required String name,
  required String nickname,
  required String department,
}) {
  final parts = name.split(' ');
  return Employee(
    id: id,
    employeeCode: code,
    firstName: parts.first,
    lastName: parts.skip(1).join(' '),
    nickname: nickname,
    department: Department(
      id: department.toLowerCase(),
      code: department.toUpperCase(),
      name: department,
    ),
    position: 'Staff',
  );
}
