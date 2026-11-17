import 'package:flutter/material.dart';

import '../../domain/import_issue.dart';
import 'issue_tile.dart';

class IssueList extends StatelessWidget {
  const IssueList({required this.issues, this.onEditIssue, super.key});

  final List<ImportIssue> issues;
  final ValueChanged<ImportIssue>? onEditIssue;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 12),
              Text('No import issues'),
            ],
          ),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < issues.length; index++) ...[
            IssueTile(issue: issues[index], onEdit: onEditIssue),
            if (index < issues.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
