import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../history/domain/sync_history_entry.dart';
import '../../history/domain/sync_history_repository.dart';
import '../domain/calendar_sync_gateway.dart';
import '../domain/calendar_sync_coordination_gateway.dart';
import '../domain/calendar_sync_command.dart';
import '../domain/calendar_sync_operation_result.dart';
import '../domain/failed_sync_operation.dart';
import '../domain/failed_sync_repository.dart';
import '../domain/managed_calendar_event.dart';
import 'calendar_sync_insert_reconciler.dart';
import 'calendar_sync_plan.dart';

class ResilientCalendarSyncResult {
  const ResilientCalendarSyncResult({
    required this.historyEntry,
    required this.operations,
  });

  final SyncHistoryEntry historyEntry;
  final List<CalendarSyncOperationResult> operations;

  bool get hasFailures => operations.any((operation) => !operation.success);
}

class ResilientCalendarSyncExecutor {
  const ResilientCalendarSyncExecutor({
    required this._gateway,
    required this._historyRepository,
    this.failedRepository,
    this.coordinationGateway,
    this.maxAttempts = 2,
  }) : assert(maxAttempts > 0);

  final CalendarSyncGateway _gateway;
  final SyncHistoryRepository _historyRepository;
  final FailedSyncRepository? failedRepository;
  final CalendarSyncCoordinationGateway? coordinationGateway;
  final int maxAttempts;

