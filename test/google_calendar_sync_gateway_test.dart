import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_command.dart';
import 'package:phakphum_calendar/features/calendar_engine/infrastructure/google_calendar_sync_gateway.dart';

void main() {
  test(
    'filters managed and legacy events locally without an invalid query',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'managed-event',
                'summary': 'GEN เช้า',
                'start': {'dateTime': '2026-08-01T07:30:00+07:00'},
                'end': {'dateTime': '2026-08-01T12:00:00+07:00'},
                'extendedProperties': {
                  'private': {'sceSyncId': 'sce-managed'},
                },
              },
              {
                'id': 'legacy-managed-event',
                'summary': 'IPD บ่าย',
                'start': {'dateTime': '2026-08-18T16:00:00+07:00'},
                'end': {'dateTime': '2026-08-19T08:00:00+07:00'},
                'extendedProperties': {
                  'private': {
                    'syncId': 'sce-legacy-managed',
                    'managedBy': 'phakphum-calendar',
                  },
                },
              },
              {
                'id': 'legacy-event',
                'summary': 'ER ดึก',
                'start': {'dateTime': '2026-08-16T00:00:00+07:00'},
                'end': {'dateTime': '2026-08-16T08:00:00+07:00'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final gateway = GoogleCalendarSyncGateway(client);

      final managed = await gateway.listManagedEvents(
        timeMin: DateTime(2026, 8),
        timeMax: DateTime(2026, 9),
      );
      final legacy = await gateway.listComparableLegacyEvents(
        timeMin: DateTime(2026, 8),
        timeMax: DateTime(2026, 9),
      );

      expect(managed.map((event) => event.eventId), [
        'managed-event',
        'legacy-managed-event',
      ]);
      expect(managed.map((event) => event.syncId), [
        'sce-managed',
        'sce-legacy-managed',
      ]);
      expect(legacy.map((event) => event.eventId), ['legacy-event']);
      expect(managed.first.start, DateTime(2026, 8, 1, 7, 30));
      expect(managed.first.end, DateTime(2026, 8, 1, 12));
      expect(legacy.single.start, DateTime(2026, 8, 16));
      expect(legacy.single.end, DateTime(2026, 8, 16, 8));
      expect(
        requests.every(
          (request) => !request.url.queryParameters.containsKey(
            'privateExtendedProperty',
          ),
        ),
        isTrue,
      );
    },
  );

  test(
    'uses a deterministic event ID and adopts the existing event after conflict',
    () async {
      const syncId = 'sce-test-sync-id';
      final eventId = 'sce${sha256.convert(utf8.encode(syncId))}';
      final requests = <http.Request>[];
      var insertRequests = 0;
      final event = {
        'id': eventId,
        'summary': 'ER เช้า',
        'start': {'dateTime': '2026-11-20T01:00:00Z'},
        'end': {'dateTime': '2026-11-20T09:00:00Z'},
        'extendedProperties': {
          'private': {'sceSyncId': syncId},
        },
      };
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' &&
            request.url.path.endsWith('/events')) {
          insertRequests++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['id'], eventId);
          if (insertRequests == 1) {
            return http.Response(
              jsonEncode(event),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'error': {'code': 409, 'message': 'Already exists'},
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/events/$eventId')) {
          return http.Response(
            jsonEncode(event),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('', 404);
      });
      final gateway = GoogleCalendarSyncGateway(client);
      final command = CalendarSyncCommand(
        syncId: syncId,
        title: 'ER เช้า',
        start: DateTime(2026, 11, 20, 8),
        end: DateTime(2026, 11, 20, 16),
      );

      final first = await gateway.insert(command);
      final second = await gateway.insert(command);

      expect(insertRequests, 2);
      expect(first.eventId, eventId);
      expect(second.eventId, eventId);
      expect(second.syncId, syncId);
      expect(
        requests.where(
          (request) =>
              request.method == 'GET' &&
              request.url.path.endsWith('/events/$eventId'),
        ),
        hasLength(1),
      );
    },
  );

  test('normalizes UTC Calendar instants to Bangkok wall-clock time', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'items': [
            {
              'id': 'existing-event',
              'summary': 'ER เช้า',
              'start': {'dateTime': '2026-08-20T01:00:00Z'},
              'end': {'dateTime': '2026-08-20T09:00:00Z'},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final gateway = GoogleCalendarSyncGateway(client);

    final events = await gateway.listComparableLegacyEvents(
      timeMin: DateTime(2026, 8),
      timeMax: DateTime(2026, 9),
    );

    expect(events.single.start, DateTime(2026, 8, 20, 8));
    expect(events.single.end, DateTime(2026, 8, 20, 16));
  });
}
