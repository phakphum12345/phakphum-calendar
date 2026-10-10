import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/features/employees/infrastructure/employee_json_codec.dart';
import 'package:phakphum_calendar/features/employees/infrastructure/shared_preferences_employee_repository.dart';

void main() {
  const department = Department(
    id: 'radiology',
    code: 'RAD',
    name: 'Radiology',
  );
  const employee = Employee(
    id: 'employee-1',
    employeeCode: 'E001',
    firstName: 'สมชาย',
    lastName: 'ใจดี',
    nickname: 'ชาย',
    department: department,
    position: 'นักรังสี',
  );

  test('employee codec preserves canonical employee fields', () {
    const codec = EmployeeJsonCodec();

    final decoded = codec.decode(codec.encode(const [employee])).single;

    expect(decoded, employee);
    expect(decoded.department, department);
  });

  test('employee codec rejects malformed and unsupported data', () {
    const codec = EmployeeJsonCodec();

    expect(
      () => codec.decode('{broken'),
      throwsA(isA<EmployeeCodecException>()),
    );
    expect(
      () => codec.decode('{"formatVersion":2,"employees":[]}'),
      throwsA(isA<EmployeeCodecException>()),
    );
  });

  test(
    'employee repository saves, searches, and deactivates employees',
    () async {
      final store = _MemoryEmployeeStore();
      final repository = SharedPreferencesEmployeeRepository(store: store);

      expect(await repository.save(employee), isA<Success<Employee>>());
      expect(
        (await repository.findById(employee.id) as Success<Employee?>).value,
        employee,
      );
      expect(
        (await repository.search('ใจดี') as Success<List<Employee>>).value,
        [employee],
      );

      final inactive = employee.copyWith(active: false);
      expect(await repository.save(inactive), isA<Success<Employee>>());
      expect(
        (await repository.findAll() as Success<List<Employee>>).value,
        isEmpty,
      );
      expect(
        (await repository.findAll(activeOnly: false) as Success<List<Employee>>)
            .value,
        [inactive],
      );
    },
  );

  test(
    'employee repository keeps last active slot when a staged write fails',
    () async {
      final store = _MemoryEmployeeStore();
      final repository = SharedPreferencesEmployeeRepository(store: store);
      expect(await repository.save(employee), isA<Success<Employee>>());
      store.failNextSlotWrite = true;

      final result = await repository.save(
        employee.copyWith(firstName: 'Changed'),
      );

      expect(result, isA<PersistenceFailure<Employee>>());
      final restored =
          (await repository.findById(employee.id) as Success<Employee?>).value;
      expect(restored, employee);
    },
  );

  test('employee repository saves a complete directory atomically', () async {
    final store = _MemoryEmployeeStore();
    final repository = SharedPreferencesEmployeeRepository(store: store);
    final second = employee.copyWith(
      id: 'employee-2',
      employeeCode: 'E002',
      firstName: 'สมหญิง',
    );

    expect(await repository.saveAll([employee, second]), isA<Success>());
    expect(
      (await repository.findAll(activeOnly: false) as Success<List<Employee>>)
          .value,
      [employee, second],
    );
    expect(
      await repository.saveAll([
        employee,
        second.copyWith(employeeCode: 'E001'),
      ]),
      isA<ValidationFailure<List<Employee>>>(),
    );
    expect(
      (await repository.findAll(activeOnly: false) as Success<List<Employee>>)
          .value,
      [employee, second],
    );
  });
}

class _MemoryEmployeeStore implements EmployeeKeyValueStore {
  final values = <String, String>{};
  bool failNextSlotWrite = false;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    if (failNextSlotWrite && key.contains('.slot.')) {
      failNextSlotWrite = false;
      throw StateError('simulated write failure');
    }
    values[key] = value;
  }
}
