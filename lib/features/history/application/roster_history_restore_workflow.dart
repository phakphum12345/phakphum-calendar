import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/result/result.dart';
import '../../../domain/entities/employee.dart';
import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/shift_template.dart';
import '../../../services/roster_revision_service.dart';
import '../../shift_parser/application/grid_roster_canonical_converter.dart';
import '../../shift_parser/application/grid_roster_import_workflow.dart';
import '../../shift_parser/application/grid_roster_workbook_scanner.dart';
import '../../shift_parser/application/monthly_roster_section_parser.dart';
import '../../shift_parser/domain/grid_roster_import_provenance.dart';

/// Restores a read-only Google Drive revision export through the same
/// review, journal and conditional Schedule commit path as a live import.
///
/// This service never writes to Drive or Google Sheets. The source revision
/// and its exact snapshot content are bound into the source fingerprint.
class RosterHistoryRestoreWorkflow {
  const RosterHistoryRestoreWorkflow({
    required this.gridImportWorkflow,
    this.workbookScanner = const GridRosterWorkbookScanner(),
  });

  final GridRosterImportWorkflow gridImportWorkflow;
  final GridRosterWorkbookScanner workbookScanner;

  MonthlyRosterParseReport scanRevision(
    RosterRevisionDocument revision, {
    String? timeZone,
  }) {
    if (revision.revisionId.trim().isEmpty) {
      throw ArgumentError.value(revision.revisionId, 'revisionId');
    }
    final fingerprint = _revisionFingerprint(revision);
    return workbookScanner.scanSnapshots(
      snapshots: revision.snapshots,
      spreadsheetTitle: 'Drive revision ' + revision.revisionId,
      sourceFingerprint: fingerprint,
      timeZone: timeZone,
    );
  }

  Future<Result<GridRosterImportReviewContext>> prepareReview({
    required RosterRevisionDocument revision,
    required String targetScheduleId,
    required String targetScheduleName,
    required Iterable<Employee> employees,
    required Iterable<ShiftTemplate> shiftTemplates,
    String? timeZone,
  }) {
    final report = scanRevision(revision, timeZone: timeZone);
    return gridImportWorkflow.prepareReview(
      report: report,
      targetScheduleId: targetScheduleId,
      targetScheduleName: targetScheduleName,
      employees: employees,
      shiftTemplates: shiftTemplates,
      sourceRevisionId: revision.revisionId,
    );
  }

  Result<GridRosterCanonicalConversionResult> convert({
    required GridRosterImportReviewContext context,
    required Iterable<Employee> employees,
    required Iterable<ShiftTemplate> shiftTemplates,
    required Map<String, GridRosterAssignmentDecision> decisions,
    required String importRunId,
    required String parserVersion,
    required DateTime createdAtUtc,
  }) {
    return gridImportWorkflow.convert(
      context: context,
      employees: employees,
      shiftTemplates: shiftTemplates,
      decisions: decisions,
      importRunId: importRunId,
      parserVersion: parserVersion,
      createdAtUtc: createdAtUtc,
    );
  }

  Future<Result<Schedule>> commit({
    required GridRosterImportReviewContext context,
    required GridRosterCanonicalConversionResult conversion,
  }) {
    return gridImportWorkflow.commit(
      context: context,
      conversion: conversion,
    );
  }

  String _revisionFingerprint(RosterRevisionDocument revision) {
    final payload = <String, Object?>{
      'revisionId': revision.revisionId,
      'modifiedAt': revision.modifiedAt.toUtc().toIso8601String(),
      'snapshots': [
        for (final snapshot in revision.snapshots)
          {
            'title': snapshot.title,
            'spreadsheetId': snapshot.spreadsheetId,
            'sheetId': snapshot.sheetId,
            'hidden': snapshot.hidden,
            'rows': [
              for (final row in snapshot.rows)
                [for (final value in row) _jsonSafe(value)],
            ],
            'backgroundColors': snapshot.backgroundColors,
          },
      ],
    };
    return 'sha256:' + sha256.convert(utf8.encode(jsonEncode(payload))).toString();
  }

  Object? _jsonSafe(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) return value.toIso8601String();
    return value.toString();
  }
}
