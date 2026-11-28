import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_command.dart';
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

  test('reconciles a timed-out update on retry without a duplicate PUT', () async {
    const syncId = 'sync-update-timeout';
    const eventId = 'event-update-timeout';
    final requests = <http.Request>[];
    var reads = 0;
    final oldEvent = {
      'id': eventId,
      'etag': 'etag-before',
      'summary': 'Old title',
      'start': {'dateTime': '2026-11-20T01:00:00Z'},
      'end': {'dateTime': '2026-11-20T09:00:00Z'},
      'extendedProperties': {
        'private': {'sceSyncId': syncId},
      },
    };
    final updatedEvent = {
      'id': eventId,
      'etag': 'etag-after',
      'summary': 'New title',
      'description': 'Reviewed update',
      'start': {'dateTime': '2026-11-20T01:00:00Z'},
      'end': {'dateTime': '2026-11-20T09:00:00Z'},
      'extendedProperties': {
        'private': {'sceSyncId': syncId},
      },
    };
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        reads++;
        return http.Response(
          jsonEncode(reads == 1 ? oldEvent : updatedEvent),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'PUT') {
        return Future<http.Response>.delayed(
          const Duration(milliseconds: 60),
          () => http.Response(
            jsonEncode(updatedEvent),
            200,
            headers: {'content-type': 'application/json'},
          ),
        );
      }
      return http.Response('', 404);
    });
    final gateway = GoogleCalendarSyncGateway(
      client,
      requestTimeout: const Duration(milliseconds: 10),
    );
    final command = CalendarSyncCommand(
      syncId: syncId,
      title: 'New title',
      start: DateTime(2026, 11, 20, 8),
      end: DateTime(2026, 11, 20, 16),
      description: 'Reviewed update',
    );

    await expectLater(
      gateway.updateConditionally(
        eventId: eventId,
        expectedEtag: 'etag-before',
        expectedSyncId: syncId,
        command: command,
      ),
      throwsA(isA<TimeoutException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 70));
    final recovered = await gateway.updateConditionally(
      eventId: eventId,
      expectedEtag: 'etag-before',
      expectedSyncId: syncId,
      command: command,
    );

    expect(recovered.title, 'New title');
    expect(recovered.etag, 'etag-after');
    expect(requests.where((request) => request.method == 'PUT'), hasLength(1));
    expect(requests.where((request) => request.method == 'GET'), hasLength(2));
  });

  test('reconciles a timed-out delete on retry when the event is already gone', () async {
    const eventId = 'event-delete-timeout';
    final requests = <http.Request>[];
    var reads = 0;
    final existingEvent = {
      'id': eventId,
      'etag': 'etag-delete',
      'summary': 'Delete me',
      'start': {'dateTime': '2026-11-20T01:00:00Z'},
      'end': {'dateTime': '2026-11-20T09:00:00Z'},
      'extendedProperties': {
        'private': {'sceSyncId': 'sync-delete-timeout'},
      },
    };
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        reads++;
        if (reads == 1) {
          return http.Response(
            jsonEncode(existingEvent),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('', 404);
      }
      if (request.method == 'DELETE') {
        return Future<http.Response>.delayed(
          const Duration(milliseconds: 60),
          () => http.Response('', 204),
        );
      }
      return http.Response('', 404);
    });
    final gateway = GoogleCalendarSyncGateway(
      client,
      requestTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      gateway.deleteConditionally(
        eventId: eventId,
        calendarId: 'primary',
        expectedEtag: 'etag-delete',
        expectedSyncId: 'sync-delete-timeout',
      ),
      throwsA(isA<TimeoutException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await gateway.deleteConditionally(
      eventId: eventId,
      calendarId: 'primary',
      expectedEtag: 'etag-delete',
      expectedSyncId: 'sync-delete-timeout',
    );

    expect(requests.where((request) => request.method == 'DELETE'), hasLength(1));
    expect(requests.where((request) => request.method == 'GET'), hasLength(2));
  });

  test('uses a production-safe default request timeout', () {
    expect(
      GoogleCalendarSyncGateway.defaultRequestTimeout,
      const Duration(seconds: 20),
    );
  });
}
