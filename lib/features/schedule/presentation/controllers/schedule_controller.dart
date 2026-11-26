import 'package:flutter/foundation.dart';

import '../../../../core/state/controller_state.dart';
import '../../../../core/result/result.dart';
import '../../../../domain/entities/schedule.dart';
import '../../../../domain/repositories/schedule_repository.dart';
import '../../../../domain/repositories/conditional_schedule_writer.dart';
import '../../../../domain/repositories/schedule_revision_source.dart';
import '../../../rules/application/schedule_validation_service.dart';
import '../../../rules/domain/rule_result.dart';
import '../../data/schedule_service.dart';
import '../../data/schedule_json_codec.dart';
import '../../domain/department.dart';
import '../../domain/employee.dart';
import '../../domain/schedule_day.dart';
import '../../domain/schedule_month.dart';
import '../../domain/schedule_statistics.dart';
import '../../domain/shift.dart';
import '../../domain/shift_assignment.dart';

class ScheduleController extends ChangeNotifier implements ControllerState {
  ScheduleController({
    ScheduleService? service,
    this.validationService,
    this.repository,
    DateTime? initialMonth,
  }) : _service = service ?? ScheduleService(),
       _currentMonth = _normalizeMonth(initialMonth ?? DateTime.now()) {
    final source = repository;
    if (source is ScheduleRevisionSource) {
      _expectedRevision = (source as ScheduleRevisionSource)
          .revisionForSnapshot(_service.schedule);
    }
    loadMonth(_currentMonth);
  }

  final ScheduleService _service;
  final ScheduleValidationService? validationService;
  final ScheduleRepository? repository;
  DateTime _currentMonth;
  late ScheduleMonth _schedule;
  RuleResult? _validationResult;
  bool _loading = false;
  Object? _error;
  String? _message;
  String? _expectedRevision;
  String _staffNameQuery = '';
  String _positionQuery = '';
  String? _employeeId;
  String? _departmentId;
  String? _shiftId;
  DateTime? _date;
  DateTime? _selectedDay;

  DateTime get currentMonth => _currentMonth;
  Schedule get canonicalSchedule => _service.schedule;
  ScheduleMonth get schedule => _schedule;
  RuleResult? get validationResult => _validationResult;
  String get searchQuery => _staffNameQuery;
  String get staffNameQuery => _staffNameQuery;
  String get positionQuery => _positionQuery;
  String? get selectedEmployeeId => _employeeId;
  String? get selectedDepartmentId => _departmentId;
  String? get selectedShiftId => _shiftId;
  DateTime? get selectedDate => _date;
  DateTime? get selectedDay => _selectedDay;
  List<Employee> get employees => _service.employees;
  List<Department> get departments => _service.departments;
  List<Shift> get shifts => _service.shifts;
  bool get hasAssignments =>
      _schedule.days.any((day) => day.assignments.isNotEmpty);
  bool get hasMatchingAssignments =>
      visibleDays.any((day) => assignmentsFor(day).isNotEmpty);
  bool get hasActiveFilters =>
      _staffNameQuery.trim().isNotEmpty ||
      _positionQuery.trim().isNotEmpty ||
      _employeeId != null ||
      _departmentId != null ||
      _shiftId != null ||
      _date != null;

  List<String> get positions {
    final values = {
      for (final employee in employees)
        if (employee.position.trim().isNotEmpty) employee.position.trim(),
    }.toList()..sort();
    return List.unmodifiable(values);
  }

  List<String> get activeFilterLabels {
    return [
      if (_staffNameQuery.trim().isNotEmpty) 'Staff: ${_staffNameQuery.trim()}',
      if (_positionQuery.trim().isNotEmpty) 'Role: ${_positionQuery.trim()}',
      if (_employeeId case final employeeId?)
        'Employee: ${_employeeName(employeeId)}',
      if (_departmentId case final departmentId?)
        'Department: ${_departmentName(departmentId)}',
      if (_shiftId case final shiftId?) 'Shift: ${_shiftName(shiftId)}',
      if (_date case final date?)
        'Date: ${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
    ];
  }

  @override
  bool get loading => _loading;

  @override
  Object? get error => _error;

  @override
  bool get success => !_loading && _error == null;

  @override
  String? get message => _message;

  List<Employee> get employeeResults => employees
      .where(
        (employee) =>
            employee.active &&
            _matchesStaffName(employee) &&
            _matchesPosition(employee),
      )
      .toList(growable: false);
  List<Shift> get shiftResults => _service.searchShift('');

  List<ScheduleDay> get visibleDays {
    if (_date != null) {
      return _schedule.days
          .where((day) => _isSameDay(day.date, _date!))
          .toList(growable: false);
    }
    return _schedule.days;
  }

