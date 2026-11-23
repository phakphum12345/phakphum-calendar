import 'package:flutter/material.dart';
import '../controller/app_controller.dart';
import '../models/audit_entry.dart';

class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.auditEntries;
    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: entries.isEmpty
          ? const Center(child: Text('No audit entries'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (ctx, i) {
                final AuditEntry e = entries[i];
                final actor = e.actorId ?? 'ไม่ทราบผู้กระทำ';
                final entity = [
                  if (e.entityType != null) e.entityType,
                  if (e.entityId != null) e.entityId,
                ].join(' · ');
                final stateChange = [
                  if (e.previousState != null) e.previousState,
                  if (e.newState != null) e.newState,
                ].join(' → ');
                final details = <String>[
                  e.message,
                  'ผู้กระทำ: $actor',
                  if (entity.isNotEmpty) 'รายการ: $entity',
                  if (stateChange.isNotEmpty) 'สถานะ: $stateChange',
                ].join('\n');
                return Card(
                  child: ListTile(
                    isThreeLine: true,
                    leading: Icon(
                      e.success ? Icons.check_circle : Icons.error_outline,
                      color: e.success ? Colors.green : Colors.red,
                    ),
                    title: Text(e.action),
                    subtitle: Text(details),
                    trailing: Text(
                      '${e.timestamp.toLocal()}',
                      textAlign: TextAlign.end,
                    ),
                  ),
                );
              },
              separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
              itemCount: entries.length,
            ),
    );
  }
}
