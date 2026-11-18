import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_day.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_template.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_issue.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_summary.dart';
import 'package:phakphum_calendar/features/excel_import/domain/shift_record.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/pages/import_summary_page.dart';

const _employee = Employee(
  id: 'employee-1',
  employeeCode: 'E001',
  firstName: 'Anan',
  lastName: 'Sukjai',
  nickname: '',
  department: Department(id: 'er', code: 'ER', name: 'Emergency'),
  position: 'Nurse',
);
const _template = ShiftTemplate(
  id: 'morning',
  code: 'M',
  name: 'Morning',
  shortName: 'AM',
  startTime: Duration(hours: 8),
  endTime: Duration(hours: 16),
  color: 0xFF1565C0,
  workingHours: 8,
);
final _date = DateTime(2026, 7, 24);
final _summary = ImportSummary(
  totalRows: 1,
  importedRows: 1,
  skippedRows: 0,
  errorRows: 0,
  issues: const <ImportIssue>[],
);
final _record = ShiftRecord(
  date: _date,
  shift: 'M',
  employee: _employee.fullName,
  rowNumber: 2,
  resolvedEmployee: _employee,
  resolvedShiftTemplate: _template,
);
Schedule _existing() => Schedule(
  id: 'imported',
  name: 'Existing roster',
  months: [ScheduleMonth.empty(_date)],
);

void main() {
  testWidgets('shows staging decisions and saves only selected rows', (
    tester,
  ) async {
    Schedule? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: ImportSummaryPage(
          summary: _summary,
          records: [_record],
          existingScheduleLoader: () async => Success(_existing()),
          scheduleSaver: (schedule) async {
            saved = schedule;
            return Success(schedule);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CREATE • เพิ่มใหม่'), findsOneWidget);
    expect(find.textContaining('เพิ่มใหม่ 1'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยืนยันและบันทึกตารางเวร'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.month(_date)!.day(_date)!.assignments, isEmpty);
  });

  testWidgets('blocks confirmation when a row identity is unresolved', (
    tester,
  ) async {
    final unresolved = ShiftRecord(
      date: _date,
      shift: 'M',
      employee: 'Unknown',
      rowNumber: 2,
    );
    var saveCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ImportSummaryPage(
          summary: _summary,
          records: [unresolved],
          existingScheduleLoader: () async => Success(_existing()),
          scheduleSaver: (schedule) async {
            saveCalled = true;
            return Success(schedule);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('ต้องตรวจ 1'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'ยืนยันและบันทึกตารางเวร'),
    );
    expect(saveButton.onPressed, isNull);
    expect(saveCalled, isFalse);
  });
}
