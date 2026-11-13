import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phakphum_calendar/features/admin/infrastructure/http_organization_admin_gateway.dart';

void main() {
  test('organization requests send a Google ID token and parse the response', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/organization-join-requests');
      expect(request.headers['Authorization'], 'Bearer test-id-token');
      expect(jsonDecode(request.body), {
        'organization_slug': 'radiology',
        'employee_id': 'EMP-001',
      });

      return http.Response(
        jsonEncode({
          'data': {
            'id': 42,
            'organization_id': 'organization-id',
            'organization_name': 'Radiology',
            'organization_slug': 'radiology',
            'employee_id': 'EMP-001',
            'status': 'pending',
          },
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final gateway = HttpOrganizationAdminGateway(
      baseUrl: 'https://api.example.com',
      idToken: () async => 'test-id-token',
      client: client,
    );

    final request = await gateway.requestMembership(
      organizationSlug: 'radiology',
      employeeId: 'EMP-001',
    );
    gateway.close();

    expect(request.id, 42);
    expect(request.organizationName, 'Radiology');
    expect(request.status, 'pending');
  });

  test('organization roles cannot be assigned outside the supported set', () async {
    final gateway = HttpOrganizationAdminGateway(
      baseUrl: 'https://api.example.com',
      idToken: () async => 'test-id-token',
      client: MockClient((_) async => http.Response('', 204)),
    );

    await expectLater(
      gateway.approveRequest(
        organizationId: 'organization-id',
        requestId: 42,
        role: 'owner',
      ),
      throwsArgumentError,
    );
    gateway.close();
  });

  test('remote organization API URLs must use HTTPS', () async {
    final gateway = HttpOrganizationAdminGateway(
      baseUrl: 'http://api.example.com',
      idToken: () async => 'test-id-token',
      client: MockClient((_) async => http.Response('', 204)),
    );

    await expectLater(
      gateway.organizations(),
      throwsFormatException,
    );
    gateway.close();
  });
}
