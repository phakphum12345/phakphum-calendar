import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

enum AccessibleSheetOrder {
  firstCreated,
  recentlyModified,
}

class RecentAccessibleSheet {
  const RecentAccessibleSheet({
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

/// Google Drive access boundary for Google Sheets.
///
/// IMPORTANT:
/// A Google Sheet does NOT need to be owned by the signed-in account.
/// The authenticated account only needs sufficient read access.
///
/// This service deliberately does NOT use `ownedByMe` as an authorization
/// condition.
abstract interface class DriveSpreadsheetAccessGateway {
  /// Lists Google Sheets accessible to the authenticated account.
  Future<List<RecentAccessibleSheet>> listAccessibleSpreadsheets(
    http.Client client, {
    int limit = 20,
    AccessibleSheetOrder order =
        AccessibleSheetOrder.recentlyModified,
  });

  /// Returns the first accessible Google Sheet created in each calendar month.
  Future<List<RecentAccessibleSheet>> listFirstSpreadsheetOfEachMonth(
    http.Client client, {
    int limit = 1000,
  });

  /// Verifies that [fileId] is a readable Google Sheet.
  ///
  /// Ownership is intentionally NOT required.
  Future<drive.File> requireReadableSpreadsheet(
    http.Client client,
    String fileId,
  );
}

class DriveSpreadsheetAccessService
    implements DriveSpreadsheetAccessGateway {
  const DriveSpreadsheetAccessService();

  static const googleSheetMimeType =
      'application/vnd.google-apps.spreadsheet';

  static const accessibleSpreadsheetsQuery =
      "mimeType = '$googleSheetMimeType' and trashed = false";

  @override
  Future<List<RecentAccessibleSheet>> listAccessibleSpreadsheets(
    http.Client client, {
    int limit = 20,
    AccessibleSheetOrder order =
        AccessibleSheetOrder.recentlyModified,
  }) async {
    final response = await drive.DriveApi(client).files.list(
      q: accessibleSpreadsheetsQuery,
      orderBy: switch (order) {
        AccessibleSheetOrder.firstCreated =>
          'createdTime,name',
        AccessibleSheetOrder.recentlyModified =>
          'modifiedTime desc,name',
      },
      corpora: 'user',
      spaces: 'drive',
      pageSize: limit.clamp(1, 1000),
      $fields:
          'files(id,name,mimeType,ownedByMe,trashed,'
          'createdTime,modifiedTime,modifiedByMeTime,webViewLink)',
    );

    return accessibleSheetsFromFiles(
      response.files ?? const <drive.File>[],
    );
  }

  @override
  Future<List<RecentAccessibleSheet>>
      listFirstSpreadsheetOfEachMonth(
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
        .map(_toRecentAccessibleSheet)
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

  Future<List<RecentAccessibleSheet>>
      listRecentlyModifiedAccessibleSpreadsheets(
    http.Client client, {
    int limit = 20,
  }) {
    return listAccessibleSpreadsheets(
      client,
      limit: limit,
      order: AccessibleSheetOrder.recentlyModified,
    );
  }

  static List<RecentAccessibleSheet> accessibleSheetsFromFiles(
    Iterable<drive.File> files,
  ) {
    return [
      for (final file in files)
        if (_isReadableGoogleSheet(file))
          _toRecentAccessibleSheet(file),
    ];
  }

  static bool _isReadableGoogleSheet(drive.File file) {
    return file.id != null &&
        file.id!.isNotEmpty &&
        file.trashed != true &&
        file.mimeType == googleSheetMimeType;
  }

  static RecentAccessibleSheet _toRecentAccessibleSheet(
    drive.File file,
  ) {
    final id = file.id!;

    return RecentAccessibleSheet(
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
  Future<drive.File> requireReadableSpreadsheet(
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

      validateReadableSpreadsheet(file);

      return file;
    } on drive.DetailedApiRequestError catch (error) {
      if (error.status == 403 ||
          error.status == 404) {
        throw StateError(
          'บัญชี Google ที่เข้าสู่ระบบไม่มีสิทธิ์อ่าน '
          'Google Sheets ไฟล์นี้ '
          'กรุณาตรวจสอบสิทธิ์การแชร์ '
          'หรือเลือกไฟล์ใหม่จาก Google Drive',
        );
      }

      rethrow;
    }
  }

  /// Validates Google Sheets type and readability boundary.
  ///
  /// IMPORTANT:
  /// `ownedByMe` is intentionally NOT checked.
  ///
  /// A shared Google Sheet is valid when the authenticated account
  /// can read it.
  static void validateReadableSpreadsheet(
    drive.File file,
  ) {
    if (file.id == null || file.id!.isEmpty) {
      throw StateError(
        'ไม่พบรหัสไฟล์ Google Sheets',
      );
    }

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

    // DO NOT check file.ownedByMe.
    //
    // Ownership is not the authorization boundary.
    // Successful files.get() already proves that the authenticated
    // account can access the file metadata.
  }
}
