import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:phakphum_calendar/core/google/google_scope_routing_client.dart';
import 'package:phakphum_calendar/core/google/google_scopes.dart';

void main() {
  test('preview reads do not request Calendar write access', () async {
    final requestedScopes = <List<String>>[];
    final clients = <_RecordingClient>[];
    final client = GoogleScopeRoutingClient(
      clientForScopes: (scopes) async {
        requestedScopes.add(List<String>.of(scopes));
        final created = _RecordingClient();
        clients.add(created);
        return created;
      },
    );

    final previewResponse = await client.get(
      Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events',
      ),
    );
    expect(previewResponse.statusCode, 200);
    expect(requestedScopes, [GoogleScopes.calendarRead]);
    expect(
      requestedScopes.expand((scopes) => scopes),
      isNot(contains(GoogleScopes.calendarEvents)),
    );

    final writeResponse = await client.post(
      Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events',
      ),
      body: '{}',
    );
    expect(writeResponse.statusCode, 200);
    expect(
      requestedScopes,
      [GoogleScopes.calendarRead, GoogleScopes.calendarWrite],
    );

    // Further reads and writes reuse their account-bound clients.
    await client.get(
      Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events',
      ),
    );
    await client.put(
      Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events/event-1',
      ),
      body: '{}',
    );
    await client.delete(
      Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events/event-1',
      ),
    );
    expect(
      requestedScopes,
      [GoogleScopes.calendarRead, GoogleScopes.calendarWrite],
    );
    expect(clients.map((item) => item.methods), [
      ['GET', 'GET'],
      ['POST', 'PUT', 'DELETE'],
    ]);

    client.close();
    await Future<void>.delayed(Duration.zero);
    expect(clients.map((item) => item.closeCalls), [1, 1]);
  });

  test('unsupported HTTP methods fail before requesting OAuth scopes', () async {
    var factoryCalls = 0;
    final client = GoogleScopeRoutingClient(
      clientForScopes: (_) async {
        factoryCalls++;
        return _RecordingClient();
      },
    );

    await expectLater(
      client.send(http.Request('OPTIONS', Uri.parse('https://example.test'))),
      throwsUnsupportedError,
    );
    expect(factoryCalls, 0);
    client.close();
  });

  test('denied write consent prevents the Calendar mutation request', () async {
    final readClient = _RecordingClient();
    final requestedScopes = <List<String>>[];
    final client = GoogleScopeRoutingClient(
      clientForScopes: (scopes) async {
        requestedScopes.add(List<String>.of(scopes));
        if (scopes.contains(GoogleScopes.calendarEvents)) {
          throw StateError('write consent was denied');
        }
        return readClient;
      },
    );

    final preview = await client.get(Uri.parse('https://example.test/calendar'));
    expect(preview.statusCode, 200);
    await expectLater(
      client.post(
        Uri.parse('https://example.test/calendar/events'),
        body: '{}',
      ),
      throwsStateError,
    );

    expect(
      requestedScopes,
      [GoogleScopes.calendarRead, GoogleScopes.calendarWrite],
    );
    expect(readClient.methods, ['GET']);

    client.close();
    await Future<void>.delayed(Duration.zero);
    expect(readClient.closeCalls, 1);
  });

  test('failed scope authorization can be retried', () async {
    var factoryCalls = 0;
    final created = _RecordingClient();
    final client = GoogleScopeRoutingClient(
      clientForScopes: (_) async {
        factoryCalls++;
        if (factoryCalls == 1) throw StateError('consent was denied');
        return created;
      },
    );

    await expectLater(
      client.get(Uri.parse('https://example.test/calendar')),
      throwsStateError,
    );
    final response = await client.get(
      Uri.parse('https://example.test/calendar'),
    );
    expect(response.statusCode, 200);
    expect(factoryCalls, 2);

    client.close();
    await Future<void>.delayed(Duration.zero);
    expect(created.closeCalls, 1);
  });
}

class _RecordingClient extends http.BaseClient {
  final List<String> methods = [];
  int closeCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    methods.add(request.method);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('ok')),
      200,
    );
  }

  @override
  void close() {
    closeCalls++;
  }
}
