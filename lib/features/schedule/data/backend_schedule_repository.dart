import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/result/result.dart';
import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/schedule_month.dart';
import '../../../domain/repositories/schedule_repository.dart';
import '../../../domain/repositories/conditional_schedule_writer.dart';
import '../../../domain/repositories/schedule_revision_source.dart';
import 'schedule_json_codec.dart';

/// Authenticated Laravel Schedule persistence using server-enforced revisions.
///
/// The revision cache is populated by reads and updated only from successful
/// server responses. A stale cached token is safe: the backend rejects it with
/// HTTP 409 rather than replacing a newer Schedule.
class BackendScheduleRepository implements ScheduleRepository, ScheduleRevisionSource, ConditionalScheduleWriter {
  BackendScheduleRepository({
    required String baseUrl,
    required this.idTokenProvider,
    http.Client? httpClient,
    this.codec = const ScheduleJsonCodec(),
  }) : _baseUri = _normalizeBaseUri(baseUrl),
       _http = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  final Uri _baseUri;
  final Future<String?> Function() idTokenProvider;
  final http.Client _http;
  final bool _ownsHttpClient;
  final ScheduleJsonCodec codec;
  final Map<String, String> _revisions = {};

  @override
  String? currentRevisionFor(String scheduleId) => _revisions[scheduleId];

