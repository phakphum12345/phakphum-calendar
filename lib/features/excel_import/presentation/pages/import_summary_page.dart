import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/result/result.dart';
import '../../../../domain/entities/employee.dart';
import '../../../../domain/entities/shift_template.dart';
import '../../../../domain/entities/schedule.dart';
import '../../../../domain/repositories/employee_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../employees/application/employee_match_resolver.dart';
import '../../../schedule/data/imported_schedule_adapter.dart';
import '../../../schedule/presentation/controllers/schedule_controller.dart';
import '../../../schedule/presentation/pages/imported_month_calendar_page.dart';
import '../../../shift_templates/application/shift_template_controller.dart';
import '../../domain/import_issue.dart';
import '../../domain/import_summary.dart';
import '../../domain/shift_record.dart';
import '../controllers/excel_import_controller.dart';
import '../widgets/import_statistics.dart';
import '../widgets/issue_list.dart';

class ImportSummaryPage extends StatefulWidget {
  const ImportSummaryPage({
    required this.summary,
    required this.records,
    this.schedule,
    this.scheduleControllerFactory,
    this.persistenceResult,
    this.scheduleSaver,
    this.scheduleFactory,
    this.controller,
    this.employeeRepository,
    this.shiftTemplateControllerFactory,
    super.key,
  });

  final ImportSummary summary;
  final List<ShiftRecord> records;
  final Schedule? schedule;
  final ScheduleController Function(Schedule)? scheduleControllerFactory;
  final Result<Schedule>? persistenceResult;
  final Future<Result<Schedule>> Function(Schedule)? scheduleSaver;
  final Schedule Function(Iterable<ShiftRecord>)? scheduleFactory;
  final ExcelImportController? controller;
  final EmployeeRepository? employeeRepository;
  final ShiftTemplateController Function()? shiftTemplateControllerFactory;

  ImportSummary get _currentSummary => controller?.importSummary ?? summary;
  List<ShiftRecord> get _currentRecords => controller?.shiftRecords ?? records;

  Schedule get _currentSchedule {
    if (controller == null && schedule != null) return schedule!;
    return scheduleFactory?.call(_currentRecords) ??
        const ImportedScheduleAdapter().createSchedule(_currentRecords);
  }

  @override
  State<ImportSummaryPage> createState() => _ImportSummaryPageState();
}

class _ImportSummaryPageState extends State<ImportSummaryPage> {
  bool _saving = false;
  Result<Schedule>? _saveResult;
  bool _employeeReviewLoading = false;
  String? _employeeReviewError;
  List<Employee> _employees = const [];
  ShiftTemplateController? _shiftTemplateController;
  List<ShiftTemplate> _shiftTemplates = const [];
  bool _shiftReviewLoading = false;
  String? _shiftReviewError;
  final Map<int, List<ShiftTemplate>> _shiftMatchCandidates = {};
  final Map<int, String> _shiftMatchStatus = {};
  final Map<int, ShiftTemplate?> _selectedShiftTemplates = {};
  final Map<int, EmployeeMatchResult> _matchResults = {};
  final Map<int, Employee?> _selectedEmployees = {};

  bool get _employeeReviewEnabled => widget.employeeRepository != null;

  bool get _shiftReviewEnabled => widget.shiftTemplateControllerFactory != null;

  bool get _isSaved =>
      _saveResult is Success<Schedule> ||
      widget.persistenceResult is Success<Schedule>;

  bool get _shiftReviewReady {
    if (!_shiftReviewEnabled) return true;
    if (_shiftReviewLoading || _shiftReviewError != null) return false;
    return widget._currentRecords.every(
      (record) => _selectedShiftTemplates[record.rowNumber] != null,
    );
  }

  bool get _employeeReviewReady {
    if (!_employeeReviewEnabled) return true;
    if (_employeeReviewLoading || _employeeReviewError != null) return false;
    return widget._currentRecords.every(
      (record) => _selectedEmployees[record.rowNumber] != null,
    );
  }

  List<ShiftRecord> get _resolvedRecords {
    return widget._currentRecords.map((record) {
      final employee = _selectedEmployees[record.rowNumber];
      final shiftTemplate = _selectedShiftTemplates[record.rowNumber];
      return record.copyWith(
        employee: employee?.fullName ?? record.employee,
        department: employee?.department.name ?? record.department,
        resolvedEmployee: employee,
        resolvedShiftTemplate: shiftTemplate,
      );
    }).toList(growable: false);
  }

