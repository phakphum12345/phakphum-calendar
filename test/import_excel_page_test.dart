import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/di/app_dependencies.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/features/excel_import/data/excel_reader_service.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_file.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/controllers/column_mapping_controller.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/controllers/excel_import_controller.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/pages/column_mapping_page.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/pages/import_excel_page.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/pages/import_summary_page.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/widgets/excel_preview_table.dart';
import 'package:phakphum_calendar/features/schedule/data/shared_preferences_schedule_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/in_memory_schedule_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('loads a workbook and lets the user choose a worksheet', (
    tester,
  ) async {
    final controller = ExcelImportController(
      reader: ExcelReaderService(filePicker: () async => _workbookFile()),
    );
    final mappingController = ColumnMappingController();
    final dependencies = AppDependencies(
      scheduleRepository: SharedPreferencesScheduleRepository(
        store: InMemoryScheduleKeyValueStore(),
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(mappingController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ImportExcelPage(
          controller: controller,
          mappingController: mappingController,
          importedScheduleFactory: dependencies.createImportedSchedule,
          scheduleControllerFactory:
              dependencies.createImportedScheduleController,
          scheduleSaver: dependencies.saveImportedSchedule,
        ),
      ),
    );

    expect(find.text('ยังไม่ได้เลือกไฟล์ Excel'), findsOneWidget);
    expect(find.text('Select Excel File'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Choose from Google Drive'), findsOneWidget);

    await tester.tap(find.text('Select Excel File'));
    await tester.pumpAndSettle();

    expect(find.text('roster.xlsx'), findsOneWidget);
    expect(find.text('Roster'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.textContaining('2 Worksheet'), findsOneWidget);

    await tester.tap(find.text('Roster'));
    await tester.pumpAndSettle();

    expect(find.textContaining('อ่าน "Roster" แล้ว 2 แถว'), findsOneWidget);
    expect(find.byType(ExcelPreviewTable), findsOneWidget);
    expect(find.text('Next: Column Mapping'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    await tester.ensureVisible(find.text('Next: Column Mapping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next: Column Mapping'));
    await tester.pumpAndSettle();

    expect(find.byType(ColumnMappingPage), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(6));

    mappingController.updateMapping(DestinationField.date, 'A');
    mappingController.updateMapping(DestinationField.shift, 'B');
    mappingController.updateMapping(DestinationField.employee, 'C');
    await tester.pump();

    await tester.ensureVisible(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.byType(ImportSummaryPage), findsOneWidget);
    expect(
      find.text('1 Shift Records created from 1 data rows.'),
      findsOneWidget,
    );
    final beforeConfirmation = await dependencies.scheduleRepository.findById(
      'imported',
    );
    expect(beforeConfirmation, isA<Success<Schedule?>>());
    expect((beforeConfirmation as Success<Schedule?>).value, isNull);

    await tester.tap(find.text('ยืนยันและบันทึกตารางเวร'));
    await tester.pumpAndSettle();
    expect(find.text('บันทึกแล้ว'), findsOneWidget);

    final persisted = await dependencies.scheduleRepository.findById(
      'imported',
    );
    expect(persisted, isA<Success<Schedule?>>());
    expect((persisted as Success<Schedule?>).value!.months, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

ImportFile _workbookFile() {
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', 'Roster');
  workbook['Roster']
    ..appendRow([
      TextCellValue('Date'),
      TextCellValue('Shift'),
      TextCellValue('Employee'),
    ])
    ..appendRow([
      TextCellValue('2026-07-24'),
      TextCellValue('Morning'),
      TextCellValue('Anan'),
    ]);
  workbook['Summary'].appendRow([TextCellValue('Total')]);

  return ImportFile(
    name: 'roster.xlsx',
    bytes: Uint8List.fromList(workbook.encode()!),
  );
}
