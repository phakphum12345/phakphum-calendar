import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/di/app_dependencies.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/features/diff_engine/domain/calendar_event_candidate.dart';
import 'package:phakphum_calendar/features/excel_import/data/excel_reader_service.dart';
import 'package:phakphum_calendar/features/excel_import/domain/column_mapping.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_file.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/controllers/excel_import_controller.dart';
import 'package:phakphum_calendar/features/schedule/data/shared_preferences_schedule_repository.dart';
import 'package:phakphum_calendar/features/workflow/application/workflow_preview_builder.dart';
import 'package:phakphum_calendar/models/shift.dart';
import 'package:phakphum_calendar/services/calendar_service.dart';

import 'support/in_memory_schedule_store.dart';

void main() {
  test(
    'import, review correction, preview, and explicit local confirmation stay in one flow',
    () async {
      final importer = ExcelImportController(
        reader: ExcelReaderService(
          filePicker: () async => _workbookWithInvalidDate(),
        ),
      );
      addTearDown(importer.dispose);

      await importer.pickFile();
      await importer.selectWorksheet(importer.workbook!.worksheets.single);
      const mapping = ColumnMapping(
        dateColumn: 'A',
        shiftColumn: 'B',
        employeeColumn: 'C',
        departmentColumn: 'D',
      );
      await importer.importRows(mapping);

      // Review: the invalid source value is visible and is not imported silently.
      expect(importer.importSummary?.errorRows, 1);
      expect(importer.shiftRecords, isEmpty);
      expect(importer.valueAt(rowNumber: 2, column: 'A'), 'not-a-date');

      // Correct the in-memory review value and explicitly reprocess the import.
      expect(
        importer.updateCellValue(
          rowNumber: 2,
          column: 'A',
          value: '2026-07-24',
        ),
        isTrue,
      );
      expect(importer.reprocessImport(), isTrue);
      expect(importer.importSummary?.errorRows, 0);
      expect(importer.importSummary?.importedRows, 1);
      final record = importer.shiftRecords.single;
      expect(record.date, DateTime(2026, 7, 24));
      expect(record.employee, 'Anan');

      // Preview is a pure comparison; it does not call a Calendar sync gateway.
      final shift = Shift(
        code: record.shift,
        rowLabel: record.shift,
        assignedName: record.employee,
        start: DateTime(2026, 7, 24, 8),
        end: DateTime(2026, 7, 24, 16),
        sheetTitle: 'Roster',
        cell: 'B2',
        category: ShiftCategory.own,
      );
      final desired = CalendarEventCandidate(
        syncId: CalendarService.keyFor(shift),
        title: CalendarService.summaryFor(shift),
        start: shift.start,
        end: shift.end,
        description: CalendarService.descriptionFor(shift),
        colorId: shift.effectiveCalendarColorId,
        shouldExist: true,
      );
      final preview = const WorkflowPreviewBuilder().buildCandidates(
        desired: [desired],
        existing: const [],
      );
      expect(preview.diff.toAdd, [desired]);
      expect(preview.diff.toUpdate, isEmpty);
      expect(preview.diff.toDelete, isEmpty);
      expect(preview.simulation.summary.canSynchronize, isTrue);

      // Confirm here means an explicit local schedule save only.
      // Google Calendar writes remain outside this test and require a separate
      // user-confirmed synchronization action.
      final dependencies = AppDependencies(
        scheduleRepository: SharedPreferencesScheduleRepository(
          store: InMemoryScheduleKeyValueStore(),
        ),
      );
      final schedule = dependencies.createImportedSchedule(
        importer.shiftRecords,
      );
      final saved = await dependencies.saveImportedSchedule(schedule);
      expect(saved.isSuccess, isTrue);

      final restored = dependencies.createImportedScheduleController(
        Schedule(id: 'temporary', name: 'Temporary'),
      );
      addTearDown(restored.dispose);
      final loaded = await restored.loadPersistedSchedule();
      expect(loaded.isSuccess, isTrue);
      expect(restored.canonicalSchedule.id, 'imported');
      final assignment = restored.schedule
          .day(DateTime(2026, 7, 24))!
          .assignments
          .single;
      expect(assignment.employee.firstName, 'Anan');
      expect(assignment.shift.name, 'Morning');
    },
  );
}

ImportFile _workbookWithInvalidDate() {
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
      TextCellValue('not-a-date'),
      TextCellValue('Morning'),
      TextCellValue('Anan'),
      TextCellValue('ER'),
    ]);

  return ImportFile(
    name: 'review-roster.xlsx',
    bytes: Uint8List.fromList(workbook.encode()!),
  );
}
