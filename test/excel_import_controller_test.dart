import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/excel_import/data/excel_reader_service.dart';
import 'package:phakphum_calendar/features/excel_import/domain/column_mapping.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_file.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/controllers/excel_import_controller.dart';

void main() {
  test('loads a workbook and reads the selected worksheet', () async {
    final controller = ExcelImportController(
      reader: ExcelReaderService(filePicker: () async => _workbookFile()),
    );
    addTearDown(controller.dispose);

    await controller.pickFile();

    expect(controller.state, ExcelImportState.workbookLoaded);
    expect(controller.selectedFile?.name, 'roster.xlsx');
    expect(controller.workbook?.worksheetCount, 2);

    final worksheet = controller.workbook!.worksheets.singleWhere(
      (candidate) => candidate.name == 'Roster',
    );
    await controller.selectWorksheet(worksheet);

    expect(controller.state, ExcelImportState.worksheetLoaded);
    expect(controller.selectedWorksheet?.name, 'Roster');
    expect(controller.rows, hasLength(2));
    expect(controller.rows[1].cells[1].value, 'Morning');
  });

  test('reports invalid workbooks and can reset to idle', () async {
    final controller = ExcelImportController(
      reader: ExcelReaderService(
        filePicker: () async =>
            ImportFile(name: 'roster.xlsx', bytes: Uint8List.fromList([1])),
      ),
    );
    addTearDown(controller.dispose);

    await controller.pickFile();

    expect(controller.state, ExcelImportState.error);
    expect(controller.error, isNotNull);
    expect(controller.workbook, isNull);

    controller.cancel();

    expect(controller.state, ExcelImportState.idle);
    expect(controller.error, isNull);
  });

  test('exposes Shift Records and completion summary', () async {
    final controller = ExcelImportController(
      reader: ExcelReaderService(filePicker: () async => _workbookFile()),
    );
    addTearDown(controller.dispose);
    await controller.pickFile();
    await controller.selectWorksheet(controller.workbook!.worksheets.first);

    final importFuture = controller.importRows(
      const ColumnMapping(
        dateColumn: 'A',
        shiftColumn: 'B',
        employeeColumn: 'C',
        departmentColumn: 'D',
      ),
    );

    expect(controller.loading, isTrue);
    expect(controller.completed, isFalse);
    await importFuture;

    expect(controller.loading, isFalse);
    expect(controller.completed, isTrue);
    expect(controller.shiftRecords, hasLength(1));
    expect(controller.shiftRecords.single.employee, 'Anan');
    expect(controller.importSummary?.importedRows, 1);
  });

  test('imports all worksheet rows while retaining a 50-row preview', () async {
    final controller = ExcelImportController(
      reader: ExcelReaderService(filePicker: () async => _largeWorkbookFile()),
    );
    addTearDown(controller.dispose);
    await controller.pickFile();
    final worksheet = controller.workbook!.worksheets.single;
    await controller.selectWorksheet(worksheet);

    expect(controller.rows, hasLength(ExcelReaderService.maxPreviewRows));

    await controller.importRows(
      const ColumnMapping(
        dateColumn: 'A',
        shiftColumn: 'B',
        employeeColumn: 'C',
      ),
    );

    expect(controller.shiftRecords, hasLength(55));
    expect(
      controller.shiftRecords.map((record) => record.employee),
      containsAll(['Employee 51', 'Employee 55']),
    );
    expect(controller.shiftRecords.last.rowNumber, 56);
    expect(controller.importSummary?.totalRows, 55);
    expect(controller.importSummary?.importedRows, 55);
  });
}

ImportFile _workbookFile() {
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', 'Roster');
  workbook['Roster']
    ..appendRow([
      TextCellValue('Date'),
      TextCellValue('Shift'),
      TextCellValue('Employee'),
      TextCellValue('Department'),
    ])
    ..appendRow([
      TextCellValue('2026-07-24'),
      TextCellValue('Morning'),
      TextCellValue('Anan'),
      TextCellValue('ER'),
    ]);
  workbook['Summary'].appendRow([TextCellValue('Total')]);

  return ImportFile(
    name: 'roster.xlsx',
    bytes: Uint8List.fromList(workbook.encode()!),
  );
}

ImportFile _largeWorkbookFile() {
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', 'Roster');
  final sheet = workbook['Roster'];
  sheet.appendRow([
    TextCellValue('Date'),
    TextCellValue('Shift'),
    TextCellValue('Employee'),
  ]);
  for (var index = 0; index < 55; index++) {
    sheet.appendRow([
      TextCellValue('2026-07-24'),
      TextCellValue('Morning'),
      TextCellValue('Employee ${index + 1}'),
    ]);
  }

  return ImportFile(
    name: 'large-roster.xlsx',
    bytes: Uint8List.fromList(workbook.encode()!),
  );
}
