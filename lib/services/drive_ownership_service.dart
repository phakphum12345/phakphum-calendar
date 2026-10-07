import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

enum AccessibleSheetOrder { firstCreated, recentlyModified }

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

/// Lists Google Sheets that the currently authenticated account can access
/// and validates that the selected file is readable.
///
/// Ownership is deliberately not part of the access boundary. A spreadsheet
/// owned by another account is valid when the authenticated account has
/// sufficient read access.
abstract interface class DriveSpreadsheetAccessGateway {
  Future<List<RecentAccessibleSheet>> listAccessibleSpreadsheets(
    http.Client client, {
    int limit = 20,
    AccessibleSheetOrder order = AccessibleSheetOrder.recentlyModified,
  });

  /// Returns the first accessible Google Sheets file created in each month.
  Future<List<RecentAccessibleSheet>> listFirstSpreadsheetOfEachMonth(
    http.Client client, {
    int limit = 1000,
  });

  /// Verifies that the authenticated account can read the spreadsheet.
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

  static const accessibleSheetsQuery =
      "mimeType = '$googleSheetMimeType' and trashed = false";

  @override
  Future<List<RecentAccessibleSheet>> listAccessibleSpreadsheets(
    http.Client client, {
    int limit = 20,
    AccessibleSheetOrder order = AccessibleSheetOrder.recentlyModified,
  }) async {
    final response = await drive.DriveApi(client).files.list(
      q: accessibleSheetsQuery,
      orderBy: switch (order) {
        AccessibleSheetOrder.firstCreated => 'createdTime,name',
        AccessibleSheetOrder.recentlyModified =>
          'modifiedTime desc,name',
      },
      corpora: 'user',
      spaces: 'drive',
      pageSize: limit.clamp(1, 1000),
      $fields:
          'files(id,name,mimeType,ownedByMe,trashed,createdTime,'
          'modifiedTime,modifiedByMeTime,webViewLink)',
    );

    return accessibleSheetsFromFiles(response.files ?? const []);
  }

  @override
  Future<List<RecentAccessibleSheet>> listFirstSpreadsheetOfEachMonth(
    http.Client client, {
    int limit = 1000,
  }) async {
    final files = <drive.File>[];
    String? pageToken;

    do {
      final response = await drive.DriveApi(client).files.list(
        q: accessibleSheetsQuery,
        orderBy: 'createdTime,name',
        corpora: 'user',
        spaces: 'drive',
        pageSize: limit.clamp(1, 1000),
        pageToken: pageToken,
        $fields:
            'nextPageToken,files(id,name,mimeType,ownedByMe,trashed,'
            'createdTime,modifiedTime,modifiedByMeTime,webViewLink)',
      );

      files.addAll(response.files ?? const <drive.File>[]);
      pageToken = response.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    final accessibleFiles = files
        .where(isReadableGoogleSheet)
        .toList()
      ..sort((left, right) {
        final leftDate = left.createdTime;
        final rightDate = right.createdTime;

        if (leftDate == null && rightDate == null) return 0;
        if (leftDate == null) return 1;
        if (rightDate == null) return -1;

        return leftDate.compareTo(rightDate);
      });

    final firstByMonth = <String, drive.File>{};

    for (final file in accessibleFiles) {
      final createdAt = file.createdTime;
      if (createdAt == null) continue;

      final localDate = createdAt.toLocal();
      final monthKey =
          '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}';

      firstByMonth.putIfAbsent(monthKey, () => file);
    }

    final results = firstByMonth.values
        .map(toRecentAccessibleSheet)
        .toList()
      ..sort((left, right) {
        final leftDate = left.createdAt;
        final rightDate = right.createdAt;

        if (leftDate == null && rightDate == null) return 0;
        if (leftDate == null) return 1;
        if (rightDate == null) return -1;

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
    );
  }

  static List<RecentAccessibleSheet> accessibleSheetsFromFiles(
    Iterable<drive.File> files,
  ) {
    return [
      for (final file in files)
        if (isReadableGoogleSheet(file)) toRecentAccessibleSheet(file),
    ];
  }

  static bool isReadableGoogleSheet(drive.File file) {
    return file.id != null &&
        file.id!.isNotEmpty &&
        file.trashed != true &&
        file.mimeType == googleSheetMimeType;
  }

  static RecentAccessibleSheet toRecentAccessibleSheet(
    drive.File file,
  ) {
    return RecentAccessibleSheet(
      id: file.id!,
      name: (file.name?.trim().isNotEmpty ?? false)
          ? file.name!.trim()
          : 'Google Sheets',
      url: file.webViewLink?.trim().isNotEmpty == true
          ? file.webViewLink!.trim()
          : 'https://docs.google.com/spreadsheets/d/${file.id}/edit',
      createdAt: file.createdTime,
      modifiedAt: file.modifiedByMeTime ?? file.modifiedTime,
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
      throw StateError('ไม่พบรหัสไฟล์ Google Sheets');
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$')
        .hasMatch(normalizedFileId)) {
      throw const FormatException(
        'รหัสไฟล์ Google Sheets ไม่ถูกต้อง',
      );
    }

    try {
      final file =
          await drive.DriveApi(client).files.get(
                normalizedFileId,
                supportsAllDrives: true,
                $fields:
                    'id,name,mimeType,ownedByMe,trashed,webViewLink',
              )
              as drive.File;

      validateReadableSpreadsheet(file);
      return file;
    } on drive.DetailedApiRequestError catch (error) {
      if (error.status == 403 || error.status == 404) {
        throw StateError(
          'บัญชี Google ที่เข้าสู่ระบบไม่มีสิทธิ์อ่าน '
          'Google Sheets ไฟล์นี้ กรุณาตรวจสอบสิทธิ์การแชร์ '
          'หรือเลือกไฟล์ใหม่จาก Google Drive',
        );
      }

      rethrow;
    }
  }

  static void validateReadableSpreadsheet(
    drive.File file,
  ) {
    if (file.trashed == true) {
      throw StateError(
        'ไฟล์ Google Sheets อยู่ในถังขยะของ Google Drive',
      );
    }

    if (file.mimeType != googleSheetMimeType) {
      throw StateError(
        'ไฟล์ต้นฉบับต้องเป็น Google Sheets',
      );
    }
  }
}
