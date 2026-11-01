import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_conversion_diagnostics.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';
import 'package:phakphum_calendar/models/shift.dart';

void main() {
  test('same A1 cell on different tabs remains two distinct roster records', () {
    final assignments = [
      MonthlyRosterAssignment(
        sectionTitle: 'เวรประจำเดือนตุลาคม 2569',
        rowLabel: 'P1 เช้า',
        rowIndex: 2,
        workerName: 'ภาคภูมิ',
        date: DateTime(2026, 10, 1),
        sourceCell: 'B3',
        spreadsheetId: 'spreadsheet-1',
        sheetId: 101,
        sheetTitle: 'เวรหลัก',
      ),
      MonthlyRosterAssignment(
        sectionTitle: 'เวรประจำเดือนตุลาคม 2569',
        rowLabel: 'P1 เช้า',
        rowIndex: 2,
        workerName: 'ภาคภูมิ',
        date: DateTime(2026, 10, 1),
        sourceCell: 'B3',
        spreadsheetId: 'spreadsheet-1',
        sheetId: 202,
        sheetTitle: 'เวรคลินิก',
      ),
    ];
    expect(
      assignments.map((item) => item.sourceIdentityKey),
      ['spreadsheet-1|101|B3', 'spreadsheet-1|202|B3'],
    );
    final report = MonthlyRosterParseReport(
      sections: [
        MonthlyRosterSection(
          title: 'เวรประจำเดือนตุลาคม 2569',
          headerRowIndex: 1,
          assignments: assignments,
        ),
      ],
      warnings: const [],
    );

    final result = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(report, targetNames: ['ภาคภูมิ']);

    expect(result.shifts.length, equals(2));
    expect(result.shifts.map((shift) => shift.sourceIdentityKey).toSet(), hasLength(2));
    expect(result.shifts.map((shift) => shift.sourceSheetId), [101, 202]);
    expect(
      result.shifts.map((shift) => shift.sheetTitle),
      ['เวรหลัก', 'เวรคลินิก'],
    );
    expect(result.unconvertedAssignments, isEmpty);
  });

  test('source identity survives copyWith and distinguishes tabs', () {
    final first = Shift(
      code: 'UP1',
      rowLabel: 'P1 เช้า',
      assignedName: 'ภาคภูมิ',
      start: DateTime(2026, 10, 1, 8),
      end: DateTime(2026, 10, 1, 16),
      sheetTitle: 'เวรหลัก',
      cell: 'B3',
      category: ShiftCategory.own,
      sourceSpreadsheetId: 'spreadsheet-1',
      sourceSheetId: 101,
    );
    final second = first.copyWith(excluded: true).withSourceIdentity(
      spreadsheetId: 'spreadsheet-1',
      sheetId: 202,
    );

    expect(first.sourceIdentityKey, isNot(second.sourceIdentityKey));
    expect(first.sourceKey, '2026-10-01|UP1|ภาคภูมิ');
    expect(first.sourceUrl, isNotNull);
    expect(
      first.copyWith(excluded: true).sourceIdentityKey,
      first.sourceIdentityKey,
    );
    expect(second.sourceSheetId, 202);
    expect(second.excluded, isTrue);
    expect(
      first.sourceUrl,
      'https://docs.google.com/spreadsheets/d/spreadsheet-1/edit#gid=101&range=B3',
    );
  });

  test('diagnostics match by spreadsheet, sheet and A1 cell', () {
    final report = MonthlyRosterParseReport(
      sections: [
        MonthlyRosterSection(
          title: 'เวรประจำเดือนตุลาคม 2569',
          headerRowIndex: 1,
          assignments: [
            MonthlyRosterAssignment(
              sectionTitle: 'เวรประจำเดือนตุลาคม 2569',
              rowLabel: 'P1 เช้า',
              rowIndex: 2,
              workerName: 'ภาคภูมิ',
              date: DateTime(2026, 10, 1),
              sourceCell: 'B3',
              spreadsheetId: 'spreadsheet-1',
              sheetId: 101,
              sheetTitle: 'เวรหลัก',
            ),
            MonthlyRosterAssignment(
              sectionTitle: 'เวรประจำเดือนตุลาคม 2569',
              rowLabel: 'เวรที่ยังไม่รองรับ',
              rowIndex: 2,
              workerName: 'ภาคภูมิ',
              date: DateTime(2026, 10, 1),
              sourceCell: 'B3',
              spreadsheetId: 'spreadsheet-1',
              sheetId: 202,
              sheetTitle: 'เวรคลินิก',
            ),
          ],
        ),
      ],
      warnings: const [],
    );

    final result = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(report, targetNames: ['ภาคภูมิ']);

    expect(result.convertedCount, 1);
    expect(result.unconvertedCount, 1);
    expect(result.unconvertedAssignments.single.sheetId, 202);
  });
}
