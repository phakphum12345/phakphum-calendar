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
