class CalendarSyncLease {
  const CalendarSyncLease({
    required this.runId,
    required this.calendarId,
    required this.scheduleId,
    required this.leaseToken,
    required this.expiresAt,
  });

  final String runId;
  final String calendarId;
  final String scheduleId;
  final String leaseToken;
  final DateTime expiresAt;
}

abstract interface class CalendarSyncCoordinationGateway {
  Future<CalendarSyncLease> acquire({
    required String calendarId,
    required String scheduleId,
  });

  Future<void> heartbeat(CalendarSyncLease lease);

  Future<void> recordOperation({
    required CalendarSyncLease lease,
    required String operationKey,
    required String operationType,
    required String payloadHash,
  });

  Future<void> updateOperation({
    required CalendarSyncLease lease,
    required String operationKey,
    required String status,
    required int attemptCount,
    String? providerEventId,
    String? lastError,
  });

  Future<void> release({
    required CalendarSyncLease lease,
    required String status,
  });
}
