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
import 'package:phakphum_calendar/features/shift_parser/data/grid_roster_bundle_journal.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';

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

  test('runs review, conversion, journal commit and canonical repository save', () async {
    final context = await _prepare();
    final conversion = _convert(context);

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
    final context = await _prepare();
    final conversion = _convert(context);
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

  test('commit rejects a Schedule changed after the review snapshot', () async {
    final context = await _prepare();
    final conversion = _convert(context);
    repository.value = Schedule(id: 'schedule-1', name: 'Changed elsewhere');

    final result = await workflow.commit(
      context: context,
      conversion: conversion,
    );
    expect(result, isA<ValidationFailure<Schedule>>());
    expect(store.values, isEmpty);
  });

  Future<GridRosterImportReviewContext> _prepare() async {
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

  GridRosterCanonicalConversionResult _convert(
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
