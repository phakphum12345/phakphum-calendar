import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/normalized_cell.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/shift_parser_input.dart';

void main() {
  test('maps cross-month header days to the declared full date range', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: '16 ส.ค. 69 - 15 ก.ย. 69',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวร 16 ส.ค. 69 - 15 ก.ย. 69']),
        ..._row(1, [
          'วันที่',
          16,
          17,
          18,
          19,
          20,
          21,
          22,
          23,
          24,
          25,
          26,
          27,
          28,
          29,
          30,
          31,
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
        ]),
        ..._row(2, [
          'ER',
          '16 ส.ค.',
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          '30 ส.ค.',
          '31 ส.ค.',
          '1 ก.ย.',
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          '15 ก.ย.',
        ]),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);
    final assignments = report.assignments;

    expect(report.warnings, isEmpty);
    expect(assignments.map((item) => item.date), [
      DateTime(2026, 8, 16),
      DateTime(2026, 8, 30),
      DateTime(2026, 8, 31),
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 15),
    ]);
  });

  test('warns and skips a header day outside the declared period', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: '16 ส.ค. 69 - 15 ก.ย. 69',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวร 16 ส.ค. 69 - 15 ก.ย. 69']),
        ..._row(1, ['วันที่', 16, 17, 18, 19, 20, 21, 22, 31, 30]),
        ..._row(2, [
          'ER',
          'ถูกต้อง',
          null,
          null,
          null,
          null,
          null,
          null,
          '31 ส.ค.',
          'ย้อนลำดับ',
        ]),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.assignments.map((item) => item.date), [
      DateTime(2026, 8, 16),
      DateTime(2026, 8, 31),
    ]);
    expect(report.warnings, hasLength(1));
    expect(report.warnings.single, contains('วันที่ 30'));
    expect(report.warnings.single, contains('อยู่นอกช่วง'));
  });

  test('prefers a dated monthly section heading over a conflicting tab title', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'ธันวาคม 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(4, ['พฤศจิกายน 2569']),
        ..._row(12, ['วันที่', ...List.generate(30, (i) => i + 1)]),
        ..._row(13, [
          'GEN',
          ...List.generate(30, (i) => i == 25 ? 'ภาคภูมิ' : null),
        ]),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.warnings, isEmpty);
    expect(report.sections.single.startDate, DateTime(2026, 11, 1));
    expect(report.sections.single.endDate, DateTime(2026, 11, 30));
    expect(report.assignments.single.date, DateTime(2026, 11, 26));
  });

  test('accepts 29 February in a leap year', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: '16 ก.พ. 67 - 15 มี.ค. 67',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวร 16 ก.พ. 67 - 15 มี.ค. 67']),
        ..._row(1, [
          'วันที่',
          16,
          17,
          18,
          19,
          20,
          21,
          22,
          23,
          24,
          25,
          26,
          27,
          28,
          29,
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
        ]),
        ..._row(2, [
          'ER',
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          '29 ก.พ.',
          '1 มี.ค.',
        ]),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.warnings, isEmpty);
    expect(report.assignments.map((item) => item.date), [
      DateTime(2024, 2, 29),
      DateTime(2024, 3, 1),
    ]);
  });

  test('rejects 29 February in a non-leap year', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: '16 ก.พ. 69 - 15 มี.ค. 69',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวร 16 ก.พ. 69 - 15 มี.ค. 69']),
        ..._row(1, [
          'วันที่',
          16,
          17,
          18,
          19,
          20,
          21,
          22,
          23,
          24,
          25,
          26,
          27,
          28,
          29,
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
        ]),
        ..._row(2, [
          'ER',
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          '29 ก.พ.',
          '1 มี.ค.',
        ]),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.assignments.map((item) => item.date), [DateTime(2026, 3, 1)]);
    expect(report.warnings, hasLength(1));
    expect(report.warnings.single, contains('วันที่ 29'));
    expect(report.warnings.single, contains('อยู่นอกช่วง'));
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
