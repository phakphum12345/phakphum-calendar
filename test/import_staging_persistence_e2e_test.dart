import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_day.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_assignment.dart';
import 'package:phakphum_calendar/domain/entities/shift_template.dart';
import 'package:phakphum_calendar/features/excel_import/application/import_staging_applier.dart';
import 'package:phakphum_calendar/features/excel_import/application/import_staging_planner.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_staging_plan.dart';
import 'package:phakphum_calendar/features/excel_import/domain/shift_record.dart';
import 'package:phakphum_calendar/features/schedule/data/shared_preferences_schedule_repository.dart';

import 'support/in_memory_schedule_store.dart';

const _department = Department(id: 'er', code: 'ER', name: 'Emergency');
const _employee = Employee(
  id: 'employee-1',
  employeeCode: 'E001',
  firstName: 'Anan',
  lastName: 'Sukjai',
  nickname: 'Nan',
  department: _department,
  position: 'Nurse',
);
const _otherEmployee = Employee(
  id: 'employee-2',
  employeeCode: 'E002',
  firstName: 'Mali',
  lastName: 'Dee',
  nickname: 'May',
  department: _department,
  position: 'Nurse',
);
const _night = ShiftTemplate(
  id: 'night',
  code: 'N',
  name: 'Night',
  shortName: 'N',
  startTime: Duration(hours: 20),
  endTime: Duration(hours: 8),
  color: 0xFF4527A0,
  workingHours: 12,
);
const _morning = ShiftTemplate(
  id: 'morning',
  code: 'M',
  name: 'Morning',
  shortName: 'AM',
  startTime: Duration(hours: 8),
  endTime: Duration(hours: 16),
  color: 0xFF1565C0,
  workingHours: 8,
);
const _evening = ShiftTemplate(
  id: 'evening',
  code: 'E',
  name: 'Evening',
  shortName: 'PM',
  startTime: Duration(hours: 16),
  endTime: Duration(hours: 0),
  color: 0xFF00897B,
  workingHours: 8,
);
final _date = DateTime(2026, 7, 24);
final _nextDate = DateTime(2026, 7, 25);

Schedule _existingSchedule() => Schedule(
  id: 'imported',
  name: 'Existing roster',
  months: [
    ScheduleMonth(
      month: _date,
      days: [
        ScheduleDay(
          date: _date,
          assignments: [
            ShiftAssignment(
              employee: _employee,
              shift: _night.toShiftType(),
              remark: 'old note',
              location: 'Ward A',
            ),
            ShiftAssignment(
              employee: _otherEmployee,
              shift: _evening.toShiftType(),
              remark: 'keep this assignment',
              location: 'Ward B',
            ),
          ],
        ),
        ScheduleDay(
          date: _nextDate,
          assignments: [
            ShiftAssignment(
              employee: _otherEmployee,
              shift: _night.toShiftType(),
              remark: 'different day remains untouched',
            ),
          ],
          holidayName: 'Hospital holiday',
        ),
      ],
    ),
  ],
);

List<ShiftRecord> _importRows() => [
  ShiftRecord(
    date: _date,
    shift: 'N',
    employee: _employee.fullName,
    rowNumber: 2,
    notes: 'updated note',
    location: 'Ward C',
    resolvedEmployee: _employee,
    resolvedShiftTemplate: _night,
  ),
  ShiftRecord(
    date: _date,
    shift: 'M',
    employee: _employee.fullName,
    rowNumber: 3,
    notes: 'new morning assignment',
    resolvedEmployee: _employee,
    resolvedShiftTemplate: _morning,
  ),
];

void main() {
  test(
    'saved import updates and creates only selected identities, '
    'then reimport skips duplicates',
    () async {
      final repository = SharedPreferencesScheduleRepository(
        store: InMemoryScheduleKeyValueStore(),
      );
      const planner = ImportStagingPlanner();
      const applier = ImportStagingApplier();

      final original = _existingSchedule();
      expect(await repository.save(original), isA<Success<Schedule>>());

      final loadedBeforeImport = await repository.findById(original.id);
      expect(loadedBeforeImport, isA<Success<Schedule?>>());
      final snapshot = (loadedBeforeImport as Success<Schedule?>).value!;
      final firstPlan = planner.plan(
        existingSchedule: snapshot,
        records: _importRows(),
      );

      expect(
        firstPlan.entries.map((entry) => entry.action),
        [ImportRowAction.update, ImportRowAction.create],
      );

      final staged = applier.apply(
        existingSchedule: snapshot,
        plan: firstPlan,
        includedRowNumbers: {2, 3},
      );
      expect(await repository.save(staged), isA<Success<Schedule>>());

      final loadedAfterImport = await repository.findById(original.id);
      expect(loadedAfterImport, isA<Success<Schedule?>>());
      final persisted = (loadedAfterImport as Success<Schedule?>).value!;
      final importedDay = persisted.month(_date)!.day(_date)!;

      expect(importedDay.assignments, hasLength(3));
      expect(
        importedDay.assignments
            .singleWhere(
              (item) =>
                  item.employee.id == _employee.id &&
                  item.shift.id == _night.id,
            )
            .remark,
        'updated note',
      );
      expect(
        importedDay.assignments.any(
          (item) =>
              item.employee.id == _otherEmployee.id &&
              item.shift.id == _evening.id &&
              item.remark == 'keep this assignment' &&
              item.location == 'Ward B',
        ),
        isTrue,
      );
      expect(
        persisted.month(_nextDate)!.day(_nextDate)!.holidayName,
        'Hospital holiday',
      );
      expect(
        persisted.month(_nextDate)!.day(_nextDate)!.assignments.single.remark,
        'different day remains untouched',
      );

      final repeatedPlan = planner.plan(
        existingSchedule: persisted,
        records: _importRows(),
      );
      expect(
        repeatedPlan.entries.map((entry) => entry.action),
        [ImportRowAction.skip, ImportRowAction.skip],
      );
      final repeatedResult = applier.apply(
        existingSchedule: persisted,
        plan: repeatedPlan,
        includedRowNumbers: const {},
      );
      expect(
        repeatedResult.month(_date)!.day(_date)!.assignments,
        hasLength(3),
      );
      expect(
        repeatedResult.month(_date)!.day(_date)!.assignments.where(
          (item) =>
              item.employee.id == _employee.id &&
              item.shift.id == _morning.id,
        ),
        hasLength(1),
      );
    },
  );
}
