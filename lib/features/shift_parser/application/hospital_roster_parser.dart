import '../domain/a1_notation.dart';
import '../domain/roster_cell_assignment.dart';
import '../domain/roster_parse_report.dart';
import '../domain/shift_parser_input.dart';
import '../domain/thai_roster_period_parser.dart';

/// Parses the hospital roster grid in two explicit stages:
/// 1. Resolve the date period and every date-header column.
/// 2. Read worker names only from cells whose dates were validated.
class HospitalRosterParser {
  const HospitalRosterParser({
    this._periodParser = const ThaiRosterPeriodParser(),
  });

  final ThaiRosterPeriodParser _periodParser;

  RosterParseReport parse(ShiftParserInput input) {
    final byCoordinate = <(int, int), dynamic>{
      for (final cell in input.cells) (cell.rowIndex, cell.columnIndex): cell,
    };
    final warnings = <String>[];

    // Date structure is resolved before any worker cell is read.
    final dateHeaderRow = _findDateHeaderRow(input);
    final period = _findPeriod(input, dateHeaderRow);
    final dayByColumn = _readDateColumns(input, dateHeaderRow, warnings);
    final dateByColumn = <int, DateTime>{};

    for (final entry in dayByColumn.entries) {
      try {
        dateByColumn[entry.key] = _resolveDate(
          day: entry.value,
          start: period.start,
          end: period.end,
        );
      } on FormatException catch (error) {
        warnings.add(
          'คอลัมน์ ${entry.key + 1}: ${error.message}',
        );
      }
    }

    final assignments = <RosterCellAssignment>[];
    final rowLabelCells = input.cells
        .where((cell) => cell.columnIndex == 0 && cell.text != null)
        .toList()
      ..sort((left, right) => left.rowIndex.compareTo(right.rowIndex));

    for (final rowLabelCell in rowLabelCells) {
      if (rowLabelCell.rowIndex == dateHeaderRow) continue;
      final definition = _parseRowLabel(rowLabelCell.text!);
      if (definition == null) continue;

      for (final entry in dateByColumn.entries) {
        final workerCell = byCoordinate[(rowLabelCell.rowIndex, entry.key)];
        final worker = workerCell?.text?.trim();
        if (worker == null || worker.isEmpty) continue;

        assignments.add(
          RosterCellAssignment(
            spreadsheetId: input.spreadsheetId,
            sheetId: input.sheetId,
            sheetTitle: input.sheetTitle,
            sourceCell: A1Notation.fromZeroBased(
              rowIndex: rowLabelCell.rowIndex,
              columnIndex: entry.key,
            ),
            date: entry.value,
            category: definition.category,
            period: definition.period,
            slot: definition.slot,
            workerName: worker,
            backgroundColor: workerCell?.backgroundColor?.hex,
          ),
        );
      }
    }

    if (assignments.isEmpty) {
      warnings.add('ไม่พบรายการเวรจากชีต ${input.sheetTitle}');
    }

    return RosterParseReport(
      assignments: List.unmodifiable(assignments),
      warnings: List.unmodifiable(warnings),
      periodStart: period.start,
      periodEnd: period.end,
    );
  }

  int _findDateHeaderRow(ShiftParserInput input) {
    final cellsByRow = <int, List<dynamic>>{};
    for (final cell in input.cells) {
      cellsByRow.putIfAbsent(cell.rowIndex, () => []).add(cell);
    }

    final candidates = <({int row, int dateCount})>[];
    for (final entry in cellsByRow.entries) {
      final hasDateLabel = entry.value.any(
        (cell) =>
            cell.columnIndex == 0 &&
            cell.text?.trim() == 'วันที่',
      );
      if (!hasDateLabel) continue;
      final dateCount = entry.value
          .where((cell) => cell.columnIndex > 0)
          .map((cell) => _asDay(cell.rawValue ?? cell.text))
          .whereType<int>()
          .length;
      if (dateCount > 0) {
        candidates.add((row: entry.key, dateCount: dateCount));
      }
    }

    if (candidates.isEmpty) {
      throw const FormatException('ไม่พบแถวหัวข้อวันที่ในทุกแถวของตาราง');
    }
    candidates.sort((left, right) {
      final byCoverage = right.dateCount.compareTo(left.dateCount);
      return byCoverage != 0 ? byCoverage : left.row.compareTo(right.row);
    });
    return candidates.first.row;
  }

