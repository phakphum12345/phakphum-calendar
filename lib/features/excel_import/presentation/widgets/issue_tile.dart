import 'package:flutter/material.dart';

import '../../domain/import_issue.dart';

class IssueTile extends StatelessWidget {
  const IssueTile({required this.issue, this.onEdit, super.key});

  final ImportIssue issue;
  final ValueChanged<ImportIssue>? onEdit;

  @override
  Widget build(BuildContext context) {
    final isError = issue.severity == ImportIssueSeverity.error;
    final color = isError ? Theme.of(context).colorScheme.error : Colors.orange;
    final editable = onEdit != null &&
        issue.column.isNotEmpty &&
        issue.column.codeUnits.every((code) => code >= 65 && code <= 90);
    return ListTile(
      leading: Icon(
        isError ? Icons.error_outline : Icons.warning_amber,
        color: color,
      ),
      title: Text(issue.message),
      subtitle: Text('Row ' + issue.rowNumber.toString() + ' • Column ' + issue.column),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            issue.severity.name.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          if (editable)
            IconButton(
              tooltip: 'แก้ไขข้อมูลแถวนี้',
              onPressed: () => onEdit!(issue),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
    );
  }
}
