import '../../history/domain/sync_history_entry.dart';
import '../../history/domain/sync_history_repository.dart';
import '../domain/calendar_sync_gateway.dart';
import '../domain/calendar_sync_operation_result.dart';
import '../domain/failed_sync_operation.dart';
import '../domain/failed_sync_repository.dart';
import 'calendar_sync_insert_reconciler.dart';

class ResumeSyncResult {
  const ResumeSyncResult({
    required this.historyEntry,
    required this.operations,
  });
  final SyncHistoryEntry historyEntry;
  final List<CalendarSyncOperationResult> operations;
  bool get completed => operations.every((item) => item.success);
}

class ResumeSyncService {
  const ResumeSyncService({
    required this._gateway,
    required this._historyRepository,
    required this._failedRepository,
  });

  final CalendarSyncGateway _gateway;
  final SyncHistoryRepository _historyRepository;
  final FailedSyncRepository _failedRepository;

  Future<ResumeSyncResult> resume(String historyId) async {
    final original = await _historyRepository.findById(historyId);
    if (original == null) throw StateError('Sync history entry not found.');
    final failed = await _failedRepository.listForHistory(historyId);
    final remaining = <FailedSyncOperation>[];
    final results = <CalendarSyncOperationResult>[];
    var inserted = original.inserted;
    var updated = original.updated;
    var deleted = original.deleted;
    final insertReconciler = CalendarSyncInsertReconciler(_gateway);

    for (final item in failed) {
      String? providerEventId;
      try {
        if (item.type == CalendarSyncOperationType.insert) {
          final command = item.command;
          if (command == null) throw StateError('Insert command missing.');
          var event = await insertReconciler.findExisting(command);
          if (event == null) {
            try {
              event = await _gateway.insert(command);
            } catch (_) {
              event = await insertReconciler.findExisting(command);
              if (event == null) rethrow;
            }
          }
          providerEventId = event.eventId.isEmpty ? null : event.eventId;
          inserted++;
        } else if (item.type == CalendarSyncOperationType.update) {
          final command = item.command;
          final eventId = item.eventId;
          if (command == null || eventId == null) {
            throw StateError('Update payload incomplete.');
          }
          if (_gateway is ConditionalCalendarSyncGateway) {
            final etag = item.expectedEtag;
            final syncId = item.expectedSyncId;
            if (etag == null) {
              throw StateError('Cannot resume a stale Calendar update without its original provider ETag.');
            }
            await (_gateway as ConditionalCalendarSyncGateway).updateConditionally(
              eventId: eventId,
              expectedEtag: etag,
              expectedSyncId: syncId,
              command: command,
            );
          } else {
            await _gateway.update(eventId: eventId, command: command);
          }
          updated++;
        } else {
          final eventId = item.eventId;
          if (eventId == null) throw StateError('Delete event ID missing.');
          if (_gateway is ConditionalCalendarSyncGateway) {
            final etag = item.expectedEtag;
            final syncId = item.expectedSyncId;
            if (etag == null) {
              throw StateError('Cannot resume a stale Calendar delete without its original provider ETag.');
            }
            await (_gateway as ConditionalCalendarSyncGateway).deleteConditionally(
              eventId: eventId,
              calendarId: item.calendarId,
              expectedEtag: etag,
              expectedSyncId: syncId,
            );
          } else {
            await _gateway.delete(eventId: eventId, calendarId: item.calendarId);
          }
          deleted++;
        }
        results.add(
          CalendarSyncOperationResult(
            type: item.type,
            referenceId: item.referenceId,
            success: true,
            providerEventId: providerEventId,
          ),
        );
      } catch (error) {
        remaining.add(
          FailedSyncOperation(
            historyId: item.historyId,
            type: item.type,
            referenceId: item.referenceId,
            attempts: item.attempts + 1,
            command: item.command,
            eventId: item.eventId,
            calendarId: item.calendarId,
            expectedEtag: item.expectedEtag,
            expectedSyncId: item.expectedSyncId,
            message: error.toString(),
          ),
        );
        results.add(
          CalendarSyncOperationResult(
            type: item.type,
            referenceId: item.referenceId,
            success: false,
            message: error.toString(),
          ),
        );
      }
    }

    await _failedRepository.replaceForHistory(historyId, remaining);
    final history = original.copyWith(
      finishedAt: DateTime.now(),
      status: remaining.isEmpty
          ? SyncHistoryStatus.success
          : SyncHistoryStatus.partialSuccess,
      inserted: inserted,
      updated: updated,
      deleted: deleted,
      failed: remaining.length,
      message: remaining.isEmpty
          ? 'All failed operations resumed successfully.'
          : '${remaining.length} operation(s) still failed.',
    );
    await _historyRepository.save(history);
    return ResumeSyncResult(historyEntry: history, operations: results);
  }
}
