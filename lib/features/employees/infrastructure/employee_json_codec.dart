import 'dart:convert';

import '../../../domain/entities/department.dart';
import '../../../domain/entities/employee.dart';

/// Controlled decoding failure for persisted employee data.
class EmployeeCodecException implements Exception {
  const EmployeeCodecException(this.message);

  final String message;

  @override
  String toString() => 'EmployeeCodecException: $message';
}

/// Versioned JSON codec for canonical employees.
class EmployeeJsonCodec {
  const EmployeeJsonCodec();

  static const formatVersion = 1;

  String encode(List<Employee> employees) {
    final ordered = List<Employee>.of(employees)
      ..sort((left, right) => left.id.compareTo(right.id));
    return jsonEncode({
      'formatVersion': formatVersion,
      'employees': [for (final employee in ordered) _encodeEmployee(employee)],
    });
  }

  List<Employee> decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw EmployeeCodecException('Malformed employee JSON: $error');
    }
    final root = _map(decoded, 'root');
    final version = _integer(root['formatVersion'], 'formatVersion');
    if (version != formatVersion) {
      throw EmployeeCodecException(
        'Unsupported employee format version $version.',
      );
    }
    final values = _list(root['employees'], 'employees');
    final byId = <String, Employee>{};
    for (var index = 0; index < values.length; index++) {
      final employee = _decodeEmployee(
        _map(values[index], 'employees[$index]'),
        'employees[$index]',
      );
      if (byId.containsKey(employee.id)) {
        throw EmployeeCodecException('Duplicate employee ID "${employee.id}".');
      }
      byId[employee.id] = employee;
    }
    return List.unmodifiable(byId.values);
  }

  Map<String, Object?> _encodeEmployee(Employee employee) => {
    'id': employee.id,
    'employeeCode': employee.employeeCode,
    'firstName': employee.firstName,
    'lastName': employee.lastName,
    'nickname': employee.nickname,
    'alternateNames': employee.alternateNames,
    'position': employee.position,
    'active': employee.active,
    'department': {
      'id': employee.department.id,
      'code': employee.department.code,
      'name': employee.department.name,
    },
  };

  Employee _decodeEmployee(Map<String, Object?> value, String path) {
    final department = _map(value['department'], '$path.department');
    return Employee(
      id: _requiredString(value['id'], '$path.id'),
      employeeCode: _requiredString(
        value['employeeCode'],
        '$path.employeeCode',
      ),
      firstName: _requiredString(value['firstName'], '$path.firstName'),
      lastName: _string(value['lastName'], '$path.lastName'),
      nickname: _string(value['nickname'], '$path.nickname'),
      alternateNames: value['alternateNames'] == null
          ? ''
          : _string(value['alternateNames'], '$path.alternateNames'),
      position: _string(value['position'], '$path.position'),
      active: _boolean(value['active'], '$path.active'),
      department: Department(
        id: _requiredString(department['id'], '$path.department.id'),
        code: _requiredString(department['code'], '$path.department.code'),
        name: _requiredString(department['name'], '$path.department.name'),
      ),
    );
  }

  Map<String, Object?> _map(Object? value, String path) {
    if (value is! Map<String, Object?>) {
      throw EmployeeCodecException('$path must be an object.');
    }
    return value;
  }

  List<Object?> _list(Object? value, String path) {
    if (value is! List<Object?>) {
      throw EmployeeCodecException('$path must be a list.');
    }
    return value;
  }

  int _integer(Object? value, String path) {
    if (value is! int) {
      throw EmployeeCodecException('$path must be an integer.');
    }
    return value;
  }

  String _requiredString(Object? value, String path) {
    final result = _string(value, path).trim();
    if (result.isEmpty) {
      throw EmployeeCodecException('$path must not be empty.');
    }
    return result;
  }

  String _string(Object? value, String path) {
    if (value is! String) {
      throw EmployeeCodecException('$path must be a string.');
    }
    return value;
  }

  bool _boolean(Object? value, String path) {
    if (value is! bool) {
      throw EmployeeCodecException('$path must be a boolean.');
    }
    return value;
  }
}
