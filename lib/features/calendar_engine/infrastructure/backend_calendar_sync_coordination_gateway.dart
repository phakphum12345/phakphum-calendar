import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../domain/calendar_sync_coordination_gateway.dart';

class BackendCalendarSyncCoordinationGateway
    implements CalendarSyncCoordinationGateway {
  BackendCalendarSyncCoordinationGateway({
    required String baseUrl,
    required this.idTokenProvider,
    http.Client? httpClient,
    String? clientInstanceId,
    this.leaseTtlSeconds = 60,
  }) : _baseUri = _normalizeBaseUri(baseUrl),
       _http = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       clientInstanceId = clientInstanceId ?? _newUuid() {
    if (leaseTtlSeconds < 15 || leaseTtlSeconds > 300) {
      throw ArgumentError.value(leaseTtlSeconds, 'leaseTtlSeconds');
    }
  }

  final Uri _baseUri;
  final http.Client _http;
  final bool _ownsHttpClient;
  final Future<String?> Function() idTokenProvider;
  final String clientInstanceId;
  final int leaseTtlSeconds;

  static Uri _normalizeBaseUri(String value) {
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      throw ArgumentError.value(
        value,
        'baseUrl',
        'An absolute HTTP(S) URL is required.',
      );
    }
    final localHttp =
        parsed.scheme == 'http' &&
        {'localhost', '127.0.0.1', '::1'}.contains(parsed.host);
    if (parsed.scheme != 'https' && !localHttp) {
      throw ArgumentError.value(
        value,
        'baseUrl',
        'HTTPS is required outside loopback.',
      );
    }
    return parsed.replace(
      path: parsed.path.endsWith('/') ? parsed.path : '${parsed.path}/',
    );
  }

  @override
  Future<CalendarSyncLease> acquire({
    required String calendarId,
    required String scheduleId,
  }) async {
    if (scheduleId.trim().isEmpty || scheduleId == 'unknown') {
      throw const CalendarSyncCoordinationException(
        400,
        'A stable Schedule ID is required for server-coordinated synchronization.',
      );
    }
    final runId = _newUuid();
    final response = await _request(
      'POST',
      'api/v1/calendar-sync/leases',
      body: {
        'run_id': runId,
        'calendar_id': calendarId,
        'schedule_id': scheduleId,
        'client_instance_id': clientInstanceId,
        'ttl_seconds': leaseTtlSeconds,
      },
    );
    final data = response['data'];
    if (data is! Map ||
        data['run_id'] != runId ||
        data['lease_token'] is! String ||
        data['expires_at'] is! String) {
      throw const FormatException(
        'The backend returned an invalid Calendar sync lease.',
      );
    }
    return CalendarSyncLease(
      runId: runId,
      calendarId: calendarId,
      scheduleId: scheduleId,
      leaseToken: data['lease_token'] as String,
      expiresAt: DateTime.parse(data['expires_at'] as String),
    );
  }

  @override
  Future<void> heartbeat(CalendarSyncLease lease) async {
    await _request(
      'PUT',
      'api/v1/calendar-sync/leases/${Uri.encodeComponent(lease.runId)}',
      body: {'lease_token': lease.leaseToken, 'ttl_seconds': leaseTtlSeconds},
    );
  }

  @override
  Future<CalendarSyncRunRecord?> getRun(String runId) async {
    final Map<String, dynamic> response;
    try {
      response = await _request(
        'GET',
        'api/v1/calendar-sync/runs/${Uri.encodeComponent(runId)}',
      );
    } on CalendarSyncCoordinationException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
    final data = response['data'];
    if (data is! Map) {
      throw const FormatException('The backend returned an invalid sync run.');
    }
    final record = data.map((key, value) => MapEntry(key.toString(), value));
    return _parseRunRecord(record);
  }

  @override
  Future<List<CalendarSyncRunRecord>> listRuns({
    String? calendarId,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 100.');
    }
    final query = <String, String>{
      'limit': limit.toString(),
      if (calendarId != null && calendarId.trim().isNotEmpty)
        'calendar_id': calendarId,
    };
    final response = await _request(
      'GET',
      'api/v1/calendar-sync/runs?${Uri(queryParameters: query).query}',
    );
    final data = response['data'];
    if (data is! List) {
      throw const FormatException('The backend returned an invalid sync run list.');
    }
    return data.map((entry) {
      if (entry is! Map) {
        throw const FormatException('The backend returned an invalid sync run.');
      }
      return _parseRunRecord(
        entry.map((key, value) => MapEntry(key.toString(), value)),
      );
    }).toList(growable: false);
  }

  CalendarSyncRunRecord _parseRunRecord(Map<String, dynamic> record) {
    final startedAt = DateTime.tryParse(record['started_at']?.toString() ?? '');
    final heartbeatAt = DateTime.tryParse(record['heartbeat_at']?.toString() ?? '');
    if (record['run_id'] is! String ||
        record['calendar_id'] is! String ||
        record['schedule_id'] is! String ||
        record['status'] is! String ||
        startedAt == null ||
        heartbeatAt == null) {
      throw const FormatException('The backend sync run is missing required fields.');
    }
    int count(String key) {
      final value = record[key];
      if (value == null) return 0;
      if (value is! num || value < 0) {
        throw FormatException('The backend sync run has an invalid $key.');
      }
      return value.toInt();
    }
    final finishedAt = DateTime.tryParse(record['finished_at']?.toString() ?? '');
    return CalendarSyncRunRecord(
      runId: record['run_id'] as String,
      calendarId: record['calendar_id'] as String,
      scheduleId: record['schedule_id'] as String,
      status: record['status'] as String,
      startedAt: startedAt,
      heartbeatAt: heartbeatAt,
      finishedAt: finishedAt,
      operationCount: count('operation_count'),
      insertedCount: count('inserted_count'),
      updatedCount: count('updated_count'),
      deletedCount: count('deleted_count'),
      failedCount: count('failed_count'),
      pendingCount: count('pending_count'),
    );
  }

  @override
  Future<List<CalendarSyncOperationRecord>> listOperations(String runId) async {
    final response = await _request(
      'GET',
      'api/v1/calendar-sync/runs/${Uri.encodeComponent(runId)}/operations',
    );
    final data = response['data'];
    if (data is! List) {
      throw const FormatException('The backend returned an invalid sync operation list.');
    }
    return data.map((entry) {
      if (entry is! Map) {
        throw const FormatException('The backend returned an invalid sync operation.');
      }
      final record = entry.map((key, value) => MapEntry(key.toString(), value));
      final payload = record['operation_payload'];
      if (record['operation_key'] is! String ||
          record['operation_type'] is! String ||
          record['status'] is! String ||
          record['payload_hash'] is! String ||
          payload is! Map ||
          record['attempt_count'] is! num) {
        throw const FormatException('The backend sync operation is missing required fields.');
      }
      return CalendarSyncOperationRecord(
        operationKey: record['operation_key'] as String,
        operationType: record['operation_type'] as String,
        status: record['status'] as String,
        payloadHash: record['payload_hash'] as String,
        operationPayload: payload.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        attemptCount: (record['attempt_count'] as num).toInt(),
        providerEventId: record['provider_event_id']?.toString(),
        lastError: record['last_error']?.toString(),
      );
    }).toList(growable: false);
  }

  @override
  Future<void> recordOperation({
    required CalendarSyncLease lease,
    required String operationKey,
    required String operationType,
    required String payloadHash,
    required Map<String, Object?> operationPayload,
  }) async {
    await _request(
      'POST',
      'api/v1/calendar-sync/leases/${Uri.encodeComponent(lease.runId)}/operations',
      body: {
        'lease_token': lease.leaseToken,
        'operation_key': operationKey,
        'operation_type': operationType,
        'payload_hash': payloadHash,
        'operation_payload': operationPayload,
      },
    );
  }

  @override
  Future<void> updateOperation({
    required CalendarSyncLease lease,
    required String operationKey,
    required String status,
    required int attemptCount,
    String? providerEventId,
    String? lastError,
  }) async {
    await _request(
      'PATCH',
      'api/v1/calendar-sync/leases/${Uri.encodeComponent(lease.runId)}/operations/${Uri.encodeComponent(operationKey)}',
      body: {
        'lease_token': lease.leaseToken,
        'status': status,
        'attempt_count': attemptCount,
        'provider_event_id': providerEventId,
        'last_error': lastError,
      },
    );
  }

  @override
  Future<void> release({
    required CalendarSyncLease lease,
    required String status,
  }) async {
    await _request(
      'DELETE',
      'api/v1/calendar-sync/leases/${Uri.encodeComponent(lease.runId)}',
      body: {'lease_token': lease.leaseToken, 'status': status},
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await idTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const CalendarSyncCoordinationException(
        401,
        'Sign in again before using server-coordinated Calendar sync.',
      );
    }
    final uri = _baseUri.resolve(path);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final pending = switch (method) {
      'POST' => _http.post(uri, headers: headers, body: encodedBody),
      'PUT' => _http.put(uri, headers: headers, body: encodedBody),
      'PATCH' => _http.patch(uri, headers: headers, body: encodedBody),
      'DELETE' => _http.delete(uri, headers: headers, body: encodedBody),
      _ => throw ArgumentError.value(method, 'method'),
    };
    final response = await pending.timeout(const Duration(seconds: 15));
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw CalendarSyncCoordinationException(
        response.statusCode,
        'The synchronization backend returned an invalid response.',
      );
    }
    if (decoded is! Map) {
      throw CalendarSyncCoordinationException(
        response.statusCode,
        'The synchronization backend returned an invalid response.',
      );
    }
    final result = decoded.map((key, value) => MapEntry(key.toString(), value));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = result['error'];
      final message = error is Map ? error['message']?.toString() : null;
      throw CalendarSyncCoordinationException(
        response.statusCode,
        message ?? 'The synchronization coordination request failed.',
      );
    }
    return result;
  }

  void close() {
    if (_ownsHttpClient) _http.close();
  }

  static String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class CalendarSyncCoordinationException implements Exception {
  const CalendarSyncCoordinationException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() =>
      'CalendarSyncCoordinationException($statusCode): $message';
}
