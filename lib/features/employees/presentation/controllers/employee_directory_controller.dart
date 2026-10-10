import 'package:flutter/foundation.dart';

import '../../../../core/result/result.dart';
import '../../../../core/google/google_scopes.dart';
import '../../../../domain/entities/employee.dart';
import '../../../../domain/entities/schedule.dart';
import '../../../../domain/repositories/employee_repository.dart';
import '../../../../services/google_auth_service.dart';
import '../../../../services/google_api_client.dart';
import '../../application/employee_directory_service.dart';
import '../../infrastructure/google_employee_sync_service.dart';

/// Controls search and filtering for the employee directory.
class EmployeeDirectoryController extends ChangeNotifier {
  EmployeeDirectoryController({
    required Schedule schedule,
    EmployeeRepository? repository,
    GoogleAuthGateway? googleAuth,
    EmployeeDirectoryService service = const EmployeeDirectoryService(),
  }) : this._(schedule, service, repository, googleAuth);

  EmployeeDirectoryController._(
    this._schedule,
    this._service,
    this._repository,
    this._googleAuth,
  );

  Schedule _schedule;
  final EmployeeDirectoryService _service;
  final EmployeeRepository? _repository;
  final GoogleAuthGateway? _googleAuth;
  List<Employee> _repositoryEmployees = const [];
  String _query = '';
  String? _departmentId;
  bool _activeOnly = true;
  bool _loading = false;
  String? _error;

  /// Whether repository work is running.
  bool get loading => _loading;

  /// Controlled repository error, if any.
  String? get error => _error;

  /// Current free-text search.
  String get query => _query;

  /// Selected department identifier, or null for every department.
  String? get departmentId => _departmentId;

  /// Whether inactive employees are excluded.
  bool get activeOnly => _activeOnly;

  /// Departments represented by the current canonical schedule.
  List<String> get departmentIds {
    final values =
        _allEmployees.map((employee) => employee.department.id).toSet().toList()
          ..sort();
    return List.unmodifiable(values);
  }

  /// Employees matching all active filters.
  List<Employee> get employees => List.unmodifiable(
    _allEmployees.where((employee) {
      if (_activeOnly && !employee.active) return false;
      if (_departmentId != null && employee.department.id != _departmentId) {
        return false;
      }
      return employee.matches(_query);
    }),
  );

  List<EmployeeShiftDate> shiftsFor(String employeeId) =>
      _service.assignments(_schedule, employeeId);

  List<Employee> get contactExportCandidates =>
      List.unmodifiable(_allEmployees.where((employee) => employee.active));

  List<Employee> get _allEmployees {
    final persistedByCode = {
      for (final employee in _repositoryEmployees)
        if (_normalize(employee.employeeCode).isNotEmpty)
          _normalize(employee.employeeCode): employee,
    };
    final valuesById = <String, Employee>{};
    for (final scheduled in _service.employees(_schedule)) {
      final code = _normalize(scheduled.employeeCode);
      final persisted =
          (code.isEmpty ? null : persistedByCode[code]) ??
          _repositoryEmployees
              .where((employee) => _sameDirectoryIdentity(employee, scheduled))
              .firstOrNull;
      final selected = persisted ?? scheduled;
      valuesById[selected.id] = selected;
    }
    for (final employee in _repositoryEmployees) {
      valuesById[employee.id] = employee;
    }
    final values = valuesById.values.toList()
      ..sort((left, right) {
        final department = left.department.name.compareTo(
          right.department.name,
        );
        if (department != 0) return department;
        final name = left.displayName.compareTo(right.displayName);
        return name != 0 ? name : left.id.compareTo(right.id);
      });
    return values;
  }

  /// Loads the durable employee directory when configured.
  Future<void> load() async {
    final repository = _repository;
    if (repository == null || _loading) return;
    _setLoading(true);
    notifyListeners();
    final result = await repository.findAll(activeOnly: false);
    switch (result) {
      case Success<List<Employee>>(value: final employees):
        _repositoryEmployees = employees;
      case Failure<List<Employee>>():
        _error = result.message;
    }
    _loading = false;
    notifyListeners();
  }

