import 'package:googleapis/sheets/v4.dart' as sheets;

import '../models/shift.dart';
import 'google_api_client.dart';

class SheetReference {
  const SheetReference({
    required this.spreadsheetId,
    required this.spreadsheetTitle,
    required this.url,
    this.sheetId,
    this.sheetTitle,
  });

  final String spreadsheetId;
  final String spreadsheetTitle;
  final int? sheetId;
  final String? sheetTitle;
  final String url;
}

/// Google Sheets operations required by the legacy roster workflow.
abstract interface class RosterSheetsGateway {
  String parseSpreadsheetId(String input);
  Future<SheetReference> describeSpreadsheet(
    GoogleApiClient client,
    String sourceUrl,
  );
  Future<List<SheetSnapshot>> readAll(GoogleApiClient client, String sourceUrl);
  Future<SheetReference> duplicateSheet(
    GoogleApiClient client, {
    required String sourceUrl,
    required String templateTitle,
    required String newTitle,
  });
}

class SheetsService implements RosterSheetsGateway {
  final Map<String, List<String>> _titleCache = {};

  static String spreadsheetIdFromUrl(String input) {
    final normalized = input.replaceAll(RegExp(r'\s+'), '');
    final match = RegExp(
      r'/spreadsheets/d/([a-zA-Z0-9_-]+)',
    ).firstMatch(normalized);
    if (match != null) return match.group(1)!;
    if (RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(normalized)) {
      return normalized;
    }
    throw const FormatException('ลิงก์ Google Sheets ไม่ถูกต้อง');
  }

  @override
  String parseSpreadsheetId(String input) => spreadsheetIdFromUrl(input);

