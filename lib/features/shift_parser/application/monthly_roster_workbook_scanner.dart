import '../../../models/shift.dart';
import '../../google_sheets/domain/sheet_color.dart';
import '../domain/a1_notation.dart';
import '../domain/monthly_roster_section.dart';
import '../domain/normalized_cell.dart';
import '../domain/shift_parser_input.dart';
import 'monthly_roster_section_parser.dart';
import 'vertical_monthly_roster_section_parser.dart';

/// Scans every supplied worksheet independently, preserving its identity and
/// reporting sheets that contain no recognizable monthly roster blocks.
class MonthlyRosterWorkbookScanner {
  const MonthlyRosterWorkbookScanner({
    this.sectionParser = const MonthlyRosterSectionParser(),
  });

  final MonthlyRosterSectionParser sectionParser;

  MonthlyRosterParseReport scan({
    required List<SheetSnapshot> snapshots,
    required String spreadsheetId,
    required String spreadsheetTitle,
    String? timeZone = 'Asia/Bangkok',
  }) {
    final sections = <MonthlyRosterSection>[];
    final warnings = <String>[];
    final summaries = <MonthlyRosterSheetScanSummary>[];

    for (var sheetIndex = 0; sheetIndex < snapshots.length; sheetIndex++) {
      final snapshot = snapshots[sheetIndex];
      final sheetId = snapshot.sheetId ?? sheetIndex;
      final cells = <NormalizedCell>[];

      for (var rowIndex = 0; rowIndex < snapshot.rows.length; rowIndex++) {
        final row = snapshot.rows[rowIndex];
        for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
          final value = row[columnIndex];
          final text = value?.toString().trim();
          final background = snapshot.backgroundColorAt(rowIndex, columnIndex);
          if ((text == null || text.isEmpty) && background == null) continue;

          cells.add(
            NormalizedCell(
              sheetId: sheetId,
              sheetTitle: snapshot.title,
              a1: A1Notation.fromZeroBased(
                rowIndex: rowIndex,
                columnIndex: columnIndex,
              ),
              rowIndex: rowIndex,
              columnIndex: columnIndex,
              text: text == null || text.isEmpty ? null : text,
              rawValue: value,
              backgroundColor: _sheetColor(background),
            ),
          );
        }
      }

      final parserInput = ShiftParserInput(
        spreadsheetId: snapshot.spreadsheetId ?? spreadsheetId,
        spreadsheetTitle: spreadsheetTitle,
        sheetId: sheetId,
        sheetTitle: snapshot.title,
        timeZone: timeZone,
        cells: cells,
      );
      final horizontalReport = sectionParser.parse(parserInput);
      final verticalReport = const VerticalMonthlyRosterSectionParser().parse(
        parserInput,
      );
      final sheetSections = <MonthlyRosterSection>[
        ...horizontalReport.sections,
        ...verticalReport.sections,
      ];
      final sheetWarnings = <String>[
        ...horizontalReport.warnings,
        ...verticalReport.warnings,
      ];

      sections.addAll(sheetSections);
      warnings.addAll(
        sheetWarnings.map((warning) => '${snapshot.title}: $warning'),
      );
      summaries.add(
        MonthlyRosterSheetScanSummary(
          sheetId: sheetId,
          title: snapshot.title,
          hidden: snapshot.hidden,
          blockCount: sheetSections.length,
          assignmentCount: sheetSections.fold<int>(
            0,
            (total, section) => total + section.assignments.length,
          ),
          warningCount: sheetWarnings.length,
        ),
      );
    }

    return MonthlyRosterParseReport(
      sections: List.unmodifiable(sections),
      warnings: List.unmodifiable(warnings),
      sourceSheetCount: snapshots.length,
      sheetSummaries: List.unmodifiable(summaries),
    );
  }

  SheetColor? _sheetColor(int? value) {
    if (value == null) return null;
    return SheetColor(
      red: ((value >> 16) & 0xFF) / 255,
      green: ((value >> 8) & 0xFF) / 255,
      blue: (value & 0xFF) / 255,
      alpha: ((value >> 24) & 0xFF) / 255,
    );
  }
}
