import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/organization_admin_gateway.dart';

class HttpOrganizationAdminGateway implements OrganizationAdminGateway {
  HttpOrganizationAdminGateway({
    required this.baseUrl,
    required this.idToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _requestTimeout = Duration(seconds: 20);
  static const _roles = {'staff', 'incharge', 'manager', 'admin'};

  final String baseUrl;
  final Future<String?> Function() idToken;
  final http.Client _client;

  @override
  Future<List<OrganizationMembership>> organizations() async {
    final data = await _request('GET', ['organizations']);
    return _list(data).map(_organization).toList(growable: false);
  }

  @override
  Future<List<OrganizationMember>> members(String organizationId) async {
    final data = await _request('GET', [
      'organizations',
      organizationId,
      'members',
    ]);
    return _list(data).map(_member).toList(growable: false);
  }

  @override
  Future<List<OrganizationJoinRequest>> pendingRequests(
    String organizationId,
  ) async {
    final data = await _request('GET', [
      'organizations',
      organizationId,
      'join-requests',
    ]);
    return _list(data).map((item) => _joinRequest(item)).toList(growable: false);
  }

  @override
  Future<List<OrganizationJoinRequest>> myRequests() async {
    final data = await _request('GET', ['organization-join-requests']);
    return _list(data).map((item) => _joinRequest(item)).toList(growable: false);
  }

  @override
  Future<OrganizationJoinRequest> requestMembership({
    required String organizationSlug,
    required String employeeId,
  }) async {
    final data = await _request(
      'POST',
      ['organization-join-requests'],
      body: {
        'organization_slug': organizationSlug,
        'employee_id': employeeId,
      },
    );
    return _joinRequest(_map(data));
  }

  @override
  Future<void> approveRequest({
    required String organizationId,
    required int requestId,
    required String role,
  }) async {
    if (!_roles.contains(role)) {
      throw ArgumentError.value(role, 'role', 'Unsupported organization role');
    }
    await _request(
      'POST',
      [
        'organizations',
        organizationId,
        'join-requests',
        '$requestId',
        'approve',
      ],
      body: {'role': role},
    );
  }

  @override
  Future<void> rejectRequest({
    required String organizationId,
    required int requestId,
  }) async {
    await _request(
      'POST',
      [
        'organizations',
        organizationId,
        'join-requests',
        '$requestId',
        'reject',
      ],
    );
  }

  Future<Object?> _request(
    String method,
    List<String> pathSegments, {
    Map<String, Object?>? body,
  }) async {
    final token = (await idToken())?.trim();
    if (token == null || token.isEmpty) {
      throw StateError('กรุณาเข้าสู่ระบบ Google เพื่อจัดการสมาชิกองค์กร');
    }

    final request = http.Request(method, _endpoint(pathSegments))
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final streamedResponse = await _client
        .send(request)
        .timeout(_requestTimeout);
    final response = await http.Response.fromStream(
      streamedResponse,
    ).timeout(_requestTimeout);
    final decoded = _decodeResponse(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map<String, dynamic>
          ? decoded['error']
          : null;
      final details = error is Map<String, dynamic> ? error : null;
      final code = details?['code'];
      final message = details?['message'];
      throw OrganizationAdminApiException(
        statusCode: response.statusCode,
        code: code is String ? code : 'request_failed',
        message: message is String
            ? message
            : 'Organization API request failed (${response.statusCode}).',
      );
    }

    if (response.statusCode == 204) return null;
    if (decoded is! Map<String, dynamic> || !decoded.containsKey('data')) {
      throw const FormatException('Organization API returned an invalid response.');
    }
    return decoded['data'];
  }

  Uri _endpoint(List<String> pathSegments) {
    final configured = baseUrl.trim();
    if (configured.isEmpty) {
      throw StateError(
        'ยังไม่ได้ตั้งค่า ORGANIZATION_API_BASE_URL สำหรับระบบสมาชิกองค์กร',
      );
    }
    final origin = Uri.tryParse(configured);
    if (origin == null ||
        !origin.hasAuthority ||
        origin.host.isEmpty ||
        (origin.path.isNotEmpty && origin.path != '/') ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment) {
      throw FormatException(
        'ORGANIZATION_API_BASE_URL ต้องเป็น origin เช่น https://api.example.com',
      );
    }
    final localHttp = origin.scheme == 'http' &&
        {'localhost', '127.0.0.1', '::1'}.contains(origin.host);
    if (origin.scheme != 'https' && !localHttp) {
      throw const FormatException(
        'Organization API ต้องใช้ HTTPS ยกเว้น loopback สำหรับ local development',
      );
    }
    return origin.replace(
      pathSegments: ['api', 'v1', ...pathSegments],
      query: null,
      fragment: null,
    );
  }

  Object? _decodeResponse(String source) {
    if (source.isEmpty) return null;
    try {
      return jsonDecode(source);
    } on FormatException {
      return null;
    }
  }

  List<Object?> _list(Object? data) {
    if (data is! List) {
      throw const FormatException('Organization API data must be a list.');
    }
    return data.cast<Object?>();
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Organization API item must be an object.');
    }
    return value;
  }

  OrganizationMembership _organization(Object? value) {
    final item = _map(value);
    return OrganizationMembership(
      id: _string(item, 'id'),
      name: _string(item, 'name'),
      slug: _string(item, 'slug'),
      employeeId: _string(item, 'employee_id'),
      role: _string(item, 'role'),
    );
  }

  OrganizationMember _member(Object? value) {
    final item = _map(value);
    return OrganizationMember(
      userId: _string(item, 'user_id'),
      name: _string(item, 'name'),
      email: _string(item, 'email'),
      employeeId: _string(item, 'employee_id'),
      role: _string(item, 'role'),
      status: _string(item, 'status'),
    );
  }

  OrganizationJoinRequest _joinRequest(Object? value) {
    final item = _map(value);
    final createdAt = item['created_at'];
    return OrganizationJoinRequest(
      id: _integer(item, 'id'),
      name: _optionalString(item, 'name'),
      email: _optionalString(item, 'email'),
      employeeId: _string(item, 'employee_id'),
      status: _string(item, 'status'),
      organizationId: _optionalString(item, 'organization_id'),
      organizationName: _optionalString(item, 'organization_name'),
      organizationSlug: _optionalString(item, 'organization_slug'),
      approvedRole: _optionalString(item, 'approved_role'),
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
    );
  }

  String _string(Map<String, dynamic> item, String key) {
    final value = item[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Organization API field "$key" is invalid.');
    }
    return value;
  }

  String? _optionalString(Map<String, dynamic> item, String key) {
    final value = item[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Organization API field "$key" is invalid.');
    }
    return value;
  }

  int _integer(Map<String, dynamic> item, String key) {
    final value = item[key];
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException('Organization API field "$key" is invalid.');
  }

  @override
  void close() => _client.close();
}
