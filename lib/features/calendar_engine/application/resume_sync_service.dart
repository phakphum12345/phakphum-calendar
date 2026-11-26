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

  /// Rebuilds a local recovery queue from the owner-scoped durable ledger.
  ///
  /// This method is explicit; it is never invoked automatically at startup.
  /// Provider mutations still pass through the normal lease, ETag and
  /// idempotency checks in [resume].
  Future<ResumeSyncResult> recoverRun(String runId) async {
    final coordination = coordinationGateway;
    if (coordination == null) {
      throw StateError('Durable Calendar recovery requires a configured backend.');
    }

    final run = await coordination.getRun(runId);
    final ledger = await coordination.listOperations(runId);
    final succeeded = ledger.where((item) => item.status == 'succeeded');
    final pending = ledger.where((item) => item.status != 'succeeded').toList();
    final recovered = pending
        .map((item) => _failedOperationFromLedger(run, item))
        .toList(growable: false);

    final history = SyncHistoryEntry(
      id: run.runId,
      startedAt: run.startedAt,
      status: recovered.isEmpty
          ? SyncHistoryStatus.success
          : SyncHistoryStatus.running,
      inserted: succeeded.where((item) => item.operationType == 'insert').length,
      updated: succeeded.where((item) => item.operationType == 'update').length,
      deleted: succeeded.where((item) => item.operationType == 'delete').length,
      failed: recovered.length,
      finishedAt: recovered.isEmpty ? (run.finishedAt ?? DateTime.now()) : null,
      message: recovered.isEmpty
          ? 'All durable Calendar operations are already complete.'
          : 'Recovered ${recovered.length} unfinished operation(s) from the durable ledger.',
      scheduleId: run.scheduleId,
    );

    await _historyRepository.save(history);
    await _failedRepository.replaceForHistory(run.runId, recovered);

    if (recovered.isEmpty) {
      return ResumeSyncResult(historyEntry: history, operations: const []);
    }
    return resume(run.runId);
  }

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
      if (original.scheduleId.trim().isEmpty ||
          original.scheduleId == 'unknown') {
        throw StateError(
          'Cannot resume server-coordinated sync without the original Schedule ID.',
        );
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
            operationPayload: _operationPayload(item),
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
                throw StateError(
                  'Cannot resume a stale Calendar update without its original provider ETag.',
                );
              }
              await (_gateway as ConditionalCalendarSyncGateway)
                  .updateConditionally(
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
                throw StateError(
                  'Cannot resume a stale Calendar delete without its original provider ETag.',
                );
              }
              await (_gateway as ConditionalCalendarSyncGateway)
                  .deleteConditionally(
                    eventId: eventId,
                    calendarId: item.calendarId,
                    expectedEtag: etag,
                    expectedSyncId: syncId,
                  );
            } else {
              await _gateway.delete(
                eventId: eventId,
                calendarId: item.calendarId,
              );
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
              lastError: 'resume_operation_exception',
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

FailedSyncOperation _failedOperationFromLedger(
  CalendarSyncRunRecord run,
  CalendarSyncOperationRecord record,
) {
  final matchingTypes = CalendarSyncOperationType.values
      .where((value) => value.name == record.operationType)
      .toList(growable: false);
  if (matchingTypes.isEmpty ||
      !['prepared', 'running', 'failed'].contains(record.status)) {
    throw FormatException(
      'Durable operation ${record.operationKey} has an unsupported recovery state.',
    );
  }

  final type = matchingTypes.single;
  final payload = record.operationPayload;
  String requiredString(String key) {
    final value = payload[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'Durable operation ${record.operationKey} is missing $key.',
      );
    }
    return value;
  }

  final command = switch (type) {
    CalendarSyncOperationType.insert || CalendarSyncOperationType.update =>
      CalendarSyncCommand(
        syncId: requiredString('sync_id'),
        title: requiredString('title'),
        start: DateTime.parse(requiredString('start')),
        end: DateTime.parse(requiredString('end')),
        description: payload['description']?.toString(),
        colorId: payload['color_id']?.toString(),
        calendarId: payload['calendar_id']?.toString() ?? run.calendarId,
      ),
    CalendarSyncOperationType.delete => null,
  };
  final eventId = payload['event_id']?.toString();
  final referenceId = switch (type) {
    CalendarSyncOperationType.insert || CalendarSyncOperationType.update =>
      command!.syncId,
    CalendarSyncOperationType.delete =>
      eventId == null || eventId.isEmpty
          ? throw FormatException('Delete operation is missing event_id.')
          : eventId,
  };

  return FailedSyncOperation(
    historyId: run.runId,
    type: type,
    referenceId: referenceId,
    attempts: record.attemptCount,
    command: command,
    eventId: eventId,
    calendarId: payload['calendar_id']?.toString() ?? run.calendarId,
    message: record.lastError,
    expectedEtag: payload['expected_etag']?.toString(),
    expectedSyncId: payload['expected_sync_id']?.toString(),
  );
}

String _ledgerOperationKey(CalendarSyncOperationType type, String referenceId) {
  final digest = sha256.convert(utf8.encode(referenceId));
  return '${type.name}:$digest';
}

Map<String, Object?> _operationPayload(FailedSyncOperation item) {
  final command = item.command;
  if (item.type == CalendarSyncOperationType.insert) {
    if (command == null) throw StateError('Insert command missing.');
    return _commandPayload(command);
  }
  if (item.type == CalendarSyncOperationType.update) {
    if (command == null) throw StateError('Update command missing.');
    return {
      'event_id': item.eventId,
      'expected_etag': item.expectedEtag,
      'expected_sync_id': item.expectedSyncId,
      ..._commandPayload(command),
    };
  }
  return {
    'event_id': item.eventId,
    'calendar_id': item.calendarId,
    'expected_etag': item.expectedEtag,
    'expected_sync_id': item.expectedSyncId,
  };
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

String _payloadHash(FailedSyncOperation item) {
  return sha256.convert(utf8.encode(_canonicalJson(_operationPayload(item)))).toString();
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
