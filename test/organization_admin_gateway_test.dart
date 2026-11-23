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


  test('member management uses authenticated PATCH and DELETE requests', () async {
    final calls = <http.Request>[];
    final client = MockClient((request) async {
      calls.add(request);
      return http.Response(
        jsonEncode({'data': {'user_id': '42', 'role': 'manager', 'status': 'active'}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final gateway = HttpOrganizationAdminGateway(
      baseUrl: 'https://api.example.com',
      idToken: () async => 'test-id-token',
      client: client,
    );

    await gateway.updateMemberRole(
      organizationId: 'organization-id',
      userId: '42',
      role: 'manager',
    );
    await expectLater(
      gateway.updateMemberRole(
        organizationId: 'organization-id',
        userId: '42',
        role: 'owner',
      ),
      throwsArgumentError,
    );
    await gateway.removeMember(
      organizationId: 'organization-id',
      userId: '42',
    );
    gateway.close();

    expect(calls.map((request) => request.method), ['PATCH', 'DELETE']);
    expect(calls.first.url.path, '/api/v1/organizations/organization-id/members/42');
    expect(jsonDecode(calls.first.body), {'role': 'manager'});
    expect(calls.last.url.path, '/api/v1/organizations/organization-id/members/42');
    expect(
      calls.every((request) =>
          request.headers['Authorization'] == 'Bearer test-id-token'),
      isTrue,
    );
  });

  test('membership audit uses authenticated cursor pagination and parses states', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.path,
        '/api/v1/organizations/organization-id/membership-audit',
      );
      expect(request.url.queryParameters, {
        'limit': '1',
        'before_id': '9',
      });
      expect(request.headers['Authorization'], 'Bearer test-id-token');
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 8,
              'action': 'role_changed',
              'actor': {'user_id': '1', 'name': 'Owner'},
              'subject': {'user_id': '2', 'name': 'Member'},
              'before': {'role': 'staff', 'status': 'active'},
              'after': {'role': 'manager', 'status': 'active'},
              'created_at': '2026-11-23T10:00:00.000000Z',
            },
          ],
          'meta': {'limit': 1, 'next_before_id': 7},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final gateway = HttpOrganizationAdminGateway(
      baseUrl: 'https://api.example.com',
      idToken: () async => 'test-id-token',
      client: client,
    );

    final page = await gateway.membershipAudit(
      'organization-id',
      limit: 1,
      beforeId: 9,
    );
    gateway.close();

    expect(page.events, hasLength(1));
    expect(page.events.single.action, 'role_changed');
    expect(page.events.single.actorName, 'Owner');
    expect(page.events.single.subjectName, 'Member');
    expect(page.events.single.before?['role'], 'staff');
    expect(page.events.single.after?['role'], 'manager');
    expect(page.nextBeforeId, 7);
  });

  test('membership audit rejects invalid pagination bounds', () async {
    final gateway = HttpOrganizationAdminGateway(
      baseUrl: 'https://api.example.com',
      idToken: () async => 'test-id-token',
      client: MockClient((_) async => http.Response('', 204)),
    );
    await expectLater(
      gateway.membershipAudit('organization-id', limit: 101),
      throwsArgumentError,
    );
    await expectLater(
      gateway.membershipAudit('organization-id', beforeId: 0),
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
