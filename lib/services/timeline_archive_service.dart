import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shift.dart';
import 'roster_revision_service.dart';

/// Durable local cache for revision snapshots and resumable sync progress.
///
/// Records are scoped to the signed-in Google account and source file. A
/// revision is written before the checkpoint advances, so an interrupted sync
/// never marks an unpersisted revision as complete.
class TimelineArchiveService {
  const TimelineArchiveService();

  static const _indexPrefix = 'timeline_archive_index_v1_';
  static const _recordPrefix = 'timeline_archive_record_v1_';
  static const _checkpointPrefix = 'timeline_archive_checkpoint_v1_';

  String _scope(String accountId, String fileId) {
    final bytes = utf8.encode('${accountId.trim().toLowerCase()}|$fileId');
    return sha256.convert(bytes).toString();
  }

  String _recordKey(String scope, String revisionId) {
    final revisionHash = sha256.convert(utf8.encode(revisionId)).toString();
    return '$_recordPrefix${scope}_$revisionHash';
  }

  /// Persist one revision idempotently. Re-reading the same revision replaces
  /// its record instead of creating duplicates.
  Future<void> putRevision({
    required String accountId,
    required String fileId,
    required RosterRevisionDocument document,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final scope = _scope(accountId, fileId);
    final key = _recordKey(scope, document.revisionId);
    final record = <String, Object?>{
      'revisionId': document.revisionId,
      'modifiedAt': document.modifiedAt.toUtc().toIso8601String(),
      'snapshots': [
        for (final snapshot in document.snapshots)
          {
            'title': snapshot.title,
            'rows': [
              for (final row in snapshot.rows)
                [for (final value in row) _jsonSafe(value)],
            ],
            'backgroundColors': snapshot.backgroundColors,
          },
      ],
    };
    final saved = await prefs.setString(key, jsonEncode(record));
    if (!saved) {
      throw StateError('Could not persist Timeline revision ${document.revisionId}.');
    }

    final indexKey = '$_indexPrefix$scope';
    final ids = (prefs.getStringList(indexKey) ?? <String>[]).toSet()
      ..add(document.revisionId);
    final indexSaved = await prefs.setStringList(indexKey, ids.toList()..sort());
    if (!indexSaved) {
      throw StateError('Could not update Timeline archive index.');
    }
  }

  /// Load archived revisions ordered by their original modification time.
  Future<List<RosterRevisionDocument>> readRevisions({
    required String accountId,
    required String fileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final scope = _scope(accountId, fileId);
    final ids = prefs.getStringList('$_indexPrefix$scope') ?? const <String>[];
    final documents = <RosterRevisionDocument>[];
    for (final id in ids) {
      final raw = prefs.getString(_recordKey(scope, id));
      if (raw == null) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final snapshots = (map['snapshots'] as List<dynamic>? ?? const [])
            .map((item) {
              final value = item as Map<String, dynamic>;
              return SheetSnapshot(
                title: value['title'] as String? ?? '',
                rows: (value['rows'] as List<dynamic>? ?? const [])
                    .map((row) => (row as List<dynamic>).cast<Object?>())
                    .toList(),
                backgroundColors:
                    (value['backgroundColors'] as List<dynamic>? ?? const [])
                        .map((row) => (row as List<dynamic>)
                            .map((cell) => cell as int?)
                            .toList())
                        .toList(),
              );
            })
            .toList();
        documents.add(RosterRevisionDocument(
          revisionId: map['revisionId'] as String,
          modifiedAt: DateTime.parse(map['modifiedAt'] as String),
          snapshots: snapshots,
        ));
      } on Object {
        // A corrupt record is omitted from results; the sync status remains
        // incomplete rather than deleting or overwriting other valid records.
        continue;
      }
    }
    documents.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
    return documents;
  }

  /// Save the next revision index only after all earlier records were stored.
  Future<void> saveCheckpoint({
    required String accountId,
    required String fileId,
    required int nextIndex,
    required int total,
    required bool complete,
    String? lastError,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final scope = _scope(accountId, fileId);
    final payload = jsonEncode({
      'nextIndex': nextIndex < 0 ? 0 : nextIndex,
      'total': total < 0 ? 0 : total,
      'complete': complete,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      if (lastError != null) 'lastError': lastError,
    });
    final saved = await prefs.setString('$_checkpointPrefix$scope', payload);
    if (!saved) throw StateError('Could not persist Timeline sync checkpoint.');
  }

  Future<Map<String, dynamic>?> readCheckpoint({
    required String accountId,
    required String fileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_checkpointPrefix${_scope(accountId, fileId)}');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  Object? _jsonSafe(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    return value.toString();
  }
}
