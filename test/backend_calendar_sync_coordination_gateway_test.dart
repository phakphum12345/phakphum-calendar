import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phakphum_calendar/features/calendar_engine/infrastructure/backend_calendar_sync_coordination_gateway.dart';

void main() {
  test('lists server run summaries without requesting encrypted operation payloads', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'data': [
            {
              'run_id': 'run-1',
              'calendar_id': 'primary',
              'schedule_id': 'schedule-1',
              'status': 'partial_success',
              'started_at': '2026-11-26T08:00:00Z',
              'heartbeat_at': '2026-11-26T08:05:00Z',
              'finished_at': '2026-11-26T08:06:00Z',
              'operation_count': 4,
              'inserted_count': 1,
              'updated_count': 1,
              'deleted_count': 0,
              'failed_count': 1,
              'pending_count': 1,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final gateway = BackendCalendarSyncCoordinationGateway(
      baseUrl: 'https://api.example.test/',
      idTokenProvider: () async => 'test-id-token',
      httpClient: client,
    );

    final runs = await gateway.listRuns(calendarId: 'primary', limit: 10);

    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/api/v1/calendar-sync/runs');
    expect(requests.single.url.queryParameters, {
      'calendar_id': 'primary',
      'limit': '10',
    });
    expect(requests.single.headers['authorization'], 'Bearer test-id-token');
    expect(runs, hasLength(1));
    expect(runs.single.runId, 'run-1');
    expect(runs.single.operationCount, 4);
    expect(runs.single.insertedCount, 1);
    expect(runs.single.updatedCount, 1);
    expect(runs.single.failedCount, 1);
    expect(runs.single.pendingCount, 1);
  });

  test('rejects an invalid server run history limit', () async {
    final gateway = BackendCalendarSyncCoordinationGateway(
      baseUrl: 'https://api.example.test/',
      idTokenProvider: () async => 'test-id-token',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );

    expect(() => gateway.listRuns(limit: 0), throwsArgumentError);
  });
}
