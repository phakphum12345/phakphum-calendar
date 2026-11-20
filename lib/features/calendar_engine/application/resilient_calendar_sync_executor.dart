import '../../history/domain/sync_history_entry.dart';
import '../../history/domain/sync_history_repository.dart';
import '../domain/calendar_sync_gateway.dart';
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
    this.maxAttempts = 2,
  }) : assert(maxAttempts > 0);

  final CalendarSyncGateway _gateway;
  final SyncHistoryRepository _historyRepository;
  final FailedSyncRepository? failedRepository;
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
    );

    await _historyRepository.save(history);

    final operations = <CalendarSyncOperationResult>[];
    final failedOperations = <FailedSyncOperation>[];
    var inserted = 0;
    var updated = 0;
    var deleted = 0;
    var failed = 0;

    Future<void> executeDelete(CalendarDeleteOperation operation) async {
      final result = await _retry(
        type: CalendarSyncOperationType.delete,
        referenceId: operation.eventId,
        operation: () => _gateway.delete(
          eventId: operation.eventId,
          calendarId: operation.calendarId,
        ),
      );
      operations.add(result);
      if (!result.success) {
        failedOperations.add(
          FailedSyncOperation(
            historyId: historyId,
            type: CalendarSyncOperationType.delete,
            referenceId: operation.eventId,
            attempts: maxAttempts,
            eventId: operation.eventId,
            calendarId: operation.calendarId,
            message: result.message,
          ),
        );
      }
      result.success ? deleted++ : failed++;
    }

    for (final operation in plan.deletes.where(
      (operation) => operation.beforeWrites,
    )) {
      await executeDelete(operation);
    }

    final insertReconciler = CalendarSyncInsertReconciler(_gateway);
    for (final command in plan.inserts) {
      final attempt = await _retryInsert(command, insertReconciler);
      final result = attempt.result;
      operations.add(result);
      if (!result.success) {
        failedOperations.add(
          FailedSyncOperation(
            historyId: historyId,
            type: CalendarSyncOperationType.insert,
            referenceId: command.syncId,
            attempts: attempt.attempts,
            command: command,
            message: result.message,
          ),
        );
      }
      result.success ? inserted++ : failed++;
    }

    for (final operation in plan.updates) {
      final result = await _retry(
        type: CalendarSyncOperationType.update,
        referenceId: operation.command.syncId,
        operation: () => _gateway.update(
          eventId: operation.eventId,
          command: operation.command,
        ),
      );
      operations.add(result);
      if (!result.success) {
        failedOperations.add(
          FailedSyncOperation(
            historyId: historyId,
            type: CalendarSyncOperationType.update,
            referenceId: operation.command.syncId,
            attempts: maxAttempts,
            command: operation.command,
            eventId: operation.eventId,
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

    return ResilientCalendarSyncResult(
      historyEntry: history,
      operations: operations,
    );
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
                providerEventId:
                    existing.eventId.isEmpty ? null : existing.eventId,
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
          providerEventId: value is ManagedCalendarEvent && value.eventId.isNotEmpty
              ? value.eventId
              : null,
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
    );
  }
}

class _RetryInsertResult {
  const _RetryInsertResult({
    required this.result,
    required this.attempts,
  });

  final CalendarSyncOperationResult result;
  final int attempts;
}
