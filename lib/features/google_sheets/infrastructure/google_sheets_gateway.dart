import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

import '../domain/grid_range.dart';
import '../domain/sheet_cell.dart';
import '../domain/sheet_color.dart';
import '../domain/sheets_gateway.dart';
import '../domain/spreadsheet_snapshot.dart';
import '../../shift_parser/domain/a1_notation.dart';

class GoogleSheetsGateway implements SheetsGateway {
  GoogleSheetsGateway(this._client);

  final http.Client _client;

  @override
  Future<SpreadsheetSnapshot> readSpreadsheet({
    required String spreadsheetId,
    bool includeGridData = true,
  }) async {
    final api = sheets.SheetsApi(_client);

    final spreadsheet = await api.spreadsheets.get(
      spreadsheetId,
      includeGridData: includeGridData,
      $fields: [
        'spreadsheetId',
        'properties(title,locale,timeZone,defaultFormat)',
        'sheets(',
        'properties(sheetId,title,gridProperties(rowCount,columnCount)),',
        'merges,',
        'data(startRow,startColumn,rowData(values(',
        'formattedValue,effectiveValue,userEnteredValue,',
        'effectiveFormat(backgroundColor,backgroundColorStyle,numberFormat)',
        ')))',
        ')',
      ].join(),
    );

    final snapshots = <SpreadsheetSheetSnapshot>[];

    for (final sheet in spreadsheet.sheets ?? const <sheets.Sheet>[]) {
      final properties = sheet.properties;
      if (properties?.sheetId == null || properties?.title == null) {
        continue;
      }

      final sheetId = properties!.sheetId!;
      final mergedRanges = (sheet.merges ?? const <sheets.GridRange>[])
          .map(
            (range) => SheetGridRange(
              sheetId: range.sheetId ?? sheetId,
              startRowIndex: range.startRowIndex ?? 0,
              endRowIndex: range.endRowIndex ?? 0,
              startColumnIndex: range.startColumnIndex ?? 0,
              endColumnIndex: range.endColumnIndex ?? 0,
            ),
          )
          .where(
            (range) =>
                range.endRowIndex > range.startRowIndex &&
                range.endColumnIndex > range.startColumnIndex,
          )
          .toList(growable: false);

      final cells = <SheetCell>[];

      for (final grid in sheet.data ?? const <sheets.GridData>[]) {
        final startRow = grid.startRow ?? 0;
        final startColumn = grid.startColumn ?? 0;
        final rows = grid.rowData ?? const <sheets.RowData>[];

        for (var rowOffset = 0; rowOffset < rows.length; rowOffset++) {
          final rowIndex = startRow + rowOffset;
          final values = rows[rowOffset].values ?? const <sheets.CellData>[];

          for (
            var columnOffset = 0;
            columnOffset < values.length;
            columnOffset++
          ) {
            final columnIndex = startColumn + columnOffset;
            final cell = values[columnOffset];
            final a1 = A1Notation.fromZeroBased(
              rowIndex: rowIndex,
              columnIndex: columnIndex,
            );

            final mergedRange = _findMergedRange(
              ranges: mergedRanges,
              rowIndex: rowIndex,
              columnIndex: columnIndex,
            );

            cells.add(
              SheetCell(
                sheetId: sheetId,
                rowIndex: rowIndex,
                columnIndex: columnIndex,
                a1: a1,
                formattedValue: cell.formattedValue,
                rawValue: _readExtendedValue(cell.effectiveValue),
                formula: cell.userEnteredValue?.formulaValue,
                backgroundColor: _readBackgroundColor(cell.effectiveFormat),
                numberFormatType: cell.effectiveFormat?.numberFormat?.type,
                numberFormatPattern:
                    cell.effectiveFormat?.numberFormat?.pattern,
                isMerged: mergedRange != null,
                mergedAnchorA1: mergedRange == null
                    ? null
                    : A1Notation.fromZeroBased(
                        rowIndex: mergedRange.startRowIndex,
                        columnIndex: mergedRange.startColumnIndex,
                      ),
              ),
            );
          }
        }
      }

      snapshots.add(
        SpreadsheetSheetSnapshot(
          sheetId: sheetId,
          title: properties.title!,
          rowCount: properties.gridProperties?.rowCount ?? 0,
          columnCount: properties.gridProperties?.columnCount ?? 0,
          cells: cells,
          mergedRanges: mergedRanges,
        ),
      );
    }

    return SpreadsheetSnapshot(
      spreadsheetId: spreadsheet.spreadsheetId ?? spreadsheetId,
      title: spreadsheet.properties?.title ?? 'Untitled spreadsheet',
      locale: spreadsheet.properties?.locale,
      timeZone: spreadsheet.properties?.timeZone,
      sheets: snapshots,
    );
  }

  Object? _readExtendedValue(sheets.ExtendedValue? value) {
    if (value == null) {
      return null;
    }
    if (value.stringValue != null) {
      return value.stringValue;
    }
    if (value.numberValue != null) {
      return value.numberValue;
    }
    if (value.boolValue != null) {
      return value.boolValue;
    }
    if (value.errorValue != null) {
      return value.errorValue?.message ?? value.errorValue?.type;
    }
    if (value.formulaValue != null) {
      return value.formulaValue;
    }
    return null;
  }

  SheetColor? _readBackgroundColor(sheets.CellFormat? format) {
    final rgb = format?.backgroundColorStyle?.rgbColor;

    if (rgb == null) {
      return null;
    }

    return SheetColor(
      red: rgb.red ?? 0,
      green: rgb.green ?? 0,
      blue: rgb.blue ?? 0,
      alpha: rgb.alpha ?? 1,
    );
  }

  SheetGridRange? _findMergedRange({
    required List<SheetGridRange> ranges,
    required int rowIndex,
    required int columnIndex,
  }) {
    for (final range in ranges) {
      if (range.contains(rowIndex: rowIndex, columnIndex: columnIndex)) {
        return range;
      }
    }
    return null;
  }
}