  static int? sheetIdFromUrl(String input) {
    final match = RegExp(r'(?:[?#&]gid=)(\d+)').firstMatch(input);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static String sheetUrl(String spreadsheetId, [int? sheetId]) =>
      'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit'
      '${sheetId == null ? '' : '#gid=$sheetId'}';

  @override
  Future<SheetReference> describeSpreadsheet(
    GoogleApiClient client,
    String sourceUrl,
  ) async {
    final id = spreadsheetIdFromUrl(sourceUrl);
    final requestedSheetId = sheetIdFromUrl(sourceUrl);
    final api = sheets.SheetsApi(client);
    final metadata = await api.spreadsheets.get(
      id,
      includeGridData: false,
      $fields: 'properties(title),sheets(properties(sheetId,title))',
    );
    final selectedSheet = requestedSheetId == null
        ? null
        : (metadata.sheets ?? const <sheets.Sheet>[])
              .where((sheet) => sheet.properties?.sheetId == requestedSheetId)
              .firstOrNull;
    return SheetReference(
      spreadsheetId: id,
      spreadsheetTitle: metadata.properties?.title ?? 'Google Sheets',
      sheetId: selectedSheet?.properties?.sheetId,
      sheetTitle: selectedSheet?.properties?.title,
      url: sheetUrl(id, selectedSheet?.properties?.sheetId),
    );
  }

  @override
  Future<List<SheetSnapshot>> readAll(
    GoogleApiClient client,
    String sourceUrl,
  ) async {
    final id = spreadsheetIdFromUrl(sourceUrl);
    final api = sheets.SheetsApi(client);
    final requestedSheetId = sheetIdFromUrl(sourceUrl);
    List<String> titles;
    if (requestedSheetId != null) {
      // A URL copied from a specific tab carries gid=<sheetId>. Honor that
      // choice rather than parsing every tab in the spreadsheet.
      final metadata = await api.spreadsheets.get(
        id,
        includeGridData: false,
        $fields: 'sheets(properties(sheetId,title,hidden))',
      );
      final selected = (metadata.sheets ?? const <sheets.Sheet>[])
          .where((sheet) => sheet.properties?.sheetId == requestedSheetId)
          .firstOrNull;
      final selectedTitle = selected?.properties?.title;
      if (selectedTitle == null || selectedTitle.isEmpty) {
        throw StateError('ไม่พบแท็บ Google Sheets ที่เลือก (gid=$requestedSheetId)');
      }
      titles = [selectedTitle];
    } else {
      titles = _titleCache[id] ?? [];
      if (titles.isEmpty) {
        final metadata = await api.spreadsheets.get(
          id,
          includeGridData: false,
          $fields: 'sheets(properties(sheetId,title,hidden))',
        );
        titles = [
          for (final sheet in metadata.sheets ?? const <sheets.Sheet>[])
            if ((sheet.properties?.title ?? '').isNotEmpty &&
                sheet.properties?.hidden != true)
              sheet.properties!.title!,
        ];
        _titleCache[id] = titles;
      }
    }
    final ranges = [
      for (final title in titles) "'${title.replaceAll("'", "''")}'!A1:AF180",
    ];
    final batch = await api.spreadsheets.values.batchGet(
      id,
      ranges: ranges,
      valueRenderOption: 'FORMATTED_VALUE',
      $fields: 'valueRanges(values)',
    );
    final values = batch.valueRanges ?? const <sheets.ValueRange>[];
    final formatted = await api.spreadsheets.get(
      id,
      ranges: ranges,
      includeGridData: true,
      $fields:
          'sheets(properties(title),data(startRow,startColumn,'
          'rowData(values(effectiveFormat(backgroundColorStyle)))))',
    );
    final colorsByTitle = <String, List<List<int?>>>{
      for (final sheet in formatted.sheets ?? const <sheets.Sheet>[])
        if ((sheet.properties?.title ?? '').isNotEmpty)
          sheet.properties!.title!: backgroundColorsForSheet(sheet),
    };
    return [
      for (var index = 0; index < titles.length; index++)
        SheetSnapshot(
          title: titles[index],
          rows:
              (index < values.length
                  ? values[index].values
                  : const <List<Object?>>[]) ??
              const <List<Object?>>[],
          backgroundColors: colorsByTitle[titles[index]] ?? const [],
        ),
    ];
  }

  static List<List<int?>> backgroundColorsForSheet(sheets.Sheet sheet) {
    final result = <List<int?>>[];
    for (final grid in sheet.data ?? const <sheets.GridData>[]) {
      final startRow = grid.startRow ?? 0;
      final startColumn = grid.startColumn ?? 0;
      final rows = grid.rowData ?? const <sheets.RowData>[];
      for (var rowOffset = 0; rowOffset < rows.length; rowOffset++) {
        final rowIndex = startRow + rowOffset;
        while (result.length <= rowIndex) {
          result.add(<int?>[]);
        }
        final cells = rows[rowOffset].values ?? const <sheets.CellData>[];
        for (
          var columnOffset = 0;
          columnOffset < cells.length;
          columnOffset++
        ) {
          final columnIndex = startColumn + columnOffset;
          while (result[rowIndex].length <= columnIndex) {
            result[rowIndex].add(null);
          }
          result[rowIndex][columnIndex] = _colorValue(cells[columnOffset]);
        }
      }
    }
    return result;
  }

  static int? _colorValue(sheets.CellData cell) {
    final color = cell.effectiveFormat?.backgroundColorStyle?.rgbColor;
    if (color == null) return null;
    final red = _colorChannel(color.red);
    final green = _colorChannel(color.green);
    final blue = _colorChannel(color.blue);
    return 0xFF000000 | (red << 16) | (green << 8) | blue;
  }

  static int _colorChannel(double? value) =>
      (((value ?? 0) * 255).round()).clamp(0, 255);

  @override
  Future<SheetReference> duplicateSheet(
    GoogleApiClient client, {
    required String sourceUrl,
    required String templateTitle,
    required String newTitle,
  }) async {
    final id = spreadsheetIdFromUrl(sourceUrl);
    final api = sheets.SheetsApi(client);
    final metadata = await api.spreadsheets.get(
      id,
      includeGridData: false,
      $fields: 'properties(title),sheets(properties(sheetId,title,index))',
    );
    final source = (metadata.sheets ?? const <sheets.Sheet>[])
        .where((sheet) => sheet.properties?.title == templateTitle)
        .firstOrNull;
    if (source?.properties?.sheetId == null) {
      throw StateError('ไม่พบแท็บต้นแบบ “$templateTitle”');
    }
    final duplicateExists = (metadata.sheets ?? const <sheets.Sheet>[]).any(
      (sheet) => sheet.properties?.title == newTitle,
    );
    if (duplicateExists) throw StateError('มีแท็บชื่อ “$newTitle” อยู่แล้ว');

    final response = await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            duplicateSheet: sheets.DuplicateSheetRequest(
              sourceSheetId: source!.properties!.sheetId,
              newSheetName: newTitle,
            ),
          ),
        ],
      ),
      id,
      $fields: 'replies(duplicateSheet(properties(title)))',
    );
    _titleCache.remove(id);
    final created = response.replies?.firstOrNull?.duplicateSheet?.properties;
    return SheetReference(
      spreadsheetId: id,
      spreadsheetTitle: metadata.properties?.title ?? 'Google Sheets',
      sheetId: created?.sheetId,
      sheetTitle: created?.title ?? newTitle,
      url: sheetUrl(id, created?.sheetId),
    );
  }
}
