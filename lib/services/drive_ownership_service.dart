import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

enum OwnedSheetOrder {
  firstCreated,
  recentlyModified,
}

class RecentOwnedSheet {
  const RecentOwnedSheet({
    required this.id,
    required this.name,
    required this.url,
    this.createdAt,
    this.modifiedAt,
  });

  final String id;
  final String name;
  final String url;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
}

/// Compatibility API for Google Drive spreadsheet access.
///
/// IMPORTANT:
/// The historical class name contains "Ownership" for API compatibility.
/// It MUST NOT be interpreted as a requirement that the Google Sheet is
/// owned by the currently authenticated Google account.
///
/// Authorization boundary:
///
///   authenticated account can READ the Google Sheet
///
/// NOT:
///
///   authenticated account owns the Google Sheet
abstract interface class DriveOwnershipGateway {
  /// Lists Google Sheets accessible to the authenticated account.
  ///
  /// Shared Sheets are valid. `ownedByMe` is NOT an access filter.
  Future<List<RecentOwnedSheet>> listOwnedSpreadsheets(
    http.Client client, {
    int limit = 20,
    OwnedSheetOrder order = OwnedSheetOrder.recentlyModified,
  });

  /// Returns the first readable Google Sheet created in each calendar month.
  ///
  /// The historical method name is retained for compatibility.
  Future<List<RecentOwnedSheet>> listFirstSpreadsheetOfEachMonth(
    http.Client client, {
    int limit = 1000,
  });

  /// Verifies that the authenticated account can read the Google Sheet.
  ///
  /// Despite the historical method name, Google Sheet ownership is NOT
  /// required.
  Future<drive.File> requireOwnedSpreadsheet(
    http.Client client,
    String fileId,
  );
}

class DriveOwnershipService implements DriveOwnershipGateway {
  const DriveOwnershipService();

  static const googleSheetMimeType =
      'application/vnd.google-apps.spreadsheet';

  static const accessibleSpreadsheetsQuery =
      "mimeType = '$googleSheetMimeType' and trashed = false";

  /// Backward-compatible name retained for existing tests/callers.
  ///
  /// Despite the historical name, this query does NOT require ownership.
  /// It returns Google Sheets accessible to the authenticated account,
  /// including Sheets shared by another account.
  static const recentOwnedSheetsQuery =
      accessibleSpreadsheetsQuery;

  @override
  Future<List<RecentOwnedSheet>> listOwnedSpreadsheets(
    http.Client client, {
    int limit = 20,
    OwnedSheetOrder order = OwnedSheetOrder.recentlyModified,
  }) async {
    final response = await drive.DriveApi(client).files.list(
      q: accessibleSpreadsheetsQuery,
      orderBy: switch (order) {
        OwnedSheetOrder.firstCreated => 'createdTime,name',
        OwnedSheetOrder.recentlyModified =>
          'modifiedTime desc,name',
      },
      corpora: 'user',
      spaces: 'drive',
      pageSize: limit.clamp(1, 1000),
      $fields:
          'files(id,name,mimeType,ownedByMe,trashed,'
          'createdTime,modifiedTime,modifiedByMeTime,webViewLink)',
    );

    return recentOwnedSheetsFromFiles(
      response.files ?? const <drive.File>[],
    );
  }

