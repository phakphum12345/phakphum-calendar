import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_conversion_diagnostics.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';

void main() {
  test('keeps unsupported monthly shift labels visible in diagnostics', () {
    final report = MonthlyRosterParseReport(
      sections: [
        MonthlyRosterSection(
          title: 'ตารางเวรเดือนสิงหาคม 2569',
          headerRowIndex: 1,
          assignments: [
            MonthlyRosterAssignment(
              sectionTitle: 'ตารางเวรเดือนสิงหาคม 2569',
              rowLabel: 'P1 เช้า',
              rowIndex: 2,
              workerName: 'ภาคภูมิ',
              date: DateTime(2026, 8, 1),
              sourceCell: 'B3',
            ),
            MonthlyRosterAssignment(
              sectionTitle: 'ตารางเวรเดือนสิงหาคม 2569',
              rowLabel: 'เวรกลางวันพิเศษ',
              rowIndex: 3,
              workerName: 'ภาคภูมิ',
              date: DateTime(2026, 8, 2),
              sourceCell: 'C4',
            ),
          ],
        ),
      ],
      warnings: const [],
    );

    final result = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(
          report,
          targetNames: ['ภาคภูมิ'],
        );

    expect(result.convertedCount, 1);
    expect(result.unconvertedCount, 1);
    expect(result.shifts.single.cell, 'B3');
    expect(result.unconvertedAssignments.single.sourceCell, 'C4');
    expect(result.unconvertedAssignments.single.rowLabel, 'เวรกลางวันพิเศษ');
  });

  test('returns an empty diagnostic report when no target worker matches', () {
    const report = MonthlyRosterParseReport(sections: [], warnings: []);

    final result = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(
          report,
          targetNames: ['ไม่มีรายชื่อนี้'],
        );

    expect(result.shifts, isEmpty);
    expect(result.unconvertedAssignments, isEmpty);
  });
}
