import 'dart:convert';
import '../domain/sync_history_entry.dart';

class SyncHistoryJsonCodec {
  const SyncHistoryJsonCodec();

  String encodeList(List<SyncHistoryEntry> entries) => jsonEncode(
    entries
        .map(
          (entry) => <String, Object?>{
            'id': entry.id,
            'startedAt': entry.startedAt.toIso8601String(),
            'finishedAt': entry.finishedAt?.toIso8601String(),
            'status': entry.status.name,
            'inserted': entry.inserted,
            'updated': entry.updated,
            'deleted': entry.deleted,
            'failed': entry.failed,
            'pending': entry.pending,
            'message': entry.message,
            'scheduleId': entry.scheduleId,
            'serverRunId': entry.serverRunId,
          },
        )
        .toList(growable: false),
  );

  List<SyncHistoryEntry> decodeList(String? source) {
    if (source == null || source.trim().isEmpty) {
      return const <SyncHistoryEntry>[];
    }
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('History payload must be a JSON list.');
    }
    return decoded
        .map((value) {
          final json = Map<String, Object?>.from(value as Map);
          return SyncHistoryEntry(
            id: json['id']! as String,
            startedAt: DateTime.parse(json['startedAt']! as String),
            finishedAt: json['finishedAt'] == null
                ? null
                : DateTime.parse(json['finishedAt']! as String),
            status: SyncHistoryStatus.values.byName(json['status']! as String),
            inserted: (json['inserted'] as num?)?.toInt() ?? 0,
            updated: (json['updated'] as num?)?.toInt() ?? 0,
            deleted: (json['deleted'] as num?)?.toInt() ?? 0,
            failed: (json['failed'] as num?)?.toInt() ?? 0,
            pending: (json['pending'] as num?)?.toInt() ?? 0,
            message: json['message'] as String?,
            scheduleId: json['scheduleId'] as String? ?? 'unknown',
            serverRunId: json['serverRunId'] as String?,
          );
        })
        .toList(growable: false);
  }
}