  Schedule get _currentSchedule {
    if (!_employeeReviewEnabled && !_shiftReviewEnabled) {
      return widget._currentSchedule;
    }
    return widget.scheduleFactory?.call(_resolvedRecords) ??
        const ImportedScheduleAdapter().createSchedule(_resolvedRecords);
  }

  @override
  void initState() {
    super.initState();
    if (_employeeReviewEnabled) unawaited(_loadEmployeeDirectory());
    if (_shiftReviewEnabled) unawaited(_loadShiftTemplates());
  }

  @override
  void dispose() {
    _shiftTemplateController?.dispose();
    super.dispose();
  }

  Future<void> _loadEmployeeDirectory() async {
    final repository = widget.employeeRepository;
    if (repository == null) return;
    setState(() {
      _employeeReviewLoading = true;
      _employeeReviewError = null;
    });
    final result = await repository.findAll(activeOnly: false);
    if (!mounted) return;
    switch (result) {
      case Success<List<Employee>>(value: final employees):
        _employees = employees;
        _matchResults.clear();
        _selectedEmployees.clear();
        const resolver = EmployeeMatchResolver();
        for (final record in widget._currentRecords) {
          final match = resolver.resolve(
            importedName: record.employee,
            department: record.department,
            employees: employees,
          );
          _matchResults[record.rowNumber] = match;
          if (match.status == EmployeeMatchStatus.matched) {
            _selectedEmployees[record.rowNumber] = match.employee;
          }
        }
      case Failure<List<Employee>>():
        _employeeReviewError = result.message;
    }
    setState(() => _employeeReviewLoading = false);
  }

  Future<void> _loadShiftTemplates() async {
    final factory = widget.shiftTemplateControllerFactory;
    if (factory == null) return;
    final controller = _shiftTemplateController ??= factory();
    setState(() {
      _shiftReviewLoading = true;
      _shiftReviewError = null;
    });
    await controller.load();
    if (!mounted) return;
    if (controller.error != null) {
      setState(() {
        _shiftReviewError = controller.error;
        _shiftReviewLoading = false;
      });
      return;
    }
    setState(() {
      _shiftTemplates = controller.templates
          .where((template) => template.active)
          .toList(growable: false);
      _resolveShiftTemplates();
      _shiftReviewLoading = false;
    });
  }

  void _resolveShiftTemplates() {
    _shiftMatchCandidates.clear();
    _shiftMatchStatus.clear();
    _selectedShiftTemplates.clear();
    for (final record in widget._currentRecords) {
      final query = _normalizeShiftLabel(record.shift);
      final matches = _shiftTemplates.where((template) {
        return [template.code, template.name, template.shortName].any(
          (alias) => alias.trim().isNotEmpty &&
              _normalizeShiftLabel(alias) == query,
        );
      }).toList(growable: false);
      if (matches.length == 1) {
        _shiftMatchCandidates[record.rowNumber] = matches;
        _shiftMatchStatus[record.rowNumber] = 'matched';
        _selectedShiftTemplates[record.rowNumber] = matches.single;
      } else if (matches.isNotEmpty) {
        _shiftMatchCandidates[record.rowNumber] = matches;
        _shiftMatchStatus[record.rowNumber] = 'ambiguous';
      } else {
        _shiftMatchCandidates[record.rowNumber] = _shiftTemplates;
        _shiftMatchStatus[record.rowNumber] = 'unmatched';
      }
    }
  }

