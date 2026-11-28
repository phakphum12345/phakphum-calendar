import 'package:crypto/crypto.dart';

import '../../excel_import/domain/excel_row.dart';
import '../../excel_import/domain/import_file.dart';
import '../../excel_import/domain/workbook_info.dart';
import '../../excel_import/domain/worksheet_info.dart';
import '../../../models/shift.dart' show SheetSnapshot;
import '../domain/a1_notation.dart';
import '../domain/monthly_roster_section.dart';
import '../domain/normalized_cell.dart';
import '../domain/shift_parser_input.dart';
import '../../google_sheets/domain/sheet_color.dart';
import 'monthly_roster_section_parser.dart';

typedef GridRosterWorksheetRowsReader =
    List<ExcelRow> Function(WorksheetInfo worksheet);

/// Converts local XLSX rows into the source-neutral parser input contract.
class GridRosterExcelInputAdapter {
  const GridRosterExcelInputAdapter();

  String sourceFingerprint(ImportFile file) =>
      'sha256:${sha256.convert(file.bytes)}';

  SheetColor? _sheetColor(int? value) {
    if (value == null) return null;
    return SheetColor(
      red: ((value >> 16) & 0xFF) / 255,
      green: ((value >> 8) & 0xFF) / 255,
      blue: (value & 0xFF) / 255,
      alpha: ((value >> 24) & 0xFF) / 255,
    );
  }

  ShiftParserInput toParserInput({
    required ImportFile file,
    required WorksheetInfo worksheet,
    required int worksheetIndex,
    required List<ExcelRow> rows,
    String? timeZone,
  }) {
    if (worksheetIndex < 0) {
      throw ArgumentError.value(worksheetIndex, 'worksheetIndex');
    }
    final cells = <NormalizedCell>[];
    for (final row in rows) {
      for (final cell in row.cells) {
        cells.add(
          NormalizedCell(
            sheetId: worksheetIndex,
            sheetTitle: worksheet.name,
            a1: A1Notation.fromZeroBased(
              rowIndex: cell.rowIndex,
              columnIndex: cell.columnIndex,
            ),
            rowIndex: cell.rowIndex,
            columnIndex: cell.columnIndex,
            text: cell.displayValue,
            rawValue: cell.value,
            backgroundColor: _sheetColor(cell.backgroundColorValue),
            isMerged: cell.isMerged,
            mergedAnchorA1: cell.mergedAnchorRowIndex == null ||
                    cell.mergedAnchorColumnIndex == null
                ? null
                : A1Notation.fromZeroBased(
                    rowIndex: cell.mergedAnchorRowIndex!,
                    columnIndex: cell.mergedAnchorColumnIndex!,
                  ),
          ),
        );
      }
    }
    return ShiftParserInput(
      // Local XLSX files do not have a Google spreadsheet ID. Keep this empty
      // so downstream sourceUrl helpers never fabricate a Google URL.
      spreadsheetId: '',
      spreadsheetTitle: file.name,
      sheetId: worksheetIndex,
      sheetTitle: worksheet.name,
      timeZone: timeZone,
      cells: List.unmodifiable(cells),
    );
  }
}


/// Converts delimited-file snapshots into the same source-neutral parser input.
/// XLSX files should use [GridRosterExcelInputAdapter] so merge provenance is
/// retained by the Excel reader.
class GridRosterSnapshotInputAdapter {
  const GridRosterSnapshotInputAdapter();

  SheetColor? _sheetColor(int? value) {
    if (value == null) return null;
    return SheetColor(
      red: ((value >> 16) & 0xFF) / 255,
      green: ((value >> 8) & 0xFF) / 255,
      blue: (value & 0xFF) / 255,
      alpha: ((value >> 24) & 0xFF) / 255,
    );
  }

  ShiftParserInput toParserInput({
    required SheetSnapshot snapshot,
    required int worksheetIndex,
    required String spreadsheetTitle,
    String? timeZone,
  }) {
    if (worksheetIndex < 0) {
      throw ArgumentError.value(worksheetIndex, 'worksheetIndex');
    }
    final sheetId = snapshot.sheetId ?? worksheetIndex;
    final cells = <NormalizedCell>[];
    for (var rowIndex = 0; rowIndex < snapshot.rows.length; rowIndex++) {
      final row = snapshot.rows[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        final value = row[columnIndex];
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
            text: value?.toString(),
            rawValue: value,
            backgroundColor: _sheetColor(
              snapshot.backgroundColorAt(rowIndex, columnIndex),
            ),
          ),
        );
      }
    }
    return ShiftParserInput(
      spreadsheetId: snapshot.spreadsheetId ?? '',
      spreadsheetTitle: spreadsheetTitle,
      sheetId: sheetId,
      sheetTitle: snapshot.title,
      timeZone: timeZone,
      cells: List.unmodifiable(cells),
    );
  }
}

