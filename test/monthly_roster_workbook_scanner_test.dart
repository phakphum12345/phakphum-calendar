import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_workbook_scanner.dart';
import 'package:phakphum_calendar/models/shift.dart';

void main() {
  test('scans every worksheet, repeated blocks, and hidden tabs independently', () {
    final snapshots = [
      SheetSnapshot(
        title: 'ตารางหลัก',
        spreadsheetId: 'book-1',
        sheetId: 10,
        rows: [
          ['เวรหลัก ประจำเดือน พฤศจิกายน พ.ศ. 2569'],
          ['วันที่', 1, 2, 3, 4, 5, 6, 7],
          ['เวรเช้า', 'ก', 'ก', 'ก', 'ก', 'ก', 'ก', 'ก'],
          [],
          ['MRI ประจำเดือน พฤศจิกายน พ.ศ. 2569'],
          ['วันที่', 1, 2, 3, 4, 5, 6, 7],
          ['MRI', 'ข', 'ข', 'ข', 'ข', 'ข', 'ข', 'ข'],
        ],
      ),
      SheetSnapshot(
        title: 'ตารางหลัก',
        spreadsheetId: 'book-1',
        sheetId: 20,
        hidden: true,
        rows: [
          ['คลินิกพิเศษ ประจำเดือน ธันวาคม พ.ศ. 2569'],
          ['วันที่', 1, 2, 3, 4, 5, 6, 7],
          ['GEN', 'ค', 'ค', 'ค', 'ค', 'ค', 'ค', 'ค'],
        ],
      ),
      const SheetSnapshot(
        title: 'คำอธิบาย',
        spreadsheetId: 'book-1',
        sheetId: 30,
        rows: [],
      ),
    ];

    final report = const MonthlyRosterWorkbookScanner().scan(
      snapshots: snapshots,
      spreadsheetId: 'book-1',
      spreadsheetTitle: 'เวรประจำเดือน',
    );

    expect(report.sourceSheetCount, 3);
    expect(report.sheetSummaries, hasLength(3));
    expect(report.sections, hasLength(3));
    expect(report.assignments, hasLength(21));
    expect(report.sheetSummaries[0].blockCount, 2);
    expect(report.sheetSummaries[0].assignmentCount, 14);
    expect(report.sheetSummaries[1].hidden, isTrue);
    expect(report.sheetSummaries[1].blockCount, 1);
    expect(report.sheetSummaries[1].assignmentCount, 7);
    expect(report.sheetSummaries[2].blockCount, 0);
    expect(report.sheetSummaries[2].warningCount, 1);
    expect(report.assignments.map((item) => item.sheetId).toSet(), {10, 20});
    expect(report.assignments.map((item) => item.sourceIdentityKey).toSet(),
        hasLength(21));
    expect(report.dateRanges.map((range) => range.start.month).toSet(), {11, 12});
  });

  test('reports an empty workbook without inventing sheets or blocks', () {
    final report = const MonthlyRosterWorkbookScanner().scan(
      snapshots: const [],
      spreadsheetId: 'book-empty',
      spreadsheetTitle: 'Empty workbook',
    );

    expect(report.sourceSheetCount, 0);
    expect(report.sheetSummaries, isEmpty);
    expect(report.sections, isEmpty);
    expect(report.assignments, isEmpty);
  });

  test('preserves per-sheet scan coverage when filtering selected periods', () {
    final report = const MonthlyRosterWorkbookScanner().scan(
      snapshots: [
        SheetSnapshot(
          title: 'November',
          sheetId: 1,
          rows: [
            ['เวรประจำเดือน พฤศจิกายน พ.ศ. 2569'],
            ['วันที่', 1, 2, 3, 4, 5, 6, 7],
            ['เวรเช้า', 'ก', 'ก', 'ก', 'ก', 'ก', 'ก', 'ก'],
          ],
        ),
        SheetSnapshot(
          title: 'December',
          sheetId: 2,
          rows: [
            ['เวรประจำเดือน ธันวาคม พ.ศ. 2569'],
            ['วันที่', 1, 2, 3, 4, 5, 6, 7],
            ['เวรเช้า', 'ข', 'ข', 'ข', 'ข', 'ข', 'ข', 'ข'],
          ],
        ),
      ],
      spreadsheetId: 'book-1',
      spreadsheetTitle: 'เวรประจำเดือน',
    );

    final november = report.filtered(
      includesDate: (date) => date.month == 11,
    );

    expect(november.assignments, hasLength(7));
    expect(november.sourceSheetCount, 2);
    expect(november.sheetSummaries, hasLength(2));
    expect(november.sheetSummaries.map((sheet) => sheet.blockCount), [1, 1]);
  });
}
