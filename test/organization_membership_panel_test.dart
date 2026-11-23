import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/access_control/domain/access_control.dart';
import 'package:phakphum_calendar/features/admin/domain/organization_admin_gateway.dart';
import 'package:phakphum_calendar/features/admin/presentation/organization_membership_panel.dart';

void main() {


  testWidgets('stale membership audit responses cannot overwrite a newer selection', (
    tester,
  ) async {
    final gateway = _RaceOrganizationAdminGateway();
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

    final auditHeading = find.text('ประวัติการเปลี่ยนแปลงสมาชิก');
    await tester.ensureVisible(auditHeading);
    await tester.tap(auditHeading);
    await tester.pump();
    expect(gateway.auditCalls['organization-id'], hasLength(1));

    Future<void> selectOrganization({
      required String currentOrganizationId,
      required String name,
    }) async {
      final organizationField = find.byKey(
        ValueKey<String?>(currentOrganizationId),
      );
      expect(organizationField, findsOneWidget);
      await tester.ensureVisible(organizationField);
      await tester.tap(organizationField);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(name).last);
      await tester.pumpAndSettle();
    }

    await selectOrganization(
      currentOrganizationId: 'organization-id',
      name: 'Cardiology',
    );
    await selectOrganization(
      currentOrganizationId: 'cardiology-id',
      name: 'Radiology',
    );

    await tester.tap(auditHeading);
    await tester.pumpAndSettle();
    await tester.tap(auditHeading);
    await tester.pump();
    expect(gateway.auditCalls['organization-id'], hasLength(2));

    gateway.auditCalls['organization-id']!.last.complete(
      _auditPage(actorName: 'New Owner'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ผู้ดำเนินการ: New Owner'), findsOneWidget);

    gateway.auditCalls['organization-id']!.first.complete(
      _auditPage(actorName: 'Old Owner'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ผู้ดำเนินการ: New Owner'), findsOneWidget);
    expect(find.textContaining('ผู้ดำเนินการ: Old Owner'), findsNothing);
  });

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

    expect(find.text('Owner'), findsOneWidget);
    expect(find.byTooltip('จัดการสมาชิก'), findsOneWidget);
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
    expect(find.text('Owner'), findsOneWidget);
    expect(find.byTooltip('จัดการสมาชิก'), findsNothing);
  });

  testWidgets('admin can view organization membership audit history', (
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

    final auditHeading = find.text('ประวัติการเปลี่ยนแปลงสมาชิก');
    await tester.ensureVisible(auditHeading);
    await tester.tap(auditHeading);
    await tester.pumpAndSettle();

    expect(gateway.auditRequests, 1);
    expect(find.text('เปลี่ยนบทบาทสมาชิก'), findsOneWidget);
    expect(find.textContaining('ผู้ดำเนินการ: Owner'), findsOneWidget);
    expect(find.textContaining('สมาชิก: Member'), findsOneWidget);
    expect(find.textContaining('บทบาท: Staff'), findsOneWidget);
    expect(find.textContaining('บทบาท: Manager'), findsOneWidget);
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

    final roleDropdown = find.byType(DropdownButtonFormField<StaffRole>);
    await tester.ensureVisible(roleDropdown);
    await tester.pumpAndSettle();
    await tester.tap(roleDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manager').last);
    await tester.pumpAndSettle();

    final approveButton = find.widgetWithText(FilledButton, 'อนุมัติ').first;
    await tester.ensureVisible(approveButton);
    await tester.pumpAndSettle();
    await tester.tap(approveButton);
    await tester.pumpAndSettle();

    final confirmButton = find.widgetWithText(FilledButton, 'อนุมัติ').last;
    await tester.ensureVisible(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(confirmButton);
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
  int auditRequests = 0;
  List<OrganizationMember> _members = const [
    OrganizationMember(
      userId: 'member-id',
      name: 'Member',
      email: 'member@example.com',
      employeeId: 'EMP-MEMBER',
      role: 'staff',
      status: 'active',
    ),
    OrganizationMember(
      userId: 'owner-id',
      name: 'Owner',
      email: 'owner@example.com',
      employeeId: 'EMP-OWNER',
      role: 'owner',
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
  Future<OrganizationMembershipAuditPage> membershipAudit(
    String organizationId, {
    int limit = 50,
    int? beforeId,
  }) async {
    auditRequests++;
    return OrganizationMembershipAuditPage(
      events: [
        OrganizationMembershipAuditEvent(
          id: 1,
          action: 'role_changed',
          actorUserId: 'owner-id',
          actorName: 'Owner',
          subjectUserId: 'member-id',
          subjectName: 'Member',
          before: const {'role': 'staff', 'status': 'active'},
          after: const {'role': 'manager', 'status': 'active'},
          createdAt: DateTime.utc(2026, 11, 23, 10),
        ),
      ],
    );
  }

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


class _RaceOrganizationAdminGateway extends _FakeOrganizationAdminGateway {
  final Map<String, List<Completer<OrganizationMembershipAuditPage>>>
      auditCalls = {};

  @override
  Future<List<OrganizationMembership>> organizations() async => const [
    OrganizationMembership(
      id: 'organization-id',
      name: 'Radiology',
      slug: 'radiology',
      employeeId: 'EMP-OWNER',
      role: 'admin',
    ),
    OrganizationMembership(
      id: 'cardiology-id',
      name: 'Cardiology',
      slug: 'cardiology',
      employeeId: 'EMP-OWNER',
      role: 'admin',
    ),
  ];

  @override
  Future<OrganizationMembershipAuditPage> membershipAudit(
    String organizationId, {
    int limit = 50,
    int? beforeId,
  }) {
    final completer = Completer<OrganizationMembershipAuditPage>();
    auditCalls.putIfAbsent(organizationId, () => []).add(completer);
    return completer.future;
  }
}

OrganizationMembershipAuditPage _auditPage({required String actorName}) =>
    OrganizationMembershipAuditPage(
      events: [
        OrganizationMembershipAuditEvent(
          id: actorName == 'New Owner' ? 2 : 1,
          action: 'role_changed',
          actorUserId: 'owner-id',
          actorName: actorName,
          subjectUserId: 'member-id',
          subjectName: 'Member',
          before: const {'role': 'staff'},
          after: const {'role': 'manager'},
          createdAt: DateTime.utc(2026, 11, 23, 10),
        ),
      ],
    );