/// Scans every worksheet in a selected local workbook independently.
///
/// A worksheet read failure is reported against that sheet and does not
/// prevent successfully read worksheets from being parsed. Local XLSX input
/// retains background colors and merged-cell anchor coordinates. Hidden-row,
/// hidden-column and hidden-sheet metadata, formula cached values, and
/// semantic propagation across multi-level merged headers remain separate
/// reader/parser capabilities and are not inferred by this scanner.
class GridRosterWorkbookScanner {
  const GridRosterWorkbookScanner({
    this.inputAdapter = const GridRosterExcelInputAdapter(),
    this.sectionParser = const MonthlyRosterSectionParser(),
  });

  final GridRosterExcelInputAdapter inputAdapter;
  final MonthlyRosterSectionParser sectionParser;

  MonthlyRosterParseReport scanSnapshots({
    required List<SheetSnapshot> snapshots,
    required String spreadsheetTitle,
    required String sourceFingerprint,
    String? timeZone,
    GridRosterSnapshotInputAdapter snapshotAdapter =
        const GridRosterSnapshotInputAdapter(),
  }) {
    final sections = <MonthlyRosterSection>[];
    final warnings = <String>[];
    final summaries = <MonthlyRosterSheetScanSummary>[];
    for (var index = 0; index < snapshots.length; index++) {
      final snapshot = snapshots[index];
      try {
        final input = snapshotAdapter.toParserInput(
          snapshot: snapshot,
          worksheetIndex: index,
          spreadsheetTitle: spreadsheetTitle,
          timeZone: timeZone,
        );
        final report = sectionParser.parse(input);
        sections.addAll(report.sections);
        warnings.addAll(
          report.warnings.map((warning) => '${snapshot.title}: $warning'),
        );
        summaries.add(
          MonthlyRosterSheetScanSummary(
            sheetId: snapshot.sheetId ?? index,
            title: snapshot.title,
            hidden: snapshot.hidden,
            blockCount: report.sections.length,
            assignmentCount: report.assignments.length,
            warningCount: report.warnings.length,
          ),
        );
      } on Object catch (error) {
        warnings.add(
          'อ่าน Worksheet "${snapshot.title}" ไม่สำเร็จ: $error',
        );
        summaries.add(
          MonthlyRosterSheetScanSummary(
            sheetId: snapshot.sheetId ?? index,
            title: snapshot.title,
            hidden: snapshot.hidden,
            blockCount: 0,
            assignmentCount: 0,
            warningCount: 1,
          ),
        );
      }
    }
    return MonthlyRosterParseReport(
      sections: List.unmodifiable(sections),
      warnings: List.unmodifiable(warnings),
      sourceSheetCount: snapshots.length,
      sheetSummaries: List.unmodifiable(summaries),
      sourceFingerprint: sourceFingerprint,
    );
  }

  MonthlyRosterParseReport scan({
    required WorkbookInfo workbook,
    required GridRosterWorksheetRowsReader readWorksheet,
  }) {
    final fingerprint = inputAdapter.sourceFingerprint(workbook.file);
    final sections = <MonthlyRosterSection>[];
    final warnings = <String>[];
    final summaries = <MonthlyRosterSheetScanSummary>[];

    for (var index = 0; index < workbook.worksheets.length; index++) {
      final worksheet = workbook.worksheets[index];
      try {
        final rows = readWorksheet(worksheet);
        final input = inputAdapter.toParserInput(
          file: workbook.file,
          worksheet: worksheet,
          worksheetIndex: index,
          rows: rows,
        );
        final report = sectionParser.parse(input);
        sections.addAll(report.sections);
        warnings.addAll(
          report.warnings.map((warning) => '${worksheet.name}: $warning'),
        );
        summaries.add(
          MonthlyRosterSheetScanSummary(
            sheetId: index,
            title: worksheet.name,
            hidden: false,
            blockCount: report.sections.length,
            assignmentCount: report.assignments.length,
            warningCount: report.warnings.length,
          ),
        );
      } on Object catch (error) {
        final message = 'อ่าน Worksheet "${worksheet.name}" ไม่สำเร็จ: $error';
        warnings.add(message);
        summaries.add(
          MonthlyRosterSheetScanSummary(
            sheetId: index,
            title: worksheet.name,
            hidden: false,
            blockCount: 0,
            assignmentCount: 0,
            warningCount: 1,
          ),
        );
      }
    }

    return MonthlyRosterParseReport(
      sections: List.unmodifiable(sections),
      warnings: List.unmodifiable(warnings),
      sourceSheetCount: workbook.worksheets.length,
      sheetSummaries: List.unmodifiable(summaries),
      sourceFingerprint: fingerprint,
    );
  }
}