  @override
  Future<List<RecentOwnedSheet>> listFirstSpreadsheetOfEachMonth(
    http.Client client, {
    int limit = 1000,
  }) async {
    final files = <drive.File>[];
    String? pageToken;

    do {
      final response = await drive.DriveApi(client).files.list(
        q: accessibleSpreadsheetsQuery,
        orderBy: 'createdTime,name',
        corpora: 'user',
        spaces: 'drive',
        pageSize: limit.clamp(1, 1000),
        pageToken: pageToken,
        $fields:
            'nextPageToken,files(id,name,mimeType,ownedByMe,'
            'trashed,createdTime,modifiedTime,modifiedByMeTime,'
            'webViewLink)',
      );

      files.addAll(
        response.files ?? const <drive.File>[],
      );

      pageToken = response.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    final accessibleFiles = files
        .where(_isReadableGoogleSheet)
        .toList()
      ..sort((left, right) {
        final leftDate = left.createdTime;
        final rightDate = right.createdTime;

        if (leftDate == null && rightDate == null) {
          return 0;
        }

        if (leftDate == null) {
          return 1;
        }

        if (rightDate == null) {
          return -1;
        }

        return leftDate.compareTo(rightDate);
      });

    final firstByMonth = <String, drive.File>{};

    for (final file in accessibleFiles) {
      final createdAt = file.createdTime;

      if (createdAt == null) {
        continue;
      }

      final localDate = createdAt.toLocal();

      final monthKey =
          '${localDate.year}-'
          '${localDate.month.toString().padLeft(2, '0')}';

      firstByMonth.putIfAbsent(
        monthKey,
        () => file,
      );
    }

    final results = firstByMonth.values
        .map(_toRecentOwnedSheet)
        .toList()
      ..sort((left, right) {
        final leftDate = left.createdAt;
        final rightDate = right.createdAt;

        if (leftDate == null && rightDate == null) {
          return 0;
        }

        if (leftDate == null) {
          return 1;
        }

        if (rightDate == null) {
          return -1;
        }

        return rightDate.compareTo(leftDate);
      });

    return results;
  }

  Future<List<RecentOwnedSheet>>
      listRecentlyModifiedOwnedSpreadsheets(
    http.Client client, {
    int limit = 20,
  }) {
    return listOwnedSpreadsheets(
      client,
      limit: limit,
      order: OwnedSheetOrder.recentlyModified,
    );
  }

  static List<RecentOwnedSheet> recentOwnedSheetsFromFiles(
    Iterable<drive.File> files,
  ) {
    return [
      for (final file in files)
        if (_isReadableGoogleSheet(file))
          _toRecentOwnedSheet(file),
    ];
  }

  static bool _isReadableGoogleSheet(drive.File file) {
    return file.id != null &&
        file.id!.isNotEmpty &&
        file.trashed != true &&
        file.mimeType == googleSheetMimeType;
  }

  static RecentOwnedSheet _toRecentOwnedSheet(
    drive.File file,
  ) {
    final id = file.id!;

    return RecentOwnedSheet(
      id: id,
      name: (file.name?.trim().isNotEmpty ?? false)
          ? file.name!.trim()
          : 'Google Sheets',
      url: file.webViewLink?.trim().isNotEmpty == true
          ? file.webViewLink!.trim()
          : 'https://docs.google.com/spreadsheets/d/$id/edit',
      createdAt: file.createdTime,
      modifiedAt:
          file.modifiedByMeTime ?? file.modifiedTime,
    );
  }

  @override
  Future<drive.File> requireOwnedSpreadsheet(
    http.Client client,
    String fileId,
  ) async {
    final normalizedFileId =
        fileId.replaceAll(RegExp(r'\s+'), '');

    if (normalizedFileId.isEmpty) {
      throw StateError(
        'ไม่พบรหัสไฟล์ Google Sheets',
      );
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$')
        .hasMatch(normalizedFileId)) {
      throw const FormatException(
        'รหัสไฟล์ Google Sheets ไม่ถูกต้อง',
      );
    }

    try {
      final file = await drive.DriveApi(client).files.get(
            normalizedFileId,
            supportsAllDrives: true,
            $fields:
                'id,name,mimeType,ownedByMe,trashed,webViewLink',
          ) as drive.File;

      validateOwnedSpreadsheet(file);

      return file;
    } on drive.DetailedApiRequestError catch (error) {
      if (error.status == 403 ||
          error.status == 404) {
        throw StateError(
          'บัญชี Google ที่เข้าสู่ระบบไม่มีสิทธิ์อ่าน '
          'Google Sheets ไฟล์นี้ '
          'กรุณาตรวจสอบสิทธิ์การแชร์ '
          'กรุณาเลือกไฟล์ใหม่จาก Google Drive',
        );
      }

      rethrow;
    }
  }

  /// Compatibility method name retained intentionally.
  ///
  /// IMPORTANT:
  /// `ownedByMe` is NOT checked.
  ///
  /// A Sheet owned by another Google account is valid when the
  /// authenticated account can read it.
  ///
  /// This validator checks only the properties of the returned Drive
  /// resource itself. File-ID validation belongs to
  /// requireOwnedSpreadsheet() before the Drive API request.
  static void validateOwnedSpreadsheet(
    drive.File file,
  ) {
    if (file.trashed == true) {
      throw StateError(
        'ไฟล์ต้นฉบับอยู่ในถังขยะของ Google Drive',
      );
    }

    if (file.mimeType != googleSheetMimeType) {
      throw StateError(
        'ไฟล์ต้นฉบับต้องเป็น Google Sheets',
      );
    }

    // DO NOT check:
    //
    // file.ownedByMe == true
    //
    // Google Sheet ownership is NOT the authorization boundary.
    //
    // DO NOT require file.id here either.
    //
    // The Drive API request in requireOwnedSpreadsheet() already uses
    // the normalized spreadsheet ID. This validator intentionally
    // validates only the returned resource's type/state.
  }
}

