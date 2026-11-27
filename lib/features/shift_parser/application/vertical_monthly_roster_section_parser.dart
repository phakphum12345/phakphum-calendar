import '../domain/monthly_roster_section.dart';
import '../domain/normalized_cell.dart';
import '../domain/shift_parser_input.dart';
import '../domain/thai_roster_period_parser.dart';

/// Discovers date-down / assignment-across tables without transposing the
/// worksheet. Detection is performed independently for each date-axis column.
class VerticalMonthlyRosterSectionParser {
  const VerticalMonthlyRosterSectionParser({
    this.periodParser = const ThaiRosterPeriodParser(),
  });

  final ThaiRosterPeriodParser periodParser;

  MonthlyRosterParseReport parse(ShiftParserInput input) {
    final byColumn = <int, List<NormalizedCell>>{};
    final byCoordinate = <(int, int), NormalizedCell>{};
    for (final cell in input.cells) {
      byColumn.putIfAbsent(cell.columnIndex, () => []).add(cell);
      byCoordinate[(cell.rowIndex, cell.columnIndex)] = cell;
    }
    for (final cells in byColumn.values) {
      cells.sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
    }

    final sections = <MonthlyRosterSection>[];
    final warnings = <String>[];
    final occupiedDateAxes = <String>{};
    final dateAxisColumns = byColumn.entries
        .where((entry) => entry.value.where((cell) => _day(cell) != null).length >= 7)
        .map((entry) => entry.key)
        .toSet();

    for (final entry in byColumn.entries) {
      final numericDates = entry.value
          .where((cell) => _day(cell) != null)
          .toList(growable: false);
      if (numericDates.length < 7) continue;

      // A date axis is a run of actual worksheet rows, not a count of values
      // gathered from unrelated tables elsewhere in the same column.
      final runs = <List<NormalizedCell>>[];
      var run = <NormalizedCell>[];
      for (final cell in numericDates) {
        final hasPeriodHeadingBetween = run.isNotEmpty && input.cells.any(
          (candidate) =>
              candidate.rowIndex > run.last.rowIndex &&
              candidate.rowIndex < cell.rowIndex &&
              _isPeriodEvidence(candidate.text ?? ''),
        );
        if (run.isNotEmpty &&
            (cell.rowIndex - run.last.rowIndex > 2 ||
                hasPeriodHeadingBetween)) {
          if (run.length >= 7) runs.add(run);
          run = <NormalizedCell>[];
        }
        run.add(cell);
      }
      if (run.length >= 7) runs.add(run);

      for (final dateCells in runs) {
        final axisKey = '${entry.key}:${dateCells.first.rowIndex}:${dateCells.last.rowIndex}';
        if (!occupiedDateAxes.add(axisKey)) continue;
        final firstRow = dateCells.first.rowIndex;
        final periodEvidence = _periodEvidence(
          input: input,
          cells: input.cells,
          firstDateRow: firstRow,
          dateColumn: entry.key,
        );
        final period = periodEvidence?.period;
        if (period == null) {
          warnings.add(
            'พบแกนวันที่แนวตั้งที่คอลัมน์ ${entry.key + 1} '
            'แต่ไม่พบช่วงวันที่ที่ยืนยันได้ใกล้แถว ${firstRow + 1}; '
            'ข้ามส่วนนี้โดยไม่เดาเดือนหรือปี',
          );
          continue;
        }

        final resolvedDates = <int, DateTime>{};
        final anomalies = <MonthlyRosterDateAnomaly>[];
        var cursor = DateTime(period.start.year, period.start.month, period.start.day);
        for (final cell in dateCells) {
          final day = _day(cell)!;
          final resolved = _resolveNextDate(
            day: day,
            cursor: cursor,
            start: period.start,
            end: period.end,
          );
          if (resolved == null) {
            anomalies.add(
              MonthlyRosterDateAnomaly(
                code: 'unresolved_date',
                columnIndex: cell.columnIndex,
                rowIndex: cell.rowIndex,
                displayedDay: day,
                message: 'ไม่สามารถจับคู่วันที่ $day ที่ ${cell.a1} '
                    'กับช่วงวันที่ที่ระบุได้',
              ),
            );
            continue;
          }
          resolvedDates[cell.rowIndex] = resolved;
          cursor = DateTime(resolved.year, resolved.month, resolved.day + 1);
        }

        final expectedDayCount = DateTime.utc(
          period.end.year,
          period.end.month,
          period.end.day,
        ).difference(DateTime.utc(
          period.start.year,
          period.start.month,
          period.start.day,
        )).inDays + 1;
        if (dateCells.length >= (expectedDayCount * 0.9).ceil()) {
          final orderedDates = resolvedDates.entries.toList()
            ..sort((left, right) => left.value.compareTo(right.value));
          for (var index = 1; index < orderedDates.length; index++) {
            final previous = orderedDates[index - 1].value;
            final current = orderedDates[index].value;
            final gap = DateTime.utc(
              current.year,
              current.month,
              current.day,
            ).difference(DateTime.utc(
              previous.year,
              previous.month,
              previous.day,
            )).inDays;
            if (gap > 1) {
              final missing = <String>[
                for (var offset = 1; offset < gap; offset++)
                  DateTime(
                    previous.year,
                    previous.month,
                    previous.day + offset,
                  ).toIso8601String().substring(0, 10),
              ];
              anomalies.add(
                MonthlyRosterDateAnomaly(
                  code: 'missing_dates',
                  columnIndex: entry.key,
                  rowIndex: orderedDates[index].key,
                  message: 'แกนวันที่แนวตั้งขาดวันที่ ${missing.join(', ')}',
                ),
              );
            }
          }
        }

        final headerRow = _findHeaderRow(
          cells: input.cells,
          firstDateRow: firstRow,
          dateColumn: entry.key,
        );
        final nextDateAxis = dateAxisColumns
            .where((column) => column > entry.key)
            .fold<int?>(null, (current, column) =>
                current == null || column < current ? column : current);
        final labelsByColumn = <int, String>{};
        for (final cell in input.cells.where((cell) => cell.rowIndex == headerRow)) {
          if (cell.columnIndex <= entry.key ||
              (nextDateAxis != null && cell.columnIndex >= nextDateAxis)) {
            continue;
          }
          final label = cell.text?.trim() ?? '';
          if (label.isNotEmpty && _day(cell) == null) {
            final hasData = dateCells.any((dateCell) {
              final value = byCoordinate[(dateCell.rowIndex, cell.columnIndex)]?.text;
              return value?.trim().isNotEmpty ?? false;
            });
            if (hasData) labelsByColumn[cell.columnIndex] = label;
          }
        }
        // Some workbooks put the date axis at the right edge. Only use
        // columns to its left when there is a single candidate date axis;
        // otherwise a neighbouring table could be mistaken for this one.
        if (labelsByColumn.isEmpty && dateAxisColumns.length == 1) {
          for (final cell in input.cells.where((cell) => cell.rowIndex == headerRow)) {
            if (cell.columnIndex >= entry.key) continue;
            final label = cell.text?.trim() ?? '';
            if (label.isEmpty || _day(cell) != null) continue;
            final hasData = dateCells.any((dateCell) {
              final value = byCoordinate[(dateCell.rowIndex, cell.columnIndex)]?.text;
              return value?.trim().isNotEmpty ?? false;
            });
            if (hasData) labelsByColumn[cell.columnIndex] = label;
          }
        }

        final rosterRows = <MonthlyRosterRow>[];
        final assignments = <MonthlyRosterAssignment>[];
        final dateColumns = <MonthlyRosterDateColumn>[];
        for (final dateCell in dateCells) {
          final date = resolvedDates[dateCell.rowIndex];
          if (date == null) continue;
          dateColumns.add(
            MonthlyRosterDateColumn(
              columnIndex: entry.key,
              rowIndex: dateCell.rowIndex,
              displayedDay: _day(dateCell)!,
              date: date,
            ),
          );
          for (final labelEntry in labelsByColumn.entries) {
            final workerCell = byCoordinate[(dateCell.rowIndex, labelEntry.key)];
            final worker = workerCell?.text?.trim() ?? '';
            if (worker.isEmpty) continue;
            assignments.add(
              MonthlyRosterAssignment(
                sectionTitle: periodEvidence!.title,
                rowLabel: labelEntry.value,
                rowIndex: dateCell.rowIndex,
                columnIndex: labelEntry.key,
                workerName: worker,
                date: date,
                sourceCell: workerCell!.a1,
                backgroundColor: workerCell.backgroundColor?.hex,
                spreadsheetId: input.spreadsheetId,
                sheetId: input.sheetId,
                sheetTitle: input.sheetTitle,
              ),
            );
          }
        }

        for (final column in labelsByColumn.keys) {
          final hasAssignments = assignments.any((item) => item.columnIndex == column);
          if (hasAssignments) {
            rosterRows.add(
              MonthlyRosterRow(
                rowIndex: firstRow,
                columnIndex: column,
                label: labelsByColumn[column]!,
              ),
            );
          }
        }

        if (dateColumns.isEmpty) {
          warnings.add(
            'พบตารางแนวตั้ง "${periodEvidence!.title}" แต่ไม่มีวันที่ที่จับคู่ได้',
          );
          continue;
        }
        sections.add(
          MonthlyRosterSection(
            title: periodEvidence!.title,
            headerRowIndex: firstRow,
            orientation: RosterGridOrientation.datesDownRows,
            assignments: List.unmodifiable(assignments),
            rowLabels: List.unmodifiable(rosterRows.map((row) => row.label)),
            dateColumns: List.unmodifiable(dateColumns),
            rosterRows: List.unmodifiable(rosterRows),
            startDate: period.start,
            endDate: period.end,
            dateAnomalies: List.unmodifiable(anomalies),
          ),
        );
      }
    }

    return MonthlyRosterParseReport(
      sections: List.unmodifiable(sections),
      warnings: List.unmodifiable(warnings),
    );
  }

