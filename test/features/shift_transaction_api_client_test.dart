import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:phakphum_calendar/features/shift_exchange/infrastructure/shift_transaction_api_client.dart';
import 'package:phakphum_calendar/features/shift_exchange/presentation/widgets/shift_transaction_history_panel.dart';

void main() {
  final transaction = <String, dynamic>{
    'id': 'transaction-1',
    'mode': 'personal',
    'type': 'give_up',
    'status': 'approved',
    'sync_status': 'not_started',
    'version': 2,
    'created_at': '2026-11-17T01:00:00Z',
    'updated_at': '2026-11-17T02:00:00Z',
    'organization_id': null,
    'participants': [
      {'employee_id': 'A', 'role': 'requester', 'name': 'Alice'},
      {'employee_id': 'B', 'role': 'recipient', 'name': 'Bob'},
    ],
    'transfers': [
      {
        'transfer_key': 'transfer-1',
        'shift_id': 'shift-1',
        'from_employee_id': 'A',
        'to_employee_id': 'B',
        'shift_code': 'morning',
        'starts_at': '2026-11-18T01:00:00Z',
        'ends_at': '2026-11-18T09:00:00Z',
        'purpose': 'give_up',
        'fulfilled_at': null,
      },
    ],
    'calendar_events': [
      {
        'transfer_key': 'transfer-1',
        'provider': 'google',
        'calendar_id': 'primary',
        'event_id': 'event-1',
        'etag': 'etag-1',
      },
    ],
    'sync_attempts': [
      {
        'attempt_number': 1,
        'status': 'completed',
      },
    ],
    'timeline': [
      {
        'id': 1,
        'event_type': 'created',
        'transaction_version': 1,
        'actor_name': 'Alice',
        'data': {'mode': 'personal'},
        'occurred_at': '2026-11-17T01:00:00Z',
      },
    ],
  };

  test('loads authenticated transaction history and preserves server timeline', () async {
    Uri? requestedUri;
    String? authorization;
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'google-id-token',
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        authorization = request.headers['Authorization'];
        return http.Response(jsonEncode({'data': [transaction]}), 200);
      }),
    );

    final result = await client.listTransactions(
      mode: 'personal',
      month: '2026-11',
    );

    expect(requestedUri!.path, '/api/v1/shift-transactions');
    expect(requestedUri!.queryParameters, {'mode': 'personal', 'month': '2026-11'});
    expect(authorization, 'Bearer google-id-token');
    expect(result, hasLength(1));
    expect(result.single.id, 'transaction-1');
    expect(result.single.timeline.single['event_type'], 'created');
    expect(result.single.calendarEvents.single['event_id'], 'event-1');
    expect(result.single.calendarEvents.single['etag'], 'etag-1');
    expect(result.single.syncAttempts.single['attempt_number'], 1);
    expect(result.single.participants.first.containsKey('account_subject'), isFalse);
    client.close();
  });

  test('loads a single transaction using its encoded ID', () async {
    Uri? requestedUri;
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test/',
      idTokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(jsonEncode({'data': transaction}), 200);
      }),
    );

    final result = await client.getTransaction('transaction-1');

    expect(requestedUri!.path, '/api/v1/shift-transactions/transaction-1');
    expect(result.transfers.single['shift_code'], 'morning');
    client.close();
  });

  test('creates transactions with idempotency and exposes lifecycle actions', () async {
    final requests = <http.Request>[];
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'google-id-token',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'data': transaction}), 200);
      }),
    );

    await client.createTransaction(
      mode: 'personal',
      type: 'give_up',
      participants: const [
        {'account_subject': 'alice', 'employee_id': 'A', 'role': 'requester'},
        {'account_subject': 'bob', 'employee_id': 'B', 'role': 'recipient'},
      ],
      transfers: const [
        {
          'id': 'transfer-1',
          'shift_id': 'shift-1',
          'from_employee_id': 'A',
          'to_employee_id': 'B',
          'shift_code': 'morning',
          'starts_at': '2026-11-18T08:00:00Z',
          'ends_at': '2026-11-18T16:00:00Z',
          'purpose': 'give_up',
        },
      ],
      idempotencyKey: 'request-unique-001',
    );
    await client.confirmTransaction('transaction-1');
    await client.rejectTransaction('transaction-1', reason: 'Unavailable');
    await client.approveTransaction('transaction-1', note: 'Approved');
    await client.rejectByApprover('transaction-1', reason: 'Policy');
    await client.cancelTransaction('transaction-1');
    await client.startCalendarSync('transaction-1', previewConfirmed: true);
    await client.completeCalendarSync(
      'transaction-1',
      calendarEventIds: const ['event-1'],
    );
    await client.completeCalendarSyncWithEvents(
      'transaction-1',
      calendarEvents: const [
        ShiftTransactionCalendarEventMapping(
          transferId: 'transfer-1',
          provider: 'google',
          calendarId: 'primary',
          eventId: 'provider-event-1',
          etag: 'etag-1',
        ),
      ],
    );
    await client.failCalendarSync('transaction-1', reason: 'Retry later');
    await client.fulfillTransfer('transaction-1', transferId: 'transfer-1');

    expect(requests, hasLength(11));
    expect(requests.first.method, 'POST');
    expect(requests.first.headers['Authorization'], 'Bearer google-id-token');
    expect(requests.first.headers['Idempotency-Key'], 'request-unique-001');
    expect(jsonDecode(requests.first.body), containsPair('type', 'give_up'));
    expect(requests.map((request) => request.url.path), [
      '/api/v1/shift-transactions',
      '/api/v1/shift-transactions/transaction-1/confirm',
      '/api/v1/shift-transactions/transaction-1/reject',
      '/api/v1/shift-transactions/transaction-1/approve',
      '/api/v1/shift-transactions/transaction-1/reject-by-approver',
      '/api/v1/shift-transactions/transaction-1/cancel',
      '/api/v1/shift-transactions/transaction-1/calendar-sync/start',
      '/api/v1/shift-transactions/transaction-1/calendar-sync/complete',
      '/api/v1/shift-transactions/transaction-1/calendar-sync/complete',
      '/api/v1/shift-transactions/transaction-1/calendar-sync/fail',
      '/api/v1/shift-transactions/transaction-1/fulfill',
    ]);
    expect(jsonDecode(requests[6].body), {'preview_confirmed': true});
    expect(jsonDecode(requests[7].body), {'calendar_event_ids': ['event-1']});
    expect(jsonDecode(requests[8].body), {
      'calendar_events': [
        {
          'transfer_id': 'transfer-1',
          'provider': 'google',
          'calendar_id': 'primary',
          'event_id': 'provider-event-1',
          'etag': 'etag-1',
        },
      ],
    });
    expect(jsonDecode(requests[10].body), {'transfer_id': 'transfer-1'});
    client.close();
  });

  test('rejects transaction creation without an idempotency key', () async {
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'token',
      httpClient: MockClient((request) async => http.Response('{}', 200)),
    );

    expect(
      () => client.createTransaction(
        mode: 'personal',
        type: 'give_up',
        participants: const [],
        transfers: const [],
        idempotencyKey: ' ',
      ),
      throwsArgumentError,
    );
    client.close();
  });

  test('loads current account, organizations, and active organization members', () async {
    final requests = <http.Request>[];
    final responses = <Map<String, dynamic>>[
      {
        'data': {'id': '7', 'email': 'alice@example.com', 'name': 'Alice'},
      },
      {
        'data': [
          {
            'id': 'org-uuid',
            'name': 'Radiology',
            'slug': 'radiology',
            'employee_id': 'A',
            'role': 'owner',
          },
        ],
      },
      {
        'data': [
          {
            'user_id': '7',
            'name': 'Alice',
            'email': 'alice@example.com',
            'employee_id': 'A',
            'role': 'owner',
            'status': 'active',
          },
          {
            'user_id': '8',
            'name': 'Bob',
            'email': 'bob@example.com',
            'employee_id': 'B',
            'role': 'staff',
            'status': 'active',
          },
        ],
      },
    ];
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'google-id-token',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(responses.removeAt(0)), 200);
      }),
    );

    final account = await client.getCurrentUser();
    final organizations = await client.listOrganizations();
    final members = await client.listOrganizationMembers('org-uuid');

    expect(account.id, '7');
    expect(account.email, 'alice@example.com');
    expect(organizations.single.employeeId, 'A');
    expect(organizations.single.role, 'owner');
    expect(members.map((member) => member.userId), ['7', '8']);
    expect(members.last.employeeId, 'B');
    expect(members.last.email, 'bob@example.com');
    expect(requests.map((request) => request.url.path), [
      '/api/v1/me',
      '/api/v1/organizations',
      '/api/v1/organizations/org-uuid/members',
    ]);
    expect(
      requests.every((request) => request.headers['Authorization'] == 'Bearer google-id-token'),
      isTrue,
    );
    client.close();
  });

  test('rejects an empty organization ID before making a request', () async {
    var requestCount = 0;
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      client.listOrganizationMembers(' '),
      throwsArgumentError,
    );
    expect(requestCount, 0);
    client.close();
  });

  test('does not make a request without a Google ID token', () async {
    var requestCount = 0;
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => null,
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      client.listTransactions(),
      throwsA(isA<ShiftTransactionApiException>().having(
        (error) => error.statusCode,
        'statusCode',
        401,
      )),
    );
    expect(requestCount, 0);
    client.close();
  });

  test('surfaces server authentication and authorization errors', () async {
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'expired-token',
      httpClient: MockClient((request) async => http.Response(
        jsonEncode({
          'error': {
            'code': 'unauthenticated',
            'message': 'A valid Google ID token is required.',
          },
        }),
        401,
      )),
    );

    await expectLater(
      client.listTransactions(),
      throwsA(isA<ShiftTransactionApiException>().having(
        (error) => error.message,
        'message',
        'A valid Google ID token is required.',
      )),
    );
    client.close();
  });

  test('reports an unconfigured API URL without network access', () async {
    var requestCount = 0;
    final client = ShiftTransactionApiClient(
      baseUrl: '',
      idTokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      client.listTransactions(),
      throwsA(isA<ShiftTransactionApiException>()),
    );
    expect(requestCount, 0);
    client.close();
  });

  testWidgets('does not request transaction history when API URL is unconfigured', (tester) async {
    var tokenRequests = 0;
    final client = ShiftTransactionApiClient(
      baseUrl: '',
      idTokenProvider: () async {
        tokenRequests++;
        return 'token';
      },
      httpClient: MockClient((request) async {
        fail('No HTTP request should be made without an API URL.');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftTransactionHistoryPanel(apiClient: client),
        ),
      ),
    );

    expect(find.text('Transaction history is not configured'), findsOneWidget);
    expect(tokenRequests, 0);
    client.close();
  });

}
