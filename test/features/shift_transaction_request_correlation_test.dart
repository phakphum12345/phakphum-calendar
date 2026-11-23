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
      'http://localhost:8787',
      'http://127.0.0.1:8787',
      'http://[::1]:8787',
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

  test('generates a distinct correlation ID for every API request', () async {
    final requestIds = <String>[];
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'google-id-token',
      httpClient: MockClient((request) async {
        requestIds.add(request.headers['X-Request-ID'] ?? '');
        return http.Response(jsonEncode({'data': []}), 200);
      }),
    );

    await client.listTransactions();
    await client.listTransactions();

    expect(requestIds, hasLength(2));
    expect(requestIds.toSet(), hasLength(2));
    expect(
      requestIds.every((id) => RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(id)),
      isTrue,
    );
    client.close();
  });
}
