import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/excel_import/data/excel_reader_service.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_error.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_file.dart';

void main() {
  test('opens an xlsx workbook and lists its worksheets', () {
    final service = ExcelReaderService();
    final workbook = service.openWorkbook(_workbookFile());

    expect(workbook.file.name, 'roster.xlsx');
    expect(
      workbook.worksheets.map((worksheet) => worksheet.name),
      containsAll(['Roster', 'Summary']),
    );
    expect(
      workbook.worksheets
          .singleWhere((worksheet) => worksheet.name == 'Roster')
          .rowCount,
      2,
    );
  });

  test('reads worksheet rows and typed cell values', () {
    final service = ExcelReaderService();
    final workbook = service.openWorkbook(_workbookFile());
    final roster = workbook.worksheets.singleWhere(
      (worksheet) => worksheet.name == 'Roster',
    );

    final rows = service.readWorksheet(roster);

    expect(rows, hasLength(2));
    expect(rows.first.cells.map((cell) => cell.value), ['Name', 'Shift']);
    expect(rows[1].cells.map((cell) => cell.value), ['Anan', 'Morning']);
  });

  test('rejects files that are not xlsx workbooks', () {
    final service = ExcelReaderService();
    final file = ImportFile(name: 'roster.csv', bytes: Uint8List.fromList([1]));

    expect(
      () => service.openWorkbook(file),
      throwsA(
        isA<ExcelReaderException>().having(
          (exception) => exception.error.code,
          'code',
          ImportErrorCode.unsupportedExtension,
        ),
      ),
    );
  });

  test('limits preview rows to 50 and tolerates merged and empty cells', () {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Roster');
    final sheet = workbook['Roster'];
    for (var index = 0; index < 55; index++) {
      sheet.appendRow([
        TextCellValue('Row ${index + 1}'),
        if (index.isEven) TextCellValue('Value') else null,
      ]);
    }
    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('B1'),
      customValue: TextCellValue('Merged header'),
    );
    final service = ExcelReaderService();
    final file = ImportFile(
      name: 'large-roster.xlsx',
      bytes: Uint8List.fromList(workbook.encode()!),
    );

    final workbookInfo = service.openWorkbook(file);
    final worksheet = workbookInfo.worksheets.single;
    final previewRows = service.readWorksheet(worksheet);

    expect(worksheet.rowCount, 55);
    expect(previewRows, hasLength(ExcelReaderService.maxPreviewRows));
    expect(previewRows.first.cells.first.value, 'Merged header');
    expect(previewRows[1].cells[1].value, isNull);
  });

  test('preserves merged range anchor coordinates for every covered cell', () {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Roster');
    final sheet = workbook['Roster'];
    sheet.appendRow([TextCellValue('Period'), TextCellValue('')]);
    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('B1'),
      customValue: TextCellValue('Period'),
    );
    final service = ExcelReaderService();
    final file = ImportFile(
      name: 'merged-roster.xlsx',
      bytes: Uint8List.fromList(workbook.encode()!),
    );

    final workbookInfo = service.openWorkbook(file);
    final worksheet = workbookInfo.worksheets.single;
    final rows = service.readWorksheetForImport(worksheet);

    expect(rows.first.cells, hasLength(2));
    for (final cell in rows.first.cells) {
      expect(cell.isMerged, isTrue);
      expect(cell.mergedAnchorRowIndex, 0);
      expect(cell.mergedAnchorColumnIndex, 0);
    }
  });

  test('reads every worksheet row for import', () {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Roster');
    final sheet = workbook['Roster'];
    for (var index = 0; index < 55; index++) {
      sheet.appendRow([TextCellValue('Row ${index + 1}')]);
    }
    final service = ExcelReaderService();
    final file = ImportFile(
      name: 'large-roster.xlsx',
      bytes: Uint8List.fromList(workbook.encode()!),
    );

    final workbookInfo = service.openWorkbook(file);
    final worksheet = workbookInfo.worksheets.single;
    final importRows = service.readWorksheetForImport(worksheet);

    expect(importRows, hasLength(55));
    expect(importRows.last.cells.single.value, 'Row 55');
  });
}

ImportFile _workbookFile() {
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', 'Roster');
  workbook['Roster']
    ..appendRow([TextCellValue('Name'), TextCellValue('Shift')])
    ..appendRow([TextCellValue('Anan'), TextCellValue('Morning')]);
  workbook['Summary'].appendRow([TextCellValue('Total'), IntCellValue(1)]);

  return ImportFile(
    name: 'roster.xlsx',
    bytes: Uint8List.fromList(workbook.encode()!),
  );
}