  ScheduleStatistics get statistics => _service.monthlyStatistics(
    _schedule,
    employeeId: _employeeId,
    departmentId: _departmentId,
    shiftId: _shiftId,
    date: _date,
    staffNameQuery: _staffNameQuery,
    positionQuery: _positionQuery,
  );

  List<ShiftAssignment> assignmentsFor(ScheduleDay day) {
    return day.assignments
        .where((assignment) {
          return _matchesStaffName(assignment.employee) &&
              _matchesPosition(assignment.employee) &&
              (_employeeId == null || assignment.employee.id == _employeeId) &&
              (_departmentId == null ||
                  assignment.employee.department.id == _departmentId) &&
              (_shiftId == null || assignment.shift.id == _shiftId);
        })
        .toList(growable: false);
  }

  void loadMonth(DateTime month) {
    _currentMonth = _normalizeMonth(month);
    _schedule = _service.createSchedule(_currentMonth);
    if (_date != null &&
        (_date!.year != _currentMonth.year ||
            _date!.month != _currentMonth.month)) {
      _date = null;
    }
    if (_selectedDay != null &&
        (_selectedDay!.year != _currentMonth.year ||
            _selectedDay!.month != _currentMonth.month)) {
      _selectedDay = null;
    }
    notifyListeners();
  }

  void previousMonth() =>
      loadMonth(DateTime(_currentMonth.year, _currentMonth.month - 1));

  void nextMonth() =>
      loadMonth(DateTime(_currentMonth.year, _currentMonth.month + 1));

  void updateAssignment(DateTime date, ShiftAssignment assignment) {
    _schedule = _service.updateAssignment(date: date, assignment: assignment);
    _validationResult = null;
    notifyListeners();
  }

  void deleteAssignment(
    DateTime date, {
    required String employeeId,
    required String shiftId,
  }) {
    _schedule = _service.deleteAssignment(
      date: date,
      employeeId: employeeId,
      shiftId: shiftId,
    );
    _validationResult = null;
    notifyListeners();
  }

  /// Validates the current canonical schedule once without mutating it.
  RuleResult? validateSchedule() {
    final service = validationService;
    if (service == null) return null;
    _validationResult = service.validateSchedule(canonicalSchedule);
    notifyListeners();
    return _validationResult;
  }

  /// Explicitly persists the current canonical aggregate.
  Future<Result<Schedule>> saveSchedule() async {
    final scheduleRepository = repository;
    if (scheduleRepository == null) {
      return const PersistenceFailure(
        'Schedule persistence is not configured.',
      );
    }
    _loading = true;
    _error = null;
    _message = null;
    notifyListeners();
    final scheduleRepositoryForCas = scheduleRepository;
    final Result<Schedule> result;
    if (scheduleRepositoryForCas is ConditionalScheduleWriter &&
        scheduleRepositoryForCas is ScheduleRevisionSource) {
      final conditionalWriter = scheduleRepositoryForCas as ConditionalScheduleWriter;
      final revisionSource = scheduleRepositoryForCas as ScheduleRevisionSource;
      var expectedRevision = _expectedRevision;
      if (expectedRevision == null || expectedRevision.trim().isEmpty) {
        final revisionFailure = await _captureExpectedRevision(revisionSource);
        if (revisionFailure != null) {
          _loading = false;
          _error = revisionFailure;
          _message = revisionFailure.message;
          notifyListeners();
          return revisionFailure;
        }
        expectedRevision = _expectedRevision;
      }
      if (expectedRevision == null || expectedRevision.trim().isEmpty) {
        const failure = PersistenceFailure<Schedule>(
          'Could not capture an exact Schedule revision before saving.',
        );
        _loading = false;
        _error = failure;
        _message = failure.message;
        notifyListeners();
        return failure;
      }
      result = await conditionalWriter.saveIfRevision(
        canonicalSchedule,
        expectedRevision,
      );
      if (result case Success<Schedule>(value: final saved)) {
        _expectedRevision = revisionSource.revisionForSnapshot(saved);
      }
    } else {
      result = await scheduleRepository.save(canonicalSchedule);
    }
    switch (result) {
      case Success<Schedule>():
        _message = 'Schedule saved.';
      case Failure<Schedule>():
        _error = result;
        _message = result.message;
    }
    _loading = false;
    notifyListeners();
    return result;
  }

