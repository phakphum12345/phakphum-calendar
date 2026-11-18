import 'package:flutter/material.dart';

import '../../../../domain/entities/schedule.dart';
import '../../../../l10n/l10n.dart';
import '../../../excel_import/domain/shift_record.dart';
import '../../../workflow/application/shift_calendar_workflow_controller.dart';
import '../../../workflow/presentation/workflow_dashboard_screen.dart';
import '../../data/imported_schedule_adapter.dart';
import '../../data/schedule_service.dart';
import '../controllers/schedule_controller.dart';
import 'monthly_schedule_page.dart';

/// Displays imported shift records using the canonical monthly schedule UI.
class ImportedMonthCalendarPage extends StatefulWidget {
  const ImportedMonthCalendarPage({
    this.records = const [],
    this.schedule,
    this.controllerFactory,
    this.workflowControllerFactory,
    super.key,
    this.adapter = const ImportedScheduleAdapter(),
  });

  /// Imported records to display.
  final List<ShiftRecord> records;
  final Schedule? schedule;
  final ScheduleController Function(Schedule)? controllerFactory;
  final Future<ShiftCalendarWorkflowController> Function()?
  workflowControllerFactory;

  /// Boundary adapter used to populate the schedule domain.
  final ImportedScheduleAdapter adapter;

  @override
  State<ImportedMonthCalendarPage> createState() =>
      _ImportedMonthCalendarPageState();
}

class _ImportedMonthCalendarPageState extends State<ImportedMonthCalendarPage> {
  late final Schedule canonicalSchedule =
      widget.schedule ?? widget.adapter.createSchedule(widget.records);
  late final ScheduleController controller =
      widget.controllerFactory?.call(canonicalSchedule) ??
      ScheduleController(
        service: ScheduleService(schedule: canonicalSchedule),
        initialMonth:
            canonicalSchedule.months.firstOrNull?.month ??
            widget.adapter.initialMonth(widget.records),
      );
  bool _openingSync = false;

  @override
  void initState() {
    super.initState();
    controller.validateSchedule();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _openCalendarSync() async {
    final factory = widget.workflowControllerFactory;
    if (factory == null || _openingSync) return;
    setState(() => _openingSync = true);
    ShiftCalendarWorkflowController? workflow;
    try {
      workflow = await factory();
      await workflow.prepareSchedule(canonicalSchedule);
      if (!mounted) {
        workflow.dispose();
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => WorkflowDashboardScreen(controller: workflow!),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เตรียม Calendar Preview ไม่สำเร็จ: $error')),
        );
      }
    } finally {
      workflow?.dispose();
      if (mounted) setState(() => _openingSync = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MonthlySchedulePage(
      controller: controller,
      title: context.l10n.monthCalendar,
      appBarActions: [
        if (widget.workflowControllerFactory != null)
          IconButton(
            key: const Key('open-calendar-sync-workflow'),
            tooltip: 'ตรวจสอบก่อน Sync Google Calendar',
            onPressed: _openingSync ? null : _openCalendarSync,
            icon: _openingSync
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_alt),
          ),
      ],
    );
  }
}
