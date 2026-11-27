import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/result/result.dart';
import '../../../domain/entities/employee.dart';
import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/shift_template.dart';
import '../../../domain/repositories/schedule_repository.dart';
import '../../../domain/repositories/conditional_schedule_writer.dart';
import '../../../domain/repositories/schedule_revision_source.dart';
import '../../excel_import/domain/workbook_info.dart';
import '../../schedule/data/schedule_json_codec.dart';
import '../data/backend_grid_roster_import_journal_gateway.dart';
import '../data/grid_roster_bundle_journal.dart';
import 'grid_roster_workbook_scanner.dart';
import '../domain/monthly_roster_section.dart';
import 'grid_roster_canonical_converter.dart';
import 'grid_roster_review_session.dart';

/// A review session bound to the exact Schedule revision loaded for review.
class GridRosterImportReviewContext {
  const GridRosterImportReviewContext({
    required this.session,
    required this.targetSchedule,
    required this.targetExisted,
  });

  final GridRosterReviewSession session;
  final Schedule targetSchedule;
  final bool targetExisted;

  String get targetScheduleRevision => session.targetScheduleRevision;
}

/// Coordinates the local XLSX scan → review → canonical conversion →
/// journal commit → canonical repository save flow.
///
/// Calendar synchronization is deliberately not part of this service.
class GridRosterImportWorkflow {
  GridRosterImportWorkflow({
    required this._scheduleRepository,
    required this._journal,
    this.remoteJournalGateway,
    this.workbookScanner = const GridRosterWorkbookScanner(),
    this.reviewSessionBuilder = const GridRosterReviewSessionBuilder(),
    this.canonicalConverter = const GridRosterCanonicalConverter(),
    this.scheduleCodec = const ScheduleJsonCodec(),
  });

  final ScheduleRepository _scheduleRepository;
  final GridRosterBundleJournal _journal;
  final GridRosterImportJournalGateway? remoteJournalGateway;
  final GridRosterWorkbookScanner workbookScanner;
  final GridRosterReviewSessionBuilder reviewSessionBuilder;
  final GridRosterCanonicalConverter canonicalConverter;
  final ScheduleJsonCodec scheduleCodec;

  MonthlyRosterParseReport scanWorkbook({
    required WorkbookInfo workbook,
    required GridRosterWorksheetRowsReader readWorksheet,
  }) {
    return workbookScanner.scan(
      workbook: workbook,
      readWorksheet: readWorksheet,
    );
  }

