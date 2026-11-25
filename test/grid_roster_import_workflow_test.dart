import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_repository.dart';
import 'package:phakphum_calendar/features/schedule/data/shared_preferences_schedule_repository.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_canonical_converter.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_import_workflow.dart';
import 'package:phakphum_calendar/features/shift_parser/data/backend_grid_roster_import_journal_gateway.dart';
import 'package:phakphum_calendar/features/shift_parser/data/grid_roster_bundle_journal.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/grid_roster_import_provenance.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';
import 'package:phakphum_calendar/features/excel_import/domain/excel_cell.dart';
import 'package:phakphum_calendar/features/excel_import/domain/excel_row.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_file.dart';
import 'package:phakphum_calendar/features/excel_import/domain/workbook_info.dart';
import 'package:phakphum_calendar/features/excel_import/domain/worksheet_info.dart';

class _MemoryStore implements ScheduleKeyValueStore {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _MemoryScheduleRepository implements ScheduleRepository {
  Schedule? value;
  bool failNextSave = false;

  @override
  Future<Result<Schedule?>> findById(String id) async => Success(value);

  @override
  Future<Result<ScheduleMonth?>> loadMonth(String scheduleId, DateTime month) async =>
      Success(value?.month(month));

  @override
  Future<Result<Schedule>> save(Schedule schedule) async {
    if (failNextSave) {
      failNextSave = false;
      return const PersistenceFailure('simulated schedule repository failure');
    }
    value = schedule;
    return Success(schedule);
  }

  @override
  Future<Result<void>> delete(String id) async {
    value = null;
    return const Success(null);
  }
}

class _MemoryRemoteJournalGateway implements GridRosterImportJournalGateway {
  final calls = <String>[];
  bool failCommitted = false;
  GridRosterBundleJournalSnapshot? recoverySnapshot;

  @override
  Future<void> appendPrepared({
    required String scheduleId,
    required GridRosterImportProvenance provenance,
  }) async {
    calls.add('prepared');
  }

  @override
  Future<void> appendCommitted({
    required Schedule schedule,
    required GridRosterImportProvenance provenance,
  }) async {
    calls.add('committed');
    if (failCommitted) throw StateError('simulated remote journal failure');
  }

