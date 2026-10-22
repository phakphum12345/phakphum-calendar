import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/normalized_cell.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/shift_parser_input.dart';
import 'package:phakphum_calendar/models/shift.dart';

void main() {
  test('discovers monthly blocks and keeps section and row labels dynamic', () {
    final cells = <NormalizedCell>[
      ..._row(0, ['เวรใหญ่ ประจำเดือน กรกฎาคม พ.ศ. 2569']),
      ..._row(1, ['เวร', 'พ', 'พฤ', 'ศ', 'ส', 'อา', 'จ', 'อ']),
      ..._row(2, ['วันที่', 1, 2, 3, 4, 5, 6, 7]),
      ..._row(3, ['MRI', 'ก', 'ข', null, null, null, null, null]),
      ..._row(4, ['MRI', 'ง', null, null, null, null, null, null]),
      ..._row(6, ['GEN คลินิคพิเศษ ประจำเดือน กรกฎาคม พ.ศ. 2569']),
      ..._row(7, ['เวร', 'พ', 'พฤ', 'ศ', 'ส', 'อา', 'จ', 'อ']),
      ..._row(8, ['วันที่', 1, 2, 3, 4, 5, 6, 7]),
      ..._row(9, ['คลินิก A', 'ค', null, null, null, null, null, null]),
    ];
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1666384927,
      sheetTitle: 'ตารางเวรรายเดือน',
      timeZone: 'Asia/Bangkok',
      cells: cells,
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.warnings, isEmpty);
    expect(report.sections, hasLength(2));
    expect(report.sections.first.title, contains('เวรใหญ่'));
    expect(report.sections.last.title, contains('คลินิคพิเศษ'));
    expect(report.assignments, hasLength(4));
    expect(report.assignments.first.rowLabel, 'MRI');
    expect(report.assignments.first.date, DateTime(2026, 7, 1));
    expect(
      report.sections.first.assignments.map((item) => item.rowIndex).toSet(),
      containsAll(<int>{3, 4}),
    );
    expect(report.assignments.last.rowLabel, 'คลินิก A');
    expect(report.assignments.last.sourceCell, 'B10');
  });

  test('does not require fixed names for exten or future sections', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'รายเดือน',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['Exten ใหม่ ประจำเดือน สิงหาคม พ.ศ. 2569']),
        ..._row(1, ['วันที่', 1, 2, 3, 4, 5, 6, 7]),
        ..._row(2, ['พื้นที่ A', 'บุคลากร A']),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.sections.single.title, startsWith('Exten ใหม่'));
    expect(report.assignments.single.rowLabel, 'พื้นที่ A');
    expect(report.assignments.single.workerName, 'บุคลากร A');
    expect(report.assignments.single.date, DateTime(2026, 8, 1));
  });

  test('keeps the exact cross-month range declared by the roster', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: '16 ส.ค. - 15 ก.ย. 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวร 16 สิงหาคม 2569 - 15 กันยายน 2569']),
        ..._row(1, ['วันที่', 16, 17, 18, 19, 20, 21, 22]),
        ..._row(2, ['พื้นที่ A', 'บุคลากร A']),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.dateRanges, hasLength(1));
    expect(report.dateRanges.single.start, DateTime(2026, 8, 16));
    expect(report.dateRanges.single.end, DateTime(2026, 9, 15));
  });

  test('filters assignments by query, section, and selected month', () {
    final report = MonthlyRosterParseReport(
      sections: [
        MonthlyRosterSection(
          title: 'เวรใหญ่',
          headerRowIndex: 0,
          assignments: [
            MonthlyRosterAssignment(
              sectionTitle: 'เวรใหญ่',
              rowLabel: 'ER',
              rowIndex: 1,
              workerName: 'สมชาย',
              date: DateTime(2026, 7, 1),
              sourceCell: 'B2',
            ),
            MonthlyRosterAssignment(
              sectionTitle: 'เวรใหญ่',
              rowLabel: 'CT',
              rowIndex: 2,
              workerName: 'สมหญิง',
              date: DateTime(2026, 8, 1),
              sourceCell: 'B3',
            ),
          ],
        ),
      ],
      warnings: const [],
    );

    final filtered = report.filtered(
      query: 'สมชาย',
      sectionTitle: 'เวรใหญ่',
      includesDate: (date) => date.month == 7,
    );

    expect(filtered.sections, hasLength(1));
    expect(filtered.assignments, hasLength(1));
    expect(filtered.assignments.single.workerName, 'สมชาย');
    expect(filtered.assignments.single.date.month, 7);
  });

  test('creates a source-neutral monthly report from imported shifts', () {
    final report = MonthlyRosterParseReport.fromShifts([
      Shift(
        code: 'CUSTOM',
        rowLabel: 'รายการ A',
        assignedName: '',
        start: DateTime(2026, 9, 4, 8),
        end: DateTime(2026, 9, 4, 16),
        sheetTitle: 'ไฟล์ที่นำเข้า',
        cell: 'B2',
        category: ShiftCategory.own,
      ),
    ]);

    expect(report.sections.single.title, 'ไฟล์ที่นำเข้า');
    expect(report.assignments.single.rowLabel, 'รายการ A');
    expect(report.assignments.single.workerName, isEmpty);
    expect(report.assignments.single.date, DateTime(2026, 9, 4));
    expect(report.dateRanges.single.start, DateTime(2026, 9, 4));
    expect(report.dateRanges.single.end, DateTime(2026, 9, 4));
  });

  test('appends a confirmed camera entry to the monthly report', () {
    const empty = MonthlyRosterParseReport(sections: [], warnings: []);
    final report = empty.appendShift(
      Shift(
        code: 'MANUAL',
        rowLabel: 'รายการจากกล้อง',
        assignedName: '',
        start: DateTime(2026, 9, 5, 9),
        end: DateTime(2026, 9, 5, 12),
        sheetTitle: 'ต้นฉบับ: กล้อง',
        cell: 'ผู้ใช้กำหนด',
        category: ShiftCategory.own,
      ),
    );

    expect(report.sections.single.title, 'ต้นฉบับ: กล้อง');
    expect(report.assignments.single.rowLabel, 'รายการจากกล้อง');
  });
}

