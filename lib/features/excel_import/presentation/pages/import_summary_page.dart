import 'package:flutter/material.dart';

import '../../../../core/result/result.dart';
import '../../../../domain/entities/schedule.dart';
import '../../../../l10n/l10n.dart';
import '../../../schedule/data/imported_schedule_adapter.dart';
import '../../../schedule/presentation/controllers/schedule_controller.dart';
import '../../../schedule/presentation/pages/imported_month_calendar_page.dart';
import '../../domain/import_summary.dart';
import '../../domain/shift_record.dart';
import '../../domain/import_issue.dart';
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
    this.controller,
    super.key,
  });

  final ImportSummary summary;
  final List<ShiftRecord> records;
  final Schedule? schedule;
  final ScheduleController Function(Schedule)? scheduleControllerFactory;
  final Result<Schedule>? persistenceResult;
  final Future<Result<Schedule>> Function(Schedule)? scheduleSaver;
  final ExcelImportController? controller;

  ImportSummary get _currentSummary => controller?.importSummary ?? summary;
  List<ShiftRecord> get _currentRecords => controller?.shiftRecords ?? records;

  @override
  State<ImportSummaryPage> createState() => _ImportSummaryPageState();
}

class _ImportSummaryPageState extends State<ImportSummaryPage> {
  bool _saving = false;
  Result<Schedule>? _saveResult;

  @override
  Widget build(BuildContext context) {
    final persistenceResult = _saveResult ?? widget.persistenceResult;
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
                      _currentRecords.length,
                      _currentSummary.totalRows,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ImportStatistics(summary: widget.summary),
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
                      onPressed: _saving ||
                              persistenceResult is Success<Schedule>
                          ? null
                          : _saveSchedule,
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
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: widget.records.any((record) => record.date != null)
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
                  IssueList(issues: widget.summary.issues),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editIssue(ImportIssue issue) async {
    final activeController = controller;
    if (activeController == null ||
        !RegExp(r'^[A-Z]+
    final save = widget.scheduleSaver;
    if (save == null || _saving) return;
    setState(() => _saving = true);
    final schedule = widget.schedule ??
        const ImportedScheduleAdapter().createSchedule(widget.records);
    final result = await save(schedule);
    if (!mounted) return;
    setState(() {
      _saveResult = result;
      _saving = false;
    });
  }

  void _openCalendar(BuildContext context) {
    final canonicalSchedule =
        widget.schedule ??
        const ImportedScheduleAdapter().createSchedule(widget.records);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImportedMonthCalendarPage(
          schedule: canonicalSchedule,
          controllerFactory: widget.scheduleControllerFactory,
        ),
      ),
    );
  }
}
).hasMatch(issue.column)) {
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
          title: Text('แก้ไขแถว ${issue.rowNumber} • คอลัมน์ ${issue.column}'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ปรับข้อมูลและประมวลผลใหม่แล้ว')),
      );
    } finally {
      editor.dispose();
    }
  }

  Future<void> _saveSchedule() async {
    final save = widget.scheduleSaver;
    if (save == null || _saving) return;
    setState(() => _saving = true);
    final schedule = widget.schedule ??
        const ImportedScheduleAdapter().createSchedule(widget.records);
    final result = await save(schedule);
    if (!mounted) return;
    setState(() {
      _saveResult = result;
      _saving = false;
    });
  }

  void _openCalendar(BuildContext context) {
    final canonicalSchedule =
        widget.schedule ??
        const ImportedScheduleAdapter().createSchedule(widget.records);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImportedMonthCalendarPage(
          schedule: canonicalSchedule,
          controllerFactory: widget.scheduleControllerFactory,
        ),
      ),
    );
  }
}
