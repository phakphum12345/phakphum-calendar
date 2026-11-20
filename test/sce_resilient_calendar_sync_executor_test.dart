import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/calendar_engine/application/calendar_sync_plan.dart';
import 'package:phakphum_calendar/features/calendar_engine/application/resilient_calendar_sync_executor.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_command.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_gateway.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/managed_calendar_event.dart';
import 'package:phakphum_calendar/features/history/domain/sync_history_entry.dart';
import 'package:phakphum_calendar/features/history/infrastructure/in_memory_sync_history_repository.dart';

class FlakyCalendarGateway implements CalendarSyncGateway {
  int insertAttempts = 0;

  @override
  Future<void> delete({
    required String eventId,
    String calendarId = 'primary',
  }) async {}

  @override
  Future<ManagedCalendarEvent> insert(CalendarSyncCommand command) async {
    insertAttempts++;
    if (insertAttempts == 1) {
      throw StateError('temporary failure');
    }
    return ManagedCalendarEvent(
      eventId: 'event-1',
      syncId: command.syncId,
      title: command.title,
      start: command.start,
      end: command.end,
    );
  }

  @override
  Future<List<ManagedCalendarEvent>> listManagedEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    String calendarId = 'primary',
  }) async => const [];

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

class AmbiguousInsertCalendarGateway implements CalendarSyncGateway {
  final events = <ManagedCalendarEvent>[];
  int insertAttempts = 0;

  @override
  Future<void> delete({
    required String eventId,
    String calendarId = 'primary',
  }) async {}

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
    if (insertAttempts == 1) {
      throw StateError('connection lost after provider accepted insert');
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
  test('retries a temporary failure and records successful history', () async {
    final gateway = FlakyCalendarGateway();
    final historyRepository = InMemorySyncHistoryRepository();
    final executor = ResilientCalendarSyncExecutor(
      gateway: gateway,
      historyRepository: historyRepository,
      maxAttempts: 2,
    );

    final start = DateTime(2026, 8, 4, 8);
    final end = DateTime(2026, 8, 4, 16);

    final result = await executor.execute(
      CalendarSyncPlan(
        inserts: [
          CalendarSyncCommand(
            syncId: 'sync-1',
            title: 'ER เช้า',
            start: start,
            end: end,
          ),
        ],
        updates: const [],
        deletes: const [],
      ),
    );

    expect(gateway.insertAttempts, 2);
    expect(result.hasFailures, isFalse);
    expect(result.historyEntry.status, SyncHistoryStatus.success);
    expect(result.historyEntry.inserted, 1);
    expect(result.operations.single.providerEventId, 'event-1');
  });
  test(
    'reconciles an insert accepted by the provider before its response is lost',
    () async {
      final gateway = AmbiguousInsertCalendarGateway();
      final historyRepository = InMemorySyncHistoryRepository();
      final executor = ResilientCalendarSyncExecutor(
        gateway: gateway,
        historyRepository: historyRepository,
        maxAttempts: 2,
      );
      final start = DateTime(2026, 11, 20, 8);
      final end = DateTime(2026, 11, 20, 16);

      final result = await executor.execute(
        CalendarSyncPlan(
          inserts: [
            CalendarSyncCommand(
              syncId: 'sync-ambiguous-1',
              title: 'ER เช้า',
              start: start,
              end: end,
            ),
          ],
          updates: const [],
          deletes: const [],
        ),
      );

      expect(gateway.insertAttempts, 1);
      expect(gateway.events, hasLength(1));
      expect(result.hasFailures, isFalse);
      expect(result.historyEntry.status, SyncHistoryStatus.success);
      expect(result.historyEntry.inserted, 1);
      expect(result.operations.single.providerEventId, 'event-1');
    },
  );
}
