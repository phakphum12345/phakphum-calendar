import 'package:flutter_test/flutter_test.dart';

import 'package:phakphum_calendar/features/calendar_engine/application/calendar_sync_plan.dart';
import 'package:phakphum_calendar/features/calendar_engine/application/resilient_calendar_sync_executor.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_command.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_coordination_gateway.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_gateway.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_operation_result.dart';
import 'package:phakphum_calendar/features/calendar_engine/application/resume_sync_service.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/failed_sync_operation.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/failed_sync_repository.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/managed_calendar_event.dart';
import 'package:phakphum_calendar/features/history/domain/sync_history_entry.dart';
import 'package:phakphum_calendar/features/history/domain/sync_history_repository.dart';

void main() {
  test('coordinates every provider mutation and releases the lease', () async {
    final coordination = _FakeCoordinationGateway();
    final history = _MemoryHistoryRepository();
    final failed = _MemoryFailedSyncRepository();
    final executor = ResilientCalendarSyncExecutor(
      gateway: _FakeCalendarGateway(),
      historyRepository: history,
      failedRepository: failed,
      coordinationGateway: coordination,
    );
    final command = CalendarSyncCommand(
      syncId: 'stable-sync-id',
      title: 'OPD',
      start: DateTime(2026, 11, 26, 8),
      end: DateTime(2026, 11, 26, 16),
    );

    final result = await executor.execute(
      CalendarSyncPlan(
        inserts: [command],
        updates: const [],
        deletes: const [],
        scheduleId: 'schedule-1',
        calendarId: 'primary',
      ),
    );

    expect(result.historyEntry.status, SyncHistoryStatus.success);
    expect(result.operations.single.success, isTrue);
    expect(coordination.recorded.single.operationType, 'insert');
    expect(
      coordination.recorded.single.payloadHash,
      matches(RegExp(r'^[a-f0-9]{64}$')),
    );
    expect(coordination.updates.map((value) => value.status), [
      'running',
      'succeeded',
    ]);
    expect(coordination.updates.last.providerEventId, 'provider-event-1');
    expect(coordination.released.single.status, 'success');
    expect(coordination.calls.first, 'acquire:primary:schedule-1');
    expect(coordination.calls.last, 'release:success');
  });

  test(
    'coordinates resumed operations under the original Schedule lease',
    () async {
      final history = _MemoryHistoryRepository();
      history.entries['history-1'] = SyncHistoryEntry(
        id: 'history-1',
        startedAt: DateTime(2026, 11, 26, 8),
        status: SyncHistoryStatus.failure,
        inserted: 0,
        updated: 0,
        deleted: 0,
        failed: 1,
        scheduleId: 'schedule-1',
      );
      final command = CalendarSyncCommand(
        syncId: 'resume-sync-id',
        title: 'OPD',
        start: DateTime(2026, 11, 26, 8),
        end: DateTime(2026, 11, 26, 16),
      );
      final failed = _MemoryFailedSyncRepository([
        FailedSyncOperation(
          historyId: 'history-1',
          type: CalendarSyncOperationType.insert,
          referenceId: command.syncId,
          attempts: 1,
          command: command,
        ),
      ]);
      final coordination = _FakeCoordinationGateway();
      final result = await ResumeSyncService(
        gateway: _FakeCalendarGateway(),
        historyRepository: history,
        failedRepository: failed,
        coordinationGateway: coordination,
      ).resume('history-1');

      expect(result.completed, isTrue);
      expect(result.historyEntry.scheduleId, 'schedule-1');
      expect(failed.operations, isEmpty);
      expect(coordination.updates.map((value) => value.status), [
        'running',
        'succeeded',
      ]);
      expect(coordination.released.single.status, 'success');
    },
  );

  test('does not call Calendar when lease acquisition is rejected', () async {
    final coordination = _FakeCoordinationGateway()..rejectAcquire = true;
    final gateway = _FakeCalendarGateway();
    final executor = ResilientCalendarSyncExecutor(
      gateway: gateway,
      historyRepository: _MemoryHistoryRepository(),
      coordinationGateway: coordination,
    );

    await expectLater(
      executor.execute(
        CalendarSyncPlan(
          inserts: [
            CalendarSyncCommand(
              syncId: 'stable-sync-id',
              title: 'OPD',
              start: DateTime(2026, 11, 26, 8),
              end: DateTime(2026, 11, 26, 16),
            ),
          ],
          updates: const [],
          deletes: const [],
          scheduleId: 'schedule-1',
        ),
      ),
      throwsStateError,
    );
    expect(gateway.insertCount, 0);
    expect(coordination.calls, ['acquire:primary:schedule-1']);
  });
}

