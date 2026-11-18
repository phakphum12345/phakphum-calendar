import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../domain/entities/employee.dart';
import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/shift_assignment.dart';
import '../../shift_exchange/infrastructure/shift_transaction_api_client.dart';

/// Stable identity for one assignment in the imported canonical roster.
///
/// The owner is part of the identity so a later transfer can refer to the
/// current owner after an earlier approved transfer has been projected.
class ShiftAssignmentIdentity {
  const ShiftAssignmentIdentity._();

  static String create({
    required String scheduleId,
    required DateTime date,
    required String employeeId,
    required String shiftId,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final source = [
      scheduleId,
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
      employeeId,
      shiftId,
    ].join('|');
    return sha256.convert(utf8.encode(source)).toString();
  }
}

class ShiftTransactionScheduleProjection {
  const ShiftTransactionScheduleProjection({
    required this.schedule,
    required this.warnings,
  });

  final Schedule schedule;
  final List<String> warnings;
}

/// Builds an effective schedule from the imported source plus approved
/// transaction transfers. The source schedule is never mutated or overwritten.
///
/// Re-running projection is idempotent. If an import is repeated, callers
/// should project the newly imported source with the independent server ledger.
class ShiftTransactionScheduleProjector {
  const ShiftTransactionScheduleProjector();

  ShiftTransactionScheduleProjection project({
    required Schedule source,
    required Iterable<ShiftTransactionSnapshot> transactions,
  }) {
    var projected = source;
    final warnings = <String>[];
    final ordered = transactions
        .where((transaction) =>
            transaction.status == 'approved' ||
            transaction.status == 'completed')
        .toList()
      ..sort((left, right) {
        final byCreated = left.createdAt.compareTo(right.createdAt);
        return byCreated != 0 ? byCreated : left.id.compareTo(right.id);
      });

    for (final transaction in ordered) {
      final resolved = <_ResolvedTransfer>[];
      var transactionIsValid = true;

      for (final transfer in transaction.transfers) {
        final resolution = _resolveTransfer(projected, transfer);
        if (resolution.warning != null) {
          warnings.add('Transaction ${transaction.id}: ${resolution.warning}');
          transactionIsValid = false;
          break;
        }
        if (resolution.transfer != null) {
          resolved.add(resolution.transfer!);
        }
      }

      if (!transactionIsValid) continue;
      final uniqueSlots = resolved
          .map((item) => '${_dateKey(item.date)}:${item.assignmentIndex}')
          .toSet();
      if (uniqueSlots.length != resolved.length) {
        warnings.add(
          'Transaction ${transaction.id}: multiple transfer legs target the same roster assignment; no changes were projected.',
        );
        continue;
      }
      projected = _applyTransfers(projected, resolved);
    }

    return ShiftTransactionScheduleProjection(
      schedule: projected,
      warnings: List.unmodifiable(warnings),
    );
  }

