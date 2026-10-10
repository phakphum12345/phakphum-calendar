import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/features/employees/infrastructure/google_employee_sync_service.dart';

void main() {
  test('Google Contacts import maps names and employee metadata', () async {
    final service = GoogleContactsService(
      MockClient((request) async {
        expect(request.url.path, '/v1/people/me/connections');
        expect(
          request.url.queryParameters['personFields'],
          'names,metadata,organizations,userDefined',
        );
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'connections': [
                {
                  'resourceName': 'people/c123',
                  'names': [
                    {'givenName': 'สมชาย', 'familyName': 'ใจดี'},
                  ],
                  'organizations': [
                    {'department': 'รังสีวิทยา', 'title': 'นักรังสี'},
                  ],
                  'userDefined': [
                    {'key': 'shift_tools_employee_code', 'value': 'E001'},
                    {'key': 'shift_tools_nickname', 'value': 'ชาย'},
                  ],
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final employees = await service.importableEmployees();

    expect(employees, hasLength(1));
    expect(employees.single.employeeCode, 'E001');
    expect(employees.single.displayName, 'สมชาย ใจดี (ชาย)');
    expect(employees.single.department.name, 'รังสีวิทยา');
    expect(employees.single.position, 'นักรังสี');
  });

  test(
    'export updates only tagged contacts and preserves other custom data',
    () async {
      late Map<String, Object?> updateBody;
      final service = GoogleContactsService(
        MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'connections': [
                  {
                    'resourceName': 'people/c123',
                    'etag': 'etag-1',
                    'userDefined': [
                      {'key': 'shift_tools_employee_code', 'value': 'E001'},
                      {'key': 'external_reference', 'value': 'keep-me'},
                    ],
                  },
                ],
              }),
              200,
            );
          }
          expect(request.method, 'PATCH');
          expect(request.url.path, '/v1/people/c123:updateContact');
          updateBody = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response('{}', 200);
        }),
      );
      const employee = Employee(
        id: 'employee-1',
        employeeCode: 'E001',
        firstName: 'Somchai',
        lastName: 'Dee',
        nickname: '',
        department: Department(id: 'rad', code: 'RAD', name: 'Radiology'),
        position: 'Technologist',
      );

      final result = await service.exportEmployees(const [employee]);

      expect(result.created, 0);
      expect(result.updated, 1);
      expect(updateBody['etag'], 'etag-1');
      expect(
        (updateBody['userDefined'] as List).any(
          (entry) => (entry as Map)['key'] == 'external_reference',
        ),
        isTrue,
      );
    },
  );
}
