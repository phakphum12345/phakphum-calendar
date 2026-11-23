import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_conversion_diagnostics.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/normalized_cell.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/roster_sync_period_filter.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/shift_parser_input.dart';
import 'package:phakphum_calendar/models/roster_period.dart';

void main() {
  const parser = MonthlyRosterSectionParser();

  test('November split sections remain syncable through day 30', () {
    final report = parser.parse(_novemberDecemberRoster());
    final conversion = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(
          report,
          targetNames: const ['นาย ทดสอบ'],
        );

    final november = conversion.shifts
        .where((shift) => RosterSyncPeriodFilter.includes(
              shift.start,
              const [RosterPeriod(year: 2026, month: 11)],
            ))
        .toList();

    expect(report.warnings, isEmpty);
    expect(report.sections, hasLength(4));
    expect(report.assignments, hasLength(61));
    expect(conversion.convertedCount, 61);
    expect(conversion.unconvertedCount, 0);
    expect(november, hasLength(30));
    expect(november.first.start, DateTime(2026, 11, 1, 8));
    expect(november.last.start, DateTime(2026, 11, 30, 8));
  });

  test('selecting November and December includes every day of both months', () {
    final report = parser.parse(_novemberDecemberRoster());
    final conversion = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(
          report,
          targetNames: const ['นาย ทดสอบ'],
        );
    const selected = [
      RosterPeriod(year: 2026, month: 11),
      RosterPeriod(year: 2026, month: 12),
    ];

    final selectedShifts = conversion.shifts
        .where((shift) => RosterSyncPeriodFilter.includes(shift.start, selected))
        .toList();

    expect(selectedShifts, hasLength(61));
    expect(selectedShifts.first.start, DateTime(2026, 11, 1, 8));
    expect(selectedShifts[29].start, DateTime(2026, 11, 30, 8));
    expect(selectedShifts[30].start, DateTime(2026, 12, 1, 8));
    expect(selectedShifts.last.start, DateTime(2026, 12, 31, 8));
  });
}

ShiftParserInput _novemberDecemberRoster() {
  final cells = <NormalizedCell>[
    ..._row(0, ['เวรหลัก 1 พฤศจิกายน 2569 - 15 พฤศจิกายน 2569']),
    ..._row(1, ['วันที่', ...List<int>.generate(15, (index) => index + 1)]),
    ..._row(2, ['ER', ...List<String>.filled(15, 'นาย ทดสอบ')]),
    ..._row(4, ['เวรเสริม 16 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569']),
    ..._row(5, ['วันที่', ...List<int>.generate(15, (index) => index + 16)]),
    ..._row(6, ['ER', ...List<String>.filled(15, 'นาย ทดสอบ')]),
    ..._row(8, ['เวรหลัก 1 ธันวาคม 2569 - 15 ธันวาคม 2569']),
    ..._row(9, ['วันที่', ...List<int>.generate(15, (index) => index + 1)]),
    ..._row(10, ['ER', ...List<String>.filled(15, 'นาย ทดสอบ')]),
    ..._row(12, ['เวรเสริม 16 ธันวาคม 2569 - 31 ธันวาคม 2569']),
    ..._row(13, ['วันที่', ...List<int>.generate(16, (index) => index + 16)]),
    ..._row(14, ['ER', ...List<String>.filled(16, 'นาย ทดสอบ')]),
  ];

  return ShiftParserInput(
    spreadsheetId: 'november-december-regression',
    spreadsheetTitle: 'ตารางเวร พฤศจิกายน-ธันวาคม 2569',
    sheetId: 1,
    sheetTitle: 'ตารางเวร พฤศจิกายน-ธันวาคม 2569',
    timeZone: 'Asia/Bangkok',
    cells: cells,
  );
}

List<NormalizedCell> _row(int rowIndex, List<Object?> values) => [
  for (var columnIndex = 0; columnIndex < values.length; columnIndex++)
    if (values[columnIndex] != null)
      NormalizedCell(
        sheetId: 1,
        sheetTitle: 'ตารางเวร พฤศจิกายน-ธันวาคม 2569',
        a1: '',
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        text: values[columnIndex] is String
            ? values[columnIndex] as String
            : null,
        rawValue: values[columnIndex],
      ),
];
