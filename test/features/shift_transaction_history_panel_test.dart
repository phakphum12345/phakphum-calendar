import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:phakphum_calendar/features/shift_exchange/infrastructure/shift_transaction_api_client.dart';
import 'package:phakphum_calendar/features/shift_exchange/presentation/widgets/shift_transaction_history_panel.dart';
import 'package:phakphum_calendar/models/roster_assignment_timeline.dart';

Map<String, dynamic> transaction({
  String status = 'pending_response',
  String syncStatus = 'not_started',
  String? organizationId,
  bool currentUser = true,
  String? confirmedAt,
  String? fulfilledAt,
  List<Map<String, dynamic>> timeline = const [],
}) => {
  'id': '11111111-1111-4111-8111-111111111111',
  'mode': organizationId == null ? 'personal' : 'organization',
  'type': 'give_up',
  'status': status,
  'sync_status': syncStatus,
  'version': 1,
  'created_at': '2026-11-18T01:00:00Z',
  'updated_at': '2026-11-18T01:00:00Z',
  'organization_id': organizationId,
  'participants': [
    {
      'employee_id': 'A',
      'role': 'requester',
      'name': 'Alice',
      'confirmed_at': confirmedAt,
      'is_current_user': currentUser,
    },
    {
      'employee_id': 'B',
      'role': 'recipient',
      'name': 'Bob',
      'confirmed_at': null,
      'is_current_user': false,
    },
  ],
  'transfers': [
    {
      'transfer_key': 'transfer-1',
      'shift_id': 'shift-1',
      'from_employee_id': 'A',
      'to_employee_id': 'B',
      'shift_code': 'M',
      'starts_at': '2026-11-18T01:00:00Z',
      'ends_at': '2026-11-18T09:00:00Z',
      'purpose': 'give_up',
      'fulfilled_at': fulfilledAt,
    },
  ],
  'timeline': timeline,
};

