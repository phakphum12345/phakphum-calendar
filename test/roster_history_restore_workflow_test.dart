import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/repositories/conditional_schedule_writer.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_repository.dart';
import 'package:phakphum_calendar/features/schedule/data/shared_preferences_schedule_repository.dart' show ScheduleKeyValueStore, ScheduleKeyEnumerator;
import 'package:phakphum_calendar/domain/repositories/schedule_revision_source.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_canonical_converter.dart';
import 'package:phakphum_calendar/features/shift_parser/application/grid_roster_import_workflow.dart';
import 'package:phakphum_calendar/features/shift_parser/data/grid_roster_bundle_journal.dart';
import 'package:phakphum_calendar/features/history/application/roster_history_restore_workflow.dart';
import 'package:phakphum_calendar/models/shift.dart' show SheetSnapshot;
import 'package:phakphum_calendar/services/roster_revision_service.dart';

class _MemoryStore implements ScheduleKeyValueStore, ScheduleKeyEnumerator {
  final values = <String, String>{};

  @override
  Future<Set<String>> getKeys() async => values.keys.toSet();

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

class _MemoryScheduleRepository
    implements ScheduleRepository, ScheduleRevisionSource, ConditionalScheduleWriter {
  Schedule? value;
  int generation = 0;

  @override
  String? currentRevisionFor(String scheduleId) =>
      value == null ? 'absent:$scheduleId' : 'revision-$generation';

  @override
  String? revisionForSnapshot(Schedule schedule) =>
      value != null && value!.id == schedule.id ? 'revision-$generation' : null;

  @override
  String? revisionForAbsentSchedule(String scheduleId) =>
      value == null ? 'absent:$scheduleId' : null;

  @override
  Future<Result<Schedule?>> findById(String id) async => Success(value);

  @override
  Future<Result<Schedule>> saveIfRevision(
    Schedule schedule,
    String expectedRevision,
  ) async {
    if (currentRevisionFor(schedule.id) != expectedRevision) {
      return const ValidationFailure('revision conflict');
    }
    return save(schedule);
  }

  @override
  Future<Result<ScheduleMonth?>> loadMonth(
    String scheduleId,
    DateTime month,
  ) async =>
      Success(value?.month(month));

  @override
  Future<Result<Schedule>> save(Schedule schedule) async {
    value = schedule;
    generation++;
    return Success(schedule);
  }

  @override
  Future<Result<void>> delete(String id) async {
    value = null;
    generation++;
    return const Success(null);
  }
}

void main() {
  test('restores a Drive revision through review and conditional Schedule commit', () async {
    final repository = _MemoryScheduleRepository();
    final gridWorkflow = GridRosterImportWorkflow(
      scheduleRepository: repository,
      journal: GridRosterBundleJournal(store: _MemoryStore()),
    );
    final workflow = RosterHistoryRestoreWorkflow(
      gridImportWorkflow: gridWorkflow,
    );
    final revision = _revision('drive-revision-17');
    final employee = Employee(
      id: 'employee-a',
      employeeCode: 'A001',
      firstName: 'Staff',
      lastName: 'One',
      nickname: 'A',
      department: const Department(
        id: 'department-a',
        code: 'GEN',
        name: 'General',
      ),
      position: 'Doctor',
    );

    final report = workflow.scanRevision(revision, timeZone: 'Asia/Bangkok');
    expect(report.sourceFingerprint, startsWith('sha256:'));
    expect(report.assignments, hasLength(7));

    final reviewResult = await workflow.prepareReview(
      revision: revision,
      targetScheduleId: 'schedule-1',
      targetScheduleName: 'Restored November roster',
      employees: [employee],
      shiftTemplates: const [],
      timeZone: 'Asia/Bangkok',
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
          employeeId: employee.id,
          reviewerId: 'history-reviewer',
          reviewedAtUtc: DateTime.utc(2026, 11, 27, 8),
        ),
    };

    final conversionResult = workflow.convert(
      context: context,
      employees: [employee],
      shiftTemplates: const [],
      decisions: decisions,
      importRunId: 'restore-drive-revision-17',
      parserVersion: 'history-restore/1',
      createdAtUtc: DateTime.utc(2026, 11, 27, 8),
    );
    expect(conversionResult, isA<Success<GridRosterCanonicalConversionResult>>());
    final conversion =
        (conversionResult as Success<GridRosterCanonicalConversionResult>).value;
    expect(
      conversion.preparedProvenance.sourceRevisionId,
      'drive-revision-17',
    );

    final committed = await workflow.commit(
      context: context,
      conversion: conversion,
    );

    expect(committed, isA<Success<Schedule>>());
    expect(repository.value?.id, 'schedule-1');
    expect(
      repository.value!.month(DateTime(2026, 11, 1))!
          .day(DateTime(2026, 11, 7))!
          .assignments,
      hasLength(1),
    );
  });

  test('binds the history source fingerprint to the exact Drive revision', () {
    final workflow = RosterHistoryRestoreWorkflow(
      gridImportWorkflow: _UnusedGridWorkflow(),
    );
    final first = workflow.scanRevision(_revision('revision-a'));
    final second = workflow.scanRevision(_revision('revision-b'));
    expect(first.sourceFingerprint, isNot(second.sourceFingerprint));
  });
}

RosterRevisionDocument _revision(String revisionId) => RosterRevisionDocument(
  revisionId: revisionId,
  modifiedAt: DateTime.utc(2026, 11, 1),
  snapshots: [
    SheetSnapshot(
      title: 'November',
      spreadsheetId: null,
      sheetId: 0,
      hidden: false,
      rows: const [
        ['เวรประจำเดือน พฤศจิกายน พ.ศ. 2569'],
        ['วันที่', '1', '2', '3', '4', '5', '6', '7'],
        ['เวรเช้า', 'Staff A', 'Staff A', 'Staff A', 'Staff A', 'Staff A', 'Staff A', 'Staff A'],
      ],
      backgroundColors: const [],
    ),
  ],
);

class _UnusedGridWorkflow extends GridRosterImportWorkflow {
  _UnusedGridWorkflow()
      : super(
          scheduleRepository: _MemoryScheduleRepository(),
          journal: GridRosterBundleJournal(store: _MemoryStore()),
        );
}
