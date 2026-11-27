import '../../../models/shift.dart';
import 'normalized_cell.dart';
import 'roster_grid_axis_mapping.dart';

/// A resolved calendar date attached to its original spreadsheet column.
class MonthlyRosterDateColumn {
  const MonthlyRosterDateColumn({
    required this.columnIndex,
    required this.displayedDay,
    required this.date,
    this.rowIndex,
  });

  final int columnIndex;
  final int displayedDay;
  final DateTime date;
  final int? rowIndex;
}

/// A blocking date-grid issue that must be reviewed before calendar sync.
class MonthlyRosterDateAnomaly {
  const MonthlyRosterDateAnomaly({
    required this.code,
    required this.message,
    this.columnIndex,
    this.displayedDay,
    this.rowIndex,
  });

  final String code;
  final String message;
  final int? columnIndex;
  final int? displayedDay;
  final int? rowIndex;
}

/// A shift row discovered independently of the worker names in its cells.
class MonthlyRosterRow {
  const MonthlyRosterRow({
    required this.rowIndex,
    required this.label,
    this.columnIndex,
  });

  final int rowIndex;
  final int? columnIndex;
  final String label;
}

class MonthlyRosterSection {
  const MonthlyRosterSection({
    required this.title,
    required this.headerRowIndex,
    required this.assignments,
    this.rowLabels = const [],
    this.dateColumns = const [],
    this.rosterRows = const [],
    this.startDate,
    this.endDate,
    this.dateAnomalies = const [],
    this.sourceSpreadsheetId,
    this.sourceSheetId,
    this.sourceSheetTitle,
    this.sourceCells = const [],
    this.orientation = RosterGridOrientation.datesAcrossColumns,
  });

  final String title;
  final int headerRowIndex;
  final List<MonthlyRosterAssignment> assignments;
  final List<String> rowLabels;
  final List<MonthlyRosterDateColumn> dateColumns;
  final List<MonthlyRosterRow> rosterRows;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<MonthlyRosterDateAnomaly> dateAnomalies;
  final String? sourceSpreadsheetId;
  final int? sourceSheetId;
  final String? sourceSheetTitle;
  /// Original normalized worksheet cells retained for source-bound correction.
  final List<NormalizedCell> sourceCells;
  final RosterGridOrientation orientation;

  bool get hasBlockingDateAnomalies => dateAnomalies.isNotEmpty;
}

class MonthlyRosterAssignment {
  const MonthlyRosterAssignment({
    required this.sectionTitle,
    required this.rowLabel,
    required this.rowIndex,
    required this.workerName,
    required this.date,
    required this.sourceCell,
    this.backgroundColor,
    this.spreadsheetId,
    this.sheetId,
    this.sheetTitle,
    this.columnIndex,
  });

  final String sectionTitle;
  final String rowLabel;
  final int rowIndex;
  final int? columnIndex;
  final String workerName;
  final DateTime date;
  final String sourceCell;
  final String? backgroundColor;
  final String? spreadsheetId;
  final int? sheetId;
  final String? sheetTitle;

  String get sourceIdentityKey => spreadsheetId != null && sheetId != null
      ? '$spreadsheetId|$sheetId|${sourceCell.toUpperCase()}'
      : sourceCell.toUpperCase();

  /// Opens the exact Google Sheets tab and cell when stable source metadata
  /// is available. Local imports intentionally have no fabricated URL.
  String? get sourceUrl {
    final fileId = spreadsheetId;
    final tabId = sheetId;
    final cell = sourceCell.trim();
    if (fileId == null || fileId.isEmpty || tabId == null || cell.isEmpty) {
      return null;
    }
    return 'https://docs.google.com/spreadsheets/d/$fileId/edit'
        '#gid=$tabId&range=$cell';
  }
}

class MonthlyRosterSheetScanSummary {
  const MonthlyRosterSheetScanSummary({
    required this.sheetId,
    required this.title,
    required this.hidden,
    required this.blockCount,
    required this.assignmentCount,
    required this.warningCount,
  });

  final int sheetId;
  final String title;
  final bool hidden;
  final int blockCount;
  final int assignmentCount;
  final int warningCount;
}

class MonthlyRosterParseReport {
  const MonthlyRosterParseReport({
    required this.sections,
    required this.warnings,
    this.sourceSheetCount = 0,
    this.sheetSummaries = const [],
    this.sourceFingerprint,
  });

  final List<MonthlyRosterSection> sections;
  final List<String> warnings;
  final int sourceSheetCount;
  final List<MonthlyRosterSheetScanSummary> sheetSummaries;
  final String? sourceFingerprint;

  List<MonthlyRosterDateAnomaly> get blockingDateAnomalies => [
    for (final section in sections) ...section.dateAnomalies,
  ];

  bool get hasBlockingDateAnomalies => blockingDateAnomalies.isNotEmpty;