void main() {
  testWidgets('lets the current participant confirm a pending request', (tester) async {
    final requests = <http.Request>[];
    var getCount = 0;
    final pending = transaction();
    final approved = transaction(
      status: 'approved',
      confirmedAt: '2026-11-18T02:00:00Z',
    );
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          getCount++;
          return http.Response(
            jsonEncode({'data': [getCount == 1 ? pending : approved]}),
            200,
          );
        }
        return http.Response(jsonEncode({'data': approved}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftTransactionHistoryPanel(apiClient: client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give up · pending_response'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(
      requests.where((request) => request.method == 'POST').single.url.path,
      '/api/v1/shift-transactions/11111111-1111-4111-8111-111111111111/confirm',
    );
    expect(getCount, greaterThanOrEqualTo(2));
    expect(find.text('Confirm'), findsNothing);
    client.close();
  });

  testWidgets('offers transaction Calendar preview only through the supplied explicit-confirmation callback', (tester) async {
    final approved = transaction(status: 'approved');
    var previewRequested = false;
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'token',
      httpClient: MockClient((request) async =>
          http.Response(jsonEncode({'data': [approved]}), 200)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftTransactionHistoryPanel(
            apiClient: client,
            onSyncTransaction: (item) async {
              expect(item.id, approved['id']);
              previewRequested = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give up · approved'));
    await tester.pumpAndSettle();
    expect(find.text('Preview & sync Calendar'), findsOneWidget);
    await tester.tap(find.text('Preview & sync Calendar'));
    await tester.pumpAndSettle();
    expect(previewRequested, isTrue);
    client.close();
  });

  testWidgets('shows named transfer ownership, fulfillment and event audit details', (tester) async {
    final completedLeg = transaction(
      status: 'approved',
      syncStatus: 'synced',
      fulfilledAt: '2026-11-18T09:05:00Z',
      timeline: [
        {
          'event_type': 'confirm',
          'transaction_version': 2,
          'actor_name': 'Alice',
          'occurred_at': '2026-11-18T02:00:00Z',
          'data': {'account_confirmed': true},
        },
        {
          'event_type': 'fulfill',
          'transaction_version': 3,
          'actor_name': 'Bob',
          'occurred_at': '2026-11-18T09:05:00Z',
          'data': {'transfer_id': 'transfer-1', 'shift_id': 'shift-1'},
        },
      ],
    );
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'token',
      httpClient: MockClient((request) async =>
          http.Response(jsonEncode({'data': [completedLeg]}), 200)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftTransactionHistoryPanel(apiClient: client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give up · approved'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Alice (A) → Bob (B)'), findsOneWidget);
    expect(find.textContaining('Fulfilled: 2026-11-18T09:05:00Z'), findsOneWidget);
    expect(find.textContaining('Participant confirmed'), findsOneWidget);
    expect(find.textContaining('Transfer: transfer-1 · Shift: shift-1'), findsOneWidget);
    expect(find.textContaining('Bob · 2026-11-18T09:05:00Z'), findsOneWidget);
    client.close();
  });

  testWidgets('shows matching historical roster ownership beside a transfer', (tester) async {
    final item = transaction();
    final start = DateTime.parse('2026-11-18T01:00:00Z').toLocal();
    final end = DateTime.parse('2026-11-18T09:00:00Z').toLocal();
    final timeline = RosterAssignmentTimeline(
      positionKey: 'position-1',
      start: start,
      end: end,
      shiftCode: 'M',
      sheetTitle: 'Main roster',
      rowLabel: 'Morning',
      column: 'B',
      versions: [
        RosterAssignmentVersion(
          revisionId: 'revision-1',
          modifiedAt: DateTime.utc(2026, 11, 1),
          assignedName: 'Alice',
        ),
        RosterAssignmentVersion(
          revisionId: 'revision-2',
          modifiedAt: DateTime.utc(2026, 11, 10),
          assignedName: 'Bob',
        ),
      ],
    );
    final unrelated = RosterAssignmentTimeline(
      positionKey: 'position-2',
      start: start,
      end: end,
      shiftCode: 'N',
      sheetTitle: 'Other roster',
      rowLabel: 'Night',
      column: 'C',
      versions: [
        RosterAssignmentVersion(
          revisionId: 'revision-3',
          modifiedAt: DateTime.utc(2026, 11, 1),
          assignedName: 'Carol',
        ),
        RosterAssignmentVersion(
          revisionId: 'revision-4',
          modifiedAt: DateTime.utc(2026, 11, 10),
          assignedName: 'Dana',
        ),
      ],
    );
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'token',
      httpClient: MockClient((request) async =>
          http.Response(jsonEncode({'data': [item]}), 200)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShiftTransactionHistoryPanel(
              apiClient: client,
              rosterTimelines: {
                timeline.positionKey: timeline,
                unrelated.positionKey: unrelated,
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give up · pending_response'));
    await tester.pumpAndSettle();

    expect(find.text('Roster ownership history'), findsOneWidget);
    expect(find.text('Alice → Bob'), findsOneWidget);
    expect(find.text('Carol → Dana'), findsNothing);

    await tester.tap(find.text('Roster ownership history'));
    await tester.pumpAndSettle();
    expect(find.text('Main roster · Morning · B'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    client.close();
  });

  testWidgets('allows a participant to recover a stalled Calendar sync', (tester) async {
    final pending = transaction(status: 'approved', syncStatus: 'pending');
    final failed = {...pending, 'sync_status': 'failed', 'version': 2};
    final requests = <http.Request>[];
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'data': [pending]}), 200);
        }
        return http.Response(jsonEncode({'data': failed}), 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftTransactionHistoryPanel(apiClient: client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give up · approved'));
    await tester.pumpAndSettle();
    expect(find.text('Reset stalled Calendar sync'), findsOneWidget);
    await tester.tap(find.text('Reset stalled Calendar sync'));
    await tester.pumpAndSettle();
    expect(
      requests.where((request) => request.method == 'POST').single.url.path,
      '/api/v1/shift-transactions/11111111-1111-4111-8111-111111111111/calendar-sync/fail',
    );
    client.close();
  });

  testWidgets('shows organization approval only to an authorized organization manager', (tester) async {
    final requests = <http.Request>[];
    final pendingApproval = transaction(
      status: 'pending_approval',
      organizationId: 'org-uuid',
      currentUser: false,
    );
    final approved = transaction(
      status: 'approved',
      organizationId: 'org-uuid',
      currentUser: false,
    );
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'data': [pendingApproval]}), 200);
        }
        return http.Response(jsonEncode({'data': approved}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftTransactionHistoryPanel(
            apiClient: client,
            approvableOrganizationIds: const {'org-uuid'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give up · pending_approval'));
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(
      requests.where((request) => request.method == 'POST').single.url.path,
      '/api/v1/shift-transactions/11111111-1111-4111-8111-111111111111/approve',
    );
    client.close();
  });
}