  Future<ResilientCalendarSyncResult> execute(CalendarSyncPlan plan) async {
    final startedAt = DateTime.now();
    final historyId = 'sync-${startedAt.microsecondsSinceEpoch}';

    var history = SyncHistoryEntry(
      id: historyId,
      startedAt: startedAt,
      status: SyncHistoryStatus.running,
      inserted: 0,
      updated: 0,
      deleted: 0,
      failed: 0,
      scheduleId: plan.scheduleId,
    );

    await _historyRepository.save(history);

    final operations = <CalendarSyncOperationResult>[];
    final failedOperations = <FailedSyncOperation>[];
    var inserted = 0;
    var updated = 0;
    var deleted = 0;
    var failed = 0;
    final coordination = coordinationGateway;
    final lease = coordination == null || plan.operationCount == 0
        ? null
        : await coordination.acquire(
            calendarId: plan.calendarId,
            scheduleId: plan.scheduleId,
          );
    var leaseStatus = 'failed';

    Future<CalendarSyncOperationResult> trackOperation({
      required CalendarSyncOperationType type,
      required String referenceId,
      required Map<String, Object?> payload,
      required Future<CalendarSyncOperationResult> Function() operation,
    }) async {
      if (coordination == null || lease == null) return operation();
      final operationKey = _ledgerOperationKey(type, referenceId);
      final payloadHash = sha256
          .convert(utf8.encode(_canonicalJson(payload)))
          .toString();
      await coordination.heartbeat(lease);
      await coordination.recordOperation(
        lease: lease,
        operationKey: operationKey,
        operationType: type.name,
        payloadHash: payloadHash,
        operationPayload: payload,
      );
      await coordination.updateOperation(
        lease: lease,
        operationKey: operationKey,
        status: 'running',
        attemptCount: 0,
      );
      try {
        final result = await operation();
        await coordination.updateOperation(
          lease: lease,
          operationKey: operationKey,
          status: result.success ? 'succeeded' : 'failed',
          attemptCount: result.attempts,
          providerEventId: result.providerEventId,
          lastError: _safeLedgerErrorCode(result.message),
        );
        return result;
      } catch (error) {
        await coordination.updateOperation(
          lease: lease,
          operationKey: operationKey,
          status: 'failed',
          attemptCount: 1,
          lastError: 'operation_exception',
        );
        rethrow;
      }
    }

    Future<void> executeDelete(CalendarDeleteOperation operation) async {
      final result = await trackOperation(
        type: CalendarSyncOperationType.delete,
        referenceId: operation.eventId,
        payload: {
          'event_id': operation.eventId,
          'calendar_id': operation.calendarId,
          'expected_etag': operation.expectedEtag,
          'expected_sync_id': operation.expectedSyncId,
        },
        operation: () => _retry(
          type: CalendarSyncOperationType.delete,
          referenceId: operation.eventId,
          operation: () {
            if (_gateway is ConditionalCalendarSyncGateway) {
              final etag = operation.expectedEtag;
              final syncId = operation.expectedSyncId;
              if (etag == null) {
                throw StateError(
                  'Calendar delete is blocked because its preview has no provider ETag or managed identity.',
                );
              }
              return (_gateway as ConditionalCalendarSyncGateway)
                  .deleteConditionally(
                    eventId: operation.eventId,
                    calendarId: operation.calendarId,
                    expectedEtag: etag,
                    expectedSyncId: syncId,
                  );
            }
            return _gateway.delete(
              eventId: operation.eventId,
              calendarId: operation.calendarId,
            );
          },
        ),
      );
      operations.add(result);
      if (!result.success) {
        failedOperations.add(
          FailedSyncOperation(
            historyId: historyId,
            type: CalendarSyncOperationType.delete,
            referenceId: operation.eventId,
            attempts: result.attempts,
            eventId: operation.eventId,
            calendarId: operation.calendarId,
            expectedEtag: operation.expectedEtag,
            expectedSyncId: operation.expectedSyncId,
            message: result.message,
          ),
        );
      }
      result.success ? deleted++ : failed++;
    }

    try {
      for (final operation in plan.deletes.where(
        (operation) => operation.beforeWrites,
      )) {
        await executeDelete(operation);
      }

      final insertReconciler = CalendarSyncInsertReconciler(_gateway);
      for (final command in plan.inserts) {
        final result = await trackOperation(
          type: CalendarSyncOperationType.insert,
          referenceId: command.syncId,
          payload: _commandPayload(command),
          operation: () async =>
              (await _retryInsert(command, insertReconciler)).result,
        );
        operations.add(result);
        if (!result.success) {
          failedOperations.add(
            FailedSyncOperation(
              historyId: historyId,
              type: CalendarSyncOperationType.insert,
              referenceId: command.syncId,
              attempts: result.attempts,
              command: command,
              message: result.message,
            ),
          );
        }
        result.success ? inserted++ : failed++;
      }

      for (final operation in plan.updates) {
        final result = await trackOperation(
          type: CalendarSyncOperationType.update,
          referenceId: operation.command.syncId,
          payload: {
            'event_id': operation.eventId,
            'expected_etag': operation.expectedEtag,
            'expected_sync_id': operation.expectedSyncId,
            ..._commandPayload(operation.command),
          },
          operation: () => _retry(
            type: CalendarSyncOperationType.update,
            referenceId: operation.command.syncId,
            operation: () {
              if (_gateway is ConditionalCalendarSyncGateway) {
                final etag = operation.expectedEtag;
                final syncId = operation.expectedSyncId;
                if (etag == null) {
                  throw StateError(
                    'Calendar update is blocked because its preview has no provider ETag or managed identity.',
                  );
                }
                return (_gateway as ConditionalCalendarSyncGateway)
                    .updateConditionally(
                      eventId: operation.eventId,
                      expectedEtag: etag,
                      expectedSyncId: syncId,
                      command: operation.command,
                    );
              }
              return _gateway.update(
                eventId: operation.eventId,
                command: operation.command,
              );
            },
          ),
        );
        operations.add(result);
        if (!result.success) {
          failedOperations.add(
            FailedSyncOperation(
              historyId: historyId,
              type: CalendarSyncOperationType.update,
              referenceId: operation.command.syncId,
              attempts: result.attempts,
              command: operation.command,
              eventId: operation.eventId,
              expectedEtag: operation.expectedEtag,
              expectedSyncId: operation.expectedSyncId,
              message: result.message,
            ),
          );
        }
        result.success ? updated++ : failed++;
      }

      for (final operation in plan.deletes.where(
        (operation) => !operation.beforeWrites,
      )) {
        await executeDelete(operation);
      }

      final status = failed == 0
          ? SyncHistoryStatus.success
          : inserted + updated + deleted == 0
          ? SyncHistoryStatus.failure
          : SyncHistoryStatus.partialSuccess;

      history = history.copyWith(
        finishedAt: DateTime.now(),
        status: status,
        inserted: inserted,
        updated: updated,
        deleted: deleted,
        failed: failed,
        message: failed == 0
            ? 'Synchronization completed successfully.'
            : 'Synchronization completed with $failed failed operation(s).',
      );

      await failedRepository?.replaceForHistory(historyId, failedOperations);
      await _historyRepository.save(history);
      leaseStatus = switch (status) {
        SyncHistoryStatus.success => 'success',
        SyncHistoryStatus.partialSuccess => 'partial_success',
        SyncHistoryStatus.failure => 'failed',
        SyncHistoryStatus.running => 'failed',
      };

      return ResilientCalendarSyncResult(
        historyEntry: history,
        operations: operations,
      );
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

  Future<_RetryInsertResult> _retryInsert(
    CalendarSyncCommand command,
    CalendarSyncInsertReconciler reconciler,
  ) async {
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final created = await _gateway.insert(command);
        return _RetryInsertResult(
          result: CalendarSyncOperationResult(
            type: CalendarSyncOperationType.insert,
            referenceId: command.syncId,
            success: true,
            providerEventId: created.eventId.isEmpty ? null : created.eventId,
            attempts: attempt,
          ),
          attempts: attempt,
        );
      } catch (error) {
        lastError = error;
        try {
          final existing = await reconciler.findExisting(command);
          if (existing != null) {
            return _RetryInsertResult(
              result: CalendarSyncOperationResult(
                type: CalendarSyncOperationType.insert,
                referenceId: command.syncId,
                success: true,
                providerEventId: existing.eventId.isEmpty
                    ? null
                    : existing.eventId,
                attempts: attempt,
              ),
              attempts: attempt,
            );
          }
        } catch (verificationError) {
          return _RetryInsertResult(
            result: CalendarSyncOperationResult(
              type: CalendarSyncOperationType.insert,
              referenceId: command.syncId,
              success: false,
              message:
                  'Insert failed and its provider outcome could not be verified: '
                  '$error; verification failed: $verificationError',
              attempts: attempt,
            ),
            attempts: attempt,
          );
        }

        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
        }
      }
    }

