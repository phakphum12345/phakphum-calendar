import '../../diff_engine/domain/calendar_event_candidate.dart';

enum GeneratorAdapterIssueSeverity { warning, blocking }

class GeneratorAdapterIssue {
  const GeneratorAdapterIssue({
    required this.code,
    required this.message,
    required this.severity,
    this.sourceRecordId,
  });

  final String code;
  final String message;
  final GeneratorAdapterIssueSeverity severity;
  final String? sourceRecordId;
}

/// A preview only. It cannot execute, persist or synchronize calendar events.
class GeneratorAdapterPreview {
  GeneratorAdapterPreview({
    required List<CalendarEventCandidate> candidates,
    required List<GeneratorAdapterIssue> issues,
  }) : candidates = List.unmodifiable(candidates),
       issues = List.unmodifiable(issues);

  final List<CalendarEventCandidate> candidates;
  final List<GeneratorAdapterIssue> issues;

  bool get hasBlockingIssues => issues.any(
    (issue) => issue.severity == GeneratorAdapterIssueSeverity.blocking,
  );

  bool get isReady => !hasBlockingIssues && candidates.isNotEmpty;

  /// Calendar write/sync always remains a separate, explicit user action.
  bool get requiresUserConfirmation => true;
}
