import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/excel_import/data/excel_reader_service.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_file.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_workbook_scanner.dart';

void main() {
  test('preserves Excel background colors through normalized parser cells', () {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Roster');
    final sheet = workbook['Roster'];
    sheet.appendRow([TextCellValue('เวร')]);
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.red,
    );
    final file = ImportFile(
      name: 'colored-roster.xlsx',
      bytes: Uint8List.fromList(workbook.encode()!),
    );
    final reader = ExcelReaderService();
    final info = reader.openWorkbook(file);
    final worksheet = info.worksheets.single;
    final rows = reader.readWorksheetForImport(worksheet);

    final input = const GridRosterExcelInputAdapter().toParserInput(
      file: file,
      worksheet: worksheet,
      worksheetIndex: 0,
      rows: rows,
    );

    expect(input.cells.single.backgroundColor?.hex, '#F44336');
  });

  test('carries merged-cell anchor provenance into normalized parser cells', () {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Roster');
    final sheet = workbook['Roster'];
    sheet.appendRow([TextCellValue('Department'), TextCellValue('')]);
    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('B1'),
      customValue: TextCellValue('Department'),
    );
    final file = ImportFile(
      name: 'merged-roster.xlsx',
      bytes: Uint8List.fromList(workbook.encode()!),
    );
    final reader = ExcelReaderService();
    final info = reader.openWorkbook(file);
    final worksheet = info.worksheets.single;
    final rows = reader.readWorksheetForImport(worksheet);

    final input = const GridRosterExcelInputAdapter().toParserInput(
      file: file,
      worksheet: worksheet,
      worksheetIndex: 0,
      rows: rows,
    );

    final anchor = input.cells.singleWhere((cell) => cell.a1 == 'A1');
    final continuation = input.cells.singleWhere((cell) => cell.a1 == 'B1');
    expect(anchor.isMerged, isTrue);
    expect(anchor.mergedAnchorA1, 'A1');
    expect(continuation.isMerged, isTrue);
    expect(continuation.mergedAnchorA1, 'A1');
    expect(continuation.text, isEmpty);
  });
}
