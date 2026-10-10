import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../models/shift.dart';
import 'local_roster_file_service.dart';

class RosterRevisionDocument {
  const RosterRevisionDocument({
    required this.revisionId,
    required this.modifiedAt,
    required this.snapshots,
  });

  final String revisionId;
  final DateTime modifiedAt;
  final List<SheetSnapshot> snapshots;
}

abstract interface class RosterRevisionGateway {
  Future<List<RosterRevisionDocument>> readHistory(
    http.Client client,
    String fileId,
  );
}

/// Reads Google Drive revision exports only. This service never writes to Drive
/// or Sheets and must be used with a read-only Drive OAuth scope.
class RosterRevisionService implements RosterRevisionGateway {
  const RosterRevisionService({
    this.fileReader = const LocalRosterFileService(),
    this.pageSize = 1000,
  });

  static const xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  final LocalRosterFileService fileReader;
  final int pageSize;
  static final Map<String, RosterRevisionDocument> _memoryCache = {};

  @override
  Future<List<RosterRevisionDocument>> readHistory(
    http.Client client,
    String fileId,
  ) async {
    final api = drive.DriveApi(client);
    final revisions = <drive.Revision>[];
    final effectivePageSize = pageSize < 1
        ? 1
        : pageSize > 1000
        ? 1000
        : pageSize;
    String? pageToken;
    do {
      final response = await api.revisions.list(
        fileId,
        pageSize: effectivePageSize,
        pageToken: pageToken,
        $fields: 'nextPageToken,revisions(id,modifiedTime,exportLinks)',
      );
      revisions.addAll(response.revisions ?? const <drive.Revision>[]);
      pageToken = response.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    revisions.sort((left, right) {
      final leftTime =
          left.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightTime =
          right.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return leftTime.compareTo(rightTime);
    });

    final documents = <RosterRevisionDocument>[];
    const parallelDownloads = 4;
    for (
      var offset = 0;
      offset < revisions.length;
      offset += parallelDownloads
    ) {
      final end = offset + parallelDownloads < revisions.length
          ? offset + parallelDownloads
          : revisions.length;
      final batch = revisions.sublist(offset, end);
      final loaded = await Future.wait([
        for (final revision in batch)
          _readRevision(client, fileId: fileId, revision: revision),
      ]);
      documents.addAll(loaded.whereType<RosterRevisionDocument>());
    }
    documents.sort(
      (left, right) => left.modifiedAt.compareTo(right.modifiedAt),
    );
    return documents;
  }

  /// Reads revision exports without storing them in the in-memory cache.
  /// Useful for on-demand generation where we don't want to retain large
  /// snapshot objects across the application lifetime.
  Future<List<RosterRevisionDocument>> readHistoryTransient(
    http.Client client,
    String fileId,
  ) async {
    final api = drive.DriveApi(client);
    final revisions = <drive.Revision>[];
    final effectivePageSize = pageSize < 1
        ? 1
        : pageSize > 1000
        ? 1000
        : pageSize;
    String? pageToken;
    do {
      final response = await api.revisions.list(
        fileId,
        pageSize: effectivePageSize,
        pageToken: pageToken,
        $fields: 'nextPageToken,revisions(id,modifiedTime,exportLinks)',
      );
      revisions.addAll(response.revisions ?? const <drive.Revision>[]);
      pageToken = response.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    revisions.sort((left, right) {
      final leftTime =
          left.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightTime =
          right.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return leftTime.compareTo(rightTime);
    });

    final documents = <RosterRevisionDocument>[];
    const parallelDownloads = 4;
    for (
      var offset = 0;
      offset < revisions.length;
      offset += parallelDownloads
    ) {
      final end = offset + parallelDownloads < revisions.length
          ? offset + parallelDownloads
          : revisions.length;
      final batch = revisions.sublist(offset, end);
      final loaded = await Future.wait([
        for (final revision in batch)
          _readRevisionTransient(client, fileId: fileId, revision: revision),
      ]);
      documents.addAll(loaded.whereType<RosterRevisionDocument>());
    }
    documents.sort(
      (left, right) => left.modifiedAt.compareTo(right.modifiedAt),
    );
    return documents;
  }

  Future<RosterRevisionDocument?> _readRevision(
    http.Client client, {
    required String fileId,
    required drive.Revision revision,
  }) async {
    final revisionId = revision.id;
    final modifiedAt = revision.modifiedTime;
    final exportUrl = revision.exportLinks?[xlsxMimeType];
    if (revisionId == null ||
        revisionId.isEmpty ||
        modifiedAt == null ||
        exportUrl == null ||
        exportUrl.isEmpty) {
      return null;
    }
    final cacheKey = '$fileId|$revisionId';
    final cached = _memoryCache[cacheKey];
    if (cached != null) return cached;

    try {
      final response = await client.get(Uri.parse(exportUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Could not download revision $revisionId '
          '(HTTP ${response.statusCode}).',
        );
      }
      final document = fileReader.readBytes(
        name: 'revision-$revisionId.xlsx',
        bytes: response.bodyBytes,
      );
      final result = RosterRevisionDocument(
        revisionId: revisionId,
        modifiedAt: modifiedAt,
        snapshots: document.snapshots,
      );
      _memoryCache[cacheKey] = result;
      return result;
    } catch (_) {
      // One bad/oversized historical export must not block the live roster.
      return null;
    }
  }

  Future<RosterRevisionDocument?> _readRevisionTransient(
    http.Client client, {
    required String fileId,
    required drive.Revision revision,
  }) async {
    final revisionId = revision.id;
    final modifiedAt = revision.modifiedTime;
    final exportUrl = revision.exportLinks?[xlsxMimeType];
    if (revisionId == null ||
        revisionId.isEmpty ||
        modifiedAt == null ||
        exportUrl == null ||
        exportUrl.isEmpty) {
      return null;
    }

    try {
      final response = await client.get(Uri.parse(exportUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Could not download revision $revisionId '
          '(HTTP ${response.statusCode}).',
        );
      }
      final document = fileReader.readBytes(
        name: 'revision-$revisionId.xlsx',
        bytes: response.bodyBytes,
      );
      final result = RosterRevisionDocument(
        revisionId: revisionId,
        modifiedAt: modifiedAt,
        snapshots: document.snapshots,
      );
      return result;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StateError('Could not read Google Sheets revision $revisionId: $error'),
        stackTrace,
      );
    }
  }
}