  @override
  Future<GridRosterBundleJournalSnapshot?> recover(String scheduleId) async =>
      recoverySnapshot;
}

void main() {
  late _MemoryStore store;
  late _MemoryScheduleRepository repository;
  late GridRosterImportWorkflow workflow;
  final createdAt = DateTime.utc(2026, 11, 24, 12);

  setUp(() {
    store = _MemoryStore();
    repository = _MemoryScheduleRepository();
    workflow = GridRosterImportWorkflow(
      scheduleRepository: repository,
      journal: GridRosterBundleJournal(store: store),
    );
  });

  Future<GridRosterImportReviewContext> prepareContext() async {
    final result = await workflow.prepareReview(
      report: _report(),
      targetScheduleId: 'schedule-1',
      targetScheduleName: 'November roster',
      employees: [_employee],
      shiftTemplates: const [],
    );
    expect(result, isA<Success<GridRosterImportReviewContext>>());
    return (result as Success<GridRosterImportReviewContext>).value;
  }

  GridRosterCanonicalConversionResult convertContext(
    GridRosterImportReviewContext context,
  ) {
    final source = context.session.assignments.single.source;
    final sourceId = GridRosterCanonicalConverter.assignmentId(
      context.session.sourceFingerprint,
      source,
    );
    final result = workflow.convert(
      context: context,
      employees: [_employee],
      shiftTemplates: const [],
      decisions: {
        sourceId: GridRosterAssignmentDecision(
          include: true,
          employeeId: _employee.id,
          reviewerId: 'reviewer-1',
          reviewedAtUtc: createdAt,
        ),
      },
      importRunId: 'workflow-run-1',
      parserVersion: 'grid-parser/1',
      createdAtUtc: createdAt,
    );
    expect(result, isA<Success<GridRosterCanonicalConversionResult>>());
    return (result as Success<GridRosterCanonicalConversionResult>).value;
  }

  test('scans a local workbook through review and canonical commit end-to-end', () async {
    final workbook = WorkbookInfo(
      file: ImportFile(
        name: 'roster.xlsx',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
      worksheets: const [
        WorksheetInfo(name: 'GEN', rowCount: 3, columnCount: 8),
      ],
    );
    final report = workflow.scanWorkbook(
      workbook: workbook,
      readWorksheet: (_) => _validRows(),
    );
    expect(report.sourceFingerprint, startsWith('sha256:'));
    expect(report.assignments, hasLength(7));

    final reviewResult = await workflow.prepareReview(
      report: report,
      targetScheduleId: 'schedule-1',
      targetScheduleName: 'November roster',
      employees: [_employee],
      shiftTemplates: const [],
    );
    expect(reviewResult, isA<Success<GridRosterImportReviewContext>>());
    final context =
        (reviewResult as Success<GridRosterImportReviewContext>).value;
    final decisions = {
      for (final review in context.session.assignments)
        GridRosterCanonicalConverter.assignmentId(
          context.session.sourceFingerprint,
          review.source,
        ): GridRosterAssignmentDecision(
          include: true,
          employeeId: _employee.id,
          reviewerId: 'reviewer-1',
          reviewedAtUtc: createdAt,
        ),
    };
    final conversion = workflow.convert(
      context: context,
      employees: [_employee],
      shiftTemplates: const [],
      decisions: decisions,
      importRunId: 'end-to-end-grid-run',
      parserVersion: 'grid-parser/1',
      createdAtUtc: createdAt,
    );
    expect(conversion, isA<Success<GridRosterCanonicalConversionResult>>());
    final committed = await workflow.commit(
      context: context,
      conversion:
          (conversion as Success<GridRosterCanonicalConversionResult>).value,
    );

    expect(committed, isA<Success<Schedule>>());
    expect(repository.value?.months, hasLength(1));
    expect(repository.value!.month(DateTime(2026, 11, 1))!.days, hasLength(30));
    expect(
      repository.value!.month(DateTime(2026, 11, 1))!
          .day(DateTime(2026, 11, 7))!
          .assignments,
      hasLength(1),
    );
  });

  test('runs review, conversion, journal commit and canonical repository save', () async {
    final context = await prepareContext();
    final conversion = convertContext(context);

    final saved = await workflow.commit(
      context: context,
      conversion: conversion,
    );

    expect(saved, isA<Success<Schedule>>());
    expect(repository.value?.id, 'schedule-1');
    expect(
      repository.value!.month(DateTime(2026, 11, 1))!
          .day(DateTime(2026, 11, 1))!
          .assignments,
      hasLength(1),
    );
    expect(await workflow.recover('schedule-1'), isA<Success<Schedule?>>());
  });

  test('recovery replays committed journal after canonical save failure', () async {
    final context = await prepareContext();
    final conversion = convertContext(context);
    repository.failNextSave = true;

    final commit = await workflow.commit(
      context: context,
      conversion: conversion,
    );
    expect(commit, isA<PersistenceFailure<Schedule>>());
    expect(repository.value, isNull);

    final recovered = await workflow.recover('schedule-1');
    expect(recovered, isA<Success<Schedule?>>());
    expect(repository.value?.id, 'schedule-1');
    expect(
      repository.value!.month(DateTime(2026, 11, 1))!
          .day(DateTime(2026, 11, 1))!
          .assignments,
      hasLength(1),
    );
  });

  test('recovery refuses to overwrite a newer canonical Schedule', () async {
    final context = await prepareContext();
    final conversion = convertContext(context);
    repository.failNextSave = true;

    final commit = await workflow.commit(
      context: context,
      conversion: conversion,
    );
    expect(commit, isA<PersistenceFailure<Schedule>>());
    final newerSchedule = Schedule(
      id: 'schedule-1',
      name: 'Edited by another workflow',
    );
    repository.value = newerSchedule;

    final recovered = await workflow.recover('schedule-1');

    expect(recovered, isA<ValidationFailure<Schedule?>>());
    expect(repository.value, same(newerSchedule));
  });

  test('recovery is idempotent when canonical Schedule already matches journal', () async {
    final context = await prepareContext();
    final conversion = convertContext(context);
    final committed = await workflow.commit(
      context: context,
      conversion: conversion,
    );
    expect(committed, isA<Success<Schedule>>());
    final accepted = repository.value;

    final recovered = await workflow.recover('schedule-1');

    expect(recovered, isA<Success<Schedule?>>());
    expect(repository.value, same(accepted));
  });

  test('persists PREPARED remotely before COMMITTED and canonical save', () async {
    final context = await prepareContext();
    final conversion = convertContext(context);
    final remote = _MemoryRemoteJournalGateway();
    final remoteWorkflow = GridRosterImportWorkflow(
      scheduleRepository: repository,
      journal: GridRosterBundleJournal(store: store),
      remoteJournalGateway: remote,
    );

    final result = await remoteWorkflow.commit(
      context: context,
      conversion: conversion,
    );

    expect(result, isA<Success<Schedule>>());
    expect(remote.calls, ['prepared', 'committed']);
    expect(repository.value?.id, 'schedule-1');
  });

  test('does not save canonical Schedule when remote COMMITTED stage fails', () async {
    final context = await prepareContext();
    final conversion = convertContext(context);
    final remote = _MemoryRemoteJournalGateway()..failCommitted = true;
    final remoteWorkflow = GridRosterImportWorkflow(
      scheduleRepository: repository,
      journal: GridRosterBundleJournal(store: store),
      remoteJournalGateway: remote,
    );

    final result = await remoteWorkflow.commit(
      context: context,
      conversion: conversion,
    );

    expect(result, isA<PersistenceFailure<Schedule>>());
    expect(remote.calls, ['prepared', 'committed']);
    expect(repository.value, isNull);
    expect(await GridRosterBundleJournal(store: store).recover('schedule-1'),
        isNotNull);
  });

  test('recovers a committed remote journal when the local device has no journal', () async {
    final context = await prepareContext();
    final conversion = convertContext(context);
    final acceptedFingerprint = workflow.scheduleFingerprint(conversion.schedule);
    final committedProvenance = conversion.committedProvenance(
      acceptedScheduleFingerprint: acceptedFingerprint,
    );
    final remote = _MemoryRemoteJournalGateway()
      ..recoverySnapshot = GridRosterBundleJournalSnapshot(
        schedule: conversion.schedule,
        provenance: committedProvenance,
        generation: 0,
      );
    final remoteWorkflow = GridRosterImportWorkflow(
      scheduleRepository: repository,
      journal: GridRosterBundleJournal(store: store),
      remoteJournalGateway: remote,
    );

    final recovered = await remoteWorkflow.recover('schedule-1');

    expect(recovered, isA<Success<Schedule?>>());
    expect(repository.value?.id, 'schedule-1');
    expect(repository.value, conversion.schedule);
  });

  test('commit rejects a Schedule changed after the review snapshot', () async {
    final context = await prepareContext();
    final conversion = convertContext(context);
    repository.value = Schedule(id: 'schedule-1', name: 'Changed elsewhere');

    final result = await workflow.commit(
      context: context,
      conversion: conversion,
    );
    expect(result, isA<ValidationFailure<Schedule>>());
    expect(store.values, isEmpty);
  });


}

MonthlyRosterParseReport _report() {
  return MonthlyRosterParseReport(
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
    warnings: const [],
    sourceFingerprint: 'sha256:source-1',
  );
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


List<ExcelRow> _validRows() {
  return [
    ExcelRow(
      index: 0,
      cells: const [
        ExcelCell(
          rowIndex: 0,
          columnIndex: 0,
          value: 'GEN คลินิก 1 พฤศจิกายน 2569 - 7 พฤศจิกายน 2569',
        ),
      ],
    ),
    ExcelRow(
      index: 1,
      cells: [
        const ExcelCell(rowIndex: 1, columnIndex: 0, value: 'วันที่'),
        for (var day = 1; day <= 7; day++)
          ExcelCell(rowIndex: 1, columnIndex: day, value: day),
      ],
    ),
    ExcelRow(
      index: 2,
      cells: [
        const ExcelCell(rowIndex: 2, columnIndex: 0, value: 'GEN'),
        for (var day = 1; day <= 7; day++)
          ExcelCell(
            rowIndex: 2,
            columnIndex: day,
            value: 'Somchai Example',
          ),
      ],
    ),
  ];
}
