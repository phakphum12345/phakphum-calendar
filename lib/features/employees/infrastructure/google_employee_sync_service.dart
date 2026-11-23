import 'dart:async';
import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../../../domain/entities/department.dart';
import '../../../domain/entities/employee.dart';
import 'employee_json_codec.dart';

class GoogleEmployeeSyncService {
  GoogleEmployeeSyncService(
    this._client, {
    this.codec = const EmployeeJsonCodec(),
  });

  static const _fileName = 'shift-tools-employee-directory-v1.json';
  final http.Client _client;
  final EmployeeJsonCodec codec;

  Future<List<Employee>> download() async {
    final file = await _findFile();
    if (file == null) return const [];
    final response = await _client.get(
      Uri.https('www.googleapis.com', '/drive/v3/files/${file.id}', {
        'alt': 'media',
      }),
    );
    _requireSuccess(response, 'อ่านรายชื่อจาก Google Drive');
    return codec.decode(utf8.decode(response.bodyBytes));
  }

  Future<void> upload(List<Employee> employees) async {
    final api = drive.DriveApi(_client);
    final existing = await _findFile();
    final bytes = utf8.encode(codec.encode(employees));
    final media = drive.Media(
      Stream<List<int>>.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );
    if (existing == null) {
      await api.files.create(
        drive.File(
          name: _fileName,
          mimeType: 'application/json',
          parents: const ['appDataFolder'],
        ),
        uploadMedia: media,
        $fields: 'id,name',
      );
      return;
    }
    final existingId = existing.id;
    if (existingId == null || existingId.isEmpty) {
      throw StateError('ไฟล์รายชื่อใน Google Drive ไม่มีรหัสไฟล์');
    }
    await api.files.update(
      drive.File(name: _fileName, mimeType: 'application/json'),
      existingId,
      uploadMedia: media,
      $fields: 'id,name',
    );
  }

  Future<drive.File?> _findFile() async {
    final files = await drive.DriveApi(_client).files.list(
      spaces: 'appDataFolder',
      q: "name = '$_fileName' and trashed = false",
      pageSize: 10,
      $fields: 'files(id,name)',
    );
    final matches = files.files ?? const <drive.File>[];
    if (matches.length > 1) {
      throw StateError(
        'พบไฟล์รายชื่อซ้ำในพื้นที่แอปของ Google Drive กรุณาติดต่อผู้ดูแล',
      );
    }
    return matches.firstOrNull;
  }

  void _requireSuccess(http.Response response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('$action ไม่สำเร็จ (${response.statusCode})');
    }
  }
}

class GoogleContactTransferResult {
  const GoogleContactTransferResult({
    required this.created,
    required this.updated,
  });

  final int created;
  final int updated;
}

class GoogleContactsService {
  GoogleContactsService(this._client);

  static const _baseUri = 'people.googleapis.com';
  static const _employeeCodeKey = 'shift_tools_employee_code';
  final http.Client _client;

  Future<List<Employee>> importableEmployees() async {
    final people = await _listContacts();
    final employees = <Employee>[];
    for (final person in people) {
      final names = person['names'];
      if (names is! List || names.isEmpty || names.first is! Map) continue;
      final name = names.first as Map;
      final firstName = _string(name['givenName']).trim();
      final lastName = _string(name['familyName']).trim();
      if (firstName.isEmpty && lastName.isEmpty) continue;
      final userDefined = person['userDefined'];
      final properties = userDefined is List
          ? userDefined.whereType<Map>().toList()
          : const <Map>[];
      final code = _property(properties, _employeeCodeKey).trim();
      final organizations = person['organizations'];
      final organization = organizations is List && organizations.isNotEmpty
          ? organizations.first
          : null;
      final org = organization is Map
          ? organization
          : const <Object?, Object?>{};
      final resourceName = _string(person['resourceName']);
      final stableCode = code.isEmpty ? resourceName : code;
      if (stableCode.isEmpty || resourceName.isEmpty) continue;
      employees.add(
        Employee(
          id: 'google-contact:$resourceName',
          employeeCode: stableCode,
          firstName: firstName.isEmpty ? lastName : firstName,
          lastName: firstName.isEmpty ? '' : lastName,
          nickname: _property(properties, 'shift_tools_nickname'),
          position: _string(org['title']),
          department: Department(
            id: 'google-contact-department',
            code: _string(org['department']).isEmpty
                ? 'CONTACT'
                : _string(org['department']),
            name: _string(org['department']).isEmpty
                ? 'Google Contacts'
                : _string(org['department']),
          ),
        ),
      );
    }
    return List.unmodifiable(employees);
  }

