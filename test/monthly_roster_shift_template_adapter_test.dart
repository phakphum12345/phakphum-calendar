import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/shift_template.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_conversion_diagnostics.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/normalized_cell.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/shift_parser_input.dart';

void main() {
  const template = ShiftTemplate(
    id: 'custom-night',
    code: 'XN',
    name: 'เวรสนับสนุนกลางคืน',
    shortName: 'สนับสนุนดึก',
    startTime: Duration(hours: 19, minutes: 30),
    endTime: Duration(hours: 7, minutes: 30),
    color: 0xFF4527A0,
    workingHours: 12,
  );

  MonthlyRosterParseReport reportFor(String label) => MonthlyRosterParseReport(
    sections: [
      MonthlyRosterSection(
        title: 'ตารางเวรทดสอบ',
        headerRowIndex: 0,
        assignments: [
          MonthlyRosterAssignment(
            sectionTitle: 'ตารางเวรทดสอบ',
            rowLabel: label,
            rowIndex: 1,
            workerName: 'ผู้ทดสอบ',
            date: DateTime(2026, 11, 17),
            sourceCell: 'B2',
          ),
        ],
      ),
    ],
    warnings: const [],
  );

  test('converts a custom row label using an active shift template', () {
    final result = const MonthlyRosterShiftAdapter().parseForWorkersWithDiagnostics(
      reportFor('สนับสนุนดึก'),
      targetNames: const ['ผู้ทดสอบ'],
      shiftTemplates: const [template],
    );

    expect(result.convertedCount, 1);
    expect(result.unconvertedCount, 0);
    expect(result.shifts.single.code, 'XN');
    expect(result.shifts.single.start, DateTime(2026, 11, 17, 19, 30));
    expect(result.shifts.single.end, DateTime(2026, 11, 18, 7, 30));
  });

  test('does not use inactive templates to convert a custom label', () {
    final result = const MonthlyRosterShiftAdapter().parseForWorkersWithDiagnostics(
      reportFor('สนับสนุนดึก'),
      targetNames: const ['ผู้ทดสอบ'],
      shiftTemplates: [template.copyWith(active: false)],
    );

    expect(result.convertedCount, 0);
    expect(result.unconvertedCount, 1);
  });

  test('keeps duplicate active template aliases unconverted instead of guessing', () {
    final duplicate = template.copyWith(
      id: 'another-night',
      startTime: const Duration(hours: 20),
      endTime: const Duration(hours: 8),
    );
    final result = const MonthlyRosterShiftAdapter().parseForWorkersWithDiagnostics(
      reportFor('สนับสนุนดึก'),
      targetNames: const ['ผู้ทดสอบ'],
      shiftTemplates: [template, duplicate],
    );

    expect(result.convertedCount, 0);
    expect(result.unconvertedCount, 1);
    expect(result.unconvertedAssignments.single.rowLabel, 'สนับสนุนดึก');
  });

  test('matches a configured shift code from a real monthly roster grid', () {
    final report = const MonthlyRosterSectionParser().parse(_inputForRow('XN'));
    final result = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(
          report,
          targetNames: const ['ผู้ทดสอบ'],
          shiftTemplates: const [template],
        );
    expect(report.assignments, hasLength(1));
    expect(report.assignments.single.rowLabel, 'XN');
    expect(result.convertedCount, 1);
    expect(result.unconvertedCount, 0);
    expect(result.shifts.single.code, 'XN');
    expect(result.shifts.single.start, DateTime(2026, 11, 17, 19, 30));
    expect(result.shifts.single.end, DateTime(2026, 11, 18, 7, 30));
  });

  test('matches a configured template name from a real monthly roster grid', () {
    final report = const MonthlyRosterSectionParser()
        .parse(_inputForRow('เวรสนับสนุนกลางคืน'));
    final result = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(
          report,
          targetNames: const ['ผู้ทดสอบ'],
          shiftTemplates: const [template],
        );
    expect(result.convertedCount, 1);
    expect(result.unconvertedCount, 0);
    expect(result.shifts.single.code, 'XN');
    expect(result.shifts.single.start, DateTime(2026, 11, 17, 19, 30));
    expect(result.shifts.single.end, DateTime(2026, 11, 18, 7, 30));
  });

  test('matches a normalized short name from a real monthly roster grid', () {
    final report = const MonthlyRosterSectionParser()
        .parse(_inputForRow('  สนับสนุนดึก  '));
    final result = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(
          report,
          targetNames: const ['ผู้ทดสอบ'],
          shiftTemplates: const [template],
        );
    expect(result.convertedCount, 1);
    expect(result.unconvertedCount, 0);
    expect(result.shifts.single.code, 'XN');
    expect(result.shifts.single.start, DateTime(2026, 11, 17, 19, 30));
    expect(result.shifts.single.end, DateTime(2026, 11, 18, 7, 30));
  });

  test('keeps an unknown new row label visible for review after real parsing', () {
    final report = const MonthlyRosterSectionParser()
        .parse(_inputForRow('เวรใหม่ที่ยังไม่ตั้งค่า'));
    final result = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(
          report,
          targetNames: const ['ผู้ทดสอบ'],
          shiftTemplates: const [template],
        );
    expect(report.assignments, hasLength(1));
    expect(result.convertedCount, 0);
    expect(result.unconvertedCount, 1);
    expect(
      result.unconvertedAssignments.single.rowLabel,
      'เวรใหม่ที่ยังไม่ตั้งค่า',
    );
  });
}

ShiftParserInput _inputForRow(String rowLabel) {
  final cells = <NormalizedCell>[];
  void addRow(int row, List<Object?> values) {
    for (var column = 0; column < values.length; column++) {
      final value = values[column];
      cells.add(
        NormalizedCell(
          sheetId: 1,
          sheetTitle: 'Roster',
          a1: '${String.fromCharCode(65 + column)}${row + 1}',
          rowIndex: row,
          columnIndex: column,
          text: value is String ? value : null,
          rawValue: value,
        ),
      );
    }
  }

  addRow(0, ['เวรประจำเดือน พฤศจิกายน พ.ศ. 2569']);
  addRow(1, ['วันที่', 17]);
  addRow(2, [rowLabel, 'ผู้ทดสอบ']);
  return ShiftParserInput(
    spreadsheetId: 'synthetic-spreadsheet',
    spreadsheetTitle: 'Synthetic roster',
    sheetId: 1,
    sheetTitle: 'พฤศจิกายน 2569',
    timeZone: 'Asia/Bangkok',
    cells: cells,
  );
}