  static Uri _normalizeBaseUri(String value) {
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      throw ArgumentError.value(value, 'baseUrl', 'An absolute HTTP(S) URL is required.');
    }
    final localHttp = parsed.scheme == 'http' &&
        {'localhost', '127.0.0.1', '::1'}.contains(parsed.host);
    if (parsed.scheme != 'https' && !localHttp) {
      throw ArgumentError.value(value, 'baseUrl', 'HTTPS is required outside loopback.');
    }
    return parsed.replace(
      path: parsed.path.endsWith('/') ? parsed.path : '${parsed.path}/',
    );
  }

  @override
  Future<Result<Schedule?>> findById(String id) async {
    try {
      final response = await _request('GET', _schedulePath(id));
      final revision = response['revision'];
      final state = response['state'];
      if (revision is! String || state is! String) {
        throw const FormatException('Schedule response is missing its revision or state.');
      }
      _revisions[id] = revision;
      if (state == 'absent' || state == 'deleted') return const Success(null);
      if (state != 'live' || response['data'] is! Map) {
        throw const FormatException('The backend returned an invalid Schedule state.');
      }
      final schedule = codec.decode(jsonEncode(response['data']));
      if (schedule.id != id) {
        throw const FormatException('The backend returned a different Schedule identity.');
      }
      return Success(schedule);
    } on BackendScheduleApiException catch (error, stackTrace) {
      return NetworkFailure(
        error.message,
        statusCode: error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      return ValidationFailure(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      return NetworkFailure(
        'Could not load Schedule "$id" from the backend.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<ScheduleMonth?>> loadMonth(String scheduleId, DateTime month) async {
    final result = await findById(scheduleId);
    return switch (result) {
      Success<Schedule?>(value: final schedule) => Success(schedule?.month(month)),
      Failure<Schedule?>() => _copyFailure<Schedule?, ScheduleMonth?>(result),
    };
  }

  @override
  Future<Result<Schedule>> saveIfRevision(
    Schedule schedule,
    String expectedRevision,
  ) async {
    try {
      if (expectedRevision.trim().isEmpty) {
        return const PersistenceFailure('An expected Schedule revision is required.');
      }
      final response = await _request(
        'PUT',
        _schedulePath(schedule.id),
        body: {
          'expected_revision': expectedRevision,
          'schedule': jsonDecode(codec.encode(schedule)),
        },
      );
      return _decodeSavedSchedule(response, schedule.id);
    } on BackendScheduleApiException catch (error, stackTrace) {
      return NetworkFailure(
        error.message,
        statusCode: error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    } on ScheduleCodecException catch (error, stackTrace) {
      return ValidationFailure(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      return NetworkFailure(
        'Could not conditionally save Schedule "${schedule.id}" to the backend.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<Schedule>> save(Schedule schedule) async {
    try {
      var expectedRevision = _revisions[schedule.id];
      if (expectedRevision == null) {
        final current = await findById(schedule.id);
        if (current case Failure<Schedule?>()) {
          return _copyFailure<Schedule?, Schedule>(current);
        }
        expectedRevision = _revisions[schedule.id];
      }
      if (expectedRevision == null) {
        return PersistenceFailure('The backend did not provide a Schedule revision.');
      }

      final response = await _request(
        'PUT',
        _schedulePath(schedule.id),
        body: {
          'expected_revision': expectedRevision,
          'schedule': jsonDecode(codec.encode(schedule)),
        },
      );
      return _decodeSavedSchedule(response, schedule.id);
    } on BackendScheduleApiException catch (error, stackTrace) {
      return NetworkFailure(
        error.message,
        statusCode: error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    } on ScheduleCodecException catch (error, stackTrace) {
      return ValidationFailure(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      return NetworkFailure(
        'Could not save Schedule "${schedule.id}" to the backend.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      var expectedRevision = _revisions[id];
      if (expectedRevision == null) {
        final current = await findById(id);
        if (current case Failure<Schedule?>()) {
          return _copyFailure<Schedule?, void>(current);
        }
        if ((current as Success<Schedule?>).value == null) {
          return const Success(null);
        }
        expectedRevision = _revisions[id];
      }
      if (expectedRevision == null) return const Success(null);

      final response = await _request(
        'DELETE',
        _schedulePath(id),
        body: {'expected_revision': expectedRevision},
      );
      final revision = response['revision'];
      if (revision is! String || response['state'] != 'deleted') {
        throw const FormatException('The backend returned an invalid delete response.');
      }
      _revisions[id] = revision;
      return const Success(null);
    } on BackendScheduleApiException catch (error, stackTrace) {
      return NetworkFailure(
        error.message,
        statusCode: error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      return PersistenceFailure(
        'Could not delete Schedule "$id" from the backend.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Result<Schedule> _decodeSavedSchedule(Map<String, dynamic> response, String id) {
    final revision = response['revision'];
    final data = response['data'];
    if (revision is! String || response['state'] != 'live' || data is! Map) {
      throw const FormatException('The backend returned an invalid saved Schedule.');
    }
    final schedule = codec.decode(jsonEncode(data));
    if (schedule.id != id) {
      throw const FormatException('The saved Schedule identity does not match the request.');
    }
    _revisions[id] = revision;
    return Success(schedule);
  }

  String _schedulePath(String id) {
    if (id.trim().isEmpty || id.length > 128 || id.contains('/')) {
      throw ArgumentError.value(id, 'id', 'A valid Schedule ID is required.');
    }
    return 'api/v1/schedules/${Uri.encodeComponent(id)}';
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await idTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const BackendScheduleApiException(401, 'Please sign in with Google again.');
    }
    final uri = _baseUri.resolve(path);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _http.get(uri, headers: headers),
      'PUT' => await _http.put(uri, headers: headers, body: encodedBody),
      'DELETE' => await _http.delete(uri, headers: headers, body: encodedBody),
      _ => throw ArgumentError.value(method, 'method', 'Unsupported HTTP method.'),
    };

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw BackendScheduleApiException(
        response.statusCode,
        'The backend returned an invalid response.',
      );
    }
    if (decoded is! Map) {
      throw BackendScheduleApiException(
        response.statusCode,
        'The backend returned an invalid response.',
      );
    }
    final result = decoded.map((key, value) => MapEntry(key.toString(), value));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = result['error'];
      final message = error is Map ? error['message']?.toString() : null;
      throw BackendScheduleApiException(
        response.statusCode,
        message ?? 'The Schedule request failed.',
      );
    }
    return result;
  }

  void close() {
    if (_ownsHttpClient) _http.close();
  }
}

class BackendScheduleApiException implements Exception {
  const BackendScheduleApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'BackendScheduleApiException($statusCode): $message';
}

Result<TTarget> _copyFailure<TSource, TTarget>(Result<TSource> result) {
  final failure = result as Failure<TSource>;
  return switch (failure) {
    ValidationFailure<TSource>() => ValidationFailure(
      failure.message,
      fieldErrors: failure.fieldErrors,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
    NetworkFailure<TSource>() => NetworkFailure(
      failure.message,
      statusCode: failure.statusCode,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
    ImportFailure<TSource>() => ImportFailure(
      failure.message,
      rowNumber: failure.rowNumber,
      column: failure.column,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
    PersistenceFailure<TSource>() => PersistenceFailure(
      failure.message,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
  };
}
