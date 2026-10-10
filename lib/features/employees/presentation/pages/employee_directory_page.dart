import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../domain/entities/department.dart';
import '../../../../domain/entities/employee.dart';
import '../../../../domain/entities/schedule.dart';
import '../../../../l10n/l10n.dart';
import '../../application/employee_directory_service.dart';
import '../controllers/employee_directory_controller.dart';

/// Responsive employee directory backed by the canonical schedule.
class EmployeeDirectoryPage extends StatefulWidget {
  const EmployeeDirectoryPage({
    required this.schedule,
    this.controllerFactory,
    super.key,
  });

  final Schedule schedule;
  final EmployeeDirectoryController Function(Schedule schedule)?
  controllerFactory;

  @override
  State<EmployeeDirectoryPage> createState() => _EmployeeDirectoryPageState();
}

class _EmployeeDirectoryPageState extends State<EmployeeDirectoryPage> {
  late final EmployeeDirectoryController controller =
      widget.controllerFactory?.call(widget.schedule) ??
      EmployeeDirectoryController(schedule: widget.schedule);
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(controller.load());
  }

  @override
  void didUpdateWidget(covariant EmployeeDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller.updateSchedule(widget.schedule);
  }

  @override
  void dispose() {
    searchController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final employees = controller.employees;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.employees,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              FilledButton.icon(
                onPressed: controller.loading
                    ? null
                    : () => _editEmployee(context),
                icon: const Icon(Icons.person_add_outlined),
                label: Text(context.l10n.addEmployee),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(context.l10n.employeeDirectoryDescription),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: controller.loading
                    ? null
                    : () => _syncDirectory(context),
                icon: const Icon(Icons.cloud_sync_outlined),
                label: const Text('ซิงค์ข้ามอุปกรณ์'),
              ),
              OutlinedButton.icon(
                onPressed: controller.loading
                    ? null
                    : () => _importGoogleContacts(context),
                icon: const Icon(Icons.contact_page_outlined),
                label: const Text('นำเข้าจาก Google Contacts'),
              ),
              OutlinedButton.icon(
                onPressed:
                    controller.loading ||
                        controller.contactExportCandidates.isEmpty
                    ? null
                    : () => _exportGoogleContacts(context),
                icon: const Icon(Icons.upload_outlined),
                label: const Text('ส่งออกไป Google Contacts'),
              ),
            ],
          ),
          if (controller.error case final error?) ...[
            const SizedBox(height: 12),
            MaterialBanner(
              content: Text(error),
              actions: [
                TextButton(
                  onPressed: controller.load,
                  child: Text(context.l10n.retry),
                ),
              ],
            ),
          ],
          if (controller.loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  controller: searchController,
                  onChanged: controller.updateQuery,
                  decoration: InputDecoration(
                    labelText: context.l10n.searchEmployees,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: controller.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: context.l10n.clear,
                            onPressed: () {
                              searchController.clear();
                              controller.updateQuery('');
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
              ),
              DropdownButton<String?>(
                value: controller.departmentId,
                hint: Text(context.l10n.allDepartments),
                onChanged: controller.updateDepartment,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(context.l10n.allDepartments),
                  ),
                  for (final id in controller.departmentIds)
                    DropdownMenuItem(value: id, child: Text(id)),
                ],
              ),
              FilterChip(
                selected: controller.activeOnly,
                onSelected: controller.updateActiveOnly,
                label: Text(context.l10n.activeEmployeesOnly),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (employees.isEmpty)
            _EmployeeEmptyState(hasFilters: controller.query.isNotEmpty)
          else
            Card(
              child: Column(
                children: [
                  for (var index = 0; index < employees.length; index++) ...[
                    ExpansionTile(
                      leading: CircleAvatar(
                        child: Text(
                          employees[index].displayName.characters.firstOrNull ??
                              '?',
                        ),
                      ),
                      title: Text(employees[index].displayName),
                      subtitle: Text(
                        [
                          employees[index].employeeCode,
                          employees[index].position,
                          employees[index].department.name,
                        ].where((value) => value.trim().isNotEmpty).join(' • '),
                      ),
                      trailing: employees[index].active
                          ? PopupMenuButton<_EmployeeAction>(
                              onSelected: (action) {
                                if (action == _EmployeeAction.edit) {
                                  unawaited(
                                    _editEmployee(
                                      context,
                                      employee: employees[index],
                                    ),
                                  );
                                } else {
                                  unawaited(
                                    _confirmDeactivate(
                                      context,
                                      employees[index],
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: _EmployeeAction.edit,
                                  child: Text(context.l10n.edit),
                                ),
                                PopupMenuItem(
                                  value: _EmployeeAction.deactivate,
                                  child: Text(context.l10n.deactivate),
                                ),
                              ],
                            )
                          : const Icon(Icons.block_outlined),
                      children: [
                        _EmployeeShiftHistory(
                          shifts: controller.shiftsFor(employees[index].id),
                          locale: Localizations.localeOf(context).languageCode,
                        ),
                      ],
                    ),
                    if (index != employees.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      );
    },
  );

  Future<void> _syncDirectory(BuildContext context) async {
    final confirmed = await _confirmAction(
      context,
      title: 'ซิงค์รายชื่อข้ามอุปกรณ์?',
      message:
          'แอปจะรวมรายชื่อในอุปกรณ์นี้กับไฟล์ส่วนตัวใน Google Drive '
          'และใช้ข้อมูลในอุปกรณ์นี้เมื่อพบรหัสบุคลากรซ้ำ',
    );
    if (confirmed != true) return;
    try {
      final result = await controller.syncWithGoogle();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ซิงค์ไม่สำเร็จ: $error')));
      }
    }
  }

  Future<void> _importGoogleContacts(BuildContext context) async {
    try {
      final contacts = await controller.previewGoogleContactsImport();
      if (!context.mounted) return;
      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Contacts ไม่มีรายชื่อที่นำเข้าได้'),
          ),
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('ตรวจสอบรายชื่อ (${contacts.length})'),
          content: SizedBox(
            width: 460,
            height: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'รายการต่อไปนี้จะเพิ่มหรือรวมเข้ากับรายชื่อบุคลากร:',
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, index) => ListTile(
                      dense: true,
                      title: Text(contacts[index].displayName),
                      subtitle: Text(contacts[index].employeeCode),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ยืนยันนำเข้า'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final imported = await controller.importGoogleContacts(contacts);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('นำเข้ารายชื่อ $imported รายการแล้ว')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('นำเข้าไม่สำเร็จ: $error')));
      }
    }
  }

  Future<void> _exportGoogleContacts(BuildContext context) async {
    final candidates = controller.contactExportCandidates;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ส่งออก ${candidates.length} รายชื่อไป Google Contacts?'),
        content: SizedBox(
          width: 460,
          height: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'รายชื่อที่เคยส่งออกโดยแอปจะได้รับการปรับปรุง '
                'รายชื่ออื่นจะถูกสร้างใหม่ ไม่มีการลบรายชื่อใน Google Contacts',
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: candidates.length,
                  itemBuilder: (context, index) => ListTile(
                    dense: true,
                    title: Text(candidates[index].displayName),
                    subtitle: Text(candidates[index].employeeCode),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันส่งออก'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await controller.exportGoogleContacts();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ส่งออกสำเร็จ: เพิ่ม ${result.created} • ปรับปรุง ${result.updated}',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ส่งออกไม่สำเร็จ: $error')));
      }
    }
  }

  Future<bool?> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.confirm),
        ),
      ],
    ),
  );

  Future<void> _editEmployee(BuildContext context, {Employee? employee}) async {
    final result = await showDialog<Employee>(
      context: context,
      builder: (context) => _EmployeeDialog(employee: employee),
    );
    if (result == null) return;
    await controller.saveEmployee(result);
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    Employee employee,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deactivateEmployee),
        content: Text(
          context.l10n.deactivateEmployeeConfirmation(employee.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deactivateEmployee(employee);
    }
  }
}

