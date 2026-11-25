import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_day.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_assignment.dart';
import 'package:phakphum_calendar/domain/entities/shift_type.dart';
import 'package:phakphum_calendar/features/shift_exchange/application/shift_transaction_calendar_sync_mapper.dart';
import 'package:phakphum_calendar/features/shift_exchange/infrastructure/shift_transaction_api_client.dart';
import 'package:phakphum_calendar/features/workflow/application/canonical_schedule_event_mapper.dart';

void main() {
  const mapper = ShiftTransactionCalendarSyncMapper();
  final date = DateTime(2026, 11, 18);
  final morning = ShiftType(
    id: 'morning',
    code: 'M',
    name: 'Morning',
    color: 0,
    startTime: const Duration(hours: 8),
    endTime: const Duration(hours: 16),
    workingHours: 8,
  );
  final bob = _employee('legacy:B', 'B', 'Bob');

  Schedule schedule({bool duplicate = false}) => Schedule(
    id: 'schedule-1',
    name: 'November roster',
    months: [
      ScheduleMonth.empty(date).replaceDay(
        ScheduleDay(
          date: date,
          assignments: [
            ShiftAssignment(employee: bob, shift: morning),
            if (duplicate) ShiftAssignment(employee: bob, shift: morning),
          ],
        ),
      ),
    ],
  );

  ShiftTransactionSnapshot transaction() => ShiftTransactionSnapshot(
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
        'shift_id': 'source-identity',
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

  test('maps one approved transfer to the effective recipient event identity', () {
    final effective = schedule();
    final result = mapper.map(schedule: effective, transaction: transaction());

    expect(
      result,
      [const CanonicalScheduleEventMapper().map(effective).single.syncId],
    );
  });

  test('retains the transfer key alongside the effective event sync identity', () {
    final targets = mapper.mapTargets(
      schedule: schedule(),
      transaction: transaction(),
    );

    expect(targets, hasLength(1));
    expect(targets.single.transferId, 'transfer-1');
    expect(
      targets.single.syncId,
      const CanonicalScheduleEventMapper().map(schedule()).single.syncId,
    );
  });

  test('fails closed when more than one effective assignment matches a transfer', () {
    expect(
      () => mapper.map(
        schedule: schedule(duplicate: true),
        transaction: transaction(),
      ),
      throwsStateError,
    );
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
