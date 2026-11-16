import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/normalized_cell.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/roster_layout_profile.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/shift_parser_input.dart';

void main() {
  test('uses configured date, label, name, and data row positions', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'Roster',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวรหลัก ประจำเดือน สิงหาคม พ.ศ. 2569']),
        ..._row(3, [null, null, null, 'วันที่', 1, 2, 3]),
        ..._row(4, ['รังสี', 'เจ้าหน้าที่', 'เวรเช้า', null, 'นาย ก', 'นาย ข', 'นาย ค']),
        ..._row(5, ['รังสี', 'เจ้าหน้าที่', 'เวรบ่าย', null, 'นาย ง', null, 'นาย จ']),
        ..._row(6, ['ข้อมูลนอกช่วง', null, 'ไม่ควรอ่าน', null, 'นาย ฉ']),
      ],
    );
    const profile = RosterLayoutProfile(
      profileId: 'hospital-wide-grid',
      profileName: 'Hospital wide grid',
      dateHeaderRows: [3],
      nameColumns: [4, 5, 6],
      shiftLabelColumns: [2],
      dataStartRow: 4,
      dataEndRow: 5,
    );

    final report = const MonthlyRosterSectionParser(
      layoutProfile: profile,
    ).parse(input);

    expect(report.warnings, isEmpty);
    expect(report.sections, hasLength(1));
    expect(report.sections.single.rosterRows.map((row) => row.label), [
      'เวรเช้า',
      'เวรบ่าย',
    ]);
    expect(report.assignments, hasLength(5));
    expect(report.assignments.map((item) => item.workerName), [
      'นาย ก',
      'นาย ข',
      'นาย ค',
      'นาย ง',
      'นาย จ',
    ]);
    expect(report.assignments.map((item) => item.date), [
      DateTime(2026, 8, 1),
      DateTime(2026, 8, 2),
      DateTime(2026, 8, 3),
      DateTime(2026, 8, 1),
      DateTime(2026, 8, 3),
    ]);
  });

  test('auto-detects a short date header when the row explicitly says วันที่', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'Roster',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['ตารางเวร 1 สิงหาคม 2569 - 3 สิงหาคม 2569']),
        ..._row(2, [null, null, 'วันที่', 1, 2, 3]),
        ..._row(3, ['รังสี', 'เวรเช้า', null, 'นาย ก', null, 'นาย ข']),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.warnings, isEmpty);
    expect(report.assignments, hasLength(2));
    expect(report.assignments.first.rowLabel, 'เวรเช้า');
    expect(report.assignments.first.date, DateTime(2026, 8, 1));
    expect(report.assignments.last.date, DateTime(2026, 8, 3));
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
}
