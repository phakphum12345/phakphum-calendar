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
    const parallelDownloads = 2;
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
    String fileId, {
    void Function(String revisionId, Object error)? onRevisionSkipped,
  }) async {
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
    const parallelDownloads = 2;
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
          _readRevisionTransient(
            client,
            fileId: fileId,
            revision: revision,
            onRevisionSkipped: onRevisionSkipped,
          ),
      ]);
      documents.addAll(loaded.whereType<RosterRevisionDocument>());
    }
    documents.sort(
      (left, right) => left.modifiedAt.compareTo(right.modifiedAt),
    );
    return documents;
  }

  /// Retries transient Drive export throttling without re-listing history.
  /// Keep concurrency low because each revision export is a separate request.
  Future<http.Response> _downloadRevisionExport(
    http.Client client,
    String exportUrl,
  ) async {
    const maxAttempts = 4;
    const retryableStatuses = <int>{429, 500, 502, 503, 504};
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await client.get(Uri.parse(exportUrl));
        if (!retryableStatuses.contains(response.statusCode) ||
            attempt == maxAttempts) {
          return response;
        }
        final retryAfter = response.headers['retry-after'];
        final retryAfterSeconds = int.tryParse(retryAfter ?? '');
        final retryAfterDate = retryAfter == null
            ? null
            : DateTime.tryParse(retryAfter);
        final dateDelay = retryAfterDate?.difference(DateTime.now());
        final backoff = Duration(milliseconds: 500 * (1 << (attempt - 1)));
        final requestedDelay = retryAfterSeconds != null
            ? Duration(seconds: retryAfterSeconds)
            : dateDelay != null && !dateDelay.isNegative
            ? dateDelay
            : backoff;
        // Avoid a server-supplied Retry-After making the UI wait indefinitely.
        final delay = requestedDelay > const Duration(seconds: 8)
            ? const Duration(seconds: 8)
            : requestedDelay;
        await Future<void>.delayed(delay);
      } on Object catch (error) {
        lastError = error;
        if (attempt == maxAttempts) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 500 * (1 << (attempt - 1))),
        );
      }
    }
    throw StateError('Could not download revision export: $lastError');
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
      final response = await _downloadRevisionExport(client, exportUrl);
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
    void Function(String revisionId, Object error)? onRevisionSkipped,
  }) async {
    final revisionId = revision.id;
    final modifiedAt = revision.modifiedTime;
    final exportUrl = revision.exportLinks?[xlsxMimeType];
    if (revisionId == null ||
        revisionId.isEmpty ||
        modifiedAt == null ||
        exportUrl == null ||
        exportUrl.isEmpty) {
      onRevisionSkipped?.call(
        revisionId?.isNotEmpty == true ? revisionId! : 'unknown',
        const FormatException(
          'Revision metadata or XLSX export link is missing.',
        ),
      );
      return null;
    }

    try {
      final response = await _downloadRevisionExport(client, exportUrl);
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
      return RosterRevisionDocument(
        revisionId: revisionId,
        modifiedAt: modifiedAt,
        snapshots: document.snapshots,
      );
    } on Object catch (error) {
      // A single unavailable revision must not discard other readable history.
      onRevisionSkipped?.call(revisionId, error);
      return null;
    }
  }
}
