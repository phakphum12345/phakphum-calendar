import '../../../domain/entities/schedule.dart';
import '../../workflow/application/canonical_schedule_event_mapper.dart';
import '../infrastructure/shift_transaction_api_client.dart';

class ShiftTransactionTransferSyncTarget {
  const ShiftTransactionTransferSyncTarget({
    required this.transferId,
    required this.syncId,
  });

  final String transferId;
  final String syncId;
}

/// Resolves every approved transaction transfer to exactly one event in the
/// effective schedule. Transfer order is retained for the server event ledger.
class ShiftTransactionCalendarSyncMapper {
  const ShiftTransactionCalendarSyncMapper({
    this.eventMapper = const CanonicalScheduleEventMapper(),
  });

  final CanonicalScheduleEventMapper eventMapper;

  List<String> map({
    required Schedule schedule,
    required ShiftTransactionSnapshot transaction,
  }) => mapTargets(schedule: schedule, transaction: transaction)
      .map((target) => target.syncId)
      .toList(growable: false);

  List<ShiftTransactionTransferSyncTarget> mapTargets({
    required Schedule schedule,
    required ShiftTransactionSnapshot transaction,
  }) {
    final candidates = eventMapper.map(schedule);
    final targets = <ShiftTransactionTransferSyncTarget>[];
    for (final transfer in transaction.transfers) {
      final start = DateTime.tryParse(
        transfer['starts_at']?.toString() ?? '',
      )?.toLocal();
      final end = DateTime.tryParse(
        transfer['ends_at']?.toString() ?? '',
      )?.toLocal();
      final target = transfer['to_employee_id']?.toString();
      final transferId = transfer['transfer_key']?.toString();
      if (start == null ||
          end == null ||
          target == null ||
          transferId == null ||
          transferId.isEmpty ||
          !end.isAfter(start)) {
        throw StateError('ข้อมูลเวลาและผู้รับของธุรกรรมไม่สมบูรณ์');
      }

      final matches = <String>[];
      var candidateIndex = 0;
      for (final month in schedule.months) {
        for (final day in month.days) {
          final date = DateTime(day.date.year, day.date.month, day.date.day);
          for (final assignment in day.assignments) {
            final candidate = candidates[candidateIndex++];
            final assignmentStart = date.add(assignment.shift.startTime);
            var assignmentEnd = date.add(assignment.shift.endTime);
            if (!assignmentEnd.isAfter(assignmentStart)) {
              assignmentEnd = assignmentEnd.add(const Duration(days: 1));
            }
            final employee = assignment.employee;
            final identityMatches = employee.id == target ||
                employee.employeeCode == target ||
                employee.fullName == target ||
                employee.displayName == target;
            if (identityMatches &&
                assignment.shift.code == transfer['shift_code']?.toString() &&
                assignmentStart.isAtSameMomentAs(start) &&
                assignmentEnd.isAtSameMomentAs(end)) {
              matches.add(candidate.syncId);
            }
          }
        }
      }
      if (matches.length != 1) {
        throw StateError(
          matches.isEmpty
              ? 'ไม่พบเวรปลายทางในตารางผลลัพธ์'
              : 'พบเวรปลายทางมากกว่าหนึ่งรายการ ไม่สามารถจับคู่ Event ID ได้',
        );
      }
      targets.add(ShiftTransactionTransferSyncTarget(
        transferId: transferId,
        syncId: matches.single,
      ));
    }
    final syncIds = targets.map((target) => target.syncId).toList();
    final transferIds = targets.map((target) => target.transferId).toList();
    if (syncIds.toSet().length != syncIds.length ||
        transferIds.toSet().length != transferIds.length) {
      throw StateError('หลายธุรกรรมชี้ไปยัง Calendar Event หรือ transfer เดียวกัน');
    }
    return List.unmodifiable(targets);
  }
}
