import 'dart:async';

import 'package:flutter/material.dart';

import '../../access_control/domain/access_control.dart';
import '../domain/admin_access_config.dart';
import '../domain/organization_admin_gateway.dart';
import '../infrastructure/http_organization_admin_gateway.dart';
import 'organization_membership_panel.dart';

class AdminAccessPage extends StatefulWidget {
  const AdminAccessPage({
    super.key,
    required this.currentEmail,
    required this.apiBaseUrl,
    required this.idToken,
    this.organizationGateway,
  });

  final String? currentEmail;
  final String apiBaseUrl;
  final Future<String?> Function() idToken;
  final OrganizationAdminGateway? organizationGateway;

  @override
  State<AdminAccessPage> createState() => _AdminAccessPageState();
}

class _AdminAccessPageState extends State<AdminAccessPage> {
  late final OrganizationAdminGateway _organizationGateway;

  @override
  void initState() {
    super.initState();
    _organizationGateway =
        widget.organizationGateway ??
        HttpOrganizationAdminGateway(
          baseUrl: widget.apiBaseUrl,
          idToken: widget.idToken,
        );
  }

  @override
  void dispose() {
    _organizationGateway.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.groups_outlined), text: 'องค์กรและผู้ใช้'),
            Tab(icon: Icon(Icons.devices_outlined), text: 'สิทธิ์ในเครื่อง'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              OrganizationMembershipPanel(
                apiBaseUrl: widget.apiBaseUrl,
                currentEmail: widget.currentEmail,
                gateway: _organizationGateway,
              ),
              _LocalAdminAccessPage(currentEmail: widget.currentEmail),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LocalAdminAccessPage extends StatefulWidget {
  const _LocalAdminAccessPage({required this.currentEmail});

  final String? currentEmail;

  @override
  State<_LocalAdminAccessPage> createState() => _LocalAdminAccessPageState();
}

class _LocalAdminAccessPageState extends State<_LocalAdminAccessPage> {
  final repository = AdminAccessRepository();
  AdminAccessConfig config = const AdminAccessConfig.empty();
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final loaded = await repository.load();
      if (mounted) setState(() => config = loaded);
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _bootstrap() async {
    final email = widget.currentEmail?.trim().toLowerCase();
    if (email == null || email.isEmpty) return;
    await _save([AdminUserAccess(email: email, role: StaffRole.admin)]);
  }

  Future<void> _addUser() async {
    final user = await showDialog<AdminUserAccess>(
      context: context,
      builder: (context) => const _AdminUserDialog(),
    );
    if (user == null) return;
    final updated = [...config.users];
    final index = updated.indexWhere(
      (item) => item.email.toLowerCase() == user.email.toLowerCase(),
    );
    if (index == -1) {
      updated.add(user);
    } else {
      updated[index] = user;
    }
    await _save(updated);
  }

  Future<void> _removeUser(AdminUserAccess user) async {
    if (user.role == StaffRole.admin &&
        config.users.where((item) => item.role == StaffRole.admin).length ==
            1) {
      setState(() => error = 'ไม่สามารถลบ Admin คนสุดท้ายได้');
      return;
    }
    await _save(
      config.users.where((item) => item.email != user.email).toList(),
    );
  }

  Future<void> _save(List<AdminUserAccess> users) async {
    try {
      final next = AdminAccessConfig(users: List.unmodifiable(users));
      await repository.save(next);
      if (mounted) setState(() => config = next);
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!config.isConfigured) return _buildBootstrap(context);
    if (!config.isAdmin(widget.currentEmail)) {
      return const _AdminDenied();
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Admin Console',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton.filled(
              onPressed: _addUser,
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'เพิ่มผู้ใช้และบทบาท',
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('จัดการบทบาทผู้ใช้สำหรับอุปกรณ์และเบราว์เซอร์นี้'),
        if (error case final message?) ...[
          const SizedBox(height: 12),
          MaterialBanner(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => setState(() => error = null),
                child: const Text('ปิด'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        for (final user in config.users)
          ListTile(
            leading: CircleAvatar(
              child: Icon(
                user.role == StaffRole.admin
                    ? Icons.admin_panel_settings_outlined
                    : Icons.person_outline,
              ),
            ),
            title: Text(user.email),
            subtitle: Text(_roleLabel(user.role)),
            trailing: IconButton(
              onPressed: () => _removeUser(user),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'ลบสิทธิ์',
            ),
          ),
        const SizedBox(height: 16),
        const _PermissionSummary(),
      ],
    );
  }

  Widget _buildBootstrap(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              'ยังไม่ได้กำหนด Admin',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              widget.currentEmail == null
                  ? 'เข้าสู่ระบบ Google ก่อนกำหนด Admin คนแรก'
                  : 'บัญชีที่จะกำหนด: ${widget.currentEmail}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: widget.currentEmail == null ? null : _bootstrap,
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('กำหนดบัญชีนี้เป็น Admin'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AdminDenied extends StatelessWidget {
  const _AdminDenied();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 52),
        SizedBox(height: 12),
        Text('บัญชีนี้ไม่มีสิทธิ์เปิด Admin Console'),
      ],
    ),
  );
}

class _AdminUserDialog extends StatefulWidget {
  const _AdminUserDialog();

  @override
  State<_AdminUserDialog> createState() => _AdminUserDialogState();
}

class _AdminUserDialogState extends State<_AdminUserDialog> {
  final email = TextEditingController();
  StaffRole role = StaffRole.staff;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  void _submit() {
    final value = email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return;
    Navigator.pop(context, AdminUserAccess(email: value, role: role));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('เพิ่มผู้ใช้และบทบาท'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: email,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'อีเมลบัญชี Google'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<StaffRole>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'บทบาท'),
            items: [
              for (final value in StaffRole.values)
                DropdownMenuItem(value: value, child: Text(_roleLabel(value))),
            ],
            onChanged: (value) => setState(() => role = value ?? role),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(onPressed: _submit, child: const Text('บันทึก')),
    ],
  );
}

class _PermissionSummary extends StatelessWidget {
  const _PermissionSummary();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('สิทธิ์ตามบทบาท', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final role in StaffRole.values)
        ExpansionTile(
          title: Text(_roleLabel(role)),
          children: [
            for (final permission in AccessPolicy.permissionsFor(role))
              ListTile(
                dense: true,
                leading: const Icon(Icons.check, size: 18),
                title: Text(_permissionLabel(permission)),
              ),
          ],
        ),
    ],
  );
}

String _roleLabel(StaffRole role) => switch (role) {
  StaffRole.staff => 'Staff',
  StaffRole.incharge => 'In-charge',
  StaffRole.manager => 'Manager',
  StaffRole.admin => 'Admin',
};

String _permissionLabel(Permission permission) => switch (permission) {
  Permission.viewOwnSchedule => 'ดูตารางเวรของตนเอง',
  Permission.viewDepartmentSchedule => 'ดูตารางเวรของหน่วยงาน',
  Permission.requestShiftExchange => 'ขอแลกเวร',
  Permission.approveShiftExchange => 'อนุมัติแลกเวร',
  Permission.manageDepartmentSchedule => 'จัดการตารางเวรหน่วยงาน',
  Permission.manageOrganization => 'จัดการองค์กรและผู้ใช้',
  Permission.viewAuditLog => 'ดู Audit log',
};
