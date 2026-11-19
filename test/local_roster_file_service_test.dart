import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/services/local_roster_file_service.dart';

void main() {
  const service = LocalRosterFileService();

  test('reads quoted CSV and keeps the document in memory', () {
    final document = service.readBytes(
      name: 'roster.csv',
      bytes: Uint8List.fromList(
        utf8.encode('ชื่อ,เวร\n"ภาคภูมิ, ทดสอบ","P1 เช้า"\n'),
      ),
    );

    expect(document.extension, 'csv');
    expect(document.snapshots, hasLength(1));
    expect(document.snapshots.single.rows[1], ['ภาคภูมิ, ทดสอบ', 'P1 เช้า']);
  });

  test('reads multiple XLSX worksheets and their background colors', () {
    final workbook = Excel.createExcel();
    final sheet = workbook['ตารางเวร'];
    sheet.appendRow([TextCellValue('ชื่อ'), TextCellValue('เวร')]);
    sheet.appendRow([TextCellValue('ภาคภูมิ'), TextCellValue('P1 เช้า')]);
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1))
        .cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.red,
    );

    final document = service.readBytes(
      name: 'roster.xlsx',
      bytes: Uint8List.fromList(workbook.encode()!),
    );

    final roster = document.snapshots.singleWhere(
      (snapshot) => snapshot.title == 'ตารางเวร',
    );
    expect(roster.rows[1], ['ภาคภูมิ', 'P1 เช้า']);
    expect(roster.backgroundColors[1][1], 0xFFF44336);
    expect(document.snapshots.map((sheet) => sheet.title), contains('Sheet1'));
    expect(
      document.snapshots.singleWhere((sheet) => sheet.title == 'Sheet1').rows,
      isEmpty,
      reason: 'Empty workbook tabs must remain visible to the scanner',
    );
  });

  test('rejects unsupported formats before reading content', () {
    expect(
      () => service.readBytes(
        name: 'roster.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
      throwsFormatException,
    );
  });
}