  /// Builds a source-neutral monthly view when an imported source does not
  /// expose a recognizable table grid, such as a confirmed camera entry.
  factory MonthlyRosterParseReport.fromShifts(Iterable<Shift> shifts) {
    final source = shifts.where((shift) => !shift.generated).toList()
      ..sort((left, right) => left.start.compareTo(right.start));
    if (source.isEmpty) {
      return const MonthlyRosterParseReport(sections: [], warnings: []);
    }

    final grouped = <String, List<Shift>>{};
    for (final shift in source) {
      grouped.putIfAbsent(shift.sheetTitle.trim(), () => []).add(shift);
    }
    final sections = <MonthlyRosterSection>[];
    for (final entry in grouped.entries) {
      final rowIndexes = <String, int>{};
      final assignments = <MonthlyRosterAssignment>[];
      for (final shift in entry.value) {
        final rowLabel = shift.rowLabel.trim().isEmpty
            ? shift.code
            : shift.rowLabel.trim();
        final rowIndex = rowIndexes.putIfAbsent(
          rowLabel,
          () => rowIndexes.length,
        );
        assignments.add(
          MonthlyRosterAssignment(
            sectionTitle: entry.key.isEmpty ? 'ข้อมูลที่นำเข้า' : entry.key,
            rowLabel: rowLabel,
            rowIndex: rowIndex,
            workerName: shift.assignedName.trim(),
            date: DateTime(
              shift.start.year,
              shift.start.month,
              shift.start.day,
            ),
            sourceCell: shift.cell,
            backgroundColor: shift.sourceColorHex,
            spreadsheetId: shift.sourceSpreadsheetId,
            sheetId: shift.sourceSheetId,
            sheetTitle: shift.sheetTitle,
          ),
        );
      }
      sections.add(
        MonthlyRosterSection(
          title: entry.key.isEmpty ? 'ข้อมูลที่นำเข้า' : entry.key,
          headerRowIndex: 0,
          assignments: List.unmodifiable(assignments),
          dateColumns: const [],
          rosterRows: const [],
          startDate: assignments.first.date,
          endDate: assignments.last.date,
          sourceSpreadsheetId: assignments.first.spreadsheetId,
          sourceSheetId: assignments.first.sheetId,
          sourceSheetTitle: assignments.first.sheetTitle,
        ),
      );
    }
    return MonthlyRosterParseReport(
      sections: List.unmodifiable(sections),
      warnings: const [],
    );
  }

  MonthlyRosterParseReport appendShift(Shift shift) {
    final imported = MonthlyRosterParseReport.fromShifts([shift]);
    return MonthlyRosterParseReport(
      sections: List.unmodifiable([...sections, ...imported.sections]),
      warnings: warnings,
      sourceFingerprint: sourceFingerprint,
    );
  }

  List<MonthlyRosterAssignment> get assignments => [
    for (final section in sections) ...section.assignments,
  ];

  List<({DateTime start, DateTime end})> get dateRanges {
    final unique = <String, ({DateTime start, DateTime end})>{};
    for (final section in sections) {
      final start = section.startDate;
      final end = section.endDate;
      if (start == null || end == null) continue;
      unique['${start.toIso8601String()}|${end.toIso8601String()}'] = (
        start: start,
        end: end,
      );
    }
    return unique.values.toList()
      ..sort((left, right) => left.start.compareTo(right.start));
  }

  MonthlyRosterParseReport filtered({
    String query = '',
    String? sectionTitle,
    bool Function(DateTime date)? includesDate,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final filteredSections = <MonthlyRosterSection>[];

    for (final section in sections) {
      if (sectionTitle != null && section.title != sectionTitle) continue;
      final sectionMatches = section.title.toLowerCase().contains(
        normalizedQuery,
      );
      final filteredAssignments = section.assignments
          .where((assignment) {
            if (includesDate != null && !includesDate(assignment.date)) {
              return false;
            }
            return normalizedQuery.isEmpty ||
                sectionMatches ||
                assignment.rowLabel.toLowerCase().contains(normalizedQuery) ||
                assignment.workerName.toLowerCase().contains(normalizedQuery) ||
                assignment.sourceCell.toLowerCase().contains(normalizedQuery) ||
                (assignment.sheetTitle ?? '').toLowerCase().contains(
                  normalizedQuery,
                ) ||
                (assignment.spreadsheetId ?? '').toLowerCase().contains(
                  normalizedQuery,
                ) ||
                (assignment.sheetId?.toString() ?? '').contains(
                  normalizedQuery,
                ) ||
                'row ${assignment.rowIndex + 1}'.contains(normalizedQuery);
          })
          .toList(growable: false);
      var anomalousSectionInScope = false;
      if (section.hasBlockingDateAnomalies &&
          (normalizedQuery.isEmpty || sectionMatches)) {
        final start = section.startDate;
        final end = section.endDate;
        if (includesDate == null) {
          anomalousSectionInScope = true;
        } else if (start != null && end != null) {
          for (
            var date = DateTime(start.year, start.month, start.day);
            !date.isAfter(end);
            date = DateTime(date.year, date.month, date.day + 1)
          ) {
            if (includesDate(date)) {
              anomalousSectionInScope = true;
              break;
            }
          }
        }
      }
      if (filteredAssignments.isEmpty && !anomalousSectionInScope) continue;
      filteredSections.add(
        MonthlyRosterSection(
          title: section.title,
          headerRowIndex: section.headerRowIndex,
          orientation: section.orientation,
          assignments: List.unmodifiable(filteredAssignments),
          rowLabels: section.rowLabels,
          dateColumns: section.dateColumns,
          rosterRows: section.rosterRows,
          startDate: section.startDate,
          endDate: section.endDate,
          dateAnomalies: section.dateAnomalies,
          sourceSpreadsheetId: section.sourceSpreadsheetId,
          sourceSheetId: section.sourceSheetId,
          sourceSheetTitle: section.sourceSheetTitle,
          sourceCells: section.sourceCells,
        ),
      );
    }

    return MonthlyRosterParseReport(
      sections: List.unmodifiable(filteredSections),
      warnings: warnings,
      sourceSheetCount: sourceSheetCount,
      sheetSummaries: sheetSummaries,
      sourceFingerprint: sourceFingerprint,
    );
  }
}
