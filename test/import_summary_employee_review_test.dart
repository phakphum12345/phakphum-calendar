import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/shift_template.dart';
import 'package:phakphum_calendar/domain/repositories/employee_repository.dart';
import 'package:phakphum_calendar/domain/repositories/shift_template_repository.dart';
import 'package:phakphum_calendar/features/excel_import/data/excel_reader_service.dart';
import 'package:phakphum_calendar/features/excel_import/domain/column_mapping.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_file.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_summary.dart';
import 'package:phakphum_calendar/features/excel_import/domain/shift_record.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/controllers/excel_import_controller.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/pages/import_summary_page.dart';
import 'package:phakphum_calendar/features/shift_templates/application/shift_template_controller.dart';
import 'package:phakphum_calendar/features/workflow/application/canonical_schedule_event_mapper.dart';
import 'package:phakphum_calendar/features/workflow/application/workflow_preview_builder.dart';

void _useTallTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('ambiguous employee must be explicitly selected before save', (
    tester,
  ) async {
    const emergencyEmployee = Employee(
      id: 'employee-er-1',
      employeeCode: 'ER-001',
      firstName: 'Anan',
      lastName: 'Sukjai',
      nickname: 'Nan',
      department: Department(
        id: 'emergency',
        code: 'ER',
        name: 'Emergency',
      ),
      position: 'Nurse',
    );
    const radiologyEmployee = Employee(
      id: 'employee-rad-1',
      employeeCode: 'RAD-001',
      firstName: 'Anan',
      lastName: 'Sukjai',
      nickname: 'An',
      department: Department(
        id: 'radiology',
        code: 'RAD',
        name: 'Radiology',
      ),
      position: 'Technologist',
    );
    final repository = _EmployeeRepository([
      emergencyEmployee,
      radiologyEmployee,
    ]);
    Schedule? savedSchedule;
    final summary = ImportSummary(
      totalRows: 1,
      importedRows: 1,
      skippedRows: 0,
      errorRows: 0,
      issues: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ImportSummaryPage(
          summary: summary,
          records: [
            ShiftRecord(
              date: DateTime(2026, 7, 24),
              shift: 'Morning',
              employee: 'Anan Sukjai',
              rowNumber: 2,
            ),
          ],
          employeeRepository: repository,
          scheduleSaver: (schedule) async {
            savedSchedule = schedule;
            return Success(schedule);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(
      FilledButton,
      'ยืนยันและบันทึกตารางเวร',
    );
    expect(saveButton, findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<Employee>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anan Sukjai (Nan) • Emergency').last);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(savedSchedule, isNotNull);
    final assignment = savedSchedule!
        .month(DateTime(2026, 7, 24))!
        .day(DateTime(2026, 7, 24))!
        .assignments
        .single;
    expect(assignment.employee.id, emergencyEmployee.id);
    expect(assignment.employee.department.id, 'emergency');
    expect(find.text('บันทึกแล้ว'), findsOneWidget);
    expect(
      tester.widget<DropdownButtonFormField<Employee>>(
        find.byType(DropdownButtonFormField<Employee>),
      ).onChanged,
      isNull,
      reason: 'A successfully saved employee identity must not remain editable',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uses an exact shift template and locks review edits after saving',
    (tester) async {
      _useTallTestViewport(tester);
      const employee = Employee(
        id: 'employee-er-1',
        employeeCode: 'ER-001',
        firstName: 'Anan',
        lastName: 'Sukjai',
        nickname: 'Nan',
        department: Department(
          id: 'emergency',
          code: 'ER',
          name: 'Emergency',
        ),
        position: 'Nurse',
      );
      const template = ShiftTemplate(
        id: 'shift:night-support',
        code: 'XN',
        name: 'Night Support',
        shortName: 'NS',
        startTime: Duration(hours: 19, minutes: 30),
        endTime: Duration(hours: 7, minutes: 30),
        color: 0xFF4527A0,
        workingHours: 12,
      );
      final controller = ExcelImportController(
        reader: ExcelReaderService(
          filePicker: () async => _workbookWithInvalidRow(),
        ),
      );
      addTearDown(controller.dispose);
      await controller.pickFile();
      await controller.selectWorksheet(controller.workbook!.worksheets.single);
      await controller.importRows(
        const ColumnMapping(
          dateColumn: 'A',
          shiftColumn: 'B',
          employeeColumn: 'C',
          departmentColumn: 'D',
        ),
      );
      Schedule? savedSchedule;

      await tester.pumpWidget(
        MaterialApp(
          home: ImportSummaryPage(
            summary: controller.importSummary!,
            records: controller.shiftRecords,
            controller: controller,
            employeeRepository: const _EmployeeRepository([employee]),
            shiftTemplateControllerFactory: () => ShiftTemplateController(
              repository: _ShiftTemplateRepository([template]),
            ),
            scheduleSaver: (schedule) async {
              savedSchedule = schedule;
              return Success(schedule);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('แก้ไขข้อมูลแถวนี้'), findsNWidgets(2));
      final firstEdit = find.byTooltip('แก้ไขข้อมูลแถวนี้').first;
      await tester.ensureVisible(firstEdit);
      await tester.pumpAndSettle();
      await tester.tap(firstEdit);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2026-07-25');
      await tester.tap(find.text('บันทึกและตรวจใหม่'));
      await tester.pumpAndSettle();
      expect(controller.shiftRecords, hasLength(2));
      expect(controller.importSummary!.errorRows, 1);

      final saveButton = find.widgetWithText(
        FilledButton,
        'ยืนยันและบันทึกตารางเวร',
      );
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(savedSchedule, isNotNull);
      final firstDay = savedSchedule!
          .month(DateTime(2026, 7, 24))!
          .day(DateTime(2026, 7, 24))!
          .assignments
          .single;
      final correctedDay = savedSchedule!
          .month(DateTime(2026, 7, 25))!
          .day(DateTime(2026, 7, 25))!
          .assignments
          .single;
      for (final assignment in [firstDay, correctedDay]) {
        expect(assignment.employee.id, employee.id);
        expect(assignment.shift.id, template.id);
        expect(assignment.shift.code, 'XN');
        expect(
          assignment.shift.startTime,
          const Duration(hours: 19, minutes: 30),
        );
        expect(
          assignment.shift.endTime,
          const Duration(hours: 7, minutes: 30),
        );
        expect(assignment.shift.workingHours, 12);
      }
      expect(find.text('บันทึกแล้ว'), findsOneWidget);
      expect(find.byTooltip('แก้ไขข้อมูลแถวนี้'), findsNothing);
      expect(
        tester
            .widgetList<DropdownButtonFormField<Employee>>(
              find.byType(DropdownButtonFormField<Employee>),
            )
            .every((dropdown) => dropdown.onChanged == null),
        isTrue,
      );
      expect(
        tester
            .widgetList<DropdownButtonFormField<ShiftTemplate>>(
              find.byType(DropdownButtonFormField<ShiftTemplate>),
            )
            .every((dropdown) => dropdown.onChanged == null),
        isTrue,
      );
      final candidates = const CanonicalScheduleEventMapper()
          .map(savedSchedule!);
      final preview = const WorkflowPreviewBuilder().buildCandidates(
        desired: candidates,
        existing: const [],
      );
      expect(preview.diff.toAdd, hasLength(2));
      expect(preview.diff.toUpdate, isEmpty);
      expect(preview.diff.toDelete, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown shift requires an explicit template selection', (
    tester,
  ) async {
    _useTallTestViewport(tester);
    const employee = Employee(
      id: 'employee-er-1',
      employeeCode: 'ER-001',
      firstName: 'Anan',
      lastName: 'Sukjai',
      nickname: 'Nan',
      department: Department(
        id: 'emergency',
        code: 'ER',
        name: 'Emergency',
      ),
      position: 'Nurse',
    );
    const template = ShiftTemplate(
      id: 'shift:night-support',
      code: 'XN',
      name: 'Night Support',
      shortName: 'NS',
      startTime: Duration(hours: 19, minutes: 30),
      endTime: Duration(hours: 7, minutes: 30),
      color: 0xFF4527A0,
      workingHours: 12,
    );
    Schedule? savedSchedule;

    await tester.pumpWidget(
      MaterialApp(
        home: ImportSummaryPage(
          summary: ImportSummary(
            totalRows: 1,
            importedRows: 1,
            skippedRows: 0,
            errorRows: 0,
            issues: const [],
          ),
          records: [
            ShiftRecord(
              date: DateTime(2026, 7, 24),
              shift: 'Night Duty',
              employee: 'Anan Sukjai',
              department: 'ER',
              rowNumber: 2,
            ),
          ],
          employeeRepository: const _EmployeeRepository([employee]),
          shiftTemplateControllerFactory: () => ShiftTemplateController(
            repository: _ShiftTemplateRepository([template]),
          ),
          scheduleSaver: (schedule) async {
            savedSchedule = schedule;
            return Success(schedule);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(
      FilledButton,
      'ยืนยันและบันทึกตารางเวร',
    );
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<ShiftTemplate>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Night Support • XN • 19:30–07:30').last);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(savedSchedule, isNotNull);
    final shift = savedSchedule!
        .month(DateTime(2026, 7, 24))!
        .day(DateTime(2026, 7, 24))!
        .assignments
        .single
        .shift;
    expect(shift.id, template.id);
    expect(shift.startTime, const Duration(hours: 19, minutes: 30));
  });
}

class _EmployeeRepository implements EmployeeRepository {
  const _EmployeeRepository(this.employees);

  final List<Employee> employees;

  @override
  Future<Result<void>> delete(String id) async => const Success(null);

  @override
  Future<Result<List<Employee>>> findAll({bool activeOnly = true}) async =>
      Success(
        employees
            .where((employee) => !activeOnly || employee.active)
            .toList(growable: false),
      );

  @override
  Future<Result<Employee?>> findById(String id) async => Success(
    employees.where((employee) => employee.id == id).firstOrNull,
  );

  @override
  Future<Result<Employee>> save(Employee employee) async => Success(employee);

  @override
  Future<Result<List<Employee>>> saveAll(List<Employee> employees) async =>
      Success(employees);

  @override
  Future<Result<List<Employee>>> search(String query) async => Success(
    employees.where((employee) => employee.matches(query)).toList(),
  );
}

class _ShiftTemplateRepository implements ShiftTemplateRepository {
  _ShiftTemplateRepository(this.templates);

  final List<ShiftTemplate> templates;

  @override
  Future<Result<void>> delete(String id) async => const Success(null);

  @override
  Future<Result<List<ShiftTemplate>>> findAll({
    bool activeOnly = true,
  }) async => Success(
    templates
        .where((template) => !activeOnly || template.active)
        .toList(growable: false),
  );

  @override
  Future<Result<ShiftTemplate?>> findById(String id) async => Success(
    templates.where((template) => template.id == id).firstOrNull,
  );

  @override
  Future<Result<ShiftTemplate>> save(ShiftTemplate template) async =>
      Success(template);
}



ImportFile _workbookWithInvalidRow() {
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', 'Roster');
  workbook['Roster']
    ..appendRow([
      TextCellValue('Date'),
      TextCellValue('Shift'),
      TextCellValue('Employee'),
      TextCellValue('Department'),
    ])
    ..appendRow([
      TextCellValue('2026-07-24'),
      TextCellValue('XN'),
      TextCellValue('Anan Sukjai'),
      TextCellValue('ER'),
    ])
    ..appendRow([
      TextCellValue('not-a-date'),
      TextCellValue('XN'),
      TextCellValue('Anan Sukjai'),
      TextCellValue('ER'),
    ])
    ..appendRow([
      TextCellValue('also-not-a-date'),
      TextCellValue('XN'),
      TextCellValue('Anan Sukjai'),
      TextCellValue('ER'),
    ]);
  return ImportFile(
    name: 'shift-template-review.xlsx',
    bytes: Uint8List.fromList(workbook.encode()!),
  );
}

