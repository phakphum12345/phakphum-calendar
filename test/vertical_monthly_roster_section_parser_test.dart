import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_workbook_scanner.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/roster_grid_axis_mapping.dart';
import 'package:phakphum_calendar/models/shift.dart';

void main() {
  test('scans a vertical date axis and preserves original source coordinates', () {
    final rows = <List<Object?>>[
      [null, 'เวรเช้า', 'เวรบ่าย'],
      ['ประจำเดือน พฤศจิกายน พ.ศ. 2569'],
      [1, 'นาย ก', 'นาย ข'],
      [2, 'นาย ค', null],
      [3, null, 'นาย ง'],
      [4, 'นาย จ', null],
      [5, null, null],
      [6, null, null],
      [7, 'นาย ฉ', 'นาย ช'],
    ];

    final report = const MonthlyRosterWorkbookScanner().scan(
      snapshots: [
        SheetSnapshot(
          title: 'ตารางแนวตั้ง',
          spreadsheetId: 'book-vertical',
          sheetId: 41,
          rows: rows,
        ),
      ],
      spreadsheetId: 'book-vertical',
      spreadsheetTitle: 'ตัวอย่าง',
    );

    expect(report.sections, hasLength(1));
    final section = report.sections.single;
    expect(section.orientation, RosterGridOrientation.datesDownRows);
    expect(section.dateColumns, hasLength(7));
    expect(section.dateColumns.first.date, DateTime(2026, 11, 1));
    expect(section.dateColumns.first.rowIndex, 2);
    expect(section.assignments, hasLength(8));
    expect(section.assignments.first.sourceCell, 'B3');
    expect(section.assignments.first.date, DateTime(2026, 11, 1));
    expect(section.assignments.first.rowLabel, 'เวรเช้า');
    expect(section.assignments.first.columnIndex, 1);
    expect(report.sheetSummaries.single.blockCount, 1);
    expect(report.sheetSummaries.single.assignmentCount, 8);
  });

  test('supports vertical and horizontal sections in one worksheet', () {
    final report = const MonthlyRosterWorkbookScanner().scan(
      snapshots: [
        SheetSnapshot(
          title: 'Mixed',
          spreadsheetId: 'book-mixed',
          sheetId: 42,
          rows: [
            [null, 'เวรเช้า'],
            ['ประจำเดือน พฤศจิกายน พ.ศ. 2569'],
            [1, 'นาย ก'],
            [2, 'นาย ข'],
            [3, 'นาย ค'],
            [4, 'นาย ง'],
            [5, 'นาย จ'],
            [6, 'นาย ฉ'],
            [7, 'นาย ช'],
            [],
            ['เวรหลัก ประจำเดือน ธันวาคม พ.ศ. 2569'],
            ['วันที่', 1, 2, 3, 4, 5, 6, 7],
            ['เวรบ่าย', 'นาย ซ', null, null, null, null, null, null],
          ],
        ),
      ],
      spreadsheetId: 'book-mixed',
      spreadsheetTitle: 'ตัวอย่างผสม',
    );

    expect(report.sections, hasLength(2));
    expect(
      report.sections.map((section) => section.orientation).toSet(),
      containsAll({
        RosterGridOrientation.datesDownRows,
        RosterGridOrientation.datesAcrossColumns,
      }),
    );
    expect(report.assignments, hasLength(8));
  });

  test('does not invent a month when a vertical date axis has no period evidence', () {
    final report = const MonthlyRosterWorkbookScanner().scan(
      snapshots: [
        SheetSnapshot(
          title: 'ไม่มีช่วงวันที่',
          spreadsheetId: 'book-unknown',
          sheetId: 43,
          rows: [
            [null, 'เวรเช้า'],
            ['วันที่'],
            [1, 'นาย ก'],
            [2, 'นาย ข'],
            [3, 'นาย ค'],
            [4, 'นาย ง'],
            [5, 'นาย จ'],
            [6, 'นาย ฉ'],
            [7, 'นาย ช'],
          ],
        ),
      ],
      spreadsheetId: 'book-unknown',
      spreadsheetTitle: 'ไม่ระบุช่วง',
    );

    expect(report.assignments, isEmpty);
    expect(report.warnings, hasLength(1));
    expect(report.warnings.single, contains('ไม่พบช่วงวันที่ที่ยืนยันได้'));
  });
}
