enum CalendarSyncOperationType { insert, update, delete }

class CalendarSyncOperationResult {
  const CalendarSyncOperationResult({
    required this.type,
    required this.referenceId,
    required this.success,
    this.message,
    this.providerEventId,
  });

  final CalendarSyncOperationType type;
  final String referenceId;
  final bool success;
  final String? message;
  final String? providerEventId;
}