enum _EmployeeAction { edit, deactivate }

class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog({this.employee});

  final Employee? employee;

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final formKey = GlobalKey<FormState>();
  late final code = TextEditingController(
    text: widget.employee?.employeeCode ?? '',
  );
  late final firstName = TextEditingController(
    text: widget.employee?.firstName ?? '',
  );
  late final lastName = TextEditingController(
    text: widget.employee?.lastName ?? '',
  );
  late final nickname = TextEditingController(
    text: widget.employee?.nickname ?? '',
  );
  late final position = TextEditingController(
    text: widget.employee?.position ?? '',
  );
  late final departmentCode = TextEditingController(
    text: widget.employee?.department.code ?? '',
  );
  late final departmentName = TextEditingController(
    text: widget.employee?.department.name ?? '',
  );

  @override
  void dispose() {
    code.dispose();
    firstName.dispose();
    lastName.dispose();
    nickname.dispose();
    position.dispose();
    departmentCode.dispose();
    departmentName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.employee == null
          ? context.l10n.addEmployee
          : context.l10n.editEmployee,
    ),
    content: SizedBox(
      width: 560,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _requiredField(context, code, context.l10n.employeeCode),
              const SizedBox(height: 12),
              _requiredField(context, firstName, context.l10n.firstName),
              const SizedBox(height: 12),
              TextFormField(
                controller: lastName,
                decoration: InputDecoration(labelText: context.l10n.lastName),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nickname,
                decoration: InputDecoration(labelText: context.l10n.nickname),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: position,
                decoration: InputDecoration(labelText: context.l10n.position),
              ),
              const SizedBox(height: 12),
              _requiredField(
                context,
                departmentCode,
                context.l10n.departmentCode,
              ),
              const SizedBox(height: 12),
              _requiredField(
                context,
                departmentName,
                context.l10n.departmentName,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(onPressed: _submit, child: Text(context.l10n.save)),
    ],
  );

  TextFormField _requiredField(
    BuildContext context,
    TextEditingController controller,
    String label,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: '$label *'),
      validator: (value) => value == null || value.trim().isEmpty
          ? context.l10n.requiredField
          : null,
    );
  }

  void _submit() {
    if (!formKey.currentState!.validate()) return;
    final normalizedDepartmentCode = departmentCode.text.trim();
    final id =
        widget.employee?.id ?? 'employee:${code.text.trim().toLowerCase()}';
    Navigator.pop(
      context,
      Employee(
        id: id,
        employeeCode: code.text.trim(),
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        nickname: nickname.text.trim(),
        position: position.text.trim(),
        active: widget.employee?.active ?? true,
        department: Department(
          id: 'department:${normalizedDepartmentCode.toLowerCase()}',
          code: normalizedDepartmentCode,
          name: departmentName.text.trim(),
        ),
      ),
    );
  }
}

