import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_day.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_assignment.dart';
import 'package:phakphum_calendar/domain/entities/shift_type.dart';
import 'package:phakphum_calendar/core/di/app_dependencies.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_command.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/failed_sync_operation.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/failed_sync_repository.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_gateway.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/managed_calendar_event.dart';
import 'package:phakphum_calendar/features/history/domain/sync_history_entry.dart';
import 'package:phakphum_calendar/features/history/domain/sync_history_repository.dart';
import 'package:phakphum_calendar/features/shift_exchange/application/shift_transaction_calendar_sync_mapper.dart';
import 'package:phakphum_calendar/features/shift_exchange/infrastructure/shift_transaction_api_client.dart';
import 'package:phakphum_calendar/features/shift_exchange/presentation/widgets/shift_transaction_history_panel.dart';

void main() {
  final date = DateTime(2026, 11, 18);
  final shift = ShiftType(
    id: 'morning',
    code: 'M',
    name: 'Morning',
    color: 0,
    startTime: const Duration(hours: 8),
    endTime: const Duration(hours: 16),
    workingHours: 8,
  );
  final bob = Employee(
    id: 'legacy:B',
    employeeCode: 'B',
    firstName: 'Bob',
    lastName: '',
    nickname: '',
    department: const Department(id: 'D', code: 'D', name: 'Department'),
    position: 'Staff',
  );
  final schedule = Schedule(
    id: 'schedule-1',
    name: 'November roster',
    months: [
      ScheduleMonth.empty(date).replaceDay(
        ScheduleDay(
          date: date,
          assignments: [ShiftAssignment(employee: bob, shift: shift)],
        ),
      ),
    ],
  );

  Map<String, dynamic> transactionJson({
    String syncStatus = 'not_started',
    int version = 1,
  }) => {
    'id': '11111111-1111-4111-8111-111111111111',
    'mode': 'personal',
    'type': 'give_up',
    'status': 'approved',
    'sync_status': syncStatus,
    'version': version,
    'created_at': '2026-11-18T00:00:00Z',
    'updated_at': '2026-11-18T00:00:00Z',
    'organization_id': null,
    'participants': [
      {
        'employee_id': 'A',
        'role': 'requester',
        'name': 'Alice',
        'confirmed_at': '2026-11-18T00:10:00Z',
        'is_current_user': true,
      },
      {
        'employee_id': 'B',
        'role': 'recipient',
        'name': 'Bob',
        'confirmed_at': '2026-11-18T00:11:00Z',
        'is_current_user': false,
      },
    ],
    'transfers': [
      {
        'transfer_key': 'transfer-1',
        'shift_id': 'source-shift-identity',
        'from_employee_id': 'A',
        'to_employee_id': 'B',
        'shift_code': 'M',
        'starts_at': date.add(const Duration(hours: 8)).toIso8601String(),
        'ends_at': date.add(const Duration(hours: 16)).toIso8601String(),
        'purpose': 'give_up',
        'fulfilled_at': null,
      },
    ],
    'timeline': [],
  };

  testWidgets(
    'approved shift transfer stays read-only until confirmation, then syncs and records read-back Event ID',
    (tester) async {
      final gateway = _FakeCalendarGateway();
      final dependencies = AppDependencies(
        scheduleRules: const [],
        syncHistoryRepository: _MemorySyncHistoryRepository(),
        failedSyncRepository: _MemoryFailedSyncRepository(),
      );
      final mapper = const ShiftTransactionCalendarSyncMapper();
      final transferSnapshot = ShiftTransactionSnapshot.fromJson(
        transactionJson(),
      );
      final transferSyncIds = mapper.map(
        schedule: schedule,
        transaction: transferSnapshot,
      );

      var current = transactionJson();
      final postPaths = <String>[];
      final apiClient = ShiftTransactionApiClient(
        baseUrl: 'https://calendar.example.test',
        idTokenProvider: () async => 'test-token',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'data': [current]}), 200);
          }
          postPaths.add(request.url.path);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path.endsWith('/calendar-sync/start')) {
            expect(body['preview_confirmed'], isTrue);
            current = transactionJson(syncStatus: 'pending', version: 2);
            gateway.syncStarted = true;
            return http.Response(jsonEncode({'data': current}), 200);
          }
          if (request.url.path.endsWith('/calendar-sync/complete')) {
            expect(gateway.writeCount, 1);
            expect(body['calendar_event_ids'], ['provider-event-1']);
            current = transactionJson(syncStatus: 'synced', version: 3);
            return http.Response(jsonEncode({'data': current}), 200);
          }
          return http.Response('Not found', 404);
        }),
      );
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Scaffold(
            body: ShiftTransactionHistoryPanel(
              apiClient: apiClient,
              onSyncTransaction: (transaction) async {
                final workflow = dependencies.createShiftCalendarWorkflowController(gateway);
                await workflow.prepareSchedule(schedule);
                final preparation = workflow.schedulePreparation!;
                expect(gateway.writeCount, 0);
                final confirmed = await showDialog<bool>(
                  context: navigatorKey.currentContext!,
                  builder: (context) => AlertDialog(
                    title: const Text('Review Calendar preview'),
                    content: Text(
                      'Insert ${preparation.diff.toAdd.length} · '
                      'Update ${preparation.diff.toUpdate.length} · '
                      'Delete ${preparation.diff.toDelete.length}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel preview'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Confirm and sync'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) {
                  workflow.dispose();
                  return;
                }

                try {
                  await apiClient.startCalendarSync(
                    transaction.id,
                    previewConfirmed: true,
                  );
                  await workflow.synchronize();
                  final result = workflow.lastResult!;
                  expect(result.hasFailures, isFalse);
                  final verification = dependencies.createShiftCalendarWorkflowController(gateway);
                  try {
                    await verification.prepareSchedule(schedule);
                    final readBack = verification.schedulePreparation!;
                    final eventIds = [
                      for (final syncId in transferSyncIds)
                        readBack.existingEventIdsBySyncId[syncId]!,
                    ];
                    expect(eventIds, ['provider-event-1']);
                    expect(
                      result.operations.single.providerEventId,
                      eventIds.single,
                    );
                    await apiClient.completeCalendarSync(
                      transaction.id,
                      calendarEventIds: eventIds,
                    );
                  } finally {
                    verification.dispose();
                  }
                } finally {
                  workflow.dispose();
                }
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Give up · approved'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview & sync Calendar'));
      await tester.pumpAndSettle();

      expect(find.text('Review Calendar preview'), findsOneWidget);
      expect(gateway.writeCount, 0);
      expect(postPaths, isEmpty);

      await tester.tap(find.text('Confirm and sync'));
      await tester.pumpAndSettle();

      expect(gateway.syncStarted, isTrue);
      expect(gateway.writeCount, 1);
      expect(postPaths, [
        '/api/v1/shift-transactions/11111111-1111-4111-8111-111111111111/calendar-sync/start',
        '/api/v1/shift-transactions/11111111-1111-4111-8111-111111111111/calendar-sync/complete',
      ]);
      expect(current['sync_status'], 'synced');
      apiClient.close();
    },
  );
}

