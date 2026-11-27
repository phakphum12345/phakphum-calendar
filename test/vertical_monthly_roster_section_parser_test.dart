import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_workbook_scanner.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/a1_notation.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/normalized_cell.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/shift_parser_input.dart';
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
    expect(section.assignments, hasLength(7));
    expect(section.assignments.first.sourceCell, 'B3');
    expect(section.assignments.first.date, DateTime(2026, 11, 1));
    expect(section.assignments.first.rowLabel, 'เวรเช้า');
    expect(section.assignments.first.columnIndex, 1);
    expect(report.sheetSummaries.single.blockCount, 1);
    expect(report.sheetSummaries.single.assignmentCount, 7);
  });

  test('resolves vertical date structure before populating worker assignments', () {
    final rows = <List<Object?>>[
      [null, 'เวรเช้า'],
      ['ประจำเดือน พฤศจิกายน พ.ศ. 2569'],
      [1, 'นาย ก'],
      [2, 'นาย ข'],
      [3, 'นาย ค'],
      [4, 'นาย ง'],
      [5, 'นาย จ'],
      [6, 'นาย ฉ'],
      [7, 'นาย ช'],
    ];
    final cells = <NormalizedCell>[
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
        for (var columnIndex = 0;
            columnIndex < rows[rowIndex].length;
            columnIndex++)
          if (rows[rowIndex][columnIndex] != null)
            NormalizedCell(
              sheetId: 46,
              sheetTitle: 'ตารางแนวตั้ง',
              a1: A1Notation.fromZeroBased(
                rowIndex: rowIndex,
                columnIndex: columnIndex,
              ),
              rowIndex: rowIndex,
              columnIndex: columnIndex,
              text: rows[rowIndex][columnIndex].toString(),
              rawValue: rows[rowIndex][columnIndex],
            ),
    ];
    final input = ShiftParserInput(
      spreadsheetId: 'book-two-phase',
      spreadsheetTitle: 'ตัวอย่าง',
      sheetId: 46,
      sheetTitle: 'ตารางแนวตั้ง',
      timeZone: 'Asia/Bangkok',
      cells: cells,
    );
    const parser = MonthlyRosterSectionParser();

    final structure = parser.generateDateStructure(input);
    expect(structure.sections, hasLength(1));
    expect(structure.assignments, isEmpty);
    expect(structure.sections.single.rosterRows.single.columnIndex, 1);

    final populated = parser.populateAssignments(input, structure);
    expect(populated.assignments, hasLength(7));
    expect(populated.assignments.first.sourceCell, 'B3');
    expect(populated.assignments.first.date, DateTime(2026, 11, 1));
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

  test('keeps side-by-side vertical tables in separate sections', () {
    final report = const MonthlyRosterWorkbookScanner().scan(
      snapshots: [
        SheetSnapshot(
          title: 'สองแผนก',
          spreadsheetId: 'book-side-by-side',
          sheetId: 45,
          rows: [
            [
              'แผนก A ประจำเดือน พฤศจิกายน พ.ศ. 2569',
              null,
              null,
              null,
              'แผนก B ประจำเดือน ธันวาคม พ.ศ. 2569',
            ],
            [null, 'เช้า', 'บ่าย', null, null, 'เช้า', 'บ่าย'],
            for (var day = 1; day <= 7; day++)
              [day, 'A-$day', 'A2-$day', null, day, 'B-$day', 'B2-$day'],
          ],
        ),
      ],
      spreadsheetId: 'book-side-by-side',
      spreadsheetTitle: 'สองแผนก',
    );

    expect(report.sections, hasLength(2));
    expect(report.sections.map((section) => section.startDate!.month), [11, 12]);
    expect(report.sections.first.assignments.first.sourceCell, 'B3');
    expect(report.sections.last.assignments.first.sourceCell, 'F3');
    expect(report.assignments, hasLength(28));
  });

  test('distinguishes duplicate and out-of-order dates in vertical grids', () {
    for (final scenario in [
      (days: [1, 2, 2, 3, 4, 5, 6], code: 'duplicate_date'),
      (days: [1, 2, 4, 3, 5, 6, 7], code: 'out_of_order'),
    ]) {
      final report = const MonthlyRosterWorkbookScanner().scan(
        snapshots: [
          SheetSnapshot(
            title: 'พฤศจิกายน 2569',
            spreadsheetId: 'book-${scenario.code}',
            sheetId: 47,
            rows: [
              [null, 'เวรเช้า'],
              ['ประจำเดือน พฤศจิกายน พ.ศ. 2569'],
              for (final day in scenario.days) [day, 'นาย ก'],
            ],
          ),
        ],
        spreadsheetId: 'book-${scenario.code}',
        spreadsheetTitle: 'ตัวอย่างตรวจวันที่',
      );

      expect(report.sections, hasLength(1));
      expect(
        report.sections.single.dateAnomalies.map((item) => item.code),
        contains(scenario.code),
      );
      expect(report.sections.single.hasBlockingDateAnomalies, isTrue);
    }
  });

  test('uses explicit Gregorian DateTime cells without inventing a period', () {
    final report = const MonthlyRosterWorkbookScanner().scan(
      snapshots: [
        SheetSnapshot(
          title: 'Explicit dates',
          spreadsheetId: 'book-explicit',
          sheetId: 48,
          rows: [
            [null, 'เวรเช้า'],
            ['วันที่'],
            for (var day = 1; day <= 7; day++)
              [DateTime(2026, 11, day), 'นาย $day'],
          ],
        ),
      ],
      spreadsheetId: 'book-explicit',
      spreadsheetTitle: 'Explicit dates',
    );

    expect(report.sections, hasLength(1));
    expect(report.sections.single.startDate, DateTime(2026, 11, 1));
    expect(report.sections.single.endDate, DateTime(2026, 11, 7));
    expect(report.assignments, hasLength(7));
    expect(report.assignments.first.date, DateTime(2026, 11, 1));
  });

  test('reports missing dates in a near-complete vertical date axis', () {
    final days = <int>[...List<int>.generate(16, (index) => index + 1), ...List<int>.generate(13, (index) => index + 18)];
    final report = const MonthlyRosterWorkbookScanner().scan(
      snapshots: [
        SheetSnapshot(
          title: 'พฤศจิกายน 2569',
          spreadsheetId: 'book-gap',
          sheetId: 44,
          rows: [
            [null, 'เวรเช้า'],
            ['ประจำเดือน พฤศจิกายน พ.ศ. 2569'],
            for (final day in days) [day, 'นาย ก'],
          ],
        ),
      ],
      spreadsheetId: 'book-gap',
      spreadsheetTitle: 'ตัวอย่างวันที่ขาด',
    );

    expect(report.sections, hasLength(1));
    expect(
      report.sections.single.dateAnomalies.map((anomaly) => anomaly.code),
      contains('missing_dates'),
    );
    expect(
      report.sections.single.dateAnomalies.any(
        (anomaly) => anomaly.message.contains('2026-11-17'),
      ),
      isTrue,
    );
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
    expect(
      report.warnings.any((warning) => warning.contains('ไม่พบช่วงวันที่ที่ยืนยันได้')),
      isTrue,
    );
  });
}