  Future<Result<Schedule>?> _captureExpectedRevision(
    ScheduleRevisionSource revisionSource,
  ) async {
    final scheduleRepository = repository;
    if (scheduleRepository == null) {
      return const PersistenceFailure(
        'Schedule persistence is not configured.',
      );
    }
    final loaded = await scheduleRepository.findById(canonicalSchedule.id);
    if (loaded case Failure<Schedule?>()) {
      return PersistenceFailure(
        'Could not verify the current Schedule before saving.',
        cause: loaded,
      );
    }
    final current = (loaded as Success<Schedule?>).value;
    if (current == null) {
      final absentRevision = revisionSource.revisionForAbsentSchedule(
        canonicalSchedule.id,
      );
      if (absentRevision == null || absentRevision.trim().isEmpty) {
        return const PersistenceFailure(
          'The repository did not provide an exact absent-Schedule revision.',
        );
      }
      _expectedRevision = absentRevision;
      return null;
    }
    if (const ScheduleJsonCodec().encode(current) !=
        const ScheduleJsonCodec().encode(canonicalSchedule)) {
      return const ValidationFailure(
        'The editor does not contain the exact persisted Schedule snapshot. Reload it before saving.',
      );
    }
    final revision = revisionSource.revisionForSnapshot(current);
    if (revision == null || revision.trim().isEmpty) {
      return const PersistenceFailure(
        'The repository did not provide a revision for the loaded Schedule snapshot.',
      );
    }
    _expectedRevision = revision;
    return null;
  }

  /// Loads a persisted canonical aggregate by stable schedule identity.
  Future<Result<Schedule?>> loadPersistedSchedule({
    String scheduleId = 'imported',
  }) async {
    final scheduleRepository = repository;
    if (scheduleRepository == null) {
      return const PersistenceFailure(
        'Schedule persistence is not configured.',
      );
    }
    _loading = true;
    _error = null;
    _message = null;
    notifyListeners();
    final result = await scheduleRepository.findById(scheduleId);
    switch (result) {
      case Success<Schedule?>(value: final schedule):
        if (schedule != null) {
          final source = scheduleRepository;
          _expectedRevision = source is ScheduleRevisionSource
              ? (source as ScheduleRevisionSource).revisionForSnapshot(schedule)
              : null;
          _service.replaceSchedule(schedule);
          _validationResult = null;
          loadMonth(schedule.months.firstOrNull?.month ?? _currentMonth);
          _message = 'Schedule loaded.';
        } else {
          final source = scheduleRepository;
          _expectedRevision = source is ScheduleRevisionSource
              ? (source as ScheduleRevisionSource).revisionForAbsentSchedule(scheduleId)
              : null;
          _service.replaceSchedule(
            Schedule(
              id: scheduleId,
              name: _service.schedule.name,
              months: _service.schedule.months,
            ),
          );
          _message = 'No saved schedule was found.';
        }
      case Failure<Schedule?>():
        _error = result;
        _message = result.message;
    }
    _loading = false;
    notifyListeners();
    return result;
  }

  void filterEmployee(String? employeeId) {
    _employeeId = employeeId;
    notifyListeners();
  }

  void filterDepartment(String? departmentId) {
    _departmentId = departmentId;
    notifyListeners();
  }

  void filterShift(String? shiftId) {
    _shiftId = shiftId;
    notifyListeners();
  }

  void filterDate(DateTime? date) {
    _date = date == null ? null : DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  void selectDay(DateTime? date) {
    _selectedDay = date == null
        ? null
        : DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  void search(String query) {
    filterStaffName(query);
  }

  /// Filters assignments by staff first name, last name, or nickname.
  void filterStaffName(String query) {
    _staffNameQuery = query;
    notifyListeners();
  }

  /// Filters assignments by an exact role or position.
  void filterPosition(String? position) {
    _positionQuery = position?.trim() ?? '';
    notifyListeners();
  }

  void clearFilters() {
    _employeeId = null;
    _departmentId = null;
    _shiftId = null;
    _date = null;
    _staffNameQuery = '';
    _positionQuery = '';
    notifyListeners();
  }

  static DateTime _normalizeMonth(DateTime date) =>
      DateTime(date.year, date.month);

  bool _isSameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  bool _matchesStaffName(Employee employee) {
    final query = _staffNameQuery.trim().toLowerCase();
    return query.isEmpty ||
        employee.employeeCode.toLowerCase().contains(query) ||
        employee.firstName.toLowerCase().contains(query) ||
        employee.lastName.toLowerCase().contains(query) ||
        employee.nickname.toLowerCase().contains(query) ||
        employee.fullName.toLowerCase().contains(query);
  }

  bool _matchesPosition(Employee employee) {
    final query = _positionQuery.trim().toLowerCase();
    return query.isEmpty || employee.position.toLowerCase() == query;
  }

  String _employeeName(String id) {
    for (final employee in employees) {
      if (employee.id == id) return employee.displayName;
    }
    return id;
  }

  String _departmentName(String id) {
    for (final department in departments) {
      if (department.id == id) return department.name;
    }
    return id;
  }

  String _shiftName(String id) {
    for (final shift in shifts) {
      if (shift.id == id) return '${shift.code} — ${shift.name}';
    }
    return id;
  }
}