class _FakeCalendarGateway implements CalendarSyncGateway {
  final List<ManagedCalendarEvent> events = [];
  int writeCount = 0;
  bool syncStarted = false;

  @override
  Future<ManagedCalendarEvent> insert(CalendarSyncCommand command) async {
    expect(syncStarted, isTrue, reason: 'Calendar writes must follow API sync-start after explicit confirmation.');
    writeCount++;
    final event = ManagedCalendarEvent(
      eventId: 'provider-event-1',
      syncId: command.syncId,
      title: command.title,
      start: command.start,
      end: command.end,
      description: command.description,
      colorId: command.colorId,
    );
    events.add(event);
    return event;
  }

  @override
  Future<ManagedCalendarEvent> update({
    required String eventId,
    required CalendarSyncCommand command,
  }) async {
    expect(syncStarted, isTrue);
    writeCount++;
    final event = ManagedCalendarEvent(
      eventId: eventId,
      syncId: command.syncId,
      title: command.title,
      start: command.start,
      end: command.end,
      description: command.description,
      colorId: command.colorId,
    );
    events.removeWhere((item) => item.eventId == eventId);
    events.add(event);
    return event;
  }

  @override
  Future<void> delete({
    required String eventId,
    String calendarId = 'primary',
  }) async {
    expect(syncStarted, isTrue);
    writeCount++;
    events.removeWhere((item) => item.eventId == eventId);
  }

  @override
  Future<List<ManagedCalendarEvent>> listManagedEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    String calendarId = 'primary',
  }) async => [
    for (final event in events)
      if (!event.start.isBefore(timeMin) && event.start.isBefore(timeMax))
        event,
  ];
}

class _MemorySyncHistoryRepository implements SyncHistoryRepository {
  final Map<String, SyncHistoryEntry> entries = {};

  @override
  Future<SyncHistoryEntry?> findById(String id) async => entries[id];

  @override
  Future<List<SyncHistoryEntry>> list({int limit = 100}) async =>
      entries.values.take(limit).toList(growable: false);

  @override
  Future<void> save(SyncHistoryEntry entry) async {
    entries[entry.id] = entry;
  }
}

class _MemoryFailedSyncRepository implements FailedSyncRepository {
  final Map<String, List<FailedSyncOperation>> operations = {};

  @override
  Future<void> replaceForHistory(
    String historyId,
    List<FailedSyncOperation> next,
  ) async {
    operations[historyId] = List.unmodifiable(next);
  }

  @override
  Future<List<FailedSyncOperation>> listForHistory(String historyId) async =>
      operations[historyId] ?? const [];

  @override
  Future<void> clearHistory(String historyId) async {
    operations.remove(historyId);
  }
}