  int? _day(NormalizedCell cell) {
    final value = cell.rawValue ?? cell.text;
    final parsed = value is num
        ? (value.isFinite && value == value.roundToDouble() ? value.toInt() : null)
        : int.tryParse(value?.toString().trim() ?? '');
    return parsed != null && parsed >= 1 && parsed <= 31 ? parsed : null;
  }

  int _findHeaderRow({
    required List<NormalizedCell> cells,
    required int firstDateRow,
    required int dateColumn,
  }) {
    for (var row = firstDateRow - 1; row >= 0 && row >= firstDateRow - 8; row--) {
      final hasOtherHeader = cells.any(
        (cell) =>
            cell.rowIndex == row &&
            cell.columnIndex != dateColumn &&
            (cell.text?.trim().isNotEmpty ?? false) &&
            _day(cell) == null,
      );
      if (hasOtherHeader) return row;
    }
    return firstDateRow - 1;
  }

  _PeriodEvidence? _periodEvidence({
    required ShiftParserInput input,
    required List<NormalizedCell> cells,
    required int firstDateRow,
    required int dateColumn,
  }) {
    final candidates = <({String text, int distance})>[];
    for (final cell in cells) {
      final text = cell.text?.trim() ?? '';
      if (text.isEmpty) continue;
      final rowDistance = (cell.rowIndex - firstDateRow).abs();
      if (rowDistance > 12) continue;
      final distance = rowDistance * 100 + (cell.columnIndex - dateColumn).abs();
      candidates.add((text: text, distance: distance));
    }
    candidates.add((text: input.sheetTitle, distance: 100000));
    candidates.sort((a, b) => a.distance.compareTo(b.distance));

    for (final candidate in candidates) {
      try {
        final period = periodParser.parse(candidate.text);
        return _PeriodEvidence(candidate.text, period);
      } on FormatException {
        final monthPeriod = _parseMonthOnly(candidate.text);
        if (monthPeriod != null) {
          return _PeriodEvidence(candidate.text, monthPeriod);
        }
      }
    }
    return null;
  }

