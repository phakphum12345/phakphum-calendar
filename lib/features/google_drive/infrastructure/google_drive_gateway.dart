import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../domain/drive_gateway.dart';
import '../domain/roster_file.dart';

class GoogleDriveGateway implements DriveGateway {
  GoogleDriveGateway(this._client);

  static const String spreadsheetMimeType =
      'application/vnd.google-apps.spreadsheet';

  final http.Client _client;

  @override
  Future<List<RosterFile>> listSpreadsheets({
    int pageSize = 50,
    String? pageToken,
  }) async {
    final api = drive.DriveApi(_client);

    final result = await api.files.list(
      q: "mimeType='$spreadsheetMimeType' and trashed=false",
      spaces: 'drive',
      orderBy: 'modifiedTime desc',
      pageSize: pageSize,
      pageToken: pageToken,
      $fields: 'nextPageToken,files(id,name,modifiedTime,webViewLink,mimeType)',
    );

    return result.files
            ?.where((file) => file.id != null && file.name != null)
            .map(
              (file) => RosterFile(
                id: file.id!,
                name: file.name!,
                modifiedTime: file.modifiedTime,
                webViewLink: file.webViewLink,
              ),
            )
            .toList(growable: false) ??
        const <RosterFile>[];
  }
}
