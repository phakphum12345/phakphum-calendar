import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/shift_template.dart';
import 'package:phakphum_calendar/features/excel_import/application/import_staging_applier.dart';
import 'package:phakphum_calendar/features/excel_import/application/import_staging_planner.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_staging_plan.dart';
import 'package:phakphum_calendar/features/excel_import/domain/shift_record.dart';
import 'package:phakphum_calendar/features/schedule/data/shared_preferences_schedule_repository.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_conversion_diagnostics.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/normalized_cell.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/shift_parser_input.dart';
import 'package:phakphum_calendar/features/workflow/application/canonical_schedule_event_mapper.dart';
import 'package:phakphum_calendar/features/workflow/application/workflow_preview_builder.dart';

import 'support/in_memory_schedule_store.dart';

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
  const employee = Employee(
    id: 'employee-anan',
    employeeCode: 'E001',
    firstName: 'Anan',
    lastName: 'Test',
    nickname: 'Nan',
    department: Department(id: 'er', code: 'ER', name: 'Emergency'),
    position: 'Nurse',
  );

  test(
    'date-first roster import reaches persisted canonical Calendar preview without provider writes',
    () async {
      final input = _crossMonthRoster();
      const parser = MonthlyRosterSectionParser();
      final structure = parser.generateDateStructure(input);

      // Phase one resolves the full date grid before reading any staff names.
      expect(structure.sections, hasLength(1));
      expect(structure.sections.single.dateColumns.map((item) => item.date), [
        DateTime(2026, 7, 16),
        DateTime(2026, 7, 17),
        DateTime(2026, 7, 31),
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 15),
      ]);

      final report = parser.populateAssignments(input, structure);
      expect(report.warnings, isEmpty);
      expect(report.assignments, hasLength(5));
      expect(report.assignments.every((item) => item.workerName == 'Anan Test'), isTrue);

      final conversion = const MonthlyRosterShiftAdapter()
          .parseForWorkersWithDiagnostics(
            report,
            targetNames: const ['Anan Test'],
            shiftTemplates: const [template],
          );
      expect(conversion.convertedCount, 5);
      expect(conversion.unconvertedCount, 0);
      expect(conversion.shifts.map((shift) => shift.cell), [
        'B3',
        'C3',
        'D3',
        'E3',
        'F3',
      ]);
      expect(
        conversion.shifts.every(
          (shift) =>
              shift.sourceSpreadsheetId == 'synthetic-roster-source' &&
              shift.sourceSheetId == 42,
        ),
        isTrue,
      );

      final records = [
        for (var index = 0; index < conversion.shifts.length; index++)
          ShiftRecord(
            date: DateTime(
              conversion.shifts[index].start.year,
              conversion.shifts[index].start.month,
              conversion.shifts[index].start.day,
            ),
            shift: conversion.shifts[index].code,
            employee: conversion.shifts[index].assignedName,
            rowNumber: index + 2,
            resolvedEmployee: employee,
            resolvedShiftTemplate: template,
          ),
      ];
      final original = Schedule(
        id: 'imported',
        name: 'Existing canonical roster',
      );
      final store = InMemoryScheduleKeyValueStore();
      final repository = SharedPreferencesScheduleRepository(store: store);
      final absent = await repository.findById(original.id);
      expect(absent, isA<Success<Schedule?>>());
      expect((absent as Success<Schedule?>).value, isNull);
      final absentRevision = repository.revisionForAbsentSchedule(original.id);
      expect(absentRevision, isNotNull);
      expect(
        await repository.saveIfRevision(original, absentRevision!),
        isA<Success<Schedule>>(),
      );

      const planner = ImportStagingPlanner();
      const applier = ImportStagingApplier();
      final beforeSave = await repository.findById(original.id);
      final snapshot = (beforeSave as Success<Schedule?>).value!;
      final snapshotRevision = repository.revisionForSnapshot(snapshot);
      expect(snapshotRevision, isNotNull);
      final plan = planner.plan(existingSchedule: snapshot, records: records);
      expect(
        plan.entries.map((entry) => entry.action),
        everyElement(ImportRowAction.create),
      );

      final selectedRows = records.map((record) => record.rowNumber).toSet();
      final staged = applier.apply(
        existingSchedule: snapshot,
        plan: plan,
        includedRowNumbers: selectedRows,
      );
      expect(
        await repository.saveIfRevision(staged, snapshotRevision!),
        isA<Success<Schedule>>(),
      );

      final afterSave = await repository.findById(original.id);
      final persisted = (afterSave as Success<Schedule?>).value!;
      final repeatedPlan = planner.plan(
        existingSchedule: persisted,
        records: records,
      );
      expect(
        repeatedPlan.entries.map((entry) => entry.action),
        everyElement(ImportRowAction.skip),
      );
      final repeated = applier.apply(
        existingSchedule: persisted,
        plan: repeatedPlan,
        includedRowNumbers: const {},
      );
      expect(
        repeated.months
            .expand((month) => month.days)
            .expand((day) => day.assignments),
        hasLength(5),
      );

      final candidates = const CanonicalScheduleEventMapper().map(persisted);
      expect(candidates, hasLength(5));
      expect(candidates.map((event) => event.start), [
        DateTime(2026, 7, 16, 19, 30),
        DateTime(2026, 7, 17, 19, 30),
        DateTime(2026, 7, 31, 19, 30),
        DateTime(2026, 8, 1, 19, 30),
        DateTime(2026, 8, 15, 19, 30),
      ]);
      expect(
        candidates.every(
          (event) => event.end == event.start.add(const Duration(hours: 12)),
        ),
        isTrue,
      );

      // Calendar preview is a pure diff. This test has no provider gateway.
      final preview = const WorkflowPreviewBuilder().buildCandidates(
        desired: candidates,
        existing: const [],
      );
      expect(preview.diff.toAdd, candidates);
      expect(preview.diff.toUpdate, isEmpty);
      expect(preview.diff.toDelete, isEmpty);
      expect(preview.simulation.summary.canSynchronize, isTrue);
      expect(store.values, isNotEmpty);
    },
  );
}

ShiftParserInput _crossMonthRoster() {
  final rows = <List<Object?>>[
    ['เวรประจำเดือน 16 กรกฎาคม พ.ศ. 2569 - 15 สิงหาคม พ.ศ. 2569'],
    ['วันที่', 16, 17, 31, 1, 15],
    ['XN', 'Anan Test', 'Anan Test', 'Anan Test', 'Anan Test', 'Anan Test'],
  ];
  final cells = <NormalizedCell>[];
  for (var row = 0; row < rows.length; row++) {
    for (var column = 0; column < rows[row].length; column++) {
      final value = rows[row][column];
      if (value == null) continue;
      cells.add(
        NormalizedCell(
          sheetId: 42,
          sheetTitle: 'Roster tab has misleading month',
          a1: '',
          rowIndex: row,
          columnIndex: column,
          text: value is String ? value : null,
          rawValue: value is num ? value : null,
        ),
      );
    }
  }
  return ShiftParserInput(
    spreadsheetId: 'synthetic-roster-source',
    spreadsheetTitle: 'Synthetic cross-month roster',
    sheetId: 42,
    sheetTitle: 'ธันวาคม 2569',
    timeZone: 'Asia/Bangkok',
    cells: cells,
  );
}
