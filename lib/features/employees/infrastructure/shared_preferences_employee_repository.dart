import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/result/result.dart';
import '../../../domain/entities/employee.dart';
import '../../../domain/repositories/employee_repository.dart';
import 'employee_json_codec.dart';

/// Minimal durable store used by the employee repository.
abstract interface class EmployeeKeyValueStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);
}

/// SharedPreferences implementation of [EmployeeKeyValueStore].
class SharedPreferencesEmployeeKeyValueStore implements EmployeeKeyValueStore {
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _instance =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<String?> getString(String key) => _instance.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _instance.setString(key, value);
}

/// Atomic, versioned production repository for canonical employees.
class SharedPreferencesEmployeeRepository implements EmployeeRepository {
  SharedPreferencesEmployeeRepository({
    EmployeeKeyValueStore? store,
    this.codec = const EmployeeJsonCodec(),
  }) : _store = store ?? SharedPreferencesEmployeeKeyValueStore();

  static const storageKeyPrefix = 'shift_tools.canonical_employees.v1';

  final EmployeeKeyValueStore _store;
  final EmployeeJsonCodec codec;

  String get _activeKey => '$storageKeyPrefix.active';
  String _slotKey(String slot) => '$storageKeyPrefix.slot.$slot';

  @override
  Future<Result<void>> delete(String id) async {
    final loaded = await _load();
    if (loaded case Failure<List<Employee>>()) {
      return _copyFailure<List<Employee>, void>(loaded);
    }
    final employees = (loaded as Success<List<Employee>>).value
        .where((employee) => employee.id != id)
        .toList();
    final saved = await _saveAll(employees);
    return switch (saved) {
      Success<List<Employee>>() => const Success(null),
      Failure<List<Employee>>() => _copyFailure<List<Employee>, void>(saved),
    };
  }

  @override
  Future<Result<List<Employee>>> findAll({bool activeOnly = true}) async {
    final loaded = await _load();
    return switch (loaded) {
      Success<List<Employee>>(value: final values) => Success(
        List.unmodifiable(
          values.where((employee) => !activeOnly || employee.active),
        ),
      ),
      Failure<List<Employee>>() => loaded,
    };
  }

  @override
  Future<Result<Employee?>> findById(String id) async {
    final loaded = await _load();
    return switch (loaded) {
      Success<List<Employee>>(value: final values) => Success(
        values.where((employee) => employee.id == id).firstOrNull,
      ),
      Failure<List<Employee>>() => _copyFailure<List<Employee>, Employee?>(
        loaded,
      ),
    };
  }

  @override
  Future<Result<Employee>> save(Employee employee) async {
    final validation = _validate(employee);
    if (validation != null) return validation;
    final loaded = await _load();
    if (loaded case Failure<List<Employee>>()) {
      return _copyFailure<List<Employee>, Employee>(loaded);
    }
    final employees = List<Employee>.of(
      (loaded as Success<List<Employee>>).value,
    );
    final duplicateCode = employees.any(
      (item) =>
          item.id != employee.id &&
          item.employeeCode.toLowerCase() ==
              employee.employeeCode.toLowerCase(),
    );
    if (duplicateCode) {
      return ValidationFailure(
        'Employee code "${employee.employeeCode}" is already in use.',
        fieldErrors: const {'employeeCode': 'duplicate'},
      );
    }
    final index = employees.indexWhere((item) => item.id == employee.id);
    if (index == -1) {
      employees.add(employee);
    } else {
      employees[index] = employee;
    }
    final saved = await _saveAll(employees);
    return switch (saved) {
      Success<List<Employee>>() => Success(employee),
      Failure<List<Employee>>() => _copyFailure<List<Employee>, Employee>(
        saved,
      ),
    };
  }

