import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../domain/entities/schedule.dart';
import '../../../../core/result/result.dart';
import '../../../../l10n/l10n.dart';
import '../../../roster_names/presentation/roster_name_list_page.dart';
import '../../domain/schedule_day.dart';
import '../../domain/employee.dart';
import '../../domain/shift.dart';
import '../../domain/shift_assignment.dart';
import '../controllers/schedule_controller.dart';
import '../widgets/schedule_controller_host.dart';
import '../widgets/schedule_grid.dart';
import '../widgets/schedule_view_scaffold.dart';
import '../widgets/schedule_view_selector.dart';

class ScheduleWorkspacePage extends StatefulWidget {
  const ScheduleWorkspacePage({
    super.key,
    this.controller,
    this.editable = false,
    this.onCommitted,
  });

  final ScheduleController? controller;
  final bool editable;
  final Future<void> Function(Schedule schedule)? onCommitted;

  @override
  State<ScheduleWorkspacePage> createState() => _ScheduleWorkspacePageState();
}

class _ScheduleWorkspacePageState extends State<ScheduleWorkspacePage> {
  ScheduleViewMode mode = ScheduleViewMode.month;

  @override
  Widget build(BuildContext context) {
    return ScheduleControllerHost(
      controller: widget.controller,
      builder: (context, controller) => ScheduleViewScaffold(
        title: 'Schedule',
        controller: controller,
        viewSelector: ScheduleViewSelector(
          value: mode,
          onChanged: (value) => setState(() => mode = value),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScheduleGrid(
              days: _days(controller),
              assignmentsFor: controller.assignmentsFor,
              showMonthPadding: mode == ScheduleViewMode.month,
              selectedDate: controller.selectedDay,
              onDaySelected: (day) {
                final date = day.date;
                if (controller.currentMonth.year != date.year ||
                    controller.currentMonth.month != date.month) {
                  controller.loadMonth(date);
                }
                controller.selectDay(date);
                if (mode != ScheduleViewMode.day) {
                  setState(() => mode = ScheduleViewMode.day);
                }
              },
            ),
            if (mode == ScheduleViewMode.day)
              const DailyRosterNameStatusPanel(),
            if (widget.editable) ...[
              const SizedBox(height: 20),
              _ManualAssignmentPanel(
                controller: controller,
                onCommitted: widget.onCommitted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  ScheduleDay _dayForDate(ScheduleController controller, DateTime date) =>
      controller.canonicalSchedule.month(date)?.day(date) ??
      ScheduleDay(date: date);

  List<ScheduleDay> _days(ScheduleController controller) {
    if (mode == ScheduleViewMode.month) {
      return controller.schedule.days;
    }

    final anchor =
        controller.selectedDay ??
        controller.selectedDate ??
        _todayInMonth(controller) ??
        controller.schedule.days.firstOrNull?.date;
    if (anchor == null) return const [];
    if (mode == ScheduleViewMode.day) {
      final day = _dayForDate(controller, anchor);
      return [day];
    }

    final start = anchor.subtract(Duration(days: anchor.weekday - 1));
    return [
      for (var offset = 0; offset < 7; offset++)
        _dayForDate(controller, start.add(Duration(days: offset))),
    ];
  }

  DateTime? _todayInMonth(ScheduleController controller) {
    final today = DateTime.now();
    return today.year == controller.currentMonth.year &&
            today.month == controller.currentMonth.month
        ? today
        : null;
  }
}

class _ManualAssignmentPanel extends StatelessWidget {
  const _ManualAssignmentPanel({
    required this.controller,
    required this.onCommitted,
  });

  final ScheduleController controller;
  final Future<void> Function(Schedule schedule)? onCommitted;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedDay;
    final day = selected == null ? null : controller.schedule.day(selected);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.manualRosterEditor,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      selected == null ||
                          controller.employees.isEmpty ||
                          controller.shifts.isEmpty
                      ? null
                      : () => _add(context, selected),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.addAssignment),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: controller.loading ? null : () => _save(context),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(context.l10n.save),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              selected == null
                  ? context.l10n.selectDayToEdit
                  : MaterialLocalizations.of(context).formatFullDate(selected),
            ),
            if (selected != null &&
                (controller.employees.isEmpty || controller.shifts.isEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(context.l10n.rosterCatalogRequired),
              ),
            if (day != null)
              for (final assignment in day.assignments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text(assignment.shift.code)),
                  title: Text(assignment.employee.displayName),
                  subtitle: Text(
                    [
                          assignment.shift.name,
                          assignment.location,
                          assignment.remark,
                        ]
                        .whereType<String>()
                        .where((value) => value.isNotEmpty)
                        .join(' • '),
                  ),
                  trailing: IconButton(
                    tooltip: context.l10n.delete,
                    onPressed: () => _delete(context, day.date, assignment),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, DateTime date) async {
    final assignment = await showDialog<ShiftAssignment>(
      context: context,
      builder: (context) => _AssignmentDialog(
        employees: controller.employees,
        shifts: controller.shifts,
      ),
    );
    if (assignment == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.previewChanges),
        content: ListTile(
          leading: CircleAvatar(child: Text(assignment.shift.code)),
          title: Text(assignment.employee.displayName),
          subtitle: Text(
            MaterialLocalizations.of(context).formatFullDate(date),
          ),
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
    if (confirmed == true) controller.updateAssignment(date, assignment);
  }

  Future<void> _delete(
    BuildContext context,
    DateTime date,
    ShiftAssignment assignment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteAssignment),
        content: Text(
          context.l10n.deleteAssignmentConfirmation(
            assignment.employee.displayName,
            assignment.shift.code,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.deleteAssignment(
        date,
        employeeId: assignment.employee.id,
        shiftId: assignment.shift.id,
      );
    }
  }

  Future<void> _save(BuildContext context) async {
    final result = await controller.saveSchedule();
    if (!context.mounted) return;
    if (result case Success<Schedule>(value: final schedule)) {
      await onCommitted?.call(schedule);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.scheduleSaved)));
    } else if (result case Failure<Schedule>()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({required this.employees, required this.shifts});

  final List<Employee> employees;
  final List<Shift> shifts;

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  late Employee employee = widget.employees.first;
  late Shift shift = widget.shifts.first;
  final location = TextEditingController();
  final remark = TextEditingController();

  @override
  void dispose() {
    location.dispose();
    remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.addAssignment),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Employee>(
            initialValue: employee,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.l10n.employees),
            items: [
              for (final value in widget.employees)
                DropdownMenuItem(value: value, child: Text(value.displayName)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => employee = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Shift>(
            initialValue: shift,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.l10n.shiftName),
            items: [
              for (final value in widget.shifts)
                DropdownMenuItem(
                  value: value,
                  child: Text('${value.code} — ${value.name}'),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => shift = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: location,
            decoration: InputDecoration(labelText: context.l10n.location),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: remark,
            decoration: InputDecoration(labelText: context.l10n.notes),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          ShiftAssignment(
            employee: employee,
            shift: shift,
            location: location.text.trim().isEmpty
                ? null
                : location.text.trim(),
            remark: remark.text.trim().isEmpty ? null : remark.text.trim(),
          ),
        ),
        child: Text(context.l10n.next),
      ),
    ],
  );
}
