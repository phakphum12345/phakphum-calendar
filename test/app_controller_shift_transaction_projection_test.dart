import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/di/app_dependencies.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_day.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_assignment.dart';
import 'package:phakphum_calendar/domain/entities/shift_type.dart';
import 'package:phakphum_calendar/features/shift_exchange/application/shift_transaction_schedule_projector.dart';
import 'package:phakphum_calendar/features/shift_exchange/infrastructure/shift_transaction_api_client.dart';

void main() {
  test('AppController keeps canonical import immutable and reprojects the server ledger', () async {
    final controller = AppDependencies.production().createDemoAppController();
    addTearDown(controller.dispose);

    final date = DateTime(2026, 11, 18);
    final alice = _employee('legacy:A', 'A', 'Alice');
    final bob = _employee('legacy:B', 'B', 'Bob');
    final morning = ShiftType(
      id: 'morning',
      code: 'M',
      name: 'Morning',
      color: 0,
      startTime: const Duration(hours: 8),
      endTime: const Duration(hours: 16),
      workingHours: 8,
    );
    final evening = ShiftType(
      id: 'evening',
      code: 'E',
      name: 'Evening',
      color: 0,
      startTime: const Duration(hours: 16),
      endTime: const Duration(hours: 23),
      workingHours: 7,
    );

    Schedule sourceSchedule() => Schedule(
      id: 'schedule-1',
      name: 'November roster',
      months: [
        ScheduleMonth.empty(date).replaceDay(
          ScheduleDay(
            date: date,
            assignments: [
              ShiftAssignment(employee: alice, shift: morning),
              ShiftAssignment(employee: bob, shift: evening),
            ],
          ),
        ),
      ],
    );

    final source = sourceSchedule();
    final identity = ShiftAssignmentIdentity.create(
      scheduleId: source.id,
      date: date,
      employeeId: 'A',
      shiftId: morning.id,
    );
    final transaction = ShiftTransactionSnapshot(
      id: 'transaction-1',
      mode: 'personal',
      type: 'give_up',
      status: 'approved',
      syncStatus: 'not_started',
      version: 2,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 2),
      participants: const [],
      transfers: [
        {
          'transfer_key': 'transfer-1',
          'shift_id': identity,
          'from_employee_id': 'A',
          'to_employee_id': 'B',
          'shift_code': 'M',
          'starts_at': date.add(const Duration(hours: 8)).toIso8601String(),
          'ends_at': date.add(const Duration(hours: 16)).toIso8601String(),
          'purpose': 'give_up',
        },
      ],
      timeline: const [],
    );

    await controller.adoptCanonicalSchedule(source, persist: false);
    controller.updateShiftTransactions([transaction]);

    expect(
      controller.canonicalSchedule.month(date)!.day(date)!.assignments.first.employee.employeeCode,
      'A',
    );
    expect(
      controller.effectiveSchedule.month(date)!.day(date)!.assignments.first.employee.employeeCode,
      'B',
    );
    expect(controller.shifts.first.assignedName, 'Alice');
    expect(controller.effectiveShifts.first.assignedName, 'Bob');

    final preview = await controller.previewShiftTransactionCalendarSync(transaction);
    expect(preview.transactionId, transaction.id);
    expect(preview.transferLines, hasLength(1));
    expect(preview.deleteCount, 0);
    controller.cancelShiftTransactionCalendarSyncPreview();

    // A repeated import replaces only the source; the server ledger is replayed.
    await controller.adoptCanonicalSchedule(sourceSchedule(), persist: false);
    expect(
      controller.canonicalSchedule.month(date)!.day(date)!.assignments.first.employee.employeeCode,
      'A',
    );
    expect(controller.effectiveShifts.first.assignedName, 'Bob');

    controller.clearShiftTransactions();
    expect(controller.effectiveShifts.first.assignedName, 'Alice');
  });
}

Employee _employee(String id, String code, String name) => Employee(
  id: id,
  employeeCode: code,
  firstName: name,
  lastName: '',
  nickname: '',
  department: const Department(id: 'D', code: 'D', name: 'Department'),
  position: 'Staff',
);
