import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:phakphum_calendar/features/shift_exchange/infrastructure/shift_transaction_api_client.dart';
import 'package:phakphum_calendar/features/shift_exchange/presentation/widgets/shift_transaction_history_panel.dart';

Map<String, dynamic> transaction({
  String status = 'pending_response',
  String syncStatus = 'not_started',
  String? organizationId,
  bool currentUser = true,
  String? confirmedAt,
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
      'fulfilled_at': null,
    },
  ],
  'timeline': [],
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
