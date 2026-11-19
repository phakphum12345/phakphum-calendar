import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_conversion_diagnostics.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/normalized_cell.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/shift_parser_input.dart';

void main() {
  test('blocks duplicate, missing, and out-of-order days in a complete month', () {
    final days = <Object?>[
      'วันที่',
      ...List<int>.generate(16, (index) => index + 1),
      30,
      ...List<int>.generate(13, (index) => index + 18),
    ];
    final input = _input(
      title: 'X-OPD 1 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569',
      days: days,
      workers: ['P1 เช้า', ...List<String>.filled(30, 'นายสมชาย')],
    );

    final report = const MonthlyRosterSectionParser().parse(input);
    final section = report.sections.single;

    expect(report.hasBlockingDateAnomalies, isTrue);
    expect(section.dateAnomalies.map((item) => item.code), contains('duplicate_day'));
    expect(section.dateAnomalies.map((item) => item.code), contains('day_sequence_mismatch'));
    expect(section.dateAnomalies.map((item) => item.code), contains('missing_dates'));
    expect(report.warnings, isNotEmpty);

    final converted = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(
          report,
          targetNames: ['นายสมชาย'],
        );
    expect(converted.shifts, isEmpty);
    expect(converted.hasBlockingDateAnomalies, isTrue);

    final november = report.filtered(
      includesDate: (date) => date.year == 2026 && date.month == 11,
    );
    expect(november.sections, hasLength(1));
    expect(november.hasBlockingDateAnomalies, isTrue);

    final december = report.filtered(
      includesDate: (date) => date.year == 2026 && date.month == 12,
    );
    expect(december.sections, isEmpty);
  });

  test('allows repeated day numbers when a two-month period contains both dates', () {
    final days = <Object?>[
      'วันที่',
      ...List<int>.generate(31, (index) => index + 1),
      ...List<int>.generate(31, (index) => index + 1),
    ];
    final input = _input(
      title: 'ตารางหลัก 1 พฤศจิกายน 2569 - 31 ธันวาคม 2569',
      days: days,
      workers: ['P1 เช้า', ...List<String>.filled(62, 'นายสมชาย')],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.hasBlockingDateAnomalies, isFalse);
    expect(report.sections.single.dateColumns, hasLength(62));
    expect(report.sections.single.dateColumns[31].date, DateTime(2026, 12, 1));
    expect(
      const MonthlyRosterShiftAdapter().parseForWorkers(
        report,
        targetNames: ['นายสมชาย'],
      ),
      isNotEmpty,
    );
  });
}

ShiftParserInput _input({
  required String title,
  required List<Object?> days,
  required List<Object?> workers,
}) {
  return ShiftParserInput(
    spreadsheetId: 'test-book',
    spreadsheetTitle: 'Roster',
    sheetId: 10,
    sheetTitle: 'ตารางเวร',
    timeZone: 'Asia/Bangkok',
    cells: [
      ..._row(0, [title]),
      ..._row(1, days),
      ..._row(2, workers),
    ],
  );
}

List<NormalizedCell> _row(int rowIndex, List<Object?> values) {
  return [
    for (var columnIndex = 0; columnIndex < values.length; columnIndex++)
      if (values[columnIndex] != null)
        NormalizedCell(
          sheetId: 10,
          sheetTitle: 'ตารางเวร',
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