  @override
  Future<Result<List<Employee>>> saveAll(List<Employee> employees) async {
    final ids = <String>{};
    final codes = <String>{};
    for (final employee in employees) {
      final validation = _validate(employee);
      if (validation != null) {
        return ValidationFailure(
          validation.message,
          fieldErrors: validation.fieldErrors,
        );
      }
      if (!ids.add(employee.id)) {
        return ValidationFailure('Employee ID "${employee.id}" is duplicated.');
      }
      if (!codes.add(employee.employeeCode.trim().toLowerCase())) {
        return ValidationFailure(
          'Employee code "${employee.employeeCode}" is duplicated.',
          fieldErrors: const {'employeeCode': 'duplicate'},
        );
      }
    }
    return _saveAll(employees);
  }

  @override
  Future<Result<List<Employee>>> search(String query) async {
    final loaded = await _load();
    return switch (loaded) {
      Success<List<Employee>>(value: final values) => Success(
        List.unmodifiable(values.where((employee) => employee.matches(query))),
      ),
      Failure<List<Employee>>() => loaded,
    };
  }

  Future<Result<List<Employee>>> _load() async {
    try {
      final active = await _store.getString(_activeKey);
      if (active == null) return const Success([]);
      if (active != 'a' && active != 'b') {
        return const ValidationFailure(
          'Stored employee directory has an invalid active slot.',
        );
      }
      final payload = await _store.getString(_slotKey(active));
      if (payload == null) {
        return const ValidationFailure(
          'Stored employee directory is missing its active payload.',
        );
      }
      return Success(codec.decode(payload));
    } on EmployeeCodecException catch (error, stackTrace) {
      return ValidationFailure(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      return PersistenceFailure(
        'Could not load the employee directory.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Result<List<Employee>>> _saveAll(List<Employee> employees) async {
    try {
      final current = await _store.getString(_activeKey);
      if (current != null && current != 'a' && current != 'b') {
        return const ValidationFailure(
          'Stored employee directory has an invalid active slot.',
        );
      }
      final target = current == 'a' ? 'b' : 'a';
      final payload = codec.encode(employees);
      await _store.setString(_slotKey(target), payload);
      final staged = await _store.getString(_slotKey(target));
      if (staged == null) {
        return const PersistenceFailure(
          'The staged employee payload could not be read back.',
        );
      }
      final decoded = codec.decode(staged);
      await _store.setString(_activeKey, target);
      return Success(decoded);
    } on EmployeeCodecException catch (error, stackTrace) {
      return ValidationFailure(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      return PersistenceFailure(
        'Could not save the employee directory.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  ValidationFailure<Employee>? _validate(Employee employee) {
    final errors = <String, String>{};
    if (employee.id.trim().isEmpty) errors['id'] = 'required';
    if (employee.employeeCode.trim().isEmpty) {
      errors['employeeCode'] = 'required';
    }
    if (employee.firstName.trim().isEmpty) errors['firstName'] = 'required';
    if (employee.department.id.trim().isEmpty) {
      errors['department'] = 'required';
    }
    return errors.isEmpty
        ? null
        : ValidationFailure(
            'Employee data is incomplete.',
            fieldErrors: errors,
          );
  }
}

Failure<TTarget> _copyFailure<TSource, TTarget>(Failure<TSource> source) {
  return switch (source) {
    ValidationFailure<TSource>() => ValidationFailure<TTarget>(
      source.message,
      fieldErrors: source.fieldErrors,
      cause: source.cause,
      stackTrace: source.stackTrace,
    ),
    NetworkFailure<TSource>() => NetworkFailure<TTarget>(
      source.message,
      statusCode: source.statusCode,
      cause: source.cause,
      stackTrace: source.stackTrace,
    ),
    ImportFailure<TSource>() => ImportFailure<TTarget>(
      source.message,
      rowNumber: source.rowNumber,
      column: source.column,
      cause: source.cause,
      stackTrace: source.stackTrace,
    ),
    PersistenceFailure<TSource>() => PersistenceFailure<TTarget>(
      source.message,
      cause: source.cause,
      stackTrace: source.stackTrace,
    ),
  };
}
