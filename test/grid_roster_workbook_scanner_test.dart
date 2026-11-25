import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/excel_import/domain/excel_cell.dart';
import 'package:phakphum_calendar/features/excel_import/domain/excel_row.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_file.dart';
import 'package:phakphum_calendar/features/excel_import/domain/workbook_info.dart';
import 'package:phakphum_calendar/features/excel_import/domain/worksheet_info.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_workbook_scanner.dart';

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
