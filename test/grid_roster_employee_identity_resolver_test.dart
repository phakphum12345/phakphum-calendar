import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_employee_identity_resolver.dart';

void main() {
  const resolver = GridRosterEmployeeIdentityResolver();

  test('returns one exact full-name candidate but never selects it', () {
    final result = resolver.resolve(
      sourceName: 'สมชาย ใจดี',
      employees: [_employee('e1', firstName: 'สมชาย', lastName: 'ใจดี', nickname: 'ชาย')],
    );

    expect(
      result.status,
      EmployeeIdentityResolutionStatus.exactUniqueCandidate,
    );
    expect(result.candidates.single.employee.id, 'e1');
    expect(result.candidates.single.matchKind, EmployeeIdentityMatchKind.fullName);
    expect(result.requiresHumanConfirmation, isTrue);
    expect(result.selectedEmployeeId, isNull);
    expect(result.canCommit, isFalse);
  });

  test('keeps duplicate exact names ambiguous', () {
    final result = resolver.resolve(
      sourceName: 'สมชาย ใจดี',
      employees: [
        _employee('e1', firstName: 'สมชาย', lastName: 'ใจดี', nickname: 'ชาย', code: '001'),
        _employee('e2', firstName: 'สมชาย', lastName: 'ใจดี', nickname: 'ชายน้อย', code: '002'),
      ],
    );

    expect(
      result.status,
      EmployeeIdentityResolutionStatus.ambiguousExactCandidates,
    );
    expect(result.candidates.map((item) => item.employee.id), ['e1', 'e2']);
    expect(result.selectedEmployeeId, isNull);
  });

  test('matches an exact employee code before ambiguous names', () {
    final result = resolver.resolve(
      sourceName: '002',
      employees: [
        _employee('e1', 'สมชาย', 'ใจดี', 'ชาย', code: '001'),
        _employee('e2', 'สมชาย', 'ใจดี', 'ชายน้อย', code: '002'),
      ],
    );

    expect(
      result.status,
      EmployeeIdentityResolutionStatus.exactUniqueCandidate,
    );
    expect(result.candidates.single.employee.id, 'e2');
    expect(
      result.candidates.single.matchKind,
      EmployeeIdentityMatchKind.employeeCode,
    );
  });

  test('returns substring matches as suggestions only', () {
    final result = resolver.resolve(
      sourceName: 'สมชาย',
      employees: [
        _employee('e1', 'สมชาย', 'ใจดี', 'ชาย'),
        _employee('e2', firstName: 'สมชาย', lastName: 'รักดี', nickname: 'ชายน้อย'),
      ],
    );

    expect(result.status, EmployeeIdentityResolutionStatus.suggestionsOnly);
    expect(result.candidates, hasLength(2));
    expect(
      result.candidates.every(
        (item) => item.matchKind == EmployeeIdentityMatchKind.containsText,
      ),
      isTrue,
    );
    expect(result.selectedEmployeeId, isNull);
  });

  test('does not suggest inactive employees', () {
    final result = resolver.resolve(
      sourceName: 'สมชาย ใจดี',
      employees: [
        _employee('e1', firstName: 'สมชาย', lastName: 'ใจดี', nickname: 'ชาย', active: false),
      ],
    );

    expect(result.status, EmployeeIdentityResolutionStatus.noMatch);
    expect(result.candidates, isEmpty);
  });

  test('reports missing and unknown source names explicitly', () {
    final missing = resolver.resolve(sourceName: '  ', employees: [_employee('e1')]);
    final unknown = resolver.resolve(
      sourceName: 'ไม่มีบุคลากรนี้',
      employees: [_employee('e1')],
    );

    expect(
      missing.status,
      EmployeeIdentityResolutionStatus.sourceNameMissing,
    );
    expect(unknown.status, EmployeeIdentityResolutionStatus.noMatch);
  });
}

const _department = Department(id: 'd1', code: 'D1', name: 'Department');

Employee _employee(
  String id, {
  String firstName = 'Employee',
  String lastName = 'One',
  String nickname = 'One',
  String code = '001',
  bool active = true,
}) {
  return Employee(
    id: id,
    employeeCode: code,
    firstName: firstName,
    lastName: lastName,
    nickname: nickname,
    department: _department,
    position: 'Staff',
    active: active,
  );
}