  /// Creates or replaces an employee through the repository.
  Future<bool> saveEmployee(Employee employee) async {
    final repository = _repository;
    if (repository == null) {
      _error = 'Employee persistence is not configured.';
      notifyListeners();
      return false;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    final result = await repository.save(employee);
    switch (result) {
      case Success<Employee>():
        final values = List<Employee>.of(_repositoryEmployees);
        final index = values.indexWhere((item) => item.id == employee.id);
        if (index == -1) {
          values.add(employee);
        } else {
          values[index] = employee;
        }
        _repositoryEmployees = List.unmodifiable(values);
      case Failure<Employee>():
        _error = result.message;
    }
    _loading = false;
    notifyListeners();
    return result.isSuccess;
  }

  /// Merges this device's directory into the signed-in account's private Drive
  /// app-data file, then publishes the merged directory back to both locations.
  Future<String> syncWithGoogle() async {
    final repository = _repository;
    final auth = _googleAuth;
    if (repository == null || auth == null || !auth.isSignedIn) {
      throw StateError('กรุณาเข้าสู่ระบบ Google ก่อนซิงค์รายชื่อ');
    }
    _setLoading(true);
    GoogleApiClient? client;
    try {
      client = await auth.clientFor(const [GoogleScopes.driveAppData]);
      final localResult = await repository.findAll(activeOnly: false);
      if (localResult case Failure<List<Employee>>()) {
        throw StateError(localResult.message);
      }
      final localEmployees = (localResult as Success<List<Employee>>).value;
      final cloud = GoogleEmployeeSyncService(client);
      final remoteEmployees = await cloud.download();
      final mergedByCode = <String, Employee>{};
      for (final employee in remoteEmployees) {
        mergedByCode[_directoryKey(employee)] = employee;
      }
      for (final employee in _service.employees(_schedule)) {
        final duplicateKey = mergedByCode.entries
            .where((entry) => _sameDirectoryIdentity(entry.value, employee))
            .map((entry) => entry.key)
            .firstOrNull;
        if (duplicateKey != null) continue;
        mergedByCode.putIfAbsent(_directoryKey(employee), () => employee);
      }
      for (final employee in localEmployees) {
        final duplicateKey = mergedByCode.entries
            .where((entry) => _sameDirectoryIdentity(entry.value, employee))
            .map((entry) => entry.key)
            .firstOrNull;
        if (duplicateKey != null) mergedByCode.remove(duplicateKey);
        mergedByCode[_directoryKey(employee)] = employee;
      }
      final merged = mergedByCode.values.toList()
        ..sort(
          (left, right) => left.employeeCode.compareTo(right.employeeCode),
        );
      final saved = await repository.saveAll(merged);
      if (saved case Failure<List<Employee>>()) {
        throw StateError(saved.message);
      }
      await cloud.upload(merged);
      _repositoryEmployees = List.unmodifiable(merged);
      _error = null;
      _loading = false;
      notifyListeners();
      return 'ซิงค์รายชื่อ ${merged.length} รายการกับบัญชี Google สำเร็จ '
          '(หากข้อมูลรหัสเดียวกันต่างกัน จะใช้ข้อมูลในอุปกรณ์นี้)';
    } catch (error) {
      _error = 'ซิงค์รายชื่อไม่สำเร็จ: $error';
      _loading = false;
      notifyListeners();
      rethrow;
    } finally {
      client?.close();
    }
  }

  /// Reads Google Contacts for a user-reviewed import preview.
  Future<List<Employee>> previewGoogleContactsImport() async {
    final auth = _googleAuth;
    if (auth == null || !auth.isSignedIn) {
      throw StateError('กรุณาเข้าสู่ระบบ Google ก่อนอ่าน Google Contacts');
    }
    _setLoading(true);
    GoogleApiClient? client;
    try {
      client = await auth.clientFor(const [GoogleScopes.contacts]);
      return await GoogleContactsService(client).importableEmployees();
    } catch (error) {
      _error = 'อ่าน Google Contacts ไม่สำเร็จ: $error';
      rethrow;
    } finally {
      client?.close();
      _loading = false;
      notifyListeners();
    }
  }

  /// Imports a previously previewed set and persists it on this device.
  Future<int> importGoogleContacts(List<Employee> incoming) async {
    final repository = _repository;
    if (repository == null) {
      throw StateError('ยังไม่ได้ตั้งค่าที่เก็บข้อมูลรายชื่อ');
    }
    _setLoading(true);
    final current = List<Employee>.of(_allEmployees);
    for (final contact in incoming) {
      final existingIndex = current.indexWhere(
        (employee) => _sameDirectoryIdentity(employee, contact),
      );
      if (existingIndex == -1) {
        current.add(contact);
        continue;
      }
      final existing = current[existingIndex];
      current[existingIndex] = contact.copyWith(
        id: existing.id,
        employeeCode: existing.employeeCode,
        active: existing.active,
        department: contact.department.name == 'Google Contacts'
            ? existing.department
            : contact.department,
      );
    }
    final mergedById = <String, Employee>{
      for (final employee in current) employee.id: employee,
    };
    final merged = mergedById.values.toList();
    final saved = await repository.saveAll(merged);
    if (saved case Failure<List<Employee>>()) {
      _error = 'นำเข้ารายชื่อไม่สำเร็จ: ${saved.message}';
      _loading = false;
      notifyListeners();
      throw StateError(saved.message);
    }
    _repositoryEmployees = List.unmodifiable(merged);
    _error = null;
    _loading = false;
    notifyListeners();
    return incoming.length;
  }

  /// Exports confirmed active directory entries to Google Contacts.
  Future<GoogleContactTransferResult> exportGoogleContacts() async {
    final auth = _googleAuth;
    if (auth == null || !auth.isSignedIn) {
      throw StateError('กรุณาเข้าสู่ระบบ Google ก่อนส่งออก Google Contacts');
    }
    final candidates = contactExportCandidates;
    _setLoading(true);
    GoogleApiClient? client;
    try {
      client = await auth.clientFor(const [GoogleScopes.contacts]);
      return await GoogleContactsService(client).exportEmployees(candidates);
    } catch (error) {
      _error = 'ส่งออก Google Contacts ไม่สำเร็จ: $error';
      rethrow;
    } finally {
      client?.close();
      _loading = false;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _loading = value;
    _error = null;
    notifyListeners();
  }

  String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  String _directoryKey(Employee employee) {
    final code = _normalize(employee.employeeCode);
    return code.isEmpty ? 'id:${employee.id}' : 'code:$code';
  }

  bool _sameDirectoryIdentity(Employee left, Employee right) {
    final leftCode = _normalize(left.employeeCode);
    final rightCode = _normalize(right.employeeCode);
    if (leftCode.isNotEmpty && rightCode.isNotEmpty) {
      return leftCode == rightCode;
    }
    final leftName = _normalize('${left.firstName} ${left.lastName}');
    final rightName = _normalize('${right.firstName} ${right.lastName}');
    return leftName.isNotEmpty && leftName == rightName;
  }

  /// Deactivates an employee without deleting historical identity.
  Future<bool> deactivateEmployee(Employee employee) {
    return saveEmployee(employee.copyWith(active: false));
  }

  /// Replaces the schedule source without retaining stale employees.
  void updateSchedule(Schedule schedule) {
    if (identical(_schedule, schedule)) return;
    _schedule = schedule;
    if (_departmentId != null && !departmentIds.contains(_departmentId)) {
      _departmentId = null;
    }
    notifyListeners();
  }

  /// Updates free-text search.
  void updateQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  /// Filters by one department, or clears the filter with null.
  void updateDepartment(String? value) {
    if (_departmentId == value) return;
    _departmentId = value;
    notifyListeners();
  }

  /// Toggles exclusion of inactive employees.
  void updateActiveOnly(bool value) {
    if (_activeOnly == value) return;
    _activeOnly = value;
    notifyListeners();
  }

  /// Restores the default directory filters.
  void clearFilters() {
    if (_query.isEmpty && _departmentId == null && _activeOnly) return;
    _query = '';
    _departmentId = null;
    _activeOnly = true;
    notifyListeners();
  }
}