class _EmployeeEmptyState extends StatelessWidget {
  const _EmployeeEmptyState({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.groups_outlined, size: 52),
          const SizedBox(height: 12),
          Text(
            hasFilters
                ? context.l10n.noEmployeesMatch
                : context.l10n.noEmployeesInSchedule,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _EmployeeShiftHistory extends StatelessWidget {
  const _EmployeeShiftHistory({required this.shifts, required this.locale});

  final List<EmployeeShiftDate> shifts;
  final String locale;

  @override
  Widget build(BuildContext context) {
    if (shifts.isEmpty) {
      return const ListTile(
        dense: true,
        leading: Icon(Icons.event_busy_outlined),
        title: Text('ยังไม่มีวันที่เวรในตารางปัจจุบัน'),
      );
    }
    return Column(
      children: [
        for (final shift in shifts)
          ListTile(
            dense: true,
            leading: const Icon(Icons.event_available_outlined),
            title: Text(_dateLabel(shift.date)),
            subtitle: Text(
              '${shift.shiftName} (${shift.shiftCode}) • '
              '${_timeLabel(shift.start)}–${_timeLabel(shift.end)}',
            ),
          ),
      ],
    );
  }

  String _dateLabel(DateTime date) {
    final year = locale == 'th' ? date.year + 543 : date.year;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/$year';
  }

  String _timeLabel(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