  _TransferResolution _resolveTransfer(
    Schedule schedule,
    Map<String, dynamic> transfer,
  ) {
    final start = DateTime.tryParse(transfer['starts_at']?.toString() ?? '');
    final end = DateTime.tryParse(transfer['ends_at']?.toString() ?? '');
    final shiftId = transfer['shift_id']?.toString();
    final shiftCode = transfer['shift_code']?.toString();
    final fromEmployeeId = transfer['from_employee_id']?.toString();
    final toEmployeeId = transfer['to_employee_id']?.toString();

    if (start == null || end == null || !end.isAfter(start) ||
        shiftId == null || shiftCode == null ||
        fromEmployeeId == null || toEmployeeId == null) {
      return const _TransferResolution.warning(
        'transfer is missing a valid identity, owner, or time range.',
      );
    }

    final localStart = start.toLocal();
    final localEnd = end.toLocal();
    final date = DateTime(localStart.year, localStart.month, localStart.day);
    final month = schedule.month(date);
    final day = month?.day(date);
    if (month == null || day == null) {
      return _TransferResolution.warning(
        'source schedule does not contain ${_dateKey(date)}.',
      );
    }

    final targetEmployee = _employees(schedule)[toEmployeeId];
    if (targetEmployee == null) {
      return _TransferResolution.warning(
        'recipient employee $toEmployeeId is not present in the canonical roster.',
      );
    }

    final sourceMatches = <int>[];
    for (var index = 0; index < day.assignments.length; index++) {
      final assignment = day.assignments[index];
      if (assignment.shift.code != shiftCode ||
          !_matchesTimeRange(assignment, date, localStart, localEnd)) {
        continue;
      }
      if (assignment.employee.id == fromEmployeeId &&
          ShiftAssignmentIdentity.create(
                scheduleId: schedule.id,
                date: date,
                employeeId: fromEmployeeId,
                shiftId: assignment.shift.id,
              ) ==
              shiftId) {
        sourceMatches.add(index);
      }
    }

    if (sourceMatches.length == 1) {
      return _TransferResolution.resolved(
        _ResolvedTransfer(
          date: date,
          assignmentIndex: sourceMatches.single,
          recipient: targetEmployee,
        ),
      );
    }
    if (sourceMatches.length > 1) {
      return const _TransferResolution.warning(
        'more than one roster assignment matches the transfer; no guess was made.',
      );
    }
    return _TransferResolution.warning(
      'the source assignment for $fromEmployeeId → $toEmployeeId ($shiftCode) was not found.',
    );
  }

  Schedule _applyTransfers(
    Schedule schedule,
    List<_ResolvedTransfer> transfers,
  ) {
    final assignmentsByDate = <String, List<ShiftAssignment>>{};
    for (final transfer in transfers) {
      final key = _dateKey(transfer.date);
      final month = schedule.month(transfer.date)!;
      final day = month.day(transfer.date)!;
      final assignments = assignmentsByDate.putIfAbsent(
        key,
        () => List<ShiftAssignment>.of(day.assignments),
      );
      final original = assignments[transfer.assignmentIndex];
      assignments[transfer.assignmentIndex] = original.copyWith(
        employee: transfer.recipient,
      );
    }

    var updated = schedule;
    for (final transfer in transfers) {
      final key = _dateKey(transfer.date);
      final month = updated.month(transfer.date)!;
      final day = month.day(transfer.date)!;
      final assignments = assignmentsByDate[key]!;
      updated = updated.replaceMonth(
        month.replaceDay(day.copyWith(assignments: assignments)),
      );
    }
    return updated;
  }

  Map<String, Employee> _employees(Schedule schedule) {
    final result = <String, Employee>{};
    for (final month in schedule.months) {
      for (final day in month.days) {
        for (final assignment in day.assignments) {
          result[assignment.employee.id] = assignment.employee;
        }
      }
    }
    return result;
  }

  bool _matchesTimeRange(
    ShiftAssignment assignment,
    DateTime date,
    DateTime expectedStart,
    DateTime expectedEnd,
  ) {
    final start = DateTime(date.year, date.month, date.day)
        .add(assignment.shift.startTime);
    var end = DateTime(date.year, date.month, date.day)
        .add(assignment.shift.endTime);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return start.isAtSameMomentAs(expectedStart) &&
        end.isAtSameMomentAs(expectedEnd);
  }
}

class _ResolvedTransfer {
  const _ResolvedTransfer({
    required this.date,
    required this.assignmentIndex,
    required this.recipient,
  });

  final DateTime date;
  final int assignmentIndex;
  final Employee recipient;
}

class _TransferResolution {
  const _TransferResolution._({
    this.transfer,
    this.warning,
  });

  const _TransferResolution.resolved(_ResolvedTransfer value)
    : this._(transfer: value);

  const _TransferResolution.warning(String value)
    : this._(warning: value);

  final _ResolvedTransfer? transfer;
  final String? warning;
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