  ThaiRosterPeriod _findPeriod(ShiftParserInput input, int dateHeaderRow) {
    final candidates = <({int row, int column, ThaiRosterPeriod period})>[];
    for (final cell in input.cells) {
      final text = cell.text?.trim();
      if (text == null || text.isEmpty) continue;
      // Require a roster-period heading or an explicit date range with a
      // Thai month. This avoids treating unrelated dates in notes as a period.
      final looksLikePeriod =
          text.contains('ประจำเดือน') ||
          (RegExp(r'(?:-|ถึง|–|—)').hasMatch(text) &&
              RegExp(r'[ก-๙]').hasMatch(text));
      if (!looksLikePeriod) continue;
      try {
        candidates.add((
          row: cell.rowIndex,
          column: cell.columnIndex,
          period: _periodParser.parse(text),
        ));
      } on FormatException {
        // Continue scanning all cells; a malformed heading is not a period.
      }
    }

    if (candidates.isEmpty) {
      try {
        return _periodParser.parse(input.sheetTitle);
      } on FormatException {
        throw FormatException(
          'ไม่พบช่วงวันที่ที่อ่านได้ในตารางหรือชื่อชีต "${input.sheetTitle}"',
        );
      }
    }

    // Prefer the closest explicit roster-period heading to the date grid.
    // On equal distance, prefer a heading above the date row.
    candidates.sort((left, right) {
      final leftDistance = (left.row - dateHeaderRow).abs();
      final rightDistance = (right.row - dateHeaderRow).abs();
      final byDistance = leftDistance.compareTo(rightDistance);
      if (byDistance != 0) return byDistance;
      final leftBelow = left.row > dateHeaderRow ? 1 : 0;
      final rightBelow = right.row > dateHeaderRow ? 1 : 0;
      final byPosition = leftBelow.compareTo(rightBelow);
      if (byPosition != 0) return byPosition;
      return left.column.compareTo(right.column);
    });
    return candidates.first.period;
  }

  Map<int, int> _readDateColumns(
    ShiftParserInput input,
    int dateHeaderRow,
    List<String> warnings,
  ) {
    final result = <int, int>{};
    final headerCells = input.cells
        .where((cell) => cell.rowIndex == dateHeaderRow && cell.columnIndex > 0)
        .toList()
      ..sort((left, right) => left.columnIndex.compareTo(right.columnIndex));

    for (final cell in headerCells) {
      final value = cell.rawValue ?? cell.text;
      final day = _asDay(value);
      if (day == null) {
        if (value != null && value.toString().trim().isNotEmpty) {
          warnings.add(
            'ข้ามหัวคอลัมน์ ${cell.columnIndex + 1}: ไม่ใช่วันที่ 1-31',
          );
        }
        continue;
      }
      result[cell.columnIndex] = day;
    }
    return result;
  }

  int? _asDay(Object? value) {
    if (value is num && value % 1 != 0) return null;
    final day = value is num
        ? value.toInt()
        : int.tryParse(value?.toString().trim() ?? '');
    return day != null && day >= 1 && day <= 31 ? day : null;
  }

  DateTime _resolveDate({
    required int day,
    required DateTime start,
    required DateTime end,
  }) {
    final startMonthCandidate = DateTime(start.year, start.month, day);
    if (startMonthCandidate.year == start.year &&
        startMonthCandidate.month == start.month &&
        !startMonthCandidate.isBefore(start) &&
        !startMonthCandidate.isAfter(end)) {
      return startMonthCandidate;
    }

    final endMonthCandidate = DateTime(end.year, end.month, day);
    if (endMonthCandidate.year == end.year &&
        endMonthCandidate.month == end.month &&
        !endMonthCandidate.isBefore(start) &&
        !endMonthCandidate.isAfter(end)) {
      return endMonthCandidate;
    }
    throw FormatException('วันที่ $day อยู่นอกช่วงตารางเวร');
  }

  _RowDefinition? _parseRowLabel(String value) {
    final text = value.trim().replaceAll(RegExp(r'\\s+'), ' ');
    final period = text.endsWith('เช้า')
        ? 'เช้า'
        : text.endsWith('บ่าย')
        ? 'บ่าย'
        : text.endsWith('ดึก')
        ? 'ดึก'
        : null;
    if (period == null) return null;

    final base = text.substring(0, text.length - period.length).trim();
    if (RegExp(r'^P[1-4]$', caseSensitive: false).hasMatch(base)) {
      return _RowDefinition(
        category: 'Portable',
        period: period,
        slot: base.toUpperCase(),
      );
    }

    final normalized = base
        .replaceAll('CT IPD', 'CT-IPD')
        .replaceAll('CT ER', 'CT-ER');
    const supported = <String>{'IPD', 'CT-IPD', 'CT-ER', 'ER', 'GEN', 'CT'};
    if (!supported.contains(normalized)) return null;
    return _RowDefinition(
      category: normalized,
      period: period,
      slot: normalized,
    );
  }
}

class _RowDefinition {
  const _RowDefinition({
    required this.category,
    required this.period,
    required this.slot,
  });
  final String category;
  final String period;
  final String slot;
}
