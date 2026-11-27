import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/excel_import/data/excel_reader_service.dart';
import 'package:phakphum_calendar/features/excel_import/domain/excel_cell.dart';
import 'package:phakphum_calendar/features/excel_import/domain/excel_row.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_file.dart';
import 'package:phakphum_calendar/features/excel_import/domain/workbook_info.dart';
import 'package:phakphum_calendar/features/excel_import/domain/worksheet_info.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_workbook_scanner.dart';
import 'package:phakphum_calendar/services/local_roster_file_service.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/roster_grid_axis_mapping.dart';

void main() {
  const scanner = GridRosterWorkbookScanner();

  test('scans worksheets independently and preserves per-sheet evidence', () {
    final workbook = WorkbookInfo(
      file: ImportFile(
        name: 'roster.xlsx',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
      worksheets: const [
        WorksheetInfo(name: 'GEN', rowCount: 3, columnCount: 8),
        WorksheetInfo(name: 'Broken', rowCount: 3, columnCount: 8),
      ],
    );

    final report = scanner.scan(
      workbook: workbook,
      readWorksheet: (worksheet) {
        if (worksheet.name == 'Broken') {
          throw StateError('simulated sheet read error');
        }
        return _validRows();
      },
    );

    expect(report.sourceSheetCount, 2);
    expect(report.sourceFingerprint, startsWith('sha256:'));
    expect(report.sections, hasLength(1));
    expect(report.sections.single.sourceSheetId, 0);
    expect(report.sections.single.sourceSheetTitle, 'GEN');
    expect(report.assignments, hasLength(7));
    expect(report.sheetSummaries, hasLength(2));
    expect(report.sheetSummaries.first.assignmentCount, 7);
    expect(report.sheetSummaries.last.warningCount, 1);
    expect(report.warnings, hasLength(1));
    expect(report.assignments.first.spreadsheetId, isEmpty);
    expect(report.assignments.first.sourceUrl, isNull);
  });

  test('scans vertical date axes through the Grid XLSX import path', () {
    final workbook = WorkbookInfo(
      file: ImportFile(
        name: 'vertical.xlsx',
        bytes: Uint8List.fromList([9, 8, 7, 6]),
      ),
      worksheets: const [
        WorksheetInfo(name: 'Vertical', rowCount: 9, columnCount: 2),
      ],
    );

    final report = scanner.scan(
      workbook: workbook,
      readWorksheet: (_) => [
        ExcelRow(
          index: 0,
          cells: const [
            ExcelCell(rowIndex: 0, columnIndex: 1, value: 'เวรเช้า'),
          ],
        ),
        ExcelRow(
          index: 1,
          cells: const [
            ExcelCell(
              rowIndex: 1,
              columnIndex: 0,
              value: 'ประจำเดือน พฤศจิกายน พ.ศ. 2569',
            ),
          ],
        ),
        for (var day = 1; day <= 7; day++)
          ExcelRow(
            index: day + 1,
            cells: [
              ExcelCell(
                rowIndex: day + 1,
                columnIndex: 0,
                value: day,
              ),
              ExcelCell(
                rowIndex: day + 1,
                columnIndex: 1,
                value: 'บุคลากร $day',
              ),
            ],
          ),
      ],
    );

    expect(report.sections, hasLength(1));
    expect(
      report.sections.single.orientation,
      RosterGridOrientation.datesDownRows,
    );
    expect(report.assignments, hasLength(7));
    expect(report.assignments.first.sourceCell, 'B3');
    expect(report.assignments.first.rowIndex, 2);
    expect(report.assignments.first.columnIndex, 1);
    expect(report.sections.single.sourceCells, isNotEmpty);
  });

  test('reads a real vertical XLSX workbook through ExcelReaderService and Grid scanner', () {
    final excelWorkbook = Excel.createExcel();
    excelWorkbook.rename('Sheet1', 'Vertical');
    final sheet = excelWorkbook['Vertical'];
    sheet.appendRow([TextCellValue(''), TextCellValue('เวรเช้า')]);
    sheet.appendRow([
      TextCellValue('ประจำเดือน พฤศจิกายน พ.ศ. 2569'),
    ]);
    for (var day = 1; day <= 7; day++) {
      sheet.appendRow([
        IntCellValue(day),
        TextCellValue('บุคลากร $day'),
      ]);
    }
    final service = ExcelReaderService();
    final workbook = service.openWorkbook(
      ImportFile(
        name: 'vertical.xlsx',
        bytes: Uint8List.fromList(excelWorkbook.encode()!),
      ),
    );

    final report = scanner.scan(
      workbook: workbook,
      readWorksheet: service.readWorksheetForImport,
    );

    expect(report.sections, hasLength(1));
    expect(
      report.sections.single.orientation,
      RosterGridOrientation.datesDownRows,
    );
    expect(report.assignments, hasLength(7));
    expect(report.assignments.first.sourceCell, 'B3');
    expect(report.sourceFingerprint, startsWith('sha256:'));
  });

  test('scans nested merged headers from an actual XLSX workbook', () {
    final excelWorkbook = Excel.createExcel();
    excelWorkbook.rename('Sheet1', 'Vertical');
    final sheet = excelWorkbook['Vertical'];
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('หน่วยบริการ'),
      TextCellValue(''),
    ]);
    sheet.merge(
      CellIndex.indexByString('B1'),
      CellIndex.indexByString('C1'),
      customValue: TextCellValue('หน่วยบริการ'),
    );
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('เช้า'),
      TextCellValue('บ่าย'),
    ]);
    sheet.appendRow([
      TextCellValue('ประจำเดือน พฤศจิกายน พ.ศ. 2569'),
    ]);
    for (var day = 1; day <= 7; day++) {
      sheet.appendRow([
        IntCellValue(day),
        TextCellValue('บุคลากรเช้า $day'),
        TextCellValue('บุคลากรบ่าย $day'),
      ]);
    }

    final service = ExcelReaderService();
    final workbook = service.openWorkbook(
      ImportFile(
        name: 'nested-merged-vertical.xlsx',
        bytes: Uint8List.fromList(excelWorkbook.encode()!),
      ),
    );
    final report = scanner.scan(
      workbook: workbook,
      readWorksheet: service.readWorksheetForImport,
    );

    expect(report.sections, hasLength(1));
    expect(report.assignments, hasLength(14));
    expect(
      report.assignments.map((item) => item.rowLabel).toSet(),
      {'หน่วยบริการ / เช้า', 'หน่วยบริการ / บ่าย'},
    );
    expect(report.assignments.first.sourceCell, 'B4');
    expect(report.assignments[1].sourceCell, 'C4');
    expect(report.sections.single.sourceCells.map((cell) => cell.a1),
        containsAll(['B1', 'C1', 'B2', 'C2']));
    expect(
      report.sections.single.sourceCells
          .singleWhere((cell) => cell.a1 == 'C1')
          .text,
      isEmpty,
      reason: 'The XLSX reader must retain the merged child cell as blank.',
    );
    expect(report.warnings, isEmpty);
  });

  test('scans CSV snapshots through the Grid parser with a byte fingerprint', () {
    const csv = '\uFEFFเวรประจำเดือน พฤศจิกายน พ.ศ. 2569\n'
        'วันที่,1,2,3,4,5,6,7\n'
        'เวรเช้า,ก,ก,ก,ก,ก,ก,ก\n';
    final document = const LocalRosterFileService().readBytes(
      name: 'roster.csv',
      bytes: utf8.encode(csv),
    );
    final fingerprint = document.sourceFingerprint;
    expect(fingerprint, startsWith('sha256:'));

    final report = scanner.scanSnapshots(
      snapshots: document.snapshots,
      spreadsheetTitle: 'roster.csv',
      sourceFingerprint: fingerprint!,
    );

    expect(report.sourceSheetCount, 1);
    expect(report.sections, hasLength(1));
    expect(report.assignments, hasLength(7));
    expect(report.sourceFingerprint, fingerprint);
    expect(report.sheetSummaries.single.title, 'ไฟล์ในเครื่อง');
  });

  test('source fingerprint is deterministic for the same workbook bytes', () {
    final file = ImportFile(
      name: 'roster.xlsx',
      bytes: Uint8List.fromList([10, 20, 30]),
    );
    const adapter = GridRosterExcelInputAdapter();

    expect(adapter.sourceFingerprint(file), adapter.sourceFingerprint(file));
    expect(adapter.sourceFingerprint(file), startsWith('sha256:'));
  });
}

List<ExcelRow> _validRows() {
  return [
    ExcelRow(
      index: 0,
      cells: const [
        ExcelCell(
          rowIndex: 0,
          columnIndex: 0,
          value: 'GEN คลินิก 1 พฤศจิกายน 2569 - 7 พฤศจิกายน 2569',
        ),
      ],
    ),
    ExcelRow(
      index: 1,
      cells: [
        const ExcelCell(rowIndex: 1, columnIndex: 0, value: 'วันที่'),
        for (var day = 1; day <= 7; day++)
          ExcelCell(rowIndex: 1, columnIndex: day, value: day),
      ],
    ),
    ExcelRow(
      index: 2,
      cells: [
        const ExcelCell(rowIndex: 2, columnIndex: 0, value: 'GEN'),
        for (var day = 1; day <= 7; day++)
          ExcelCell(
            rowIndex: 2,
            columnIndex: day,
            value: 'สมชาย ใจดี',
          ),
      ],
    ),
  ];
}
