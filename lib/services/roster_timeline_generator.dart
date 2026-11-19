import 'package:http/http.dart' as http;

import '../domain/entities/shift_template.dart';
import '../features/shift_parser/application/monthly_roster_conversion_diagnostics.dart';
import '../features/shift_parser/application/monthly_roster_section_parser.dart';
import '../features/shift_parser/application/monthly_roster_workbook_scanner.dart';
import '../models/roster_assignment_timeline.dart';
import '../services/roster_revision_service.dart';

/// Diagnostics produced while converting historical workbook revisions into
/// assignment timelines. Invalid date sections are omitted, never guessed.
class RosterTimelineGenerationReport {
  const RosterTimelineGenerationReport({
    required this.timelines,
    required this.warnings,
  });

  final Map<String, RosterAssignmentTimeline> timelines;
  final List<String> warnings;
}

/// Generates historical assignment timelines with the same date-first,
/// workbook-wide parser used by the live roster import path.
class RosterTimelineGenerator {
  const RosterTimelineGenerator({this.shiftTemplates = const []});

  final Iterable<ShiftTemplate> shiftTemplates;

  /// Build timelines from already-downloaded revision documents (in memory).
  Map<String, RosterAssignmentTimeline> generateFromDocuments(
    Iterable<RosterRevisionDocument> documents,
  ) => generateFromDocumentsWithDiagnostics(documents).timelines;

  RosterTimelineGenerationReport generateFromDocumentsWithDiagnostics(
    Iterable<RosterRevisionDocument> documents,
  ) {
    final revisions = <RosterRevisionShifts>[];
    final warnings = <String>[];
    for (final document in documents) {
      final parsed = _parseDocument(document);
      revisions.add(parsed.revision);
      warnings.addAll(parsed.warnings);
    }
    return RosterTimelineGenerationReport(
      timelines: buildRosterAssignmentTimelines(revisions),
      warnings: List.unmodifiable(warnings),
    );
  }

  /// Parse cached revision documents in small batches, yielding between
  /// revisions so a large history does not monopolize the UI isolate.
  Future<Map<String, RosterAssignmentTimeline>> generateFromDocumentsAsync(
    Iterable<RosterRevisionDocument> documents,
  ) async =>
      (await generateFromDocumentsWithDiagnosticsAsync(documents)).timelines;

  Future<RosterTimelineGenerationReport>
  generateFromDocumentsWithDiagnosticsAsync(
    Iterable<RosterRevisionDocument> documents,
  ) async {
    final revisions = <RosterRevisionShifts>[];
    final warnings = <String>[];
    var processed = 0;
    for (final document in documents) {
      if (processed > 0 && processed % 4 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final parsed = _parseDocument(document);
      revisions.add(parsed.revision);
      warnings.addAll(parsed.warnings);
      processed++;
    }
    return RosterTimelineGenerationReport(
      timelines: buildRosterAssignmentTimelines(revisions),
      warnings: List.unmodifiable(warnings),
    );
  }

  ({RosterRevisionShifts revision, List<String> warnings}) _parseDocument(
    RosterRevisionDocument document,
  ) {
    final warnings = <String>[];
    if (document.snapshots.isEmpty) {
      warnings.add(
        'Revision ${document.revisionId}: ไม่มีข้อมูล Worksheet สำหรับสร้าง Timeline',
      );
      return (
        revision: RosterRevisionShifts(
          revisionId: document.revisionId,
          modifiedAt: document.modifiedAt,
          shifts: const [],
        ),
        warnings: warnings,
      );
    }

    // Historical Drive XLSX exports do not carry a live Google spreadsheet ID.
    // An empty ID keeps source links unavailable; sheet indexes still preserve
    // per-tab identity for deduplication inside each revision.
    final report = const MonthlyRosterWorkbookScanner().scan(
      snapshots: document.snapshots,
      spreadsheetId: '',
      spreadsheetTitle: document.snapshots.first.title,
      timeZone: 'Asia/Bangkok',
    );
    final workerNames = report.assignments
        .map((assignment) => assignment.workerName)
        .where((name) => name.trim().isNotEmpty)
        .toSet();
    final conversion = const MonthlyRosterShiftAdapter()
        .parseForWorkersWithDiagnostics(
          report,
          targetNames: workerNames,
          shiftTemplates: shiftTemplates,
        );

    for (final warning in report.warnings) {
      if (warning.contains('ไม่พบบล็อกตารางรายเดือน')) continue;
      warnings.add('Revision ${document.revisionId}: $warning');
    }
    for (final section in report.sections.where(
      (section) => section.hasBlockingDateAnomalies,
    )) {
      for (final anomaly in section.dateAnomalies) {
        warnings.add(
          'Revision ${document.revisionId} · ${section.title}: ${anomaly.message}',
        );
      }
    }
    if (report.sections.isEmpty) {
      warnings.add(
        'Revision ${document.revisionId}: ไม่พบบล็อกตารางเวรที่มีวันที่ระบุชัดเจน',
      );
    }
    if (conversion.unconvertedAssignments.isNotEmpty) {
      final labels = conversion.unconvertedAssignments
          .map((assignment) => assignment.rowLabel)
          .toSet()
          .take(4)
          .join(', ');
      warnings.add(
        'Revision ${document.revisionId}: แปลงรายการเวร '
        '${conversion.unconvertedAssignments.length} รายการไม่ได้'
        '${labels.isEmpty ? '' : ' (ประเภทเวร: $labels)'}',
      );
    }

    return (
      revision: RosterRevisionShifts(
        revisionId: document.revisionId,
        modifiedAt: document.modifiedAt,
        shifts: conversion.shifts,
      ),
      warnings: warnings,
    );
  }

  /// Read revision exports transiently (no long-lived cache) and build
  /// timelines. This contacts Drive and returns timelines without persisting
  /// revision snapshots anywhere long-term.
  Future<Map<String, RosterAssignmentTimeline>> generateFromDrive(
    http.Client client,
    String fileId, {
    RosterRevisionService service = const RosterRevisionService(),
    void Function(String revisionId, Object error)? onRevisionSkipped,
  }) async {
    final documents = await service.readHistoryTransient(
      client,
      fileId,
      onRevisionSkipped: onRevisionSkipped,
    );
    return generateFromDocuments(documents);
  }
}
