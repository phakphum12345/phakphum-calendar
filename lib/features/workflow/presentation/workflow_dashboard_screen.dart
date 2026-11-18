import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../application/shift_calendar_workflow_controller.dart';
import '../domain/workflow_preview.dart';

class WorkflowDashboardScreen extends StatelessWidget {
  const WorkflowDashboardScreen({required this.controller, super.key});

  final ShiftCalendarWorkflowController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final preview = controller.preview;
        final preparation = controller.schedulePreparation;
        final diff = preparation?.diff;
        final summary = preview?.simulation.summary;
        final addCount = diff?.toAdd.length ?? summary?.addCount ?? 0;
        final updateCount = diff?.toUpdate.length ?? summary?.updateCount ?? 0;
        final deleteCount = diff?.toDelete.length ?? summary?.deleteCount ?? 0;
        final unchangedCount =
            diff?.unchanged.length ?? summary?.unchangedCount ?? 0;
        final warningCount =
            controller.validationResult?.warnings.length ??
            summary?.warningCount ??
            0;
        final blockedCount =
            controller.validationResult?.errors.length ??
            summary?.blockedCount ??
            0;
        final hasChanges = preparation != null
            ? preparation.plan.operationCount > 0
            : preview?.simulation.hasChanges ?? false;
        final canSynchronize = preparation != null
            ? !controller.hasBlockingFailures
            : summary?.canSynchronize ?? false;

        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.appTitle)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'ตรวจสอบการเปลี่ยนแปลงเวรก่อนลง Google Calendar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'ระบบจะแสดงรายการที่จะเพิ่ม แก้ไข หรือลบ และจะไม่เขียนข้อมูลจนกว่าจะยืนยัน',
              ),
              const SizedBox(height: 16),
              if (preparation == null && preview == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      controller.message ?? context.l10n.noScheduleData,
                    ),
                  ),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _countChip('เพิ่ม', addCount),
                    _countChip('แก้ไข', updateCount),
                    _countChip('ลบ', deleteCount),
                    _countChip('ไม่เปลี่ยน', unchangedCount),
                    _countChip('คำเตือน', warningCount),
                    _countChip('ถูกบล็อก', blockedCount),
                  ],
                ),
                if (diff != null) ...[
                  const SizedBox(height: 16),
                  _diffSection('รายการที่จะเพิ่ม', diff.toAdd),
                  _diffSection('รายการที่จะแก้ไข', diff.toUpdate),
                  _diffSection('รายการที่จะลบ', diff.toDelete),
                ],
              ],
              if (controller.validationResult?.violations.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                const Text(
                  'ผลการตรวจสอบตารางเวร',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                for (final violation
                    in controller.validationResult!.violations)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      violation.severity.name == 'error'
                          ? Icons.block
                          : Icons.warning_amber,
                    ),
                    title: Text(violation.ruleName),
                    subtitle: Text(violation.message),
                  ),
              ],
              if (controller.message != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(controller.message!),
                  ),
                ),
              ],
              if (controller.lastResult != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: Icon(
                      controller.lastResult!.hasFailures
                          ? Icons.warning_amber
                          : Icons.check_circle_outline,
                    ),
                    title: Text(
                      controller.lastResult!.hasFailures
                          ? 'ซิงก์สำเร็จบางส่วน'
                          : 'ซิงก์เสร็จแล้ว',
                    ),
                    subtitle: Text(
                      'สำเร็จ ${controller.lastResult!.successCount} • '
                      'ล้มเหลว ${controller.lastResult!.failureCount}',
                    ),
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: (preparation == null && preview == null) ||
                  !hasChanges
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: controller.isBusy || !canSynchronize
                          ? null
                          : () => _confirmAndSynchronize(context),
                      icon: controller.isBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calendar_month),
                      label: const Text('ตรวจแล้ว ยืนยัน Sync Google Calendar'),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _countChip(String label, int count) {
    return Chip(label: Text('$label $count'));
  }

  Widget _diffSection(
    String title,
    List<dynamic> events,
  ) {
    if (events.isEmpty) return const SizedBox.shrink();
    return Card(
      child: ExpansionTile(
        title: Text('$title (${events.length})'),
        children: [
          for (final event in events)
            ListTile(
              dense: true,
              title: Text(event.title.toString()),
              subtitle: Text(
                '${event.start} – ${event.end}',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSynchronize(BuildContext context) async {
    final preparation = controller.schedulePreparation;
    final diff = preparation?.diff;
    final preview = controller.preview;
    final added = diff?.toAdd.length ?? preview?.simulation.summary.addCount ?? 0;
    final updated =
        diff?.toUpdate.length ?? preview?.simulation.summary.updateCount ?? 0;
    final deleted =
        diff?.toDelete.length ?? preview?.simulation.summary.deleteCount ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันการซิงก์ Google Calendar'),
        content: Text(
          'ระบบจะเพิ่ม $added รายการ แก้ไข $updated รายการ '
          'และลบ $deleted รายการใน Google Calendar '
          'เมื่อยืนยันแล้วเท่านั้น',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('กลับไปตรวจสอบ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ยืนยัน Sync'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await controller.synchronize();
  }
}
