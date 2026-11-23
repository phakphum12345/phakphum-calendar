import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_day.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_assignment.dart';
import 'package:phakphum_calendar/domain/entities/shift_type.dart';
import 'package:phakphum_calendar/domain/repositories/employee_repository.dart';
import 'package:phakphum_calendar/features/employees/application/employee_directory_service.dart';
import 'package:phakphum_calendar/features/employees/presentation/controllers/employee_directory_controller.dart';

void main() {
  test('directory de-duplicates and orders canonical employees', () {
    final schedule = _schedule();
    final employees = const EmployeeDirectoryService().employees(schedule);

    expect(employees.map((employee) => employee.id), ['e2', 'e1']);
  });

  test('directory retains each employee assignment date and shift times', () {
    final schedule = _schedule();
    final assignments = const EmployeeDirectoryService().assignments(
      schedule,
      'e2',
    );

    expect(assignments, hasLength(2));
    expect(assignments.map((assignment) => assignment.date.day), [1, 2]);
    expect(assignments.first.start, DateTime(2026, 7, 1, 8));
    expect(assignments.first.end, DateTime(2026, 7, 1, 16));
  });

  test('controller combines query, department and active filters', () {
    final controller = EmployeeDirectoryController(schedule: _schedule());
    addTearDown(controller.dispose);

    expect(controller.employees, hasLength(1));

    controller.updateActiveOnly(false);
    expect(controller.employees, hasLength(2));

    controller.updateDepartment('radiology');
    controller.updateQuery('som');
    expect(controller.employees.map((employee) => employee.id), ['e1']);

    controller.clearFilters();
    expect(controller.activeOnly, isTrue);
    expect(controller.departmentId, isNull);
    expect(controller.query, isEmpty);
  });

  test(
    'directory does not merge different employees with the same name',
    () async {
      const sameNameDifferentEmployee = Employee(
        id: 'e3',
        employeeCode: '003',
        firstName: 'Somchai',
        lastName: 'Dee',
        nickname: '',
        department: Department(id: 'radiology', code: 'RAD', name: 'Radiology'),
        position: 'Technologist',
      );
      final controller = EmployeeDirectoryController(
        schedule: _schedule(),
        repository: _EmployeeRepository([sameNameDifferentEmployee]),
      );
      addTearDown(controller.dispose);

      await controller.load();
      controller.updateActiveOnly(false);

      expect(
        controller.employees
            .where((employee) => employee.firstName == 'Somchai')
            .map((employee) => employee.id),
        unorderedEquals(['e1', 'e3']),
      );
    },
  );
}

Schedule _schedule() {
  const radiology = Department(id: 'radiology', code: 'RAD', name: 'Radiology');
  const emergency = Department(id: 'er', code: 'ER', name: 'Emergency');
  const somchai = Employee(
    id: 'e1',
    employeeCode: '001',
    firstName: 'Somchai',
    lastName: 'Dee',
    nickname: '',
    department: radiology,
    position: 'Technologist',
    active: false,
  );
  const anan = Employee(
    id: 'e2',
    employeeCode: '002',
    firstName: 'Anan',
    lastName: 'Sukjai',
    nickname: 'Nan',
    department: emergency,
    position: 'Nurse',
  );
  const shift = ShiftType(
    id: 'day',
    code: 'D',
    name: 'Day',
    color: 0xFF00695C,
    startTime: Duration(hours: 8),
    endTime: Duration(hours: 16),
    workingHours: 8,
  );
  return Schedule(
    id: 'schedule',
    name: 'July',
    months: [
      ScheduleMonth(
        month: DateTime(2026, 7),
        days: [
          ScheduleDay(
            date: DateTime(2026, 7, 1),
            assignments: const [
              ShiftAssignment(employee: somchai, shift: shift),
              ShiftAssignment(employee: anan, shift: shift),
            ],
          ),
          ScheduleDay(
            date: DateTime(2026, 7, 2),
            assignments: const [ShiftAssignment(employee: anan, shift: shift)],
          ),
        ],
      ),
    ],
  );
}

class _EmployeeRepository implements EmployeeRepository {
  _EmployeeRepository(this.employees);

  final List<Employee> employees;

  @override
  Future<Result<void>> delete(String id) async => const Success(null);

  @override
  Future<Result<List<Employee>>> findAll({bool activeOnly = true}) async =>
      Success(
        employees.where((employee) => !activeOnly || employee.active).toList(),
      );

  @override
  Future<Result<Employee?>> findById(String id) async =>
      Success(employees.where((employee) => employee.id == id).firstOrNull);

  @override
  Future<Result<Employee>> save(Employee employee) async => Success(employee);

  @override
  Future<Result<List<Employee>>> saveAll(List<Employee> employees) async =>
      Success(employees);

  @override
  Future<Result<List<Employee>>> search(String query) async =>
      Success(employees.where((employee) => employee.matches(query)).toList());
}
