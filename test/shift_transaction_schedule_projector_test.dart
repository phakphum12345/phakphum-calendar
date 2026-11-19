import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_day.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_assignment.dart';
import 'package:phakphum_calendar/domain/entities/shift_type.dart';
import 'package:phakphum_calendar/features/shift_exchange/application/shift_transaction_schedule_projector.dart';
import 'package:phakphum_calendar/features/shift_exchange/infrastructure/shift_transaction_api_client.dart';
import 'package:phakphum_calendar/features/schedule/data/legacy_schedule_adapter.dart';
import 'package:phakphum_calendar/models/shift.dart' as legacy;

void main() {
  const projector = ShiftTransactionScheduleProjector();
  final date = DateTime(2026, 11, 18);
  final morning = _shift('morning', 'M', 8, 16);
  final evening = _shift('evening', 'E', 16, 23);
  final night = _shift('night', 'N', 18, 22);
  final alice = _employee('A');
  final bob = _employee('B');
  final chris = _employee('C');

  Schedule scheduleWith(List<ShiftAssignment> assignments) {
    final month = ScheduleMonth.empty(date).replaceDay(
      ScheduleDay(date: date, assignments: assignments),
    );
    return Schedule(id: 'schedule-1', name: 'November roster', months: [month]);
  }

  ShiftTransactionSnapshot transaction({
    required String id,
    required String status,
    required DateTime createdAt,
    required List<Map<String, dynamic>> transfers,
  }) => ShiftTransactionSnapshot(
    id: id,
    mode: 'personal',
    type: transfers.length == 1 ? 'give_up' : 'exchange',
    status: status,
    syncStatus: 'not_started',
    version: 1,
    createdAt: createdAt,
    updatedAt: createdAt,
    participants: const [],
    transfers: transfers,
    timeline: const [],
  );

  Map<String, dynamic> transfer({
    required String from,
    required String to,
    required ShiftType shift,
    required String purpose,
  }) {
    final start = date.add(shift.startTime);
    var end = date.add(shift.endTime);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return {
      'id': 'transfer-$from-$to-${shift.id}',
      'shift_id': ShiftAssignmentIdentity.create(
        scheduleId: 'schedule-1',
        date: date,
        employeeId: from,
        shiftId: shift.id,
      ),
      'from_employee_id': from,
      'to_employee_id': to,
      'shift_code': shift.code,
      'starts_at': start.toIso8601String(),
      'ends_at': end.toIso8601String(),
      'purpose': purpose,
    };
  }

  test('projects an approved give-up without mutating the imported source', () {
    final source = scheduleWith([
      ShiftAssignment(employee: alice, shift: morning),
      ShiftAssignment(employee: bob, shift: evening),
    ]);
    final giveUp = transaction(
      id: 'give-up',
      status: 'approved',
      createdAt: DateTime(2026, 11, 1),
      transfers: [
        transfer(from: 'A', to: 'B', shift: morning, purpose: 'give_up'),
      ],
    );

    final result = projector.project(source: source, transactions: [giveUp]);

    expect(result.warnings, isEmpty);
    expect(result.schedule.month(date)!.day(date)!.assignments[0].employee.id, 'legacy:B');
    expect(source.month(date)!.day(date)!.assignments[0].employee.id, 'legacy:A');
  });

  test('does not project pending, rejected, or cancelled transactions', () {
    final source = scheduleWith([
      ShiftAssignment(employee: alice, shift: morning),
      ShiftAssignment(employee: bob, shift: evening),
    ]);
    final pending = transaction(
      id: 'pending',
      status: 'pending_response',
      createdAt: DateTime(2026, 11, 1),
      transfers: [
        transfer(from: 'A', to: 'B', shift: morning, purpose: 'give_up'),
      ],
    );

    final result = projector.project(source: source, transactions: [pending]);

    expect(result.schedule, same(source));
    expect(result.warnings, isEmpty);
  });

  test('projects both exchange legs against the same pre-transaction roster', () {
    final source = scheduleWith([
      ShiftAssignment(employee: alice, shift: morning),
      ShiftAssignment(employee: bob, shift: evening),
    ]);
    final exchange = transaction(
      id: 'exchange',
      status: 'approved',
      createdAt: DateTime(2026, 11, 1),
      transfers: [
        transfer(from: 'A', to: 'B', shift: morning, purpose: 'exchange'),
        transfer(from: 'B', to: 'A', shift: evening, purpose: 'exchange'),
      ],
    );

    final result = projector.project(source: source, transactions: [exchange]);
    final assignments = result.schedule.month(date)!.day(date)!.assignments;

    expect(result.warnings, isEmpty);
    expect(assignments.map((item) => item.employee.id), ['legacy:B', 'legacy:A']);
    expect(assignments.map((item) => item.shift.code), ['M', 'E']);
  });

  test('replays the same approved ledger idempotently', () {
    final source = scheduleWith([
      ShiftAssignment(employee: alice, shift: morning),
      ShiftAssignment(employee: bob, shift: evening),
    ]);
    final giveUp = transaction(
      id: 'give-up',
      status: 'approved',
      createdAt: DateTime(2026, 11, 1),
      transfers: [
        transfer(from: 'A', to: 'B', shift: morning, purpose: 'give_up'),
      ],
    );
    final first = projector.project(source: source, transactions: [giveUp]);
    final second = projector.project(source: first.schedule, transactions: [giveUp]);

    expect(second.warnings, hasLength(1));
    expect(second.warnings.single, contains('source assignment'));
    expect(
      second.schedule.month(date)!.day(date)!.assignments.map((item) => item.employee.id),
      ['legacy:B', 'legacy:B'],
    );
  });

  test('chains later approved transfers using the projected current owner', () {
    final source = scheduleWith([
      ShiftAssignment(employee: alice, shift: morning),
      ShiftAssignment(employee: bob, shift: evening),
      ShiftAssignment(employee: chris, shift: night),
    ]);
    final first = transaction(
      id: 'first',
      status: 'approved',
      createdAt: DateTime(2026, 11, 1, 8),
      transfers: [
        transfer(from: 'A', to: 'B', shift: morning, purpose: 'give_up'),
      ],
    );
    final second = transaction(
      id: 'second',
      status: 'approved',
      createdAt: DateTime(2026, 11, 2, 8),
      transfers: [
        transfer(from: 'B', to: 'C', shift: morning, purpose: 'give_up'),
      ],
    );

    final result = projector.project(source: source, transactions: [second, first]);

    expect(result.warnings, isEmpty);
    expect(result.schedule.month(date)!.day(date)!.assignments.first.employee.id, 'legacy:C');
  });

  test('warns and leaves the transaction unapplied when the source shift is missing', () {
    final source = scheduleWith([
      ShiftAssignment(employee: bob, shift: evening),
    ]);
    final giveUp = transaction(
      id: 'missing-source',
      status: 'approved',
      createdAt: DateTime(2026, 11, 1),
      transfers: [
        transfer(from: 'A', to: 'B', shift: morning, purpose: 'give_up'),
      ],
    );

    final result = projector.project(source: source, transactions: [giveUp]);

    expect(result.schedule, same(source));
    expect(result.warnings, hasLength(1));
    expect(result.warnings.single, contains('source assignment'));
  });

  test('reconstructs an effective legacy schedule without changing imported source metadata', () {
    const adapter = LegacyScheduleAdapter();
    final conversion = adapter.toCanonical([
      legacy.Shift(
        code: 'M',
        rowLabel: 'Morning',
        assignedName: 'A',
        start: DateTime(2026, 11, 18, 8),
        end: DateTime(2026, 11, 18, 16),
        sheetTitle: 'November',
        cell: 'D5',
        category: legacy.ShiftCategory.own,
      ),
      legacy.Shift(
        code: 'E',
        rowLabel: 'Evening',
        assignedName: 'B',
        start: DateTime(2026, 11, 18, 16),
        end: DateTime(2026, 11, 18, 23),
        sheetTitle: 'November',
        cell: 'D6',
        category: legacy.ShiftCategory.own,
      ),
    ], id: 'schedule-1');
    final sourceAssignment = conversion.schedule
        .month(date)!.day(date)!.assignments.first;
    final transferSnapshot = transaction(
      id: 'legacy-overlay',
      status: 'approved',
      createdAt: DateTime(2026, 11, 1),
      transfers: [
        transfer(
          from: 'A',
          to: 'B',
          shift: sourceAssignment.shift,
          purpose: 'give_up',
        ),
      ],
    );

    final projected = projector.project(
      source: conversion.schedule,
      transactions: [transferSnapshot],
    );
    final effectiveLegacy = conversion.toLegacyShifts(schedule: projected.schedule);

    expect(projected.warnings, isEmpty);
    expect(effectiveLegacy.first.assignedName, 'B');
    expect(effectiveLegacy.first.sheetTitle, 'November');
    expect(effectiveLegacy.first.cell, 'D5');
    expect(conversion.toLegacyShifts().first.assignedName, 'A');
    expect(conversion.schedule.month(date)!.day(date)!.assignments.first.employee.employeeCode, 'A');
  });
}

Employee _employee(String id) => Employee(
  id: 'legacy:$id',
  employeeCode: id,
  firstName: 'Employee',
  lastName: id,
  nickname: '',
  department: const Department(id: 'D', code: 'D', name: 'Department'),
  position: 'Staff',
);

ShiftType _shift(String id, String code, int startHour, int endHour) => ShiftType(
  id: id,
  code: code,
  name: code,
  color: 0,
  startTime: Duration(hours: startHour),
  endTime: Duration(hours: endHour),
  workingHours: (endHour - startHour).toDouble(),
);
