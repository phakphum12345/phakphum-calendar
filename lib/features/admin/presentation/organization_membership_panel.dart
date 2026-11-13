import 'dart:async';

import 'package:flutter/material.dart';

import '../../access_control/domain/access_control.dart';
import '../domain/organization_admin_gateway.dart';

class OrganizationMembershipPanel extends StatefulWidget {
  const OrganizationMembershipPanel({
    super.key,
    required this.apiBaseUrl,
    required this.currentEmail,
    required this.gateway,
  });

  final String apiBaseUrl;
  final String? currentEmail;
  final OrganizationAdminGateway gateway;

  @override
  State<OrganizationMembershipPanel> createState() =>
      _OrganizationMembershipPanelState();
}

class _OrganizationMembershipPanelState
    extends State<OrganizationMembershipPanel> {
  final _organizationSlug = TextEditingController();
  final _employeeId = TextEditingController();
  final Map<int, StaffRole> _selectedRoles = {};

  List<OrganizationMembership> _organizations = const [];
  List<OrganizationMember> _members = const [];
  List<OrganizationJoinRequest> _pendingRequests = const [];
  List<OrganizationJoinRequest> _myRequests = const [];
  String? _selectedOrganizationId;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.apiBaseUrl.trim().isEmpty) {
      _loading = false;
    } else {
      unawaited(_refresh());
    }
  }

  @override
  void didUpdateWidget(covariant OrganizationMembershipPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEmail != widget.currentEmail &&
        widget.apiBaseUrl.trim().isNotEmpty) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    _organizationSlug.dispose();
    _employeeId.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (widget.apiBaseUrl.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }
    if (widget.currentEmail?.trim().isNotEmpty != true) {
      setState(() {
        _loading = false;
        _error = null;
        _organizations = const [];
        _members = const [];
        _pendingRequests = const [];
        _myRequests = const [];
        _selectedOrganizationId = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final organizations = await widget.gateway.organizations();
      final selected = organizations.where(
        (item) => item.id == _selectedOrganizationId,
      );
      final organization = selected.isEmpty
          ? (organizations.isEmpty ? null : organizations.first)
          : selected.first;
      final myRequests = await widget.gateway.myRequests();
      final members = organization == null
          ? const <OrganizationMember>[]
          : await widget.gateway.members(organization.id);
      final pendingRequests = organization?.canReviewRequests == true
          ? await widget.gateway.pendingRequests(organization!.id)
          : const <OrganizationJoinRequest>[];

      if (!mounted) return;
      setState(() {
        _organizations = organizations;
        _selectedOrganizationId = organization?.id;
        _members = members;
        _pendingRequests = pendingRequests;
        _myRequests = myRequests;
      });
    } catch (exception) {
      if (mounted) setState(() => _error = '$exception');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectOrganization(String? organizationId) async {
    if (organizationId == null) return;
    setState(() => _selectedOrganizationId = organizationId);
    await _refresh();
  }

  Future<void> _submitJoinRequest() async {
    final slug = _organizationSlug.text.trim();
    final employeeId = _employeeId.text.trim();
    if (slug.isEmpty || employeeId.isEmpty) {
      setState(() => _error = 'กรอกรหัสองค์กรและรหัสพนักงานให้ครบ');
      return;
    }
    if (widget.currentEmail?.trim().isNotEmpty != true) {
      setState(() => _error = 'กรุณาเข้าสู่ระบบ Google ก่อนส่งคำขอ');
      return;
    }
    await _run(() async {
      await widget.gateway.requestMembership(
        organizationSlug: slug,
        employeeId: employeeId,
      );
      _organizationSlug.clear();
      _employeeId.clear();
      await _refresh();
    });
  }

  Future<void> _approve(OrganizationJoinRequest request) async {
    final role = _selectedRoles[request.id] ?? StaffRole.staff;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('อนุมัติคำขอเข้าร่วมองค์กร'),
        content: Text(
          'อนุมัติ ${request.name ?? request.email ?? 'ผู้ใช้'} '
          'ในบทบาท ${_roleLabel(role)} หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('อนุมัติ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final organizationId = _selectedOrganizationId;
    if (organizationId == null) return;
    await _run(() async {
      await widget.gateway.approveRequest(
        organizationId: organizationId,
        requestId: request.id,
        role: role.name,
      );
      await _refresh();
    });
  }

  Future<void> _reject(OrganizationJoinRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ปฏิเสธคำขอ'),
        content: Text(
          'ปฏิเสธคำขอของ ${request.name ?? request.email ?? 'ผู้ใช้'} หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ปฏิเสธ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final organizationId = _selectedOrganizationId;
    if (organizationId == null) return;
    await _run(() async {
      await widget.gateway.rejectRequest(
        organizationId: organizationId,
        requestId: request.id,
      );
      await _refresh();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (exception) {
      if (mounted) setState(() => _error = '$exception');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.apiBaseUrl.trim().isEmpty) {
      return _buildNotConfigured(context);
    }
    if (_loading && _organizations.isEmpty && _myRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'องค์กรและสมาชิก',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              onPressed: _busy || _loading ? null : _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'โหลดข้อมูลใหม่',
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'ผู้ใช้ใหม่ส่งคำขอพร้อมรหัสพนักงาน '
          'ผู้ดูแลตรวจโปรไฟล์และเลือกบทบาทก่อนอนุมัติ',
        ),
        if (_error case final message?) ...[
          const SizedBox(height: 12),
          MaterialBanner(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => setState(() => _error = null),
                child: const Text('ปิด'),
              ),
            ],
          ),
        ],
        if (_loading) const LinearProgressIndicator(),
        if (_organizations.isNotEmpty) ...[
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedOrganizationId),
            initialValue: _selectedOrganizationId,
            decoration: const InputDecoration(labelText: 'องค์กร'),
            items: [
              for (final organization in _organizations)
                DropdownMenuItem(
                  value: organization.id,
                  child: Text(
                    '${organization.name} · ${organization.slug} · '
                    '${_roleLabelForName(organization.role)}',
                  ),
                ),
            ],
            onChanged: _busy ? null : _selectOrganization,
          ),
          const SizedBox(height: 16),
          _buildMembers(context),
          if (_selectedOrganization?.canReviewRequests == true)
            _buildPendingRequests(context),
        ],
        const SizedBox(height: 24),
        _buildJoinRequestForm(context),
        const SizedBox(height: 24),
        _buildMyRequests(context),
      ],
    );
  }

  OrganizationMembership? get _selectedOrganization {
    for (final organization in _organizations) {
      if (organization.id == _selectedOrganizationId) return organization;
    }
    return null;
  }

  Widget _buildMembers(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('สมาชิก', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (_members.isEmpty)
        const Text('ยังไม่มีสมาชิกในองค์กรนี้')
      else
        for (final member in _members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(
                member.name.isEmpty ? '?' : member.name.substring(0, 1),
              ),
            ),
            title: Text(member.name),
            subtitle: Text('${member.email} · ${member.employeeId}'),
            trailing: Text(_roleLabelForName(member.role)),
          ),
    ],
  );

  Widget _buildPendingRequests(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(height: 32),
      Text('คำขอรออนุมัติ', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (_pendingRequests.isEmpty)
        const Text('ไม่มีคำขอใหม่')
      else
        for (final request in _pendingRequests)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.name ?? 'ชื่อไม่ระบุ',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(request.email ?? 'อีเมลไม่ระบุ'),
                  Text('รหัสพนักงาน: ${request.employeeId}'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<StaffRole>(
                    initialValue:
                        _selectedRoles[request.id] ?? StaffRole.staff,
                    decoration: const InputDecoration(labelText: 'บทบาท'),
                    items: [
                      for (final role in StaffRole.values)
                        DropdownMenuItem(
                          value: role,
                          child: Text(_roleLabel(role)),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (role) {
                            if (role != null) {
                              setState(
                                () => _selectedRoles[request.id] = role,
                              );
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _approve(request),
                        icon: const Icon(Icons.check),
                        label: const Text('อนุมัติ'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _reject(request),
                        icon: const Icon(Icons.close),
                        label: const Text('ปฏิเสธ'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    ],
  );

  Widget _buildJoinRequestForm(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ขอเข้าร่วมองค์กร',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'ขอรหัสองค์กรจากผู้ดูแล ระบบจะแสดงชื่อและอีเมลจาก Google '
            'ให้ผู้ดูแลตรวจสอบ',
          ),
          if (widget.currentEmail?.trim().isNotEmpty != true) ...[
            const SizedBox(height: 8),
            const Text('เข้าสู่ระบบ Google ก่อนส่งคำขอ'),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _organizationSlug,
            enabled: !_busy,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'รหัสองค์กร',
              hintText: 'รหัสที่ผู้ดูแลแจ้ง',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _employeeId,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitJoinRequest(),
            decoration: const InputDecoration(labelText: 'รหัสพนักงาน'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ||
                    widget.currentEmail?.trim().isNotEmpty != true
                ? null
                : _submitJoinRequest,
            icon: const Icon(Icons.send_outlined),
            label: const Text('ส่งคำขอ'),
          ),
        ],
      ),
    ),
  );

  Widget _buildMyRequests(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('คำขอของฉัน', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (_myRequests.isEmpty)
        const Text('ยังไม่มีคำขอเข้าร่วมองค์กร')
      else
        for (final request in _myRequests)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_requestStatusIcon(request.status)),
            title: Text(request.organizationName ?? request.organizationSlug ?? ''),
            subtitle: Text(
              '${request.employeeId} · ${_requestStatusLabel(request.status)}',
            ),
            trailing: request.approvedRole == null
                ? null
                : Text(_roleLabelForName(request.approvedRole!)),
          ),
    ],
  );

  Widget _buildNotConfigured(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'องค์กรและสมาชิก',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'ยังไม่ได้เชื่อมต่อ Laravel API '
            '(ORGANIZATION_API_BASE_URL) '
            'การส่งคำขอและอนุมัติสมาชิกจึงยังใช้ไม่ได้ '
            'ส่วนสิทธิ์เฉพาะอุปกรณ์นี้ยังอยู่ในแท็บแยก',
          ),
        ),
      ),
    ],
  );
}

IconData _requestStatusIcon(String status) => switch (status) {
  'approved' => Icons.check_circle_outline,
  'rejected' => Icons.cancel_outlined,
  _ => Icons.hourglass_top,
};

String _requestStatusLabel(String status) => switch (status) {
  'approved' => 'อนุมัติแล้ว',
  'rejected' => 'ไม่อนุมัติ',
  _ => 'รอตรวจสอบ',
};

String _roleLabel(StaffRole role) => switch (role) {
  StaffRole.staff => 'Staff',
  StaffRole.incharge => 'In-charge',
  StaffRole.manager => 'Manager',
  StaffRole.admin => 'Admin',
};

String _roleLabelForName(String role) => switch (role) {
  'owner' => 'Owner',
  'staff' => 'Staff',
  'incharge' => 'In-charge',
  'manager' => 'Manager',
  'admin' => 'Admin',
  _ => role,
};