List<NormalizedCell> _row(int rowIndex, List<Object?> values) {
  return [
    for (var columnIndex = 0; columnIndex < values.length; columnIndex++)
      if (values[columnIndex] != null)
        NormalizedCell(
          sheetId: 1,
          sheetTitle: 'Sheet',
          a1: '',
          rowIndex: rowIndex,
          columnIndex: columnIndex,
          text: values[columnIndex] is String
              ? values[columnIndex] as String
              : null,
          rawValue: values[columnIndex],
        ),
  ];

  test('converts monthly roster assignments to calendar shifts for the selected worker', () {
    final labels = <String>[
      'P1 เช้า',
      'P2 ดึก',
      'GEN',
      'ER',
      'CT',
      '14ชั้น',
      'CTIPD บ่าย',
    ];
    final assignments = [
      for (var index = 0; index < labels.length; index++)
        MonthlyRosterAssignment(
          sectionTitle: 'ตารางเวรเดือนสิงหาคม 2569',
          rowLabel: labels[index],
          rowIndex: index + 3,
          workerName: 'นายสมชาย ใจดี',
          date: DateTime(2026, 8, index + 1),
          sourceCell: 'B${index + 4}',
        ),
      MonthlyRosterAssignment(
        sectionTitle: 'ตารางเวรเดือนสิงหาคม 2569',
        rowLabel: 'P3 เช้า',
        rowIndex: 20,
        workerName: 'นางสมหญิง',
        date: DateTime(2026, 8, 20),
        sourceCell: 'U21',
      ),
    ];
    final report = MonthlyRosterParseReport(
      sections: [
        MonthlyRosterSection(
          title: 'ตารางเวรเดือนสิงหาคม 2569',
          headerRowIndex: 1,
          assignments: assignments,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
        ),
      ],
      warnings: const [],
    );

    final shifts = const MonthlyRosterShiftAdapter().parseForWorkers(
      report,
      targetNames: ['สมชาย', 'ใจดี'],
    );

    expect(shifts, hasLength(7));
    expect(shifts.map((shift) => shift.code), [
      'UP1',
      'NP2',
      'UG',
      'UER',
      'UCT',
      'U14',
      'ACTIPD',
    ]);
    expect(shifts.first.start, DateTime(2026, 8, 1, 8));
    expect(shifts[1].start, DateTime(2026, 8, 2));
    expect(shifts[1].end, DateTime(2026, 8, 2, 8));
    expect(shifts.last.start, DateTime(2026, 8, 7, 16));
    expect(shifts.last.end, DateTime(2026, 8, 8, 8));
    expect(shifts.every((shift) => shift.assignedName == 'นายสมชาย ใจดี'), isTrue);
    expect(shifts.map((shift) => shift.cell), [
      'B4', 'B5', 'B6', 'B7', 'B8', 'B9', 'B10',
    ]);
  });


}
