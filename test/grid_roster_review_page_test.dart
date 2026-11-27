import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_repository.dart';
import 'package:phakphum_calendar/features/schedule/data/shared_preferences_schedule_repository.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_import_workflow.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_review_session.dart';
import 'package:phakphum_calendar/features/shift_parser/data/grid_roster_bundle_journal.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';
import 'package:phakphum_calendar/features/shift_parser/presentation/pages/grid_roster_review_page.dart';

class _MemoryStore implements ScheduleKeyValueStore {
  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> setString(String key, String value) async {}
}

void main() {
  testWidgets('all Grid assignments start excluded until reviewer opts in', (
    tester,
  ) async {
    final report = MonthlyRosterParseReport(
      sections: [
        MonthlyRosterSection(
          title: 'GEN November 2026',
          headerRowIndex: 1,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
          assignments: [
            MonthlyRosterAssignment(
              sectionTitle: 'GEN November 2026',
              rowLabel: 'GEN',
              rowIndex: 2,
              workerName: 'Somchai Example',
              date: DateTime(2026, 11, 1),
              sourceCell: 'B3',
            ),
          ],
        ),
      ],
      warnings: const ['Broken worksheet could not be read.'],
      sourceSheetCount: 2,
      sourceFingerprint: 'sha256:source-ui',
    );
    final session = const GridRosterReviewSessionBuilder().build(
      report: report,
      employees: [_employee],
      shiftTemplates: const [],
      sourceFingerprint: 'sha256:source-ui',
      targetScheduleId: 'schedule-1',
      targetScheduleRevision: 'absent:schedule-1',
    );
    final workflow = GridRosterImportWorkflow(
      scheduleRepository: _UnusedScheduleRepository(),
      journal: GridRosterBundleJournal(store: _MemoryStore()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GridRosterReviewPage(
          workflow: workflow,
          contextSnapshot: GridRosterImportReviewContext(
            session: session,
            targetSchedule: Schedule(
              id: 'schedule-1',
              name: 'November roster',
            ),
            targetExisted: false,
          ),
          employees: const [_employee],
          shiftTemplates: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final checkbox = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile).first,
    );
    expect(checkbox.value, isFalse);
    expect(find.text('รหัสหรือชื่อผู้ตรวจสอบ'), findsOneWidget);
    expect(find.text('นำรายการนี้เข้า Schedule'), findsOneWidget);
    expect(find.text('Broken worksheet could not be read.'), findsOneWidget);
  });

  testWidgets('date anomaly choices are isolated by source worksheet', (
    tester,
  ) async {
    MonthlyRosterSection section({
      required String title,
      required int sheetId,
    }) => MonthlyRosterSection(
      title: title,
      headerRowIndex: 1,
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 30),
      sourceSpreadsheetId: 'spreadsheet-1',
      sourceSheetId: sheetId,
      sourceSheetTitle: title,
      dateAnomalies: const [
        MonthlyRosterDateAnomaly(
          code: 'duplicate_day',
          columnIndex: 18,
          displayedDay: 30,
          message: 'พบเลขวันที่ 30 ซ้ำในช่วงวันที่ของส่วนนี้',
        ),
      ],
      assignments: const [],
    );

    final report = MonthlyRosterParseReport(
      sections: [
        section(title: 'X-OPD A', sheetId: 1),
        section(title: 'X-OPD B', sheetId: 2),
      ],
      warnings: const [],
      sourceSheetCount: 2,
      sourceFingerprint: 'sha256:source-ui',
    );
    final session = const GridRosterReviewSessionBuilder().build(
      report: report,
      employees: const [],
      shiftTemplates: const [],
      sourceFingerprint: 'sha256:source-ui',
      targetScheduleId: 'schedule-1',
      targetScheduleRevision: 'absent:schedule-1',
    );
    final workflow = GridRosterImportWorkflow(
      scheduleRepository: _UnusedScheduleRepository(),
      journal: GridRosterBundleJournal(store: _MemoryStore()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GridRosterReviewPage(
          workflow: workflow,
          contextSnapshot: GridRosterImportReviewContext(
            session: session,
            targetSchedule: Schedule(id: 'schedule-1', name: 'November roster'),
            targetExisted: false,
          ),
          employees: const [],
          shiftTemplates: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final choices = find.text('เลือกวิธีจัดการ');
    expect(choices, findsNWidgets(2));

    await tester.tap(choices.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ข้าม Section นี้ทั้งส่วน'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('เลือกวิธีจัดการ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('กลับไปแก้ไฟล์ต้นฉบับและนำเข้าใหม่'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ข้าม Section นี้ทั้งส่วน จะไม่นำรายการเวร'),
      findsOneWidget,
    );
    expect(
      find.textContaining('กลับไปแก้ไฟล์ต้นฉบับและนำเข้าใหม่ — ยังบันทึก'),
      findsOneWidget,
    );
  });
}

class _UnusedScheduleRepository implements ScheduleRepository {
  @override
  Future<Result<Schedule?>> findById(String id) async => const Success(null);

  @override
  Future<Result<ScheduleMonth?>> loadMonth(String scheduleId, DateTime month) async =>
      const Success(null);

  @override
  Future<Result<Schedule>> save(Schedule schedule) async => Success(schedule);

  @override
  Future<Result<void>> delete(String id) async => const Success(null);
}

const _department = Department(id: 'd1', code: 'D1', name: 'Department');
const _employee = Employee(
  id: 'employee-1',
  employeeCode: '001',
  firstName: 'Somchai',
  lastName: 'Example',
  nickname: 'Chai',
  department: _department,
  position: 'Staff',
);
