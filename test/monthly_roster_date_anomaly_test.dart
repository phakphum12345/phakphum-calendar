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

  test('blocks near-complete headers missing the first or last boundary date', () {
    final parser = const MonthlyRosterSectionParser();
    final missingFirst = parser.parse(
      _input(
        title: 'X-OPD 1 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569',
        days: [
          'วันที่',
          ...List<int>.generate(29, (index) => index + 2),
        ],
        workers: ['P1 เช้า', ...List<String>.filled(29, 'นายสมชาย')],
      ),
    );
    final missingLast = parser.parse(
      _input(
        title: 'X-OPD 1 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569',
        days: [
          'วันที่',
          ...List<int>.generate(29, (index) => index + 1),
        ],
        workers: ['P1 เช้า', ...List<String>.filled(29, 'นายสมชาย')],
      ),
    );

    expect(
      missingFirst.sections.single.dateAnomalies.map((item) => item.code),
      contains('missing_start_date'),
    );
    expect(
      missingLast.sections.single.dateAnomalies.map((item) => item.code),
      contains('missing_end_date'),
    );
    expect(missingFirst.hasBlockingDateAnomalies, isTrue);
    expect(missingLast.hasBlockingDateAnomalies, isTrue);
  });

  test('blocks fractional numeric date cells instead of truncating them', () {
    final report = const MonthlyRosterSectionParser().parse(
      _input(
        title: 'X-OPD 1 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569',
        days: [
          'วันที่',
          1.5,
          ...List<int>.generate(29, (index) => index + 2),
        ],
        workers: ['P1 เช้า', ...List<String>.filled(30, 'นายสมชาย')],
      ),
    );

    final section = report.sections.single;
    expect(section.dateColumns.first.displayedDay, 2);
    expect(section.dateColumns.any((column) => column.columnIndex == 1), isFalse);
    expect(
      section.dateAnomalies.map((item) => item.code),
      contains('missing_start_date'),
    );

    final converted = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(
          report,
          targetNames: ['นายสมชาย'],
        );
    expect(converted.shifts, isEmpty);
    expect(converted.hasBlockingDateAnomalies, isTrue);
  });

  test('accepts integer-valued numeric date cells represented as doubles', () {
    final report = const MonthlyRosterSectionParser().parse(
      _input(
        title: 'X-OPD 1 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569',
        days: [
          'วันที่',
          1.0,
          ...List<int>.generate(29, (index) => index + 2),
        ],
        workers: ['P1 เช้า', ...List<String>.filled(30, 'นายสมชาย')],
      ),
    );

    expect(report.sections.single.dateColumns, hasLength(30));
    expect(report.sections.single.dateColumns.first.date, DateTime(2026, 11, 1));
    expect(report.hasBlockingDateAnomalies, isFalse);
  });

  test('allows repeated day numbers when a two-month period contains both dates', () {
    final days = <Object?>[
      'วันที่',
      ...List<int>.generate(30, (index) => index + 1),
      ...List<int>.generate(31, (index) => index + 1),
    ];
    final input = _input(
      title: 'ตารางหลัก 1 พฤศจิกายน 2569 - 31 ธันวาคม 2569',
      days: days,
      workers: ['P1 เช้า', ...List<String>.filled(61, 'นายสมชาย')],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.hasBlockingDateAnomalies, isFalse);
    expect(report.sections.single.dateColumns, hasLength(61));
    expect(report.sections.single.dateColumns[30].date, DateTime(2026, 12, 1));
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
