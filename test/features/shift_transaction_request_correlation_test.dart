import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:phakphum_calendar/features/shift_exchange/infrastructure/shift_transaction_api_client.dart';

void main() {
  test('rejects non-loopback HTTP API origins', () {
    expect(
      () => ShiftTransactionApiClient(
        baseUrl: 'http://calendar.example.test',
        idTokenProvider: () async => 'token',
      ),
      throwsArgumentError,
    );
  });

  test('allows HTTP only for explicit loopback development origins', () {
    for (final baseUrl in [
      'http://localhost',
      'http://127.0.0.1',
      'http://[::1]',
    ]) {
      final client = ShiftTransactionApiClient(
        baseUrl: baseUrl,
        idTokenProvider: () async => 'token',
        httpClient: MockClient((request) async => http.Response('{}', 200)),
      );
      expect(client.isConfigured, isTrue);
      client.close();
    }
  });

  test('surfaces the server correlation ID with API errors', () async {
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'google-id-token',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'unauthenticated',
              'message': 'A valid Google ID token is required.',
            },
          }),
          401,
          headers: {'x-request-id': 'server-correlation-123'},
        );
      }),
    );

    await expectLater(
      client.listTransactions(),
      throwsA(
        isA<ShiftTransactionApiException>().having(
          (error) => error.correlationId,
          'correlationId',
          'server-correlation-123',
        ),
      ),
    );
    client.close();
  });

  test('generates a distinct correlation ID for every API request', () async {
    final requestIds = <String>[];
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'google-id-token',
      httpClient: MockClient((request) async {
        requestIds.add(request.headers['X-Request-ID'] ?? '');
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'transaction-1',
                'mode': 'personal',
                'type': 'give_up',
                'status': 'cancelled',
                'sync_status': 'not_started',
                'version': 1,
                'created_at': '2026-11-17T01:00:00Z',
                'updated_at': '2026-11-17T02:00:00Z',
                'participants': [],
                'transfers': [],
                'timeline': [],
              },
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'data': []}), 200);
      }),
    );

    await client.listTransactions();
    await client.listTransactions();
    await client.cancelTransaction('transaction-1');

    expect(requestIds, hasLength(3));
    expect(requestIds.toSet(), hasLength(3));
    expect(
      requestIds.every((id) => RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(id)),
      isTrue,
    );
    client.close();
  });
}
