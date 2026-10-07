import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:phakphum_calendar/services/google_api_client.dart';

class _HangingClient extends http.BaseClient {
  final Completer<http.StreamedResponse> completer =
      Completer<http.StreamedResponse>();

  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return completer.future;
  }

  @override
  void close() {
    closed = true;
  }
}

class _ImmediateClient extends http.BaseClient {
  http.BaseRequest? received;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    received = request;
    return http.StreamedResponse(
      Stream<List<int>>.value(<int>[]),
      200,
      request: request,
    );
  }

  @override
  void close() {
    closed = true;
  }
}

void main() {
  test('preserves headers and delegates request', () async {
    final inner = _ImmediateClient();
    final client = GoogleApiClient(
      const <String, String>{
        'Authorization': 'Bearer test-token',
      },
      inner,
    );

    final response = await client.get(
      Uri.parse('https://example.test/calendar'),
    );

    expect(response.statusCode, 200);
    expect(inner.received?.headers['Authorization'], 'Bearer test-token');
  });

  test('bounds a hanging request', () async {
    final inner = _HangingClient();
    final client = GoogleApiClient(
      const <String, String>{
        'Authorization': 'Bearer test-token',
      },
      inner,
      const Duration(milliseconds: 50),
    );

    await expectLater(
      client.get(Uri.parse('https://example.test/calendar')),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('delegates close to inner client', () {
    final inner = _ImmediateClient();
    final client = GoogleApiClient(
      const <String, String>{},
      inner,
    );

    client.close();

    expect(inner.closed, isTrue);
  });
}

