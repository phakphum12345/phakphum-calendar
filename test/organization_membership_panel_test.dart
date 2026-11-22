import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/access_control/domain/access_control.dart';
import 'package:phakphum_calendar/features/admin/domain/organization_admin_gateway.dart';
import 'package:phakphum_calendar/features/admin/presentation/organization_membership_panel.dart';

void main() {

  testWidgets('admin can change a member role and remove that member', (
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

    await tester.tap(find.byTooltip('จัดการสมาชิก'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เปลี่ยนบทบาท'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<StaffRole>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manager').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึกบทบาท'));
    await tester.pumpAndSettle();

    expect(gateway.updatedRole, 'manager');

    await tester.tap(find.byTooltip('จัดการสมาชิก'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('นำออกจากองค์กร'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('นำออก'));
    await tester.pumpAndSettle();

    expect(gateway.removedMemberId, 'member-id');
  });

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

    expect(find.text('Member'), findsOneWidget);
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
  String? updatedRole;
  String? removedMemberId;
  List<OrganizationMember> _members = const [
    OrganizationMember(
      userId: 'member-id',
      name: 'Member',
      email: 'member@example.com',
      employeeId: 'EMP-MEMBER',
      role: 'staff',
      status: 'active',
    ),
  ];

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
      _members;

  @override
  Future<void> updateMemberRole({
    required String organizationId,
    required String userId,
    required String role,
  }) async {
    updatedRole = role;
    _members = [
      for (final member in _members)
        if (member.userId == userId)
          OrganizationMember(
            userId: member.userId,
            name: member.name,
            email: member.email,
            employeeId: member.employeeId,
            role: role,
            status: member.status,
          )
        else
          member,
    ];
  }

  @override
  Future<void> removeMember({
    required String organizationId,
    required String userId,
  }) async {
    removedMemberId = userId;
    _members = _members.where((member) => member.userId != userId).toList();
  }

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
