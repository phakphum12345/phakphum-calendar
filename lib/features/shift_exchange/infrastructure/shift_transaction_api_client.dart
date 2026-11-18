import 'dart:convert';

import 'package:http/http.dart' as http;

/// A server transaction snapshot. It intentionally models the API response
/// separately from the local domain aggregate: the API does not expose Google
/// account subjects for participants.
class ShiftTransactionSnapshot {
  const ShiftTransactionSnapshot({
    required this.id,
    required this.mode,
    required this.type,
    required this.status,
    required this.syncStatus,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.participants,
    required this.transfers,
    required this.timeline,
    this.organizationId,
  });

  final String id;
  final String mode;
  final String type;
  final String status;
  final String syncStatus;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? organizationId;
  final List<Map<String, dynamic>> participants;
  final List<Map<String, dynamic>> transfers;
  final List<Map<String, dynamic>> timeline;

  factory ShiftTransactionSnapshot.fromJson(Map<String, dynamic> json) {
    DateTime date(String key) {
      final value = DateTime.tryParse(json[key]?.toString() ?? '');
      if (value == null) throw FormatException('Invalid $key in transaction response.');
      return value;
    }

    List<Map<String, dynamic>> records(String key) {
      final value = json[key];
      if (value is! List) throw FormatException('Invalid $key in transaction response.');
      return List.unmodifiable(value.map((item) {
        if (item is! Map) throw FormatException('Invalid $key item in transaction response.');
        return Map<String, dynamic>.unmodifiable(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
      }));
    }

    return ShiftTransactionSnapshot(
      id: json['id']?.toString() ?? (throw const FormatException('Missing transaction id.')),
      mode: json['mode']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      syncStatus: json['sync_status']?.toString() ?? '',
      version: (json['version'] as num?)?.toInt() ?? 0,
      createdAt: date('created_at'),
      updatedAt: date('updated_at'),
      organizationId: json['organization_id']?.toString(),
      participants: records('participants'),
      transfers: records('transfers'),
      timeline: records('timeline'),
    );
  }
}

class ShiftTransactionApiException implements Exception {
  const ShiftTransactionApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ShiftTransactionApiException($statusCode): $message';
}

/// Read-only API access for the transaction history and audit timeline.
///
/// Mutating endpoints are deliberately not exposed here. Calendar sync must
/// continue through the existing preview-and-confirm workflow.
class ShiftTransactionApiClient {
  ShiftTransactionApiClient({
    required String baseUrl,
    required this.idTokenProvider,
    http.Client? httpClient,
  }) : _baseUri = _normalizeBaseUri(baseUrl),
       _http = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  final Uri? _baseUri;
  final Future<String?> Function() idTokenProvider;
  final http.Client _http;
  final bool _ownsHttpClient;

