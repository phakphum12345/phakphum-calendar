import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/di/app_dependencies.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_assignment.dart';
import 'package:phakphum_calendar/domain/entities/shift_template.dart';
import 'package:phakphum_calendar/domain/repositories/employee_repository.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_repository.dart';
import 'package:phakphum_calendar/domain/repositories/shift_template_repository.dart';
import 'package:phakphum_calendar/features/schedule/data/legacy_schedule_adapter.dart';

import 'support/canonical_schedule_fixture.dart';

void main() {
  test('canonical schedule adapts to legacy view without becoming source', () {
    final schedule = canonicalScheduleFixture();
    const adapter = LegacyScheduleAdapter();

    final conversion = adapter.wrapCanonical(schedule);
    final legacy = conversion.toLegacyShifts();

    expect(conversion.schedule, same(schedule));
    expect(legacy, hasLength(2));
    expect(legacy.first.assignedName, 'Anan Sukjai');
    expect(legacy.first.code, 'N');
    expect(legacy.first.start, DateTime(2026, 7, 24, 20));
    expect(legacy.first.end, DateTime(2026, 7, 25, 8));
  });

  test(
    'composition root loads employee and shift catalogs for editor',
    () async {
      final schedule = Schedule(id: 'manual', name: 'Manual roster');
      final scheduleRepository = _ScheduleRepository();
      final dependencies = AppDependencies(
        scheduleRepository: scheduleRepository,
        employeeRepository: _EmployeeRepository(),
        shiftTemplateRepository: _ShiftTemplateRepository(),
        scheduleRules: const [],
        legacyScheduleRules: const [],
      );

      final controller = await dependencies.createRosterEditorController(
        schedule,
      );
      addTearDown(controller.dispose);

      expect(controller.canonicalSchedule.id, schedule.id);
      expect(controller.canonicalSchedule.name, schedule.name);
      expect(controller.employees.single.id, 'employee-1');
      expect(controller.shifts.single.id, 'shift-1');
      expect(controller.repository, same(scheduleRepository));

      final date = controller.schedule.days.first.date;
      controller.updateAssignment(
        date,
        ShiftAssignment(
          employee: controller.employees.single,
          shift: controller.shifts.single,
          location: 'CT',
        ),
      );
      final result = await controller.saveSchedule();

      expect(result, isA<Success<Schedule>>());
      expect(scheduleRepository.saved, hasLength(1));
      expect(
        scheduleRepository.saved.single
            .month(date)!
            .day(date)!
            .assignments
            .single
            .location,
        'CT',
      );
    },
  );
}

class _EmployeeRepository implements EmployeeRepository {
  static const employee = Employee(
    id: 'employee-1',
    employeeCode: 'E001',
    firstName: 'Anan',
    lastName: '',
    nickname: '',
    department: Department(id: 'er', code: 'ER', name: 'Emergency'),
    position: '',
  );

  @override
  Future<Result<void>> delete(String id) async => const Success(null);

  @override
  Future<Result<List<Employee>>> findAll({bool activeOnly = true}) async =>
      const Success([employee]);

  @override
  Future<Result<Employee?>> findById(String id) async =>
      Success(id == employee.id ? employee : null);

  @override
  Future<Result<Employee>> save(Employee employee) async => Success(employee);

  @override
  Future<Result<List<Employee>>> saveAll(List<Employee> employees) async =>
      Success(employees);

  @override
  Future<Result<List<Employee>>> search(String query) async =>
      const Success([employee]);
}

class _ShiftTemplateRepository implements ShiftTemplateRepository {
  static const template = ShiftTemplate(
    id: 'shift-1',
    code: 'M',
    name: 'Morning',
    shortName: 'M',
    startTime: Duration(hours: 8),
    endTime: Duration(hours: 16),
    color: 0xFF039BE5,
    workingHours: 8,
  );

  @override
  Future<Result<void>> delete(String id) async => const Success(null);

  @override
  Future<Result<List<ShiftTemplate>>> findAll({bool activeOnly = true}) async =>
      const Success([template]);

  @override
  Future<Result<ShiftTemplate?>> findById(String id) async =>
      Success(id == template.id ? template : null);

  @override
  Future<Result<ShiftTemplate>> save(ShiftTemplate template) async =>
      Success(template);
}

class _ScheduleRepository implements ScheduleRepository {
  final saved = <Schedule>[];

  @override
  Future<Result<void>> delete(String id) async => const Success(null);

  @override
  Future<Result<Schedule?>> findById(String id) async => const Success(null);

  @override
  Future<Result<ScheduleMonth?>> loadMonth(
    String scheduleId,
    DateTime month,
  ) async => const Success(null);

  @override
  Future<Result<Schedule>> save(Schedule schedule) async {
    saved.add(schedule);
    return Success(schedule);
  }
}