  String _normalizeShiftLabel(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();

  @override
  Widget build(BuildContext context) {
    final persistenceResult = _saveResult ?? widget.persistenceResult;
    final canSave = _employeeReviewReady &&
        _shiftReviewReady &&
        !_saving &&
        persistenceResult is! Success<Schedule>;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.importSummary)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.importCompleted,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.importCreatedRecords(
                      widget._currentRecords.length,
                      widget._currentSummary.totalRows,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ImportStatistics(summary: widget._currentSummary),
                  if (_employeeReviewEnabled) ...[
                    const SizedBox(height: 24),
                    _buildEmployeeReview(context),
                  ],
                  if (_shiftReviewEnabled) ...[
                    const SizedBox(height: 24),
                    _buildShiftReview(context),
                  ],
                  if (persistenceResult case Failure<Schedule>(
                    message: final message,
                  )) ...[
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.scheduleSaveFailed(message),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (widget.scheduleSaver != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: canSave ? _saveSchedule : null,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _saving
                            ? 'กำลังบันทึก...'
                            : persistenceResult is Success<Schedule>
                            ? 'บันทึกแล้ว'
                            : 'ยืนยันและบันทึกตารางเวร',
                      ),
                    ),
                    if (!_employeeReviewReady) ...[
                      const SizedBox(height: 8),
                      Text(
                        'กรุณาจับคู่พนักงานทุกรายการให้เรียบร้อยก่อนบันทึก',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: widget._currentRecords.any(
                              (record) => record.date != null,
                            ) &&
                            _employeeReviewReady &&
                            _shiftReviewReady
                        ? () => _openCalendar(context)
                        : null,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(context.l10n.viewMonthCalendar),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.issues,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  IssueList(
                    issues: widget._currentSummary.issues,
                    onEditIssue: widget.controller == null || _isSaved
                        ? null
                        : _editIssue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeReview(BuildContext context) {
    if (_employeeReviewLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_employeeReviewError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ไม่สามารถโหลดรายชื่อพนักงานได้'),
              const SizedBox(height: 8),
              Text(_employeeReviewError!),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loadEmployeeDirectory,
                  child: const Text('ลองอีกครั้ง'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final unresolved = widget._currentRecords
        .where((record) => _selectedEmployees[record.rowNumber] == null)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ตรวจสอบการจับคู่พนักงาน',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              unresolved == 0
                  ? 'จับคู่ครบแล้ว สามารถตรวจสอบและบันทึกตารางได้'
                  : 'เหลือ $unresolved รายการที่ต้องเลือกพนักงานให้ถูกต้อง',
            ),
            const SizedBox(height: 12),
            for (final record in widget._currentRecords) ...[
              _buildEmployeeMatchTile(context, record),
              const Divider(height: 20),
            ],
            if (_employees.isEmpty)
              const Text(
                'ยังไม่มีรายชื่อในสมุดพนักงาน กรุณาเพิ่มรายชื่อก่อนนำเข้าตาราง',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftReview(BuildContext context) {
    if (_shiftReviewLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_shiftReviewError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ไม่สามารถโหลดรูปแบบเวรได้'),
              const SizedBox(height: 8),
              Text(_shiftReviewError!),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loadShiftTemplates,
                  child: const Text('ลองอีกครั้ง'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final unresolved = widget._currentRecords
        .where((record) => _selectedShiftTemplates[record.rowNumber] == null)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ตรวจสอบรูปแบบเวร',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              unresolved == 0
                  ? 'จับคู่รูปแบบเวรครบแล้ว'
                  : 'เหลือ $unresolved รายการที่ต้องเลือกรูปแบบเวร',
            ),
            const SizedBox(height: 12),
            for (final record in widget._currentRecords) ...[
              _buildShiftMatchTile(context, record),
              const Divider(height: 20),
            ],
            if (_shiftTemplates.isEmpty)
              const Text(
                'ไม่มีรูปแบบเวรที่เปิดใช้งาน กรุณาตั้งค่ารูปแบบเวรก่อนนำเข้า',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftMatchTile(BuildContext context, ShiftRecord record) {
    final status = _shiftMatchStatus[record.rowNumber];
    final selected = _selectedShiftTemplates[record.rowNumber];
    final candidates = _shiftMatchCandidates[record.rowNumber] ?? const [];
    final statusText = switch (status) {
      'matched' => 'จับคู่จากรหัสหรือชื่อเวรที่ตรงกัน',
      'ambiguous' => 'พบรูปแบบเวรที่ตรงกันหลายรายการ กรุณาเลือก',
      'unmatched' => 'ไม่พบชื่อเวรที่ตรงกัน กรุณาเลือกจากรูปแบบเวร',
      _ => 'กำลังตรวจสอบ...',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('แถว ${record.rowNumber}: ${record.shift}'),
        const SizedBox(height: 4),
        Text(statusText),
        if (candidates.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<ShiftTemplate>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'รูปแบบเวรในระบบ'),
            hint: const Text('เลือกรูปแบบเวร'),
            items: [
              for (final template in candidates)
                DropdownMenuItem(
                  value: template,
                  child: Text(
                    '${template.name} • ${template.code} • '
                    '${_formatTemplateTime(template.startTime)}–'
                    '${_formatTemplateTime(template.endTime)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _isSaved
                ? null
                : (template) {
                    setState(() {
                      _selectedShiftTemplates[record.rowNumber] = template;
                    });
                  },
          ),
        ] else
          Text(
            'ไม่มีรูปแบบเวรให้เลือก',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  String _formatTemplateTime(Duration value) {
    final hours = value.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  Widget _buildEmployeeMatchTile(BuildContext context, ShiftRecord record) {
    final match = _matchResults[record.rowNumber];
    final selected = _selectedEmployees[record.rowNumber];
    final candidates = match?.status == EmployeeMatchStatus.unmatched
        ? _employees
        : match?.candidates ?? const <Employee>[];
    final statusText = switch (match?.status) {
      EmployeeMatchStatus.matched => 'จับคู่อัตโนมัติจากข้อมูลตรงกัน',
      EmployeeMatchStatus.ambiguous => 'พบชื่อที่เป็นไปได้หลายรายการ กรุณาเลือก',
      EmployeeMatchStatus.unmatched => 'ไม่พบชื่อที่ตรงกัน กรุณาเลือกจากรายชื่อ',
      null => 'กำลังตรวจสอบ...',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'แถว ${record.rowNumber}: ${record.employee}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(statusText),
        if (candidates.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<Employee>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'พนักงานในระบบ',
            ),
            hint: const Text('เลือกพนักงาน'),
            items: [
              for (final employee in candidates)
                DropdownMenuItem(
                  value: employee,
                  child: Text(
                    '${employee.displayName} • ${employee.department.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _isSaved
                ? null
                : (employee) {
                    setState(
                      () => _selectedEmployees[record.rowNumber] = employee,
                    );
                  },
          ),
        ] else
          Text(
            'ไม่มีรายชื่อให้เลือก',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  Future<void> _editIssue(ImportIssue issue) async {
    final activeController = widget.controller;
    if (activeController == null || _isSaved || !_isExcelColumn(issue.column)) {
      return;
    }

    final editor = TextEditingController(
      text: activeController.valueAt(
        rowNumber: issue.rowNumber,
        column: issue.column,
      )?.toString() ?? '',
    );
    try {
      final corrected = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            'แก้ไขแถว ${issue.rowNumber} • คอลัมน์ ${issue.column}',
          ),
          content: TextField(
            controller: editor,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'ค่าใหม่'),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(editor.text),
              child: const Text('บันทึกและตรวจใหม่'),
            ),
          ],
        ),
      );
      if (corrected == null || !mounted) return;
      final updated = activeController.updateCellValue(
        rowNumber: issue.rowNumber,
        column: issue.column,
        value: corrected,
      );
      if (!updated || !activeController.reprocessImport()) return;
      if (!mounted) return;
      setState(() {});
      await _loadEmployeeDirectory();
      if (_shiftReviewEnabled) await _loadShiftTemplates();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ปรับข้อมูลและประมวลผลใหม่แล้ว')),
      );
    } finally {
      editor.dispose();
    }
  }

  bool _isExcelColumn(String column) {
    return column.isNotEmpty &&
        column.codeUnits.every((code) => code >= 65 && code <= 90);
  }

  Future<void> _saveSchedule() async {
    final save = widget.scheduleSaver;
    if (save == null ||
        _saving ||
        !_employeeReviewReady ||
        !_shiftReviewReady ||
        _isSaved) {
      return;
    }
    setState(() => _saving = true);
    final result = await save(_currentSchedule);
    if (!mounted) return;
    setState(() {
      _saveResult = result;
      _saving = false;
    });
  }

  void _openCalendar(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImportedMonthCalendarPage(
          schedule: _currentSchedule,
          controllerFactory: widget.scheduleControllerFactory,
        ),
      ),
    );
  }
}
