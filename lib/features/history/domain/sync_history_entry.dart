enum SyncHistoryStatus { running, success, partialSuccess, failure }

class SyncHistoryEntry {
  const SyncHistoryEntry({
    required this.id,
    required this.startedAt,
    required this.status,
    required this.inserted,
    required this.updated,
    required this.deleted,
    required this.failed,
    this.finishedAt,
    this.message,
    this.scheduleId = 'unknown',
    this.serverRunId,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final SyncHistoryStatus status;
  final int inserted;
  final int updated;
  final int deleted;
  final int failed;
  final String? message;
  final String scheduleId;
  final String? serverRunId;

  SyncHistoryEntry copyWith({
    DateTime? finishedAt,
    SyncHistoryStatus? status,
    int? inserted,
    int? updated,
    int? deleted,
    int? failed,
    String? message,
    String? scheduleId,
    String? serverRunId,
  }) {
    return SyncHistoryEntry(
      id: id,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      status: status ?? this.status,
      inserted: inserted ?? this.inserted,
      updated: updated ?? this.updated,
      deleted: deleted ?? this.deleted,
      failed: failed ?? this.failed,
      message: message ?? this.message,
      scheduleId: scheduleId ?? this.scheduleId,
      serverRunId: serverRunId ?? this.serverRunId,
    );
  }
}
