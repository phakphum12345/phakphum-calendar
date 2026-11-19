import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_day.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_assignment.dart';
import 'package:phakphum_calendar/domain/entities/shift_type.dart';
import 'package:phakphum_calendar/features/shift_exchange/infrastructure/shift_transaction_api_client.dart';
import 'package:phakphum_calendar/features/shift_exchange/presentation/pages/shift_exchange_page.dart';

void main() {
  testWidgets('creates an organization give-up request from the canonical roster', (tester) async {
    final date = DateTime(2026, 11, 18);
    final alice = _employee('A');
    final bob = _employee('B');
    final morning = _shift('morning', 'M', 8, 16);
    final schedule = Schedule(
      id: 'schedule-1',
      name: 'November roster',
      months: [
        ScheduleMonth.empty(date).replaceDay(
          ScheduleDay(
            date: date,
            assignments: [
              ShiftAssignment(employee: alice, shift: morning),
              ShiftAssignment(employee: bob, shift: _shift('evening', 'E', 16, 23)),
            ],
          ),
        ),
      ],
    );
    final requests = <http.Request>[];
    final created = _transaction('pending_response');
    final approved = _transaction('partially_accepted');
    final client = ShiftTransactionApiClient(
      baseUrl: 'https://calendar.example.test',
      idTokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          if (request.url.path == '/api/v1/organizations') {
            return http.Response(jsonEncode({
              'data': [{
                'id': 'org-uuid',
                'name': 'Radiology',
                'slug': 'radiology',
                'employee_id': 'A',
                'role': 'owner',
              }],
            }), 200);
          }
          if (request.url.path == '/api/v1/organizations/org-uuid/members') {
            return http.Response(jsonEncode({
              'data': [
                {
                  'user_id': '1',
                  'name': 'Alice',
                  'email': 'alice@example.com',
                  'employee_id': 'A',
                  'role': 'owner',
                  'status': 'active',
                },
                {
                  'user_id': '2',
                  'name': 'Bob',
                  'email': 'bob@example.com',
                  'employee_id': 'B',
                  'role': 'staff',
                  'status': 'active',
                },
              ],
            }), 200);
          }
          return http.Response(jsonEncode({'data': []}), 200);
        }
        if (request.url.path == '/api/v1/shift-transactions') {
          return http.Response(jsonEncode({'data': created}), 201);
        }
        return http.Response(jsonEncode({'data': approved}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftExchangePage(
            schedule: schedule,
            organizationMode: true,
            historyApiClient: client,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New shift transaction'));
    await tester.pumpAndSettle();

    final dropdowns = find.byType(DropdownButtonFormField<String>);
    await tester.tap(dropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B · Bob').last);
    await tester.pumpAndSettle();

    await tester.tap(dropdowns.at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('18/11/2026 · M · Alice').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create request'));
    await tester.pumpAndSettle();

    final createRequest = requests.firstWhere(
      (request) => request.method == 'POST' &&
          request.url.path == '/api/v1/shift-transactions',
    );
    final payload = jsonDecode(createRequest.body) as Map<String, dynamic>;
    expect(payload['mode'], 'organization');
    expect(payload['organization_id'], 'org-uuid');
    expect(payload['type'], 'give_up');
    expect(payload['participants'][0]['employee_id'], 'A');
    expect(payload['participants'][1]['employee_id'], 'B');
    expect(payload['participants'][1]['user_id'], 2);
    expect(payload['transfers'], hasLength(1));
    expect(payload['transfers'][0]['from_employee_id'], 'A');
    expect(payload['transfers'][0]['to_employee_id'], 'B');
    expect(requests.any((request) => request.url.path.endsWith('/confirm')), isTrue);
    client.close();
  });
}

Employee _employee(String id) => Employee(
  id: 'legacy:$id',
  employeeCode: id,
  firstName: id == 'A' ? 'Alice' : 'Bob',
  lastName: '',
  nickname: '',
  department: const Department(id: 'D', code: 'D', name: 'Department'),
  position: 'Staff',
);

ShiftType _shift(String id, String code, int startHour, int endHour) => ShiftType(
  id: id,
  code: code,
  name: code,
  color: 0,
  startTime: Duration(hours: startHour),
  endTime: Duration(hours: endHour),
  workingHours: (endHour - startHour).toDouble(),
);

Map<String, dynamic> _transaction(String status) => {
  'id': '11111111-1111-4111-8111-111111111111',
  'mode': 'organization',
  'type': 'give_up',
  'status': status,
  'sync_status': 'not_started',
  'version': 1,
  'created_at': '2026-11-18T01:00:00Z',
  'updated_at': '2026-11-18T01:00:00Z',
  'organization_id': 'org-uuid',
  'participants': [
    {
      'employee_id': 'A',
      'role': 'requester',
      'name': 'Alice',
      'confirmed_at': '2026-11-18T02:00:00Z',
      'is_current_user': true,
    },
    {
      'employee_id': 'B',
      'role': 'recipient',
      'name': 'Bob',
      'confirmed_at': null,
      'is_current_user': false,
    },
  ],
  'transfers': [
    {
      'transfer_key': 'transfer-1',
      'shift_id': 'shift-1',
      'from_employee_id': 'A',
      'to_employee_id': 'B',
      'shift_code': 'M',
      'starts_at': '2026-11-18T01:00:00Z',
      'ends_at': '2026-11-18T09:00:00Z',
      'purpose': 'give_up',
      'fulfilled_at': null,
    },
  ],
  'timeline': [],
};
