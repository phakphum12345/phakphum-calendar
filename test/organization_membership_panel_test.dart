import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/access_control/domain/access_control.dart';
import 'package:phakphum_calendar/features/admin/domain/organization_admin_gateway.dart';
import 'package:phakphum_calendar/features/admin/presentation/organization_membership_panel.dart';

void main() {
  testWidgets('admin reviews profile and approves with selected role', (
    tester,
  ) async {
    final gateway = _FakeOrganizationAdminGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizationMembershipPanel(
            apiBaseUrl: 'https://api.example.com',
            currentEmail: 'admin@example.com',
            gateway: gateway,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Nurse'), findsOneWidget);
    expect(find.text('new.nurse@example.com'), findsOneWidget);
    expect(find.text('รหัสพนักงาน: EMP-001'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<StaffRole>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manager').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'อนุมัติ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'อนุมัติ').last);
    await tester.pumpAndSettle();

    expect(gateway.approvedRole, 'manager');
    expect(find.text('ไม่มีคำขอใหม่'), findsOneWidget);
  });
}

class _FakeOrganizationAdminGateway implements OrganizationAdminGateway {
  bool _hasPendingRequest = true;
  String? approvedRole;

  @override
  Future<List<OrganizationMembership>> organizations() async => const [
    OrganizationMembership(
      id: 'organization-id',
      name: 'Radiology',
      slug: 'radiology',
      employeeId: 'EMP-OWNER',
      role: 'admin',
    ),
  ];

  @override
  Future<List<OrganizationMember>> members(String organizationId) async =>
      const [];

  @override
  Future<List<OrganizationJoinRequest>> pendingRequests(
    String organizationId,
  ) async => _hasPendingRequest
      ? const [
          OrganizationJoinRequest(
            id: 1,
            name: 'New Nurse',
            email: 'new.nurse@example.com',
            employeeId: 'EMP-001',
            status: 'pending',
          ),
        ]
      : const [];

  @override
  Future<List<OrganizationJoinRequest>> myRequests() async => const [];

  @override
  Future<OrganizationJoinRequest> requestMembership({
    required String organizationSlug,
    required String employeeId,
  }) async => throw UnimplementedError();

  @override
  Future<void> approveRequest({
    required String organizationId,
    required int requestId,
    required String role,
  }) async {
    approvedRole = role;
    _hasPendingRequest = false;
  }

  @override
  Future<void> rejectRequest({
    required String organizationId,
    required int requestId,
  }) async {
    _hasPendingRequest = false;
  }

  @override
  void close() {}
}