class _FakeCalendarGateway implements CalendarSyncGateway {
  int insertCount = 0;

  @override
  Future<ManagedCalendarEvent> insert(CalendarSyncCommand command) async {
    insertCount++;
    return ManagedCalendarEvent(
      eventId: 'provider-event-1',
      syncId: command.syncId,
      title: command.title,
      start: command.start,
      end: command.end,
    );
  }

  @override
  Future<ManagedCalendarEvent> update({
    required String eventId,
    required CalendarSyncCommand command,
  }) async => throw UnimplementedError();

  @override
  Future<void> delete({
    required String eventId,
    String calendarId = 'primary',
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ManagedCalendarEvent>> listManagedEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    String calendarId = 'primary',
  }) async => const [];
}

class _FakeCoordinationGateway implements CalendarSyncCoordinationGateway {
  final calls = <String>[];
  final recorded = <({String operationType, String payloadHash, Map<String, Object?> payload})>[];
  final updates = <({String status, String? providerEventId})>[];
  final released = <({String status})>[];
  bool rejectAcquire = false;

  final lease = CalendarSyncLease(
    runId: '00000000-0000-4000-8000-000000000001',
    calendarId: 'primary',
    scheduleId: 'schedule-1',
    leaseToken: List.filled(64, 'a').join(),
    expiresAt: DateTime(2026, 11, 26, 12),
  );

  @override
  Future<CalendarSyncLease> acquire({
    required String calendarId,
    required String scheduleId,
  }) async {
    calls.add('acquire:$calendarId:$scheduleId');
    if (rejectAcquire) throw StateError('lease rejected');
    return lease;
  }

  @override
  Future<void> heartbeat(CalendarSyncLease lease) async {
    calls.add('heartbeat');
  }

  @override
  Future<void> recordOperation({
    required CalendarSyncLease lease,
    required String operationKey,
    required String operationType,
    required String payloadHash,
    required Map<String, Object?> operationPayload,
  }) async {
    calls.add('record');
    recorded.add((operationType: operationType, payloadHash: payloadHash, payload: operationPayload));
  }

  @override
  Future<void> updateOperation({
    required CalendarSyncLease lease,
    required String operationKey,
    required String status,
    required int attemptCount,
    String? providerEventId,
    String? lastError,
  }) async {
    calls.add('update:$status');
    updates.add((status: status, providerEventId: providerEventId));
  }

  @override
  Future<void> release({
    required CalendarSyncLease lease,
    required String status,
  }) async {
    calls.add('release:$status');
    released.add((status: status));
  }
}

class _MemoryHistoryRepository implements SyncHistoryRepository {
  final entries = <String, SyncHistoryEntry>{};

  @override
  Future<SyncHistoryEntry?> findById(String id) async => entries[id];

  @override
  Future<List<SyncHistoryEntry>> list({int limit = 100}) async =>
      entries.values.take(limit).toList();

  @override
  Future<void> save(SyncHistoryEntry entry) async {
    entries[entry.id] = entry;
  }
}

class _MemoryFailedSyncRepository implements FailedSyncRepository {
  _MemoryFailedSyncRepository([this.operations = const []]);

  List<FailedSyncOperation> operations;

  @override
  Future<void> clearHistory(String historyId) async {
    operations = [];
  }

  @override
  Future<List<FailedSyncOperation>> listForHistory(String historyId) async =>
      operations;

  @override
  Future<void> replaceForHistory(
    String historyId,
    List<FailedSyncOperation> operations,
  ) async {
    this.operations = List.of(operations);
  }
}
