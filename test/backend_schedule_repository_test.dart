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
    final loadedSchedule = (loaded as Success<Schedule?>).value!;
    final saved = await repository.save(loadedSchedule);
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

    final loaded = await repository.findById('roster-2');
    final result = await repository.save((loaded as Success<Schedule?>).value!);
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

  test('an ABA content cycle cannot replace an older snapshot revision', () async {
    final original = Schedule(id: 'roster-aba', name: 'A');
    final intervening = Schedule(id: 'roster-aba', name: 'B');
    final originalPayload = jsonDecode(codec.encode(original));
    final interveningPayload = jsonDecode(codec.encode(intervening));
    var reads = 0;
    String? expectedRevision;
    final repository = BackendScheduleRepository(
      baseUrl: 'https://roster.example.test',
      idTokenProvider: () async => 'test-id-token',
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          reads++;
          final isOriginal = reads == 1 || reads == 3;
          return http.Response(jsonEncode({
            'data': isOriginal ? originalPayload : interveningPayload,
            'revision': reads == 1
                ? 'v1:${List.filled(64, '1').join()}'
                : reads == 2
                ? 'v2:${List.filled(64, '2').join()}'
                : 'v3:${List.filled(64, '3').join()}',
            'state': 'live',
          }), 200);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expectedRevision = body['expected_revision'] as String;
        return http.Response(jsonEncode({
          'error': {
            'code': 'schedule_revision_conflict',
            'message': 'The original A snapshot is stale after an A-B-A cycle.',
          },
          'current_revision': 'v3:${List.filled(64, '3').join()}',
          'current_state': 'live',
        }), 409);
      }),
    );

    final first = await repository.findById('roster-aba');
    final originalSnapshot = (first as Success<Schedule?>).value!;
    await repository.findById('roster-aba');
    await repository.findById('roster-aba');

    final result = await repository.save(originalSnapshot);

    expect(result, isA<NetworkFailure<Schedule>>());
    expect(expectedRevision, 'v1:${List.filled(64, '1').join()}');
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

  test('conditional delete sends the exact caller revision and remembers the tombstone', () async {
    final requests = <http.Request>[];
    final repository = BackendScheduleRepository(
      baseUrl: 'https://roster.example.test',
      idTokenProvider: () async => 'test-id-token',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({
          'data': null,
          'revision': 'v3:${List.filled(64, '0').join()}',
          'state': 'deleted',
        }), 200);
      }),
    );
    const expectedRevision = 'v2:${'2' * 64}';

    final result = await repository.deleteIfRevision(
      'roster-8',
      expectedRevision,
    );

    expect(result, isA<Success<void>>());
    expect(requests, hasLength(1));
    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.path, '/api/v1/schedules/roster-8');
    expect(
      jsonDecode(requests.single.body)['expected_revision'],
      expectedRevision,
    );
    expect(
      (repository as ScheduleRevisionSource)
          .revisionForAbsentSchedule('roster-8'),
      isNull,
    );
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