  Future<GoogleContactTransferResult> exportEmployees(
    List<Employee> employees,
  ) async {
    final people = await _listContacts();
    final byEmployeeCode = <String, Map<String, Object?>>{};
    for (final person in people) {
      final userDefined = person['userDefined'];
      if (userDefined is! List) continue;
      final properties = userDefined.whereType<Map>().toList();
      final code = _property(properties, _employeeCodeKey).trim();
      if (code.isNotEmpty) byEmployeeCode[_normalize(code)] = person;
    }

    var created = 0;
    var updated = 0;
    for (final employee in employees) {
      final existing = byEmployeeCode[_normalize(employee.employeeCode)];
      final body = _contactPayload(employee, existing);
      if (existing == null) {
        await _request(
          'POST',
          '/v1/people:createContact',
          body: body,
          query: const {'personFields': 'names,organizations,userDefined'},
        );
        created++;
      } else {
        final resourceName = _string(existing['resourceName']);
        if (resourceName.isEmpty) {
          throw StateError(
            'Google Contacts ส่งคืนข้อมูลรายชื่อที่ไม่มี resourceName',
          );
        }
        final current = _string(existing['etag']).isEmpty
            ? await _request(
                'GET',
                '/v1/$resourceName',
                query: const {
                  'personFields': 'names,metadata,organizations,userDefined',
                },
              )
            : existing;
        await _request(
          'PATCH',
          '/v1/$resourceName:updateContact',
          body: _contactPayload(employee, current),
          query: const {
            'updatePersonFields': 'names,organizations,userDefined',
            'personFields': 'names,organizations,userDefined',
          },
        );
        updated++;
      }
    }
    return GoogleContactTransferResult(created: created, updated: updated);
  }

  Map<String, Object?> _contactPayload(
    Employee employee,
    Map<String, Object?>? existing,
  ) {
    final properties = <Map<String, Object?>>[];
    final existingValues = existing?['userDefined'];
    if (existingValues is List) {
      for (final value in existingValues.whereType<Map>()) {
        if (_string(value['key']) != _employeeCodeKey &&
            _string(value['key']) != 'shift_tools_nickname') {
          properties.add({
            'key': _string(value['key']),
            'value': _string(value['value']),
          });
        }
      }
    }
    properties.addAll([
      {'key': _employeeCodeKey, 'value': employee.employeeCode},
      if (employee.nickname.trim().isNotEmpty)
        {'key': 'shift_tools_nickname', 'value': employee.nickname},
    ]);
    final existingFields = existing == null
        ? null
        : <String, Object?>{
            'resourceName': existing['resourceName'],
            if (existing['etag'] case final String etag) 'etag': etag,
          };
    return {
      ...?existingFields,
      'names': [
        {'givenName': employee.firstName, 'familyName': employee.lastName},
      ],
      'organizations': [
        {
          'name': employee.department.name,
          'department': employee.department.name,
          'title': employee.position,
        },
      ],
      'userDefined': properties,
    };
  }

  Future<List<Map<String, Object?>>> _listContacts() async {
    final all = <Map<String, Object?>>[];
    String? pageToken;
    do {
      final pageQuery = pageToken == null
          ? null
          : <String, String>{'pageToken': pageToken};
      final response = await _request(
        'GET',
        '/v1/people/me/connections',
        query: {
          'pageSize': '1000',
          'personFields': 'names,metadata,organizations,userDefined',
          ...?pageQuery,
        },
      );
      final connections = response['connections'];
      if (connections is List) {
        all.addAll(connections.whereType<Map>().map(_stringMap));
      }
      pageToken = _string(response['nextPageToken']);
      if (all.length > 10000) {
        throw StateError(
          'มีรายชื่อเกิน 10,000 รายการ จึงหยุดอ่านเพื่อความปลอดภัย',
        );
      }
    } while (pageToken.isNotEmpty);
    return all;
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String> query = const {},
  }) async {
    final uri = Uri.https(_baseUri, path, query);
    final request = http.Request(method, uri);
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Google Contacts ตอบกลับ ${response.statusCode}: ${response.body}',
      );
    }
    if (response.body.isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Google Contacts ส่งคืนข้อมูลผิดรูปแบบ');
    }
    return _stringMap(decoded);
  }

  String _property(List<Map> properties, String key) {
    for (final property in properties) {
      if (_string(property['key']) == key) {
        return _string(property['value']);
      }
    }
    return '';
  }

  Map<String, Object?> _stringMap(Map value) => {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };

  String _string(Object? value) => value is String ? value : '';

  String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
