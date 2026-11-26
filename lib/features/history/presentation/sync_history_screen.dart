import 'dart:async';

import 'package:flutter/material.dart';

import '../application/sync_history_controller.dart';
import '../domain/sync_history_entry.dart';

class SyncHistoryScreen extends StatefulWidget {
  const SyncHistoryScreen({required this.controller, super.key});

  final SyncHistoryController controller;

  @override
  State<SyncHistoryScreen> createState() => _SyncHistoryScreenState();
}

class _SyncHistoryScreenState extends State<SyncHistoryScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('ประวัติการซิงก์')),
          body: SyncHistoryPanelContent(controller: widget.controller),
        );
      },
    );
  }
}

/// Compact sync-history panel for the existing History utility page.
class SyncHistoryPanel extends StatefulWidget {
  const SyncHistoryPanel({required this.controllerFactory, super.key});

  final SyncHistoryController Function() controllerFactory;

  @override
  State<SyncHistoryPanel> createState() => _SyncHistoryPanelState();
}

class _SyncHistoryPanelState extends State<SyncHistoryPanel> {
  late final SyncHistoryController _controller = widget.controllerFactory();

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => SyncHistoryPanelContent(controller: _controller),
    );
  }
}

class SyncHistoryPanelContent extends StatelessWidget {
  const SyncHistoryPanelContent({required this.controller, super.key});

  final SyncHistoryController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ประวัติการซิงก์',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (controller.isLoading)
              const LinearProgressIndicator()
            else if (controller.message != null)
              Text(controller.message!)
            else if (controller.entries.isEmpty)
              const Text('ยังไม่มีประวัติการซิงก์')
            else
              for (final entry in controller.entries)
                _SyncHistoryEntryTile(
                  entry: entry,
                  controller: controller,
                ),
            if (controller.recoveryMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                controller.recoveryMessage!,
                style: TextStyle(
                  color: controller.recoveryMessage!.startsWith('กู้คืนไม่สำเร็จ')
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncHistoryEntryTile extends StatelessWidget {
  const _SyncHistoryEntryTile({
    required this.entry,
    required this.controller,
  });

  final SyncHistoryEntry entry;
  final SyncHistoryController controller;

  @override
  Widget build(BuildContext context) {
    final recovering = controller.recoveringHistoryId == entry.id;
    final canRecover = controller.canRecover &&
        entry.status != SyncHistoryStatus.success &&
        (entry.failed > 0 || entry.serverRunId != null);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_iconFor(entry.status)),
      title: Text(_labelFor(entry.status)),
      subtitle: Text(
        'เริ่ม: ${entry.startedAt.toLocal()}\n'
        'เพิ่ม ${entry.inserted} · '
        'แก้ไข ${entry.updated} · '
        'ลบ ${entry.deleted} · '
        'ล้มเหลว ${entry.failed}'
        '${entry.serverRunId == null ? '' : '\nServer run: ${entry.serverRunId}'}',
      ),
      isThreeLine: true,
      trailing: canRecover
          ? TextButton.icon(
              onPressed: recovering
                  ? null
                  : () => _confirmRecovery(context),
              icon: recovering
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.replay),
              label: const Text('กู้คืน'),
            )
          : null,
    );
  }

  Future<void> _confirmRecovery(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันการกู้คืนการซิงก์'),
        content: Text(
          entry.serverRunId == null
              ? 'ระบบจะตรวจสอบคิวรายการที่ล้มเหลวในเครื่องและลองทำต่อ โดยไม่เริ่มซิงก์รายการใหม่ทั้งหมด'
              : 'ระบบจะอ่านรายการที่ยังไม่สำเร็จจาก Server Ledger และตรวจสอบสถานะ Google Calendar ก่อนทำต่อ จะไม่เล่นรายการซ้ำโดยไม่ตรวจสอบ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ยืนยันกู้คืน'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await controller.recover(entry.id);
    if (!context.mounted) return;
    final message = controller.recoveryMessage ??
        (success ? 'กู้คืนการซิงก์เสร็จแล้ว' : 'กู้คืนไม่สำเร็จ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  IconData _iconFor(SyncHistoryStatus status) {
    return switch (status) {
      SyncHistoryStatus.running => Icons.sync,
      SyncHistoryStatus.success => Icons.check_circle_outline,
      SyncHistoryStatus.partialSuccess => Icons.warning_amber_outlined,
      SyncHistoryStatus.failure => Icons.error_outline,
    };
  }

  String _labelFor(SyncHistoryStatus status) {
    return switch (status) {
      SyncHistoryStatus.running => 'กำลังซิงก์',
      SyncHistoryStatus.success => 'สำเร็จ',
      SyncHistoryStatus.partialSuccess => 'สำเร็จบางส่วน',
      SyncHistoryStatus.failure => 'ไม่สำเร็จ',
    };
  }
}