    return _RetryInsertResult(
      result: CalendarSyncOperationResult(
        type: CalendarSyncOperationType.insert,
        referenceId: command.syncId,
        success: false,
        message: lastError?.toString(),
        attempts: maxAttempts,
      ),
      attempts: maxAttempts,
    );
  }

  Future<CalendarSyncOperationResult> _retry({
    required CalendarSyncOperationType type,
    required String referenceId,
    required Future<Object?> Function() operation,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final value = await operation();
        return CalendarSyncOperationResult(
          type: type,
          referenceId: referenceId,
          success: true,
          providerEventId:
              value is ManagedCalendarEvent && value.eventId.isNotEmpty
              ? value.eventId
              : null,
          attempts: attempt,
        );
      } catch (error) {
        lastError = error;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
        }
      }
    }

    return CalendarSyncOperationResult(
      type: type,
      referenceId: referenceId,
      success: false,
      message: lastError?.toString(),
      attempts: maxAttempts,
    );
  }
}

String? _safeLedgerErrorCode(String? message) {
  if (message == null || message.trim().isEmpty) return null;
  final normalized = message.toLowerCase();
  if (normalized.contains('etag') || normalized.contains('precondition')) {
    return 'stale_precondition';
  }
  if (normalized.contains('timeout') || normalized.contains('timed out')) {
    return 'provider_timeout';
  }
  if (normalized.contains('not found') || normalized.contains('404')) {
    return 'provider_event_not_found';
  }
  return 'provider_operation_failed';
}

String _ledgerOperationKey(CalendarSyncOperationType type, String referenceId) {
  final digest = sha256.convert(utf8.encode(referenceId));
  return '${type.name}:$digest';
}

Map<String, Object?> _commandPayload(CalendarSyncCommand command) => {
  'sync_id': command.syncId,
  'title': command.title,
  'start': command.start.toIso8601String(),
  'end': command.end.toIso8601String(),
  'description': command.description,
  'color_id': command.colorId,
  'calendar_id': command.calendarId,
};

class _RetryInsertResult {
  const _RetryInsertResult({required this.result, required this.attempts});

  final CalendarSyncOperationResult result;
  final int attempts;
}

Object? _canonicalizeJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {
      for (final key in keys) key: _canonicalizeJson(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalizeJson).toList(growable: false);
  }
  return value;
}

String _canonicalJson(Map<String, Object?> value) =>
    jsonEncode(_canonicalizeJson(value));