  static Uri? _normalizeBaseUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty ||
        (parsed.scheme != 'https' && parsed.scheme != 'http')) {
      throw ArgumentError.value(value, 'baseUrl', 'Must be an absolute HTTP(S) URL.');
    }
    return parsed.replace(path: parsed.path.endsWith('/') ? parsed.path : '${parsed.path}/');
  }

  bool get isConfigured => _baseUri != null;

  Future<List<ShiftTransactionSnapshot>> listTransactions({
    String? mode,
    String? type,
    String? month,
    String? organizationId,
    String? staffId,
    String? shiftType,
  }) async {
    final query = <String, String>{
      'mode': ?mode,
      'type': ?type,
      'month': ?month,
      'organization_id': ?organizationId,
      'staff_id': ?staffId,
      'shift_type': ?shiftType,
    };
    final json = await _get('api/v1/shift-transactions', query: query);
    final data = json['data'];
    if (data is! List) throw const FormatException('Invalid transaction list response.');
    return List.unmodifiable(data.map((item) {
      if (item is! Map) throw const FormatException('Invalid transaction item.');
      return ShiftTransactionSnapshot.fromJson(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
    }));
  }

  Future<ShiftTransactionSnapshot> getTransaction(String id) async {
    if (id.trim().isEmpty || id.contains('/')) {
      throw ArgumentError.value(id, 'id', 'A transaction ID is required.');
    }
    final json = await _get('api/v1/shift-transactions/${Uri.encodeComponent(id)}');
    final data = json['data'];
    if (data is! Map) throw const FormatException('Invalid transaction detail response.');
    return ShiftTransactionSnapshot.fromJson(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  /// Creates a server-backed transaction using a stable idempotency key.
  Future<ShiftTransactionSnapshot> createTransaction({
    required String mode,
    required String type,
    required List<Map<String, dynamic>> participants,
    required List<Map<String, dynamic>> transfers,
    required String idempotencyKey,
    String? organizationId,
    Map<String, dynamic> metadata = const {},
  }) {
    if (idempotencyKey.trim().isEmpty || idempotencyKey.length > 128) {
      throw ArgumentError.value(idempotencyKey, 'idempotencyKey', 'Must contain 1–128 characters.');
    }
    final body = <String, dynamic>{
      'mode': mode,
      'type': type,
      'participants': participants,
      'transfers': transfers,
      'organization_id': ?organizationId,
      'metadata': ?(metadata.isEmpty ? null : metadata),
    };
    return _postTransaction(
      'api/v1/shift-transactions',
      body: body,
      headers: {'Idempotency-Key': idempotencyKey},
    );
  }

  Future<ShiftTransactionSnapshot> confirmTransaction(String id) =>
      _postTransaction('${_transactionPath(id)}/confirm');

  Future<ShiftTransactionSnapshot> rejectTransaction(
    String id, {
    String? reason,
  }) => _postTransaction(
    '${_transactionPath(id)}/reject',
    body: {'reason': ?reason},
  );

  Future<ShiftTransactionSnapshot> approveTransaction(
    String id, {
    String? note,
  }) => _postTransaction(
    '${_transactionPath(id)}/approve',
    body: {if (note != null) 'note': note},
  );

  Future<ShiftTransactionSnapshot> rejectByApprover(
    String id, {
    String? reason,
  }) => _postTransaction(
    '${_transactionPath(id)}/reject-by-approver',
    body: {if (reason != null) 'reason': reason},
  );

  Future<ShiftTransactionSnapshot> cancelTransaction(String id) =>
      _postTransaction('${_transactionPath(id)}/cancel');

  Future<ShiftTransactionSnapshot> startCalendarSync(
    String id, {
    required bool previewConfirmed,
  }) => _postTransaction(
    '${_transactionPath(id)}/calendar-sync/start',
    body: {'preview_confirmed': previewConfirmed},
  );

  Future<ShiftTransactionSnapshot> completeCalendarSync(
    String id, {
    required List<String> calendarEventIds,
  }) => _postTransaction(
    '${_transactionPath(id)}/calendar-sync/complete',
    body: {'calendar_event_ids': calendarEventIds},
  );

  Future<ShiftTransactionSnapshot> failCalendarSync(
    String id, {
    String? reason,
  }) => _postTransaction(
    '${_transactionPath(id)}/calendar-sync/fail',
    body: {if (reason != null) 'reason': reason},
  );

  Future<ShiftTransactionSnapshot> fulfillTransfer(
    String id, {
    required String transferId,
  }) => _postTransaction(
    '${_transactionPath(id)}/fulfill',
    body: {'transfer_id': transferId},
  );

  String _transactionPath(String id) {
    if (id.trim().isEmpty || id.contains('/')) {
      throw ArgumentError.value(id, 'id', 'A transaction ID is required.');
    }
    return 'api/v1/shift-transactions/${Uri.encodeComponent(id)}';
  }

  Future<ShiftTransactionSnapshot> _postTransaction(
    String path, {
    Map<String, dynamic> body = const {},
    Map<String, String>? headers,
  }) async {
    final json = await _post(path, body: body, headers: headers);
    final data = json['data'];
    if (data is! Map) {
      throw const FormatException('Invalid transaction response.');
    }
    return ShiftTransactionSnapshot.fromJson(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query}) async {
    final base = _baseUri;
    if (base == null) {
      throw const ShiftTransactionApiException(0, 'Transaction API URL is not configured.');
    }
    final token = await idTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const ShiftTransactionApiException(401, 'Please sign in with Google again.');
    }
    final uri = base.resolve(path).replace(queryParameters: query);
    final response = await _http.get(uri, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ShiftTransactionApiException(response.statusCode, 'The server returned an invalid response.');
    }
    if (decoded is! Map) {
      throw ShiftTransactionApiException(response.statusCode, 'The server returned an invalid response.');
    }
    final body = decoded.map((key, value) => MapEntry(key.toString(), value));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      final message = error is Map ? error['message']?.toString() : null;
      throw ShiftTransactionApiException(
        response.statusCode,
        message ?? 'Unable to load transaction history.',
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final base = _baseUri;
    if (base == null) {
      throw const ShiftTransactionApiException(0, 'Transaction API URL is not configured.');
    }
    final token = await idTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const ShiftTransactionApiException(401, 'Please sign in with Google again.');
    }
    final response = await _http.post(
      base.resolve(path),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        ...?headers,
      },
      body: jsonEncode(body),
    );
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ShiftTransactionApiException(response.statusCode, 'The server returned an invalid response.');
    }
    if (decoded is! Map) {
      throw ShiftTransactionApiException(response.statusCode, 'The server returned an invalid response.');
    }
    final result = decoded.map((key, value) => MapEntry(key.toString(), value));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = result['error'];
      final message = error is Map ? error['message']?.toString() : null;
      throw ShiftTransactionApiException(
        response.statusCode,
        message ?? 'Unable to update shift transaction.',
      );
    }
    return result;
  }

  void close() {
    if (_ownsHttpClient) _http.close();
  }
}
