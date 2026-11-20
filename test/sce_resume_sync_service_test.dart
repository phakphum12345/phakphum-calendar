import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/calendar_engine/application/resume_sync_service.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_command.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_gateway.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_operation_result.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/failed_sync_operation.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/failed_sync_repository.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/managed_calendar_event.dart';
import 'package:phakphum_calendar/features/history/domain/sync_history_entry.dart';
import 'package:phakphum_calendar/features/history/infrastructure/in_memory_sync_history_repository.dart';

class _MemoryFailedSyncRepository implements FailedSyncRepository {
  final Map<String, List<FailedSyncOperation>> records = {};

  @override
  Future<void> clearHistory(String historyId) async {
    records.remove(historyId);
  }

  @override
  Future<List<FailedSyncOperation>> listForHistory(String historyId) async {
    return List.unmodifiable(records[historyId] ?? const []);
  }

  @override
  Future<void> replaceForHistory(
    String historyId,
    List<FailedSyncOperation> operations,
  ) async {
    if (operations.isEmpty) {
      records.remove(historyId);
    } else {
      records[historyId] = List.unmodifiable(operations);
    }
  }
}

class _MemoryCalendarGateway implements CalendarSyncGateway {
  final events = <ManagedCalendarEvent>[];
  int insertAttempts = 0;
  bool failAfterInsert = false;

  @override
  Future<void> delete({
    required String eventId,
    String calendarId = 'primary',
  }) async {
    events.removeWhere((event) => event.eventId == eventId);
  }

  @override
  Future<ManagedCalendarEvent> insert(CalendarSyncCommand command) async {
    insertAttempts++;
    final event = ManagedCalendarEvent(
      eventId: 'event-$insertAttempts',
      syncId: command.syncId,
      title: command.title,
      start: command.start,
      end: command.end,
    );
    events.add(event);
    if (failAfterInsert) {
      throw StateError('provider accepted insert but response was lost');
    }
    return event;
  }

  @override
  Future<List<ManagedCalendarEvent>> listManagedEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    String calendarId = 'primary',
  }) async {
    return events
        .where(
          (event) =>
              event.start.isBefore(timeMax) && event.end.isAfter(timeMin),
        )
        .toList(growable: false);
  }

  @override
  Future<ManagedCalendarEvent> update({
    required String eventId,
    required CalendarSyncCommand command,
  }) async {
    return ManagedCalendarEvent(
      eventId: eventId,
      syncId: command.syncId,
      title: command.title,
      start: command.start,
      end: command.end,
    );
  }
}

void main() {
  late InMemorySyncHistoryRepository historyRepository;
  late _MemoryFailedSyncRepository failedRepository;
  late CalendarSyncCommand command;

  setUp(() async {
    historyRepository = InMemorySyncHistoryRepository();
    failedRepository = _MemoryFailedSyncRepository();
    command = CalendarSyncCommand(
      syncId: 'sync-resume-1',
      title: 'ER เช้า',
      start: DateTime(2026, 11, 20, 8),
      end: DateTime(2026, 11, 20, 16),
    );
    await historyRepository.save(
      SyncHistoryEntry(
        id: 'history-1',
        startedAt: DateTime(2026, 11, 20),
        status: SyncHistoryStatus.partialSuccess,
        inserted: 0,
        updated: 0,
        deleted: 0,
        failed: 1,
      ),
    );
    await failedRepository.replaceForHistory('history-1', [
      FailedSyncOperation(
        historyId: 'history-1',
        type: CalendarSyncOperationType.insert,
        referenceId: command.syncId,
        attempts: 2,
        command: command,
      ),
    ]);
  });

  test('resume adopts the event already created by an earlier attempt', () async {
    final gateway = _MemoryCalendarGateway()
      ..events.add(
        ManagedCalendarEvent(
          eventId: 'provider-event-1',
          syncId: command.syncId,
          title: command.title,
          start: command.start,
          end: command.end,
        ),
      );
    final service = ResumeSyncService(
      gateway: gateway,
      historyRepository: historyRepository,
      failedRepository: failedRepository,
    );

    final result = await service.resume('history-1');

    expect(gateway.insertAttempts, 0);
    expect(gateway.events, hasLength(1));
    expect(result.completed, isTrue);
    expect(result.operations.single.providerEventId, 'provider-event-1');
    expect(result.historyEntry.status, SyncHistoryStatus.success);
    expect(result.historyEntry.inserted, 1);
    expect(result.historyEntry.failed, 0);
    expect(await failedRepository.listForHistory('history-1'), isEmpty);
  });

  test('resume reconciles an insert after an ambiguous provider response', () async {
    final gateway = _MemoryCalendarGateway()..failAfterInsert = true;
    final service = ResumeSyncService(
      gateway: gateway,
      historyRepository: historyRepository,
      failedRepository: failedRepository,
    );

    final result = await service.resume('history-1');

    expect(gateway.insertAttempts, 1);
    expect(gateway.events, hasLength(1));
    expect(result.completed, isTrue);
    expect(result.operations.single.providerEventId, 'event-1');
    expect(result.historyEntry.status, SyncHistoryStatus.success);
    expect(result.historyEntry.inserted, 1);
    expect(result.historyEntry.failed, 0);
  });
  test('resume blocks when more than one event has the same sync ID', () async {
    final gateway = _MemoryCalendarGateway()
      ..events.addAll([
        ManagedCalendarEvent(
          eventId: 'duplicate-1',
          syncId: command.syncId,
          title: command.title,
          start: command.start,
          end: command.end,
        ),
        ManagedCalendarEvent(
          eventId: 'duplicate-2',
          syncId: command.syncId,
          title: command.title,
          start: command.start,
          end: command.end,
        ),
      ]);
    final service = ResumeSyncService(
      gateway: gateway,
      historyRepository: historyRepository,
      failedRepository: failedRepository,
    );

    final result = await service.resume('history-1');

    expect(gateway.insertAttempts, 0);
    expect(gateway.events, hasLength(2));
    expect(result.completed, isFalse);
    expect(result.historyEntry.status, SyncHistoryStatus.partialSuccess);
    expect(result.historyEntry.failed, 1);
    expect(await failedRepository.listForHistory('history-1'), hasLength(1));
  });
}
