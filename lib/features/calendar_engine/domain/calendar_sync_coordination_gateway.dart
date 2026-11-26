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

class CalendarSyncRunRecord {
  const CalendarSyncRunRecord({
    required this.runId,
    required this.calendarId,
    required this.scheduleId,
    required this.status,
    required this.startedAt,
    required this.heartbeatAt,
    this.finishedAt,
  });

  final String runId;
  final String calendarId;
  final String scheduleId;
  final String status;
  final DateTime startedAt;
  final DateTime heartbeatAt;
  final DateTime? finishedAt;
}

class CalendarSyncOperationRecord {
  const CalendarSyncOperationRecord({
    required this.operationKey,
    required this.operationType,
    required this.status,
    required this.payloadHash,
    required this.operationPayload,
    required this.attemptCount,
    this.providerEventId,
    this.lastError,
  });

  final String operationKey;
  final String operationType;
  final String status;
  final String payloadHash;
  final Map<String, Object?> operationPayload;
  final int attemptCount;
  final String? providerEventId;
  final String? lastError;
}

abstract interface class CalendarSyncCoordinationGateway {
  Future<CalendarSyncLease> acquire({
    required String calendarId,
    required String scheduleId,
  });

  Future<void> heartbeat(CalendarSyncLease lease);

  Future<CalendarSyncRunRecord> getRun(String runId);

  Future<List<CalendarSyncOperationRecord>> listOperations(String runId);

  Future<void> recordOperation({
    required CalendarSyncLease lease,
    required String operationKey,
    required String operationType,
    required String payloadHash,
    required Map<String, Object?> operationPayload,
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
