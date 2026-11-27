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
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/data/grid_roster_bundle_journal.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/normalized_cell.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/shift_parser_input.dart';
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

  testWidgets('alias suggestions never preselect an employee', (tester) async {
    final aliasEmployee = _employee.copyWith(
      alternateNames: 'Former Name',
    );
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
              workerName: 'Former Name',
              date: DateTime(2026, 11, 1),
              sourceCell: 'B3',
            ),
          ],
        ),
      ],
      warnings: const [],
      sourceSheetCount: 1,
      sourceFingerprint: 'sha256:source-alias-ui',
    );
    final session = const GridRosterReviewSessionBuilder().build(
      report: report,
      employees: [aliasEmployee],
      shiftTemplates: const [],
      sourceFingerprint: 'sha256:source-alias-ui',
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
          employees: [aliasEmployee],
          shiftTemplates: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ชื่อจากต้นฉบับ: Former Name'), findsOneWidget);
    expect(
      find.text('คำแนะนำพนักงาน: ${aliasEmployee.displayName}'),
      findsOneWidget,
    );
    final checkboxFinder = find.byType(CheckboxListTile).first;
    // The fixed commit bar occupies the bottom of the test viewport. Bring
    // the assignment control fully into the ListView's visible area before
    // tapping; otherwise the tap can land on the commit bar underneath it.
    await tester.ensureVisible(checkboxFinder);
    await tester.pumpAndSettle();

    final checkbox = tester.widget<CheckboxListTile>(checkboxFinder);
    expect(checkbox.value, isFalse);
    expect(checkbox.onChanged, isNotNull);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    await tester.tap(checkboxFinder);
    await tester.pumpAndSettle();

    final dropdownFinder = find.byType(DropdownButtonFormField<String>);
    expect(dropdownFinder, findsOneWidget);
    var dropdown = tester.widget<DropdownButtonFormField<String>>(
      dropdownFinder,
    );
    expect(dropdown.initialValue, isNull);

    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text(aliasEmployee.displayName).last);
    await tester.pumpAndSettle();

    dropdown = tester.widget<DropdownButtonFormField<String>>(
      dropdownFinder,
    );
    expect(dropdown.initialValue, aliasEmployee.id);
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

    final scrollable = find.byType(Scrollable).first;
    final choices = find.text('เลือกวิธีจัดการ');
    expect(choices, findsOneWidget);
    await tester.scrollUntilVisible(
      choices,
      200,
      scrollable: scrollable,
    );
    await tester.ensureVisible(choices);
    await tester.pumpAndSettle();

    await tester.tap(choices.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ข้าม Section นี้ทั้งส่วน'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('X-OPD B'),
      250,
      scrollable: scrollable,
    );
    final secondChoices = find.text('เลือกวิธีจัดการ');
    await tester.ensureVisible(secondChoices);
    await tester.pumpAndSettle();
    await tester.tap(secondChoices);
    await tester.pumpAndSettle();
    await tester.tap(find.text('กลับไปแก้ไฟล์ต้นฉบับและนำเข้าใหม่'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('X-OPD A'),
      250,
      scrollable: scrollable,
    );
    expect(
      find.textContaining('ข้าม Section นี้ทั้งส่วน จะไม่นำรายการเวร'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('X-OPD B'),
      250,
      scrollable: scrollable,
    );
    expect(
      find.textContaining('กลับไปแก้ไฟล์ต้นฉบับและนำเข้าใหม่ — ยังบันทึก'),
      findsOneWidget,
    );
  });

  testWidgets('reviewer can correct multiple source-backed date columns sequentially and revalidate', (
    tester,
  ) async {
    List<NormalizedCell> row(int rowIndex, List<Object?> values) => [
      for (var columnIndex = 0; columnIndex < values.length; columnIndex++)
        if (values[columnIndex] != null)
          NormalizedCell(
            sheetId: 1,
            sheetTitle: 'X-OPD',
            a1: '',
            rowIndex: rowIndex,
            columnIndex: columnIndex,
            text: values[columnIndex] is String
                ? values[columnIndex] as String
                : null,
            rawValue: values[columnIndex],
          ),
    ];
    final parsed = const MonthlyRosterSectionParser().parse(
      ShiftParserInput(
        spreadsheetId: 'spreadsheet-1',
        spreadsheetTitle: 'Roster',
        sheetId: 1,
        sheetTitle: 'X-OPD',
        timeZone: 'Asia/Bangkok',
        cells: [
          ...row(0, ['GEN 1 พฤศจิกายน 2569 - 8 พฤศจิกายน 2569']),
          ...row(1, ['วันที่', 1, 2, 3, 4, 4, 6, 6, 8]),
          ...row(2, ['GEN', 'ก', null, null, null, 'ข', null, 'ค', null]),
        ],
      ),
    );
    final parsedSection = parsed.sections.single;
    expect(parsedSection.sourceCells, isNotEmpty);
    expect(parsedSection.startDate, DateTime(2026, 11, 1));
    expect(parsedSection.endDate, DateTime(2026, 11, 8));
    expect(
      parsedSection.dateAnomalies.any((anomaly) => anomaly.columnIndex == 5),
      isTrue,
    );
    final report = MonthlyRosterParseReport(
      sections: parsed.sections,
      warnings: parsed.warnings,
      sourceSheetCount: 1,
      sourceFingerprint: 'sha256:source-correction-ui',
    );
    final session = const GridRosterReviewSessionBuilder().build(
      report: report,
      employees: const [],
      shiftTemplates: const [],
      sourceFingerprint: 'sha256:source-correction-ui',
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

    // Sections are children of a lazy ListView. Scroll to the unique
    // section-level heading first so its anomaly card and correction action
    // are built before locating the action.
    final anomalyHeading = find.text('พบจุดผิดในหัวตารางวันที่');
    await tester.scrollUntilVisible(
      anomalyHeading,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final firstCorrectionAction = find.byKey(
      const ValueKey('grid-roster-correct-date-1-1-5-duplicate_day'),
    );
    expect(firstCorrectionAction, findsOneWidget);
    await tester.ensureVisible(firstCorrectionAction);
    await tester.pumpAndSettle();
    await tester.tap(firstCorrectionAction);
    await tester.pumpAndSettle();

    await tester.tap(find.text('5').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ใช้วันที่นี้และตรวจตารางใหม่'));
    await tester.pumpAndSettle();

    expect(find.text('พบจุดผิดในหัวตารางวันที่'), findsOneWidget);
    // The second duplicate belongs to source column 8 (zero-based 7).
    // Target its stable source-coordinate key rather than relying on widget
    // order among identical action labels.
    final secondCorrectionAction = find.byKey(
      const ValueKey('grid-roster-correct-date-1-1-7-duplicate_day'),
    );
    expect(secondCorrectionAction, findsOneWidget);
    await tester.ensureVisible(secondCorrectionAction);
    await tester.pumpAndSettle();
    await tester.tap(secondCorrectionAction);
    await tester.pumpAndSettle();

    await tester.tap(find.text('7').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ใช้วันที่นี้และตรวจตารางใหม่'));
    await tester.pumpAndSettle();

    expect(find.text('พบจุดผิดในหัวตารางวันที่'), findsNothing);
    expect(find.textContaining('2026-11-05'), findsOneWidget);
    expect(find.textContaining('2026-11-07'), findsOneWidget);
    expect(find.text('กำหนดวันที่คอลัมน์นี้'), findsNothing);
  });
  testWidgets('reviewer can correct a vertical date row and rebuild assignments', (
    tester,
  ) async {
    List<NormalizedCell> row(int rowIndex, List<Object?> values) => [
      for (var columnIndex = 0; columnIndex < values.length; columnIndex++)
        if (values[columnIndex] != null)
          NormalizedCell(
            sheetId: 1,
            sheetTitle: 'Vertical',
            a1: '',
            rowIndex: rowIndex,
            columnIndex: columnIndex,
            text: values[columnIndex] is String
                ? values[columnIndex] as String
                : null,
            rawValue: values[columnIndex],
          ),
    ];
    final parsed = const MonthlyRosterSectionParser().parse(
      ShiftParserInput(
        spreadsheetId: 'spreadsheet-vertical',
        spreadsheetTitle: 'Roster',
        sheetId: 1,
        sheetTitle: 'พฤศจิกายน 2569',
        timeZone: 'Asia/Bangkok',
        cells: [
          ...row(0, [null, 'เวรเช้า']),
          ...row(1, ['ประจำเดือน พฤศจิกายน พ.ศ. 2569']),
          ...row(2, [1, 'นาย ก']),
          ...row(3, [2, 'นาย ข']),
          ...row(4, [2, 'นาย ค']),
          ...row(5, [4, 'นาย ง']),
          ...row(6, [5, 'นาย จ']),
          ...row(7, [6, 'นาย ฉ']),
          ...row(8, [7, 'นาย ช']),
        ],
      ),
    );
    final section = parsed.sections.single;
    expect(section.dateAnomalies, hasLength(1));
    expect(section.dateAnomalies.single.rowIndex, 4);
    final report = MonthlyRosterParseReport(
      sections: parsed.sections,
      warnings: parsed.warnings,
      sourceSheetCount: 1,
      sourceFingerprint: 'sha256:vertical-correction-ui',
    );
    final session = const GridRosterReviewSessionBuilder().build(
      report: report,
      employees: const [],
      shiftTemplates: const [],
      sourceFingerprint: 'sha256:vertical-correction-ui',
      targetScheduleId: 'schedule-vertical',
      targetScheduleRevision: 'absent:schedule-vertical',
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
              id: 'schedule-vertical',
              name: 'Vertical roster',
            ),
            targetExisted: false,
          ),
          employees: const [],
          shiftTemplates: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final anomalyHeading = find.text('พบจุดผิดในหัวตารางวันที่');
    await tester.scrollUntilVisible(
      anomalyHeading,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final correction = find.byKey(
      const ValueKey('grid-roster-correct-date-1-2-4-duplicate_date'),
    );
    expect(correction, findsOneWidget);
    await tester.ensureVisible(correction);
    await tester.pumpAndSettle();
    await tester.tap(correction);
    await tester.pumpAndSettle();

    await tester.tap(find.text('3').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ใช้วันที่นี้และตรวจตารางใหม่'));
    await tester.pumpAndSettle();

    expect(find.text('พบจุดผิดในหัวตารางวันที่'), findsNothing);
    expect(find.text('กำหนดวันที่แถวนี้'), findsNothing);
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
