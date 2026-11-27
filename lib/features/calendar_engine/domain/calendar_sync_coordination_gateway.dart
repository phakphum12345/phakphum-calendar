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
    this.operationCount = 0,
    this.insertedCount = 0,
    this.updatedCount = 0,
    this.deletedCount = 0,
    this.failedCount = 0,
    this.pendingCount = 0,
  });

  final String runId;
  final String calendarId;
  final String scheduleId;
  final String status;
  final DateTime startedAt;
  final DateTime heartbeatAt;
  final DateTime? finishedAt;
  final int operationCount;
  final int insertedCount;
  final int updatedCount;
  final int deletedCount;
  final int failedCount;
  final int pendingCount;
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

  Future<CalendarSyncRunRecord?> getRun(String runId);

  Future<List<CalendarSyncRunRecord>> listRuns({
    String? calendarId,
    int limit = 50,
  });

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
