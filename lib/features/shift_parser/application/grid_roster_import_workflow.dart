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

/// Outcome of inspecting a committed Grid import journal.
enum GridRosterRecoveryDisposition {
  noCommittedBundle,
  ready,
  alreadyApplied,
  conflict,
}

/// Read-only assessment of a journal before any recovery write is attempted.
class GridRosterRecoveryAssessment {
  const GridRosterRecoveryAssessment({
    required this.scheduleId,
    required this.disposition,
    required this.currentSchedule,
    this.candidateSchedule,
    this.expectedRevision,
    this.importRunId,
    this.message,
  });

  final String scheduleId;
  final GridRosterRecoveryDisposition disposition;
  final Schedule? currentSchedule;
  final Schedule? candidateSchedule;
  final String? expectedRevision;
  final String? importRunId;
  final String? message;

  bool get canRecover =>
      disposition == GridRosterRecoveryDisposition.ready;
}

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
    required ScheduleRepository scheduleRepository,
    required GridRosterBundleJournal journal,
    this.remoteJournalGateway,
    this.workbookScanner = const GridRosterWorkbookScanner(),
    this.reviewSessionBuilder = const GridRosterReviewSessionBuilder(),
    this.canonicalConverter = const GridRosterCanonicalConverter(),
    this.scheduleCodec = const ScheduleJsonCodec(),
  }) : _scheduleRepository = scheduleRepository,
       _journal = journal;

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
  Future<List<String>> discoverLocalRecoveryScheduleIds() =>
      _journal.discoverScheduleIds();

  Future<List<String>> discoverRemoteRecoveryScheduleIds() async =>
      await remoteJournalGateway?.discoverScheduleIds() ?? const <String>[];

  Future<List<String>> discoverRecoveryScheduleIds() async {
    final localIds = await discoverLocalRecoveryScheduleIds();
    final remoteIds = await discoverRemoteRecoveryScheduleIds();
    return {...localIds, ...remoteIds}.toList()..sort();
  }

  /// Inspects a journal without mutating canonical Schedule storage.
  ///
  /// A configured remote journal is authoritative for discovery/recovery
  /// failures: network or authorization errors are surfaced, never treated as
  /// an empty journal. The caller must present a [ready] assessment to the
  /// user before calling [recover].
  Future<Result<GridRosterRecoveryAssessment>> inspectRecovery(
    String scheduleId,
  ) async {
    if (scheduleId.trim().isEmpty) {
      return const ValidationFailure('A Schedule ID is required for recovery.');
    }

    final liveResult = await _scheduleRepository.findById(scheduleId);
    if (liveResult case Failure<Schedule?>()) {
      return _copyFailure<Schedule?, GridRosterRecoveryAssessment>(liveResult);
    }
    final live = (liveResult as Success<Schedule?>).value;

    try {
      final localSnapshot = await _journal.recover(scheduleId);
      final remoteSnapshot = await remoteJournalGateway?.recover(scheduleId);
      final snapshot = _newerJournalSnapshot(localSnapshot, remoteSnapshot);
      if (snapshot == null) {
        return Success(
          GridRosterRecoveryAssessment(
            scheduleId: scheduleId,
            disposition: GridRosterRecoveryDisposition.noCommittedBundle,
            currentSchedule: live,
            message: 'No committed import bundle is available.',
          ),
        );
      }

      final acceptedFingerprint =
          snapshot.provenance.acceptedScheduleFingerprint;
      if (acceptedFingerprint == null) {
        return const ValidationFailure(
          'Committed journal is missing its accepted Schedule fingerprint.',
        );
      }
      if (live != null && scheduleFingerprint(live) == acceptedFingerprint) {
        return Success(
          GridRosterRecoveryAssessment(
            scheduleId: scheduleId,
            disposition: GridRosterRecoveryDisposition.alreadyApplied,
            currentSchedule: live,
            candidateSchedule: snapshot.schedule,
            expectedRevision: snapshot.provenance.targetScheduleRevision,
            importRunId: snapshot.provenance.importRunId,
            message: 'The accepted Schedule is already present.',
          ),
        );
      }

      final liveRevision = revisionFor(live, scheduleId);
      if (liveRevision != snapshot.provenance.targetScheduleRevision) {
        return Success(
          GridRosterRecoveryAssessment(
            scheduleId: scheduleId,
            disposition: GridRosterRecoveryDisposition.conflict,
            currentSchedule: live,
            candidateSchedule: snapshot.schedule,
            expectedRevision: snapshot.provenance.targetScheduleRevision,
            importRunId: snapshot.provenance.importRunId,
            message:
                'Canonical Schedule changed after the journal base revision.',
          ),
        );
      }

      return Success(
        GridRosterRecoveryAssessment(
          scheduleId: scheduleId,
          disposition: GridRosterRecoveryDisposition.ready,
          currentSchedule: live,
          candidateSchedule: snapshot.schedule,
          expectedRevision: snapshot.provenance.targetScheduleRevision,
          importRunId: snapshot.provenance.importRunId,
          message: 'The committed bundle can be recovered against its base revision.',
        ),
      );
    } on Object catch (error, stackTrace) {
      return ValidationFailure(
        'Could not inspect the Grid import journal.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Replays a committed journal bundle only after an explicit caller action.
  ///
  /// The read-only assessment is repeated immediately before the conditional
  /// write. A changed target is rejected and the journal remains available
  /// for a later, deliberate conflict-resolution workflow.
  Future<Result<Schedule?>> recover(String scheduleId) async {
    final assessmentResult = await inspectRecovery(scheduleId);
    if (assessmentResult case Failure<GridRosterRecoveryAssessment>()) {
      return _copyFailure<GridRosterRecoveryAssessment, Schedule?>(
        assessmentResult,
      );
    }
    final assessment =
        (assessmentResult as Success<GridRosterRecoveryAssessment>).value;

    switch (assessment.disposition) {
      case GridRosterRecoveryDisposition.noCommittedBundle:
      case GridRosterRecoveryDisposition.alreadyApplied:
        return Success(assessment.currentSchedule);
      case GridRosterRecoveryDisposition.conflict:
        return const ValidationFailure(
          'Recovery conflict: canonical Schedule changed after the journal base revision.',
        );
      case GridRosterRecoveryDisposition.ready:
        break;
    }

    final candidate = assessment.candidateSchedule;
    final expectedRevision = assessment.expectedRevision;
    if (candidate == null ||
        expectedRevision == null ||
        assessment.importRunId == null) {
      return const ValidationFailure(
        'Recovery assessment is missing its candidate or revision evidence.',
      );
    }

    final latestResult = await _scheduleRepository.findById(scheduleId);
    if (latestResult case Failure<Schedule?>()) return latestResult;
    final latest = (latestResult as Success<Schedule?>).value;
    if (latest != null &&
        scheduleFingerprint(latest) == scheduleFingerprint(candidate)) {
      return Success(latest);
    }
    if (revisionFor(latest, scheduleId) != expectedRevision) {
      return const ValidationFailure(
        'Recovery target changed after inspection. No Schedule was overwritten.',
      );
    }

    final saved = await _saveWithRevision(candidate, expectedRevision);
    return switch (saved) {
      Success<Schedule>(value: final schedule) => Success(schedule),
      Failure<Schedule>() => _copyFailure<Schedule, Schedule?>(saved),
    };
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