  bool _isPeriodEvidence(String text) {
    if (text.trim().isEmpty) return false;
    try {
      periodParser.parse(text);
      return true;
    } on FormatException {
      return _parseMonthOnly(text) != null;
    }
  }

  ThaiRosterPeriod? _parseMonthOnly(String text) {
    const months = <String, int>{
      'มกราคม': 1, 'ม.ค.': 1, 'มค': 1,
      'กุมภาพันธ์': 2, 'ก.พ.': 2, 'กพ': 2,
      'มีนาคม': 3, 'มี.ค.': 3, 'มีค': 3,
      'เมษายน': 4, 'เม.ย.': 4, 'เมย': 4,
      'พฤษภาคม': 5, 'พ.ค.': 5, 'พค': 5,
      'มิถุนายน': 6, 'มิ.ย.': 6, 'มิย': 6,
      'กรกฎาคม': 7, 'ก.ค.': 7, 'กค': 7,
      'สิงหาคม': 8, 'ส.ค.': 8, 'สค': 8,
      'กันยายน': 9, 'ก.ย.': 9, 'กย': 9,
      'ตุลาคม': 10, 'ต.ค.': 10, 'ตค': 10,
      'พฤศจิกายน': 11, 'พ.ย.': 11, 'พย': 11,
      'ธันวาคม': 12, 'ธ.ค.': 12, 'ธค': 12,
    };
    final monthPattern = months.keys.map(RegExp.escape).join('|');
    final match = RegExp('($monthPattern)\\s*(?:พ\\.?\\s*ศ\\.?\\s*)?(\\d{2,4})')
        .firstMatch(text.replaceAll(' ', ''));
    if (match == null) return null;
    final month = months[match.group(1)]!;
    var year = int.parse(match.group(2)!);
    if (year < 100) year += 2500;
    if (year >= 2400) year -= 543;
    return ThaiRosterPeriod(
      start: DateTime(year, month, 1),
      end: DateTime(year, month + 1, 0),
    );
  }

  DateTime? _resolveNextDate({
    required int day,
    required DateTime cursor,
    required DateTime start,
    required DateTime end,
  }) {
    var month = DateTime(cursor.year, cursor.month);
    final lastMonth = DateTime(end.year, end.month);
    while (!month.isAfter(lastMonth)) {
      final candidate = DateTime(month.year, month.month, day);
      if (candidate.day == day &&
          !candidate.isBefore(cursor) &&
          !candidate.isBefore(start) &&
          !candidate.isAfter(end)) {
        return candidate;
      }
      month = DateTime(month.year, month.month + 1);
    }
    return null;
  }
}

class _PeriodEvidence {
  const _PeriodEvidence(this.title, this.period);
  final String title;
  final ThaiRosterPeriod period;
}
