import '../../../models/shift.dart';

class MonthlyRosterSection {
  const MonthlyRosterSection({
    required this.title,
    required this.headerRowIndex,
    required this.assignments,
    this.rowLabels = const [],
    this.startDate,
    this.endDate,
  });

  final String title;
  final int headerRowIndex;
  final List<MonthlyRosterAssignment> assignments;
  final List<String> rowLabels;
  final DateTime? startDate;
  final DateTime? endDate;
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
  });

  final String sectionTitle;
  final String rowLabel;
  final int rowIndex;
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
}

class MonthlyRosterParseReport {
  const MonthlyRosterParseReport({
    required this.sections,
    required this.warnings,
  });

  final List<MonthlyRosterSection> sections;
  final List<String> warnings;

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
          startDate: assignments.first.date,
          endDate: assignments.last.date,
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
                assignment.workerName.toLowerCase().contains(normalizedQuery);
          })
          .toList(growable: false);
      if (filteredAssignments.isEmpty) continue;
      filteredSections.add(
        MonthlyRosterSection(
          title: section.title,
          headerRowIndex: section.headerRowIndex,
          assignments: List.unmodifiable(filteredAssignments),
          rowLabels: section.rowLabels,
          startDate: section.startDate,
          endDate: section.endDate,
        ),
      );
    }

    return MonthlyRosterParseReport(
      sections: List.unmodifiable(filteredSections),
      warnings: warnings,
    );
  }
}
