import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_conversion_diagnostics.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/normalized_cell.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/roster_sync_period_filter.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/shift_parser_input.dart';
import 'package:phakphum_calendar/models/roster_period.dart';

void main() {
  test('period heading below date row resolves the November-December grid', () {
    const parser = MonthlyRosterSectionParser();
    final report = parser.parse(_crossMonthRoster());
    final conversion = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(
          report,
          targetNames: const ['นาย ทดสอบ'],
        );

    expect(report.sections, hasLength(1));
    expect(report.sections.single.startDate, DateTime(2026, 11, 16));
    expect(report.sections.single.endDate, DateTime(2026, 12, 15));
    expect(report.assignments, hasLength(30));
    expect(conversion.convertedCount, 30);
    expect(conversion.unconvertedCount, 0);

    final november = conversion.shifts
        .where((shift) => RosterSyncPeriodFilter.includes(
              shift.start,
              const [RosterPeriod(year: 2026, month: 11)],
            ))
        .toList();
    final december = conversion.shifts
        .where((shift) => RosterSyncPeriodFilter.includes(
              shift.start,
              const [RosterPeriod(year: 2026, month: 12)],
            ))
        .toList();

    expect(november, hasLength(15));
    expect(november.first.start, DateTime(2026, 11, 16, 8));
    expect(november.last.start, DateTime(2026, 11, 30, 8));
    expect(december, hasLength(15));
    expect(december.first.start, DateTime(2026, 12, 1, 8));
    expect(december.last.start, DateTime(2026, 12, 15, 8));
  });
}

ShiftParserInput _crossMonthRoster() {
  final days = [
    ...List<int>.generate(15, (index) => index + 16),
    ...List<int>.generate(15, (index) => index + 1),
  ];
  final cells = <NormalizedCell>[
    ..._row(0, ['วันที่', ...days]),
    ..._row(1, [null, 'ประจำเดือน 16 พฤศจิกายน พ.ศ. 2569 - 15 ธันวาคม พ.ศ. 2569']),
    ..._row(2, ['PORTABLE']),
    ..._row(3, ['ER', ...List<String>.filled(30, 'นาย ทดสอบ')]),
  ];

  return ShiftParserInput(
    spreadsheetId: 'uploaded-roster-period-heading-order',
    spreadsheetTitle: 'ตารางเวร',
    sheetId: 1,
    sheetTitle: 'ตารางเวร',
    timeZone: 'Asia/Bangkok',
    cells: cells,
  );
}

List<NormalizedCell> _row(int rowIndex, List<Object?> values) => [
  for (var columnIndex = 0; columnIndex < values.length; columnIndex++)
    if (values[columnIndex] != null)
      NormalizedCell(
        sheetId: 1,
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
