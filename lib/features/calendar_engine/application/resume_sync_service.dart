import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../history/domain/sync_history_entry.dart';
import '../../history/domain/sync_history_repository.dart';
import '../domain/calendar_sync_gateway.dart';
import '../domain/calendar_sync_coordination_gateway.dart';
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
    this.coordinationGateway,
  });

  final CalendarSyncGateway _gateway;
  final SyncHistoryRepository _historyRepository;
  final FailedSyncRepository _failedRepository;
  final CalendarSyncCoordinationGateway? coordinationGateway;

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
    final coordination = coordinationGateway;
    CalendarSyncLease? lease;
    var leaseStatus = 'failed';

    if (coordination != null && failed.isNotEmpty) {
      final calendarId = failed.first.calendarId;
      if (failed.any((item) => item.calendarId != calendarId)) {
        throw StateError('A resume batch cannot span multiple Calendar IDs.');
      }
      if (original.scheduleId.trim().isEmpty || original.scheduleId == 'unknown') {
        throw StateError('Cannot resume server-coordinated sync without the original Schedule ID.');
      }
      lease = await coordination.acquire(
        calendarId: calendarId,
        scheduleId: original.scheduleId,
      );
    }

    try {
      for (final item in failed) {
        final operationKey = _ledgerOperationKey(item.type, item.referenceId);
        if (coordination != null && lease != null) {
          await coordination.heartbeat(lease);
          await coordination.recordOperation(
            lease: lease,
            operationKey: operationKey,
            operationType: item.type.name,
            payloadHash: _payloadHash(item),
          );
          await coordination.updateOperation(
            lease: lease,
            operationKey: operationKey,
            status: 'running',
            attemptCount: 0,
          );
        }

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
          if (coordination != null && lease != null) {
            await coordination.updateOperation(
              lease: lease,
              operationKey: operationKey,
              status: 'succeeded',
              attemptCount: item.attempts + 1,
              providerEventId: providerEventId,
            );
          }
          results.add(
            CalendarSyncOperationResult(
              type: item.type,
              referenceId: item.referenceId,
              success: true,
              providerEventId: providerEventId,
              attempts: item.attempts + 1,
            ),
          );
        } catch (error) {
          if (coordination != null && lease != null) {
            await coordination.updateOperation(
              lease: lease,
              operationKey: operationKey,
              status: 'failed',
              attemptCount: item.attempts + 1,
              lastError: error.toString(),
            );
          }
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
              attempts: item.attempts + 1,
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
      leaseStatus = remaining.isEmpty ? 'success' : 'partial_success';
      return ResumeSyncResult(historyEntry: history, operations: results);
    } finally {
      if (coordination != null && lease != null) {
        try {
          await coordination.release(lease: lease, status: leaseStatus);
        } catch (_) {
          // The lease expires automatically if release cannot be confirmed.
        }
      }
    }
  }
}

String _ledgerOperationKey(
  CalendarSyncOperationType type,
  String referenceId,
) {
  final digest = sha256.convert(utf8.encode(referenceId));
  return '${type.name}:$digest';
}

String _payloadHash(FailedSyncOperation item) {
  final command = item.command;
  final payload = <String, Object?>{
    'event_id': item.eventId,
    'calendar_id': item.calendarId,
    'expected_etag': item.expectedEtag,
    'expected_sync_id': item.expectedSyncId,
    if (command != null) 'sync_id': command.syncId,
    if (command != null) 'title': command.title,
    if (command != null) 'start': command.start.toIso8601String(),
    if (command != null) 'end': command.end.toIso8601String(),
    if (command != null) 'description': command.description,
    if (command != null) 'color_id': command.colorId,
    if (command != null) 'command_calendar_id': command.calendarId,
  };
  return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
}
