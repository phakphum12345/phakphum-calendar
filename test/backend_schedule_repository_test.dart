import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/features/schedule/data/backend_schedule_repository.dart';
import 'package:phakphum_calendar/features/schedule/data/schedule_json_codec.dart';

void main() {
  const codec = ScheduleJsonCodec();

  test('loads a server revision and sends it with the next conditional save', () async {
    final schedule = Schedule(id: 'roster-1', name: 'November');
    final payload = jsonDecode(codec.encode(schedule));
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response(jsonEncode({
          'data': payload,
          'revision': 'v4:${List.filled(64, 'a').join()}',
          'state': 'live',
        }), 200);
      }
      expect(request.method, 'PUT');
      expect(request.headers['authorization'], 'Bearer test-id-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['expected_revision'], 'v4:${List.filled(64, 'a').join()}');
      return http.Response(jsonEncode({
        'data': payload,
        'revision': 'v5:${List.filled(64, 'b').join()}',
        'state': 'live',
      }), 200);
    });
    final repository = BackendScheduleRepository(
      baseUrl: 'https://roster.example.test',
      idTokenProvider: () async => 'test-id-token',
      httpClient: client,
    );

    final loaded = await repository.findById('roster-1');
    expect(loaded, isA<Success<Schedule?>>());
    final saved = await repository.save(schedule);
    expect(saved, isA<Success<Schedule>>());
    expect(requests.map((request) => request.method).toList(), ['GET', 'PUT']);
  });

  test('surfaces a stale revision conflict instead of falling back to local storage', () async {
    final schedule = Schedule(id: 'roster-2', name: 'Stale');
    final payload = jsonDecode(codec.encode(schedule));
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode({
          'data': payload,
          'revision': 'v2:${List.filled(64, 'a').join()}',
          'state': 'live',
        }), 200);
      }
      return http.Response(jsonEncode({
        'error': {
          'code': 'schedule_revision_conflict',
          'message': 'The Schedule changed after the supplied revision was read.',
        },
        'current_revision': 'v3:${List.filled(64, 'b').join()}',
        'current_state': 'live',
      }), 409);
    });
    final repository = BackendScheduleRepository(
      baseUrl: 'https://roster.example.test',
      idTokenProvider: () async => 'test-id-token',
      httpClient: client,
    );

    await repository.findById('roster-2');
    final result = await repository.save(schedule);
    expect(result, isA<NetworkFailure<Schedule>>());
    expect((result as NetworkFailure<Schedule>).statusCode, 409);
  });

  test('save keeps the revision attached to the exact snapshot after another read', () async {
    final oldSnapshot = Schedule(id: 'roster-5', name: 'Reviewed old snapshot');
    final newSnapshot = Schedule(id: 'roster-5', name: 'Newer snapshot');
    final oldPayload = jsonDecode(codec.encode(oldSnapshot));
    final newPayload = jsonDecode(codec.encode(newSnapshot));
    var reads = 0;
    String? putRevision;
    final repository = BackendScheduleRepository(
      baseUrl: 'https://roster.example.test',
      idTokenProvider: () async => 'test-id-token',
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          reads++;
          return http.Response(jsonEncode({
            'data': reads == 1 ? oldPayload : newPayload,
            'revision': reads == 1
                ? 'v7:${List.filled(64, '7').join()}'
                : 'v9:${List.filled(64, '9').join()}',
            'state': 'live',
          }), 200);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        putRevision = body['expected_revision'] as String;
        return http.Response(jsonEncode({
          'error': {
            'code': 'schedule_revision_conflict',
            'message': 'The reviewed Schedule snapshot is stale.',
          },
          'current_revision': 'v9:${List.filled(64, '9').join()}',
          'current_state': 'live',
        }), 409);
      }),
    );

    final old = await repository.findById('roster-5');
    await repository.findById('roster-5');
    final result = await repository.save((old as Success<Schedule?>).value!);

    expect(result, isA<NetworkFailure<Schedule>>());
    expect(putRevision, 'v7:${List.filled(64, '7').join()}');
  });

  test('save refuses an unobserved Schedule snapshot without making a request', () async {
    var requestCount = 0;
    final repository = BackendScheduleRepository(
      baseUrl: 'https://roster.example.test',
      idTokenProvider: () async => 'test-id-token',
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );

    final result = await repository.save(
      Schedule(id: 'roster-6', name: 'Unobserved'),
    );

    expect(result, isA<PersistenceFailure<Schedule>>());
    expect(requestCount, 0);
  });

  test('backend Schedule deletion fails closed without a caller-owned revision', () async {
    var requestCount = 0;
    final repository = BackendScheduleRepository(
      baseUrl: 'https://roster.example.test',
      idTokenProvider: () async => 'test-id-token',
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );

    final result = await repository.delete('roster-7');

    expect(result, isA<PersistenceFailure<void>>());
    expect(requestCount, 0);
  });

  test('requires a Google ID token before sending Schedule data', () async {
    var requestCount = 0;
    final repository = BackendScheduleRepository(
      baseUrl: 'https://roster.example.test',
      idTokenProvider: () async => null,
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );

    final result = await repository.findById('roster-3');
    expect(result, isA<NetworkFailure<Schedule?>>());
    expect((result as NetworkFailure<Schedule?>).statusCode, 401);
    expect(requestCount, 0);
  });
  test('conditional save uses the caller revision, not the shared revision cache', () async {
    final schedule = Schedule(id: 'roster-4', name: 'Reviewed snapshot');
    final payload = jsonDecode(codec.encode(schedule));
    final requests = <http.Request>[];
    final repository = BackendScheduleRepository(
      baseUrl: 'https://roster.example.test',
      idTokenProvider: () async => 'test-id-token',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode({
            'data': payload,
            'revision': 'v9:${List.filled(64, '9').join()}',
            'state': 'live',
          }), 200);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['expected_revision'], 'v7:${List.filled(64, '7').join()}');
        return http.Response(jsonEncode({
          'error': {
            'code': 'schedule_revision_conflict',
            'message': 'The Schedule changed after the reviewed snapshot.',
          },
          'current_revision': 'v9:${List.filled(64, '9').join()}',
          'current_state': 'live',
        }), 409);
      }),
    );

    await repository.findById('roster-4');
    final result = await repository.saveIfRevision(
      schedule,
      'v7:${List.filled(64, '7').join()}',
    );

    expect(result, isA<NetworkFailure<Schedule>>());
    expect((result as NetworkFailure<Schedule>).statusCode, 409);
    expect(requests.map((request) => request.method), ['GET', 'PUT']);
  });

}
