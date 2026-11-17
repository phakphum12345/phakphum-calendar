import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/shift_template.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_conversion_diagnostics.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';

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
}
