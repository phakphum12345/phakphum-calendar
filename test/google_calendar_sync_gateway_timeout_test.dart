import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:phakphum_calendar/features/calendar_engine/infrastructure/google_calendar_sync_gateway.dart';

class DelayedHttpClient extends http.BaseClient {
  DelayedHttpClient(this.delay);

  final Duration delay;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(delay);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('{"items":[]}')),
      200,
      request: request,
    );
  }
}

void main() {
  test('bounds a provider list request with the configured timeout', () async {
    final gateway = GoogleCalendarSyncGateway(
      DelayedHttpClient(const Duration(milliseconds: 100)),
      requestTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      gateway.listManagedEvents(
        timeMin: DateTime(2026, 9, 1),
        timeMax: DateTime(2026, 9, 2),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('uses a production-safe default request timeout', () {
    expect(
      GoogleCalendarSyncGateway.defaultRequestTimeout,
      const Duration(seconds: 20),
    );
  });
}