  /// Loads the current target from the canonical repository before review.
  /// A missing target is represented as an empty Schedule plus an explicit
  /// absent-revision token, not as a guessed existing revision.
  Future<Result<GridRosterImportReviewContext>> prepareReview({
    required MonthlyRosterParseReport report,
    required String targetScheduleId,
    required String targetScheduleName,
    required Iterable<Employee> employees,
    required Iterable<ShiftTemplate> shiftTemplates,
  }) async {
    final sourceFingerprint = report.sourceFingerprint;
    if (report.sections.isEmpty) {
      return const ValidationFailure(
        'Workbook scan produced no Grid sections to review.',
      );
    }
    if (sourceFingerprint == null || sourceFingerprint.trim().isEmpty) {
      return const ValidationFailure(
        'Parsed workbook is missing its source fingerprint.',
      );
    }
    if (targetScheduleId.trim().isEmpty || targetScheduleName.trim().isEmpty) {
      return const ValidationFailure(
        'Target Schedule id and name are required.',
      );
    }

    final loaded = await _scheduleRepository.findById(targetScheduleId);
    if (loaded case Failure<Schedule?>()) {
      return _copyFailure<Schedule?, GridRosterImportReviewContext>(loaded);
    }
    final existing = (loaded as Success<Schedule?>).value;
    if (existing != null && existing.id != targetScheduleId) {
      return const ValidationFailure(
        'Schedule repository returned a different target identity.',
      );
    }
    final target = existing ??
        Schedule(id: targetScheduleId, name: targetScheduleName);
    final revision = revisionFor(existing, targetScheduleId);
    try {
      final session = reviewSessionBuilder.build(
        report: report,
        employees: employees,
        shiftTemplates: shiftTemplates,
        sourceFingerprint: sourceFingerprint,
        targetScheduleId: targetScheduleId,
        targetScheduleRevision: revision,
      );
      return Success(
        GridRosterImportReviewContext(
          session: session,
          targetSchedule: target,
          targetExisted: existing != null,
        ),
      );
    } on Object catch (error, stackTrace) {
      return ValidationFailure(
        'Could not create the Grid review session.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Builds the canonical candidate from explicit per-assignment decisions.
  Result<GridRosterCanonicalConversionResult> convert({
    required GridRosterImportReviewContext context,
    required Iterable<Employee> employees,
    required Iterable<ShiftTemplate> shiftTemplates,
    required Map<String, GridRosterAssignmentDecision> decisions,
    required String importRunId,
    required String parserVersion,
    required DateTime createdAtUtc,
  }) {
    try {
      return Success(
        canonicalConverter.convert(
          session: context.session,
          targetSchedule: context.targetSchedule,
          employees: employees,
          shiftTemplates: shiftTemplates,
          decisions: decisions,
          importRunId: importRunId,
          parserVersion: parserVersion,
          createdAtUtc: createdAtUtc,
        ),
      );
    } on Object catch (error, stackTrace) {
      return ValidationFailure(
        'Grid review could not be converted into a canonical Schedule.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Re-reads the live target revision, journals the accepted bundle, then
  /// saves the canonical Schedule through the existing repository API.
  ///
  /// If repository save fails after the journal commit, recover() can replay
  /// the committed Schedule only when the live repository is still at the
  /// original target revision. Repositories implementing
  /// ConditionalScheduleWriter receive that exact caller-owned revision at
  /// the write boundary. The built-in local repository serializes conditional
  /// writes within this process; custom repositories without the capability
  /// retain a best-effort read/save fallback.
  Future<Result<Schedule>> commit({
    required GridRosterImportReviewContext context,
    required GridRosterCanonicalConversionResult conversion,
  }) async {
    if (conversion.schedule.id != context.session.targetScheduleId ||
        conversion.preparedProvenance.targetScheduleId !=
            context.session.targetScheduleId ||
        conversion.preparedProvenance.sourceFingerprint !=
            context.session.sourceFingerprint ||
        conversion.preparedProvenance.targetScheduleRevision !=
            context.targetScheduleRevision) {
      return const ValidationFailure(
        'Conversion result does not match the prepared target revision.',
      );
    }

    final liveResult = await _scheduleRepository.findById(
      context.session.targetScheduleId,
    );
    if (liveResult case Failure<Schedule?>()) {
      return _copyFailure<Schedule?, Schedule>(liveResult);
    }
    final live = (liveResult as Success<Schedule?>).value;
    final liveRevision = revisionFor(live, context.session.targetScheduleId);
    if (liveRevision != context.targetScheduleRevision) {
      return const ValidationFailure(
        'Target Schedule changed after review. Reload and review again.',
      );
    }
    if (live != null &&
        scheduleCodec.encode(live) != scheduleCodec.encode(context.targetSchedule)) {
      return const ValidationFailure(
        'Loaded Schedule content no longer matches the review snapshot.',
      );
    }

    final acceptedFingerprint = scheduleFingerprint(conversion.schedule);
    final committedProvenance = conversion.committedProvenance(
      acceptedScheduleFingerprint: acceptedFingerprint,
    );
    try {
      await remoteJournalGateway?.appendPrepared(
        scheduleId: conversion.schedule.id,
        provenance: conversion.preparedProvenance,
      );
      final journalled = await _journal.commit(
        schedule: conversion.schedule,
        preparedProvenance: conversion.preparedProvenance,
        committedProvenance: committedProvenance,
        currentTargetRevision: liveRevision,
      );
      await remoteJournalGateway?.appendCommitted(
        schedule: journalled.schedule,
        provenance: committedProvenance,
      );
      final beforeSaveResult = await _scheduleRepository.findById(
        context.session.targetScheduleId,
      );
      if (beforeSaveResult case Failure<Schedule?>()) {
        return _copyFailure<Schedule?, Schedule>(beforeSaveResult);
      }
      final beforeSave =
          (beforeSaveResult as Success<Schedule?>).value;
      if (revisionFor(beforeSave, context.session.targetScheduleId) !=
          liveRevision) {
        return const ValidationFailure(
          'Target Schedule changed while the bundle was being committed. '
          'The journal is retained for conflict-aware recovery.',
        );
      }
      return await _saveWithRevision(journalled.schedule, liveRevision);
    } on Object catch (error, stackTrace) {
      return PersistenceFailure(
        'The Grid bundle could not be committed or saved. '
        'If the journal reached COMMITTED, run recovery before retrying.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Discovers Schedule IDs with local or account-owned remote import journals.
  ///
  /// Discovery never replays a journal. Each returned ID must be presented for
  /// explicit review and passed to [recover] only after the user selects it.
  Future<List<String>> discoverRecoveryScheduleIds() async {
    final localIds = await _journal.discoverScheduleIds();
    final remoteIds = await remoteJournalGateway?.discoverScheduleIds() ??
        const <String>[];
    return {...localIds, ...remoteIds}.toList()..sort();
  }

  /// Replays a committed journal bundle only if the canonical repository is
  /// still at the exact base revision recorded by that import.
  Future<Result<Schedule?>> recover(String scheduleId) async {
    final liveResult = await _scheduleRepository.findById(scheduleId);
    if (liveResult case Failure<Schedule?>()) return liveResult;
    final live = (liveResult as Success<Schedule?>).value;

    try {
      final localSnapshot = await _journal.recover(scheduleId);
      final remoteSnapshot = await remoteJournalGateway?.recover(scheduleId);
      final snapshot = _newerJournalSnapshot(localSnapshot, remoteSnapshot);
      if (snapshot == null) return Success(live);

      final acceptedFingerprint =
          snapshot.provenance.acceptedScheduleFingerprint;
      if (acceptedFingerprint == null) {
        return const ValidationFailure(
          'Committed journal is missing its accepted Schedule fingerprint.',
        );
      }
      if (live != null &&
          scheduleFingerprint(live) == acceptedFingerprint) {
        return Success(live);
      }

      final liveRevision = revisionFor(live, scheduleId);
      if (liveRevision != snapshot.provenance.targetScheduleRevision) {
        return const ValidationFailure(
          'Recovery conflict: canonical Schedule changed after the journal base revision.',
        );
      }

      final beforeRecoverySave = await _scheduleRepository.findById(scheduleId);
      if (beforeRecoverySave case Failure<Schedule?>()) {
        return beforeRecoverySave;
      }
      final latest = (beforeRecoverySave as Success<Schedule?>).value;
      if (revisionFor(latest, scheduleId) != snapshot.provenance.targetScheduleRevision) {
        if (latest != null &&
            scheduleFingerprint(latest) == acceptedFingerprint) {
          return Success(latest);
        }
        return const ValidationFailure(
          'Recovery target changed during replay. No Schedule was overwritten.',
        );
      }
      final saved = await _saveWithRevision(
        snapshot.schedule,
        snapshot.provenance.targetScheduleRevision,
      );
      return switch (saved) {
        Success<Schedule>(value: final schedule) => Success(schedule),
        Failure<Schedule>() => _copyFailure<Schedule, Schedule?>(saved),
      };
    } on Object catch (error, stackTrace) {
      return ValidationFailure(
        'Could not recover the Grid import bundle.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Result<Schedule>> _saveWithRevision(
    Schedule schedule,
    String expectedRevision,
  ) {
    final repository = _scheduleRepository;
    if (repository is ConditionalScheduleWriter) {
      return (repository as ConditionalScheduleWriter)
          .saveIfRevision(schedule, expectedRevision);
    }
    return repository.save(schedule);
  }

  String scheduleFingerprint(Schedule schedule) =>
      'sha256:${sha256.convert(utf8.encode(scheduleCodec.encode(schedule)))}';

  String revisionFor(Schedule? schedule, String scheduleId) {
    final source = _scheduleRepository;
    final revisionSource = source is ScheduleRevisionSource
        ? source as ScheduleRevisionSource
        : null;
    final authoritative = revisionSource == null
        ? null
        : schedule == null
        ? revisionSource.revisionForAbsentSchedule(scheduleId)
        : revisionSource.revisionForSnapshot(schedule);
    if (authoritative != null) return authoritative;
    return schedule == null ? 'absent:$scheduleId' : scheduleFingerprint(schedule);
  }

}

GridRosterBundleJournalSnapshot? _newerJournalSnapshot(
  GridRosterBundleJournalSnapshot? local,
  GridRosterBundleJournalSnapshot? remote,
) {
  if (local == null) return remote;
  if (remote == null) return local;
  final localTime = local.journaledAtUtc ?? local.provenance.createdAtUtc;
  final remoteTime = remote.journaledAtUtc ?? remote.provenance.createdAtUtc;
  return remoteTime.isAfter(localTime) ? remote : local;
}

Result<TTarget> _copyFailure<TSource, TTarget>(Result<TSource> result) {
  final failure = result as Failure<TSource>;
  return switch (failure) {
    ValidationFailure<TSource>() => ValidationFailure(
      failure.message,
      fieldErrors: failure.fieldErrors,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
    NetworkFailure<TSource>() => NetworkFailure(
      failure.message,
      statusCode: failure.statusCode,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
    ImportFailure<TSource>() => ImportFailure(
      failure.message,
      rowNumber: failure.rowNumber,
      column: failure.column,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
    PersistenceFailure<TSource>() => PersistenceFailure(
      failure.message,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
  };
}
