enum CalendarSyncOperationType { insert, update, delete }

class CalendarSyncOperationResult {
  const CalendarSyncOperationResult({
    required this.type,
    required this.referenceId,
    required this.success,
    this.message,
    this.providerEventId,
    this.attempts = 0,
  });

  final CalendarSyncOperationType type;
  final String referenceId;
  final bool success;
  final String? message;
  final String? providerEventId;
  final int attempts;
}
