import '../domain/a1_notation.dart';
import '../domain/monthly_roster_section.dart';
import '../domain/normalized_cell.dart';
import '../domain/roster_grid_axis_mapping.dart';
import '../domain/shift_parser_input.dart';
import '../domain/thai_roster_period_parser.dart';

/// Discovers date-down / assignment-across tables without transposing the
/// worksheet. Detection is performed independently for each date-axis column.
class VerticalMonthlyRosterSectionParser {
  const VerticalMonthlyRosterSectionParser({
    this.periodParser = const ThaiRosterPeriodParser(),
  });

  final ThaiRosterPeriodParser periodParser;

  MonthlyRosterParseReport parse(
    ShiftParserInput input, {
    bool populateAssignments = true,
  }) {
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
    // Seven or more date cells are strong structural evidence. Shorter
    // vertical ranges are also valid, but require an explicit date-axis label
    // or a period heading in the worksheet; a month-like sheet tab alone is
    // not enough to reinterpret a short numeric ID column as calendar dates.
    final dateAxisColumns = <int>{};
    for (final entry in byColumn.entries) {
      final dateCells = entry.value.where(_isDateCell).toList(growable: false);
      if (dateCells.length >= 7) {
        dateAxisColumns.add(entry.key);
        continue;
      }
      if (dateCells.length < 2) continue;
      final firstDateRow = dateCells.first.rowIndex;
      final hasLocalPeriod = _periodEvidence(
        input: input,
        cells: input.cells,
        firstDateRow: firstDateRow,
        dateColumn: entry.key,
      )?.rowIndex != -1;
      if (hasLocalPeriod ||
          _hasDateAxisLabel(input.cells, entry.key, firstDateRow)) {
        dateAxisColumns.add(entry.key);
      }
    }

    for (final entry in byColumn.entries) {
      if (!dateAxisColumns.contains(entry.key)) continue;
      final dateCells = entry.value.where(_isDateCell).toList(growable: false);
      if (dateCells.length < 2) continue;

      // Separate stacked tables when a period heading occurs between date runs.
      final runs = <List<NormalizedCell>>[];
      var run = <NormalizedCell>[];
      for (final cell in dateCells) {
        final hasPeriodHeadingBetween = run.isNotEmpty && input.cells.any(
          (candidate) =>
              candidate.rowIndex > run.last.rowIndex &&
              candidate.rowIndex < cell.rowIndex &&
              _isPeriodEvidence(candidate.text ?? ''),
        );
        if (run.isNotEmpty &&
            (cell.rowIndex - run.last.rowIndex > 2 ||
                hasPeriodHeadingBetween)) {
          if (run.length >= 2) runs.add(run);
          run = <NormalizedCell>[];
        }
        run.add(cell);
      }
      if (run.length >= 2) runs.add(run);

      for (final axisCells in runs) {
        final firstRow = axisCells.first.rowIndex;
        final periodEvidence = _periodEvidence(
          input: input,
          cells: input.cells,
          firstDateRow: firstRow,
          dateColumn: entry.key,
        );
        final headerRow = _findHeaderRow(
          cells: input.cells,
          firstDateRow: firstRow,
          dateColumn: entry.key,
          minimumRow: 0,
        );
        final hasAssignmentShape = input.cells
            .where(
              (cell) =>
                  cell.rowIndex == headerRow &&
                  cell.columnIndex != entry.key &&
                  (cell.text?.trim().isNotEmpty ?? false) &&
                  !_isDateCell(cell) &&
                  !_isPeriodEvidence(cell.text ?? ''),
            )
            .any(
              (headerCell) => axisCells.any((dateCell) {
                final value =
                    byCoordinate[(dateCell.rowIndex, headerCell.columnIndex)]
                        ?.text;
                return value?.trim().isNotEmpty ?? false;
              }),
            );
        if (!hasAssignmentShape) continue;

        final explicitDates = axisCells
            .map(_explicitDate)
            .whereType<DateTime>()
            .toList(growable: false);
        final inferredPeriod = explicitDates.length == axisCells.length
            ? _periodFromExplicitDates(explicitDates)
            : null;
        final period = periodEvidence?.period ?? inferredPeriod;
        if (period == null) {
          warnings.add(
            'พบแกนวันที่แนวตั้งที่คอลัมน์ ${entry.key + 1} '
            'แต่ไม่พบช่วงวันที่ที่ยืนยันได้ใกล้แถว ${firstRow + 1}; '
            'ข้ามส่วนนี้โดยไม่เดาเดือนหรือปี',
          );
          continue;
        }
        final sectionTitle = periodEvidence?.title ??
            '${_formatDate(period.start)} - ${_formatDate(period.end)}';

        final resolvedDates = <int, DateTime>{};
        final anomalies = <MonthlyRosterDateAnomaly>[];
        var cursor = DateTime(
          period.start.year,
          period.start.month,
          period.start.day,
        );
        int? previousDisplayedDay;
        DateTime? previousResolvedDate;

        for (final cell in axisCells) {
          final explicitDate = _explicitDate(cell);
          final day = _day(cell) ?? explicitDate?.day;
          if (day == null) continue;
          final candidate = explicitDate ??
              _resolveNextDate(
                day: day,
                cursor: cursor,
                start: period.start,
                end: period.end,
              );
          final resolved = candidate != null &&
                  !candidate.isBefore(period.start) &&
                  !candidate.isAfter(period.end)
              ? candidate
              : null;

          if (resolved == null) {
            final isSingleMonth =
                period.start.year == period.end.year &&
                period.start.month == period.end.month;
            final anomalyCode = previousDisplayedDay == day
                ? 'duplicate_date'
                : isSingleMonth &&
                      previousDisplayedDay != null &&
                      day < previousDisplayedDay
                ? 'out_of_order'
                : 'unresolved_date';
            anomalies.add(
              MonthlyRosterDateAnomaly(
                code: anomalyCode,
                columnIndex: cell.columnIndex,
                rowIndex: cell.rowIndex,
                displayedDay: day,
                message: anomalyCode == 'duplicate_date'
                    ? 'พบวันที่ $day ซ้ำที่ ${_cellReference(cell)}'
                    : anomalyCode == 'out_of_order'
                    ? 'วันที่ $day ที่ ${_cellReference(cell)} ไม่เรียงตามปฏิทิน'
                    : 'ไม่สามารถจับคู่วันที่ $day ที่ ${_cellReference(cell)} '
                        'กับช่วงวันที่ที่ระบุได้',
              ),
            );
            previousDisplayedDay = day;
            continue;
          }

          if (previousResolvedDate != null &&
              resolved.isAtSameMomentAs(previousResolvedDate)) {
            anomalies.add(
              MonthlyRosterDateAnomaly(
                code: 'duplicate_date',
                columnIndex: cell.columnIndex,
                rowIndex: cell.rowIndex,
                displayedDay: day,
                message: 'พบวันที่ ${_formatDate(resolved)} ซ้ำที่ ${_cellReference(cell)}',
              ),
            );
          } else if (previousResolvedDate != null &&
              resolved.isBefore(previousResolvedDate)) {
            anomalies.add(
              MonthlyRosterDateAnomaly(
                code: 'out_of_order',
                columnIndex: cell.columnIndex,
                rowIndex: cell.rowIndex,
                displayedDay: day,
                message:
                    'วันที่ ${_formatDate(resolved)} ที่ ${_cellReference(cell)} ไม่เรียงตามปฏิทิน',
              ),
            );
          }
          resolvedDates[cell.rowIndex] = resolved;
          if (!resolved.isBefore(cursor)) {
            cursor = DateTime(resolved.year, resolved.month, resolved.day + 1);
          }
          previousDisplayedDay = day;
          previousResolvedDate = resolved;
        }

        final expectedDayCount = DateTime.utc(
          period.end.year,
          period.end.month,
          period.end.day,
        ).difference(
          DateTime.utc(period.start.year, period.start.month, period.start.day),
        ).inDays + 1;
        if (axisCells.length >= (expectedDayCount * 0.9).ceil() &&
            resolvedDates.isNotEmpty) {
          final orderedDates = resolvedDates.entries.toList()
            ..sort((left, right) => left.value.compareTo(right.value));
          final missing = <String>[];
          final firstResolved = orderedDates.first.value;
          final lastResolved = orderedDates.last.value;
          for (
            var date = DateTime(
              period.start.year,
              period.start.month,
              period.start.day,
            );
            date.isBefore(firstResolved);
            date = DateTime(date.year, date.month, date.day + 1)
          ) {
            missing.add(_isoDate(date));
          }
          for (var index = 1; index < orderedDates.length; index++) {
            final previous = orderedDates[index - 1].value;
            final current = orderedDates[index].value;
            final gap = DateTime.utc(
              current.year,
              current.month,
              current.day,
            ).difference(
              DateTime.utc(previous.year, previous.month, previous.day),
            ).inDays;
            for (var offset = 1; offset < gap; offset++) {
              missing.add(_isoDate(DateTime(
                previous.year,
                previous.month,
                previous.day + offset,
              )));
            }
          }
          for (
            var date = DateTime(
              lastResolved.year,
              lastResolved.month,
              lastResolved.day + 1,
            );
            !date.isAfter(period.end);
            date = DateTime(date.year, date.month, date.day + 1)
          ) {
            missing.add(_isoDate(date));
          }
          if (missing.isNotEmpty) {
            anomalies.add(
              MonthlyRosterDateAnomaly(
                code: 'missing_dates',
                columnIndex: entry.key,
                rowIndex: orderedDates.last.key,
                message: 'แกนวันที่แนวตั้งขาดวันที่ ${missing.join(', ')}',
              ),
            );
          }
        }

        final nextDateAxis = dateAxisColumns
            .where((column) => column > entry.key)
            .fold<int?>(
              null,
              (current, column) =>
                  current == null || column < current ? column : current,
            );
        final previousDateAxis = dateAxisColumns
            .where((column) => column < entry.key)
            .fold<int?>(
              null,
              (current, column) =>
                  current == null || column > current ? column : current,
            );
        final rightLabels = <int, String>{};
        final leftLabels = <int, String>{};
        for (final cell in input.cells.where(
          (cell) => cell.rowIndex == headerRow,
        )) {
          final label = cell.text?.trim() ?? '';
          if (label.isEmpty ||
              _isDateCell(cell) ||
              _isPeriodEvidence(label)) {
            continue;
          }
          final hasData = axisCells.any((dateCell) {
            final value =
                byCoordinate[(dateCell.rowIndex, cell.columnIndex)]?.text;
            return value?.trim().isNotEmpty ?? false;
          });
          if (!hasData) continue;
          if (cell.columnIndex > entry.key &&
              (nextDateAxis == null || cell.columnIndex < nextDateAxis)) {
            rightLabels[cell.columnIndex] = label;
          } else if (cell.columnIndex < entry.key &&
              (previousDateAxis == null ||
                  cell.columnIndex > previousDateAxis)) {
            leftLabels[cell.columnIndex] = label;
          }
        }

        final rightDistance = rightLabels.isEmpty
            ? null
            : rightLabels.keys.reduce((a, b) => a < b ? a : b) - entry.key;
        final leftDistance = leftLabels.isEmpty
            ? null
            : entry.key - leftLabels.keys.reduce((a, b) => a > b ? a : b);
        final labelsByColumn = <int, String>{};
        if (rightDistance != null &&
            leftDistance != null &&
            rightDistance == leftDistance) {
          warnings.add(
            'ไม่สามารถระบุด้านของหัวคอลัมน์งานสำหรับแกนวันที่ '
            '${entry.key + 1} ได้อย่างมั่นใจ; ต้องให้ผู้ตรวจเลือกแนวแกน',
          );
          continue;
        }
        if (rightDistance != null &&
            (leftDistance == null || rightDistance < leftDistance)) {
          labelsByColumn.addAll(rightLabels);
        } else if (leftDistance != null) {
          labelsByColumn.addAll(leftLabels);
        }
        if (labelsByColumn.isEmpty) {
          warnings.add(
            'พบแกนวันที่แนวตั้งที่คอลัมน์ ${entry.key + 1} '
            'แต่ไม่พบหัวคอลัมน์งานที่จับคู่กับข้อมูลได้',
          );
          continue;
        }

        final sourceStartRow = periodEvidence != null &&
                periodEvidence.rowIndex >= 0 &&
                periodEvidence.rowIndex < headerRow
            ? periodEvidence.rowIndex
            : headerRow;
        final rosterRows = <MonthlyRosterRow>[
          for (final entry in labelsByColumn.entries)
            MonthlyRosterRow(
              rowIndex: firstRow,
              columnIndex: entry.key,
              label: entry.value,
            ),
        ];
        final assignments = <MonthlyRosterAssignment>[];
        final dateColumns = <MonthlyRosterDateColumn>[];
        for (final dateCell in axisCells) {
          final date = resolvedDates[dateCell.rowIndex];
          if (date == null) continue;
          dateColumns.add(
            MonthlyRosterDateColumn(
              columnIndex: entry.key,
              rowIndex: dateCell.rowIndex,
              displayedDay: date.day,
              date: date,
            ),
          );
          if (!populateAssignments) continue;
          for (final labelEntry in labelsByColumn.entries) {
            final workerCell =
                byCoordinate[(dateCell.rowIndex, labelEntry.key)];
            final worker = workerCell?.text?.trim() ?? '';
            if (worker.isEmpty) continue;
            assignments.add(
              MonthlyRosterAssignment(
                sectionTitle: sectionTitle,
                rowLabel: labelEntry.value,
                rowIndex: dateCell.rowIndex,
                columnIndex: labelEntry.key,
                workerName: worker,
                date: date,
                sourceCell: A1Notation.fromZeroBased(
                  rowIndex: dateCell.rowIndex,
                  columnIndex: labelEntry.key,
                ),
                backgroundColor: workerCell?.backgroundColor?.hex,
                spreadsheetId: input.spreadsheetId,
                sheetId: input.sheetId,
                sheetTitle: input.sheetTitle,
              ),
            );
          }
        }

        if (dateColumns.isEmpty) {
          warnings.add(
            'พบตารางแนวตั้ง "$sectionTitle" แต่ไม่มีวันที่ที่จับคู่ได้',
          );
          continue;
        }
        sections.add(
          MonthlyRosterSection(
            title: sectionTitle,
            headerRowIndex: firstRow,
            orientation: RosterGridOrientation.datesDownRows,
            assignments: List.unmodifiable(assignments),
            rowLabels: List.unmodifiable(rosterRows.map((row) => row.label)),
            dateColumns: List.unmodifiable(dateColumns),
            rosterRows: List.unmodifiable(rosterRows),
            startDate: period.start,
            endDate: period.end,
            dateAnomalies: List.unmodifiable(anomalies),
            sourceSpreadsheetId: input.spreadsheetId,
            sourceSheetId: input.sheetId,
            sourceSheetTitle: input.sheetTitle,
            sourceCells: List.unmodifiable(
              input.cells.where(
                (cell) =>
                    cell.rowIndex >= sourceStartRow &&
                    cell.rowIndex <= axisCells.last.rowIndex,
              ),
            ),
          ),
        );
      }
    }

    return MonthlyRosterParseReport(
      sections: List.unmodifiable(sections),
      warnings: List.unmodifiable(warnings),
    );
  }

  String _cellReference(NormalizedCell cell) =>
      A1Notation.fromZeroBased(
        rowIndex: cell.rowIndex,
        columnIndex: cell.columnIndex,
      );

  bool _isDateCell(NormalizedCell cell) =>
      _day(cell) != null || _explicitDate(cell) != null;

  bool _hasDateAxisLabel(
    List<NormalizedCell> cells,
    int dateColumn,
    int firstDateRow,
  ) {
    return cells.any((cell) {
      if (cell.columnIndex != dateColumn ||
          cell.rowIndex >= firstDateRow) {
        return false;
      }
      final label = (cell.text ?? cell.rawValue?.toString() ?? '')
          .toLowerCase()
          .replaceAll(RegExp(r'[\\s._:/-]+'), '');
      return label == 'date' ||
          label == 'day' ||
          label == 'วันที่' ||
          label == 'วันปฏิบัติงาน' ||
          label == 'วันที่ปฏิบัติงาน';
    });
  }

  DateTime? _explicitDate(NormalizedCell cell) {
    final raw = cell.rawValue;
    if (raw is DateTime) {
      return DateTime(_normalizeYear(raw.year), raw.month, raw.day);
    }
    final text = cell.text?.trim() ?? raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;

    final iso = DateTime.tryParse(text);
    if (iso != null &&
        RegExp(r'^\d{4}-\d{1,2}-\d{1,2}').hasMatch(text)) {
      return DateTime(_normalizeYear(iso.year), iso.month, iso.day);
    }

    final ymd = RegExp(
      r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$',
    ).firstMatch(text);
    if (ymd != null) {
      return _checkedDate(
        year: _normalizeYear(int.parse(ymd.group(1)!)),
        month: int.parse(ymd.group(2)!),
        day: int.parse(ymd.group(3)!),
      );
    }

    final dmy = RegExp(
      r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})$',
    ).firstMatch(text);
    if (dmy != null) {
      return _checkedDate(
        year: _normalizeYear(int.parse(dmy.group(3)!)),
        month: int.parse(dmy.group(2)!),
        day: int.parse(dmy.group(1)!),
      );
    }

    if (RegExp(r'^\d{1,2}\s*[ก-๙.]+\s*\d{2,4}$').hasMatch(text)) {
      try {
        return periodParser.parse('$text - $text').start;
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  int _normalizeYear(int year) {
    if (year < 100) year += 2500;
    if (year >= 2400) year -= 543;
    return year;
  }

  DateTime? _checkedDate({
    required int year,
    required int month,
    required int day,
  }) {
    final value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return value;
  }

  ThaiRosterPeriod _periodFromExplicitDates(List<DateTime> dates) {
    final ordered = dates.toList()..sort();
    return ThaiRosterPeriod(start: ordered.first, end: ordered.last);
  }

  int? _day(NormalizedCell cell) {
    final value = cell.rawValue ?? cell.text;
    final parsed = value is num
        ? (value.isFinite && value == value.roundToDouble()
              ? value.toInt()
              : null)
        : int.tryParse(value?.toString().trim() ?? '');
    return parsed != null && parsed >= 1 && parsed <= 31 ? parsed : null;
  }

  int _findHeaderRow({
    required List<NormalizedCell> cells,
    required int firstDateRow,
    required int dateColumn,
    required int minimumRow,
  }) {
    for (
      var row = firstDateRow - 1;
      row >= minimumRow;
      row--
    ) {
      final hasOtherHeader = cells.any(
        (cell) =>
            cell.rowIndex == row &&
            cell.columnIndex != dateColumn &&
            (cell.text?.trim().isNotEmpty ?? false) &&
            !_isDateCell(cell) &&
            !_isPeriodEvidence(cell.text ?? ''),
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
    final candidates = <({String text, int distance, int rowIndex})>[];
    for (final cell in cells) {
      final text = cell.text?.trim() ?? '';
      if (text.isEmpty || _isDateCell(cell)) continue;
      final rowDistance = (cell.rowIndex - firstDateRow).abs();
      final distance =
          rowDistance * 100 + (cell.columnIndex - dateColumn).abs();
      candidates.add((text: text, distance: distance, rowIndex: cell.rowIndex));
    }
    candidates.add((text: input.sheetTitle, distance: 100000, rowIndex: -1));
    candidates.sort((a, b) => a.distance.compareTo(b.distance));

    for (final candidate in candidates) {
      try {
        final period = periodParser.parse(candidate.text);
        return _PeriodEvidence(candidate.text, period, candidate.rowIndex);
      } on FormatException {
        final monthPeriod = _parseMonthOnly(candidate.text);
        if (monthPeriod != null) {
          return _PeriodEvidence(candidate.text, monthPeriod, candidate.rowIndex);
        }
      }
    }
    return null;
  }

  ThaiRosterPeriod? _parseMonthOnly(String text) {
    const months = <String, int>{
      'มกราคม': 1,
      'ม.ค.': 1,
      'มค': 1,
      'กุมภาพันธ์': 2,
      'ก.พ.': 2,
      'กพ': 2,
      'มีนาคม': 3,
      'มี.ค.': 3,
      'มีค': 3,
      'เมษายน': 4,
      'เม.ย.': 4,
      'เมย': 4,
      'พฤษภาคม': 5,
      'พ.ค.': 5,
      'พค': 5,
      'มิถุนายน': 6,
      'มิ.ย.': 6,
      'มิย': 6,
      'กรกฎาคม': 7,
      'ก.ค.': 7,
      'กค': 7,
      'สิงหาคม': 8,
      'ส.ค.': 8,
      'สค': 8,
      'กันยายน': 9,
      'ก.ย.': 9,
      'กย': 9,
      'ตุลาคม': 10,
      'ต.ค.': 10,
      'ตค': 10,
      'พฤศจิกายน': 11,
      'พ.ย.': 11,
      'พย': 11,
      'ธันวาคม': 12,
      'ธ.ค.': 12,
      'ธค': 12,
    };
    final monthPattern = months.keys.map(RegExp.escape).join('|');
    final match = RegExp(
      '($monthPattern)\\s*(?:พ\\.?\\s*ศ\\.?\\s*)?(\\d{2,4})',
    ).firstMatch(text.replaceAll(' ', ''));
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

  bool _isPeriodEvidence(String text) {
    if (text.trim().isEmpty) return false;
    try {
      periodParser.parse(text);
      return true;
    } on FormatException {
      return _parseMonthOnly(text) != null;
    }
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

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _PeriodEvidence {
  const _PeriodEvidence(this.title, this.period, this.rowIndex);

  final String title;
  final ThaiRosterPeriod period;
  final int rowIndex;
}
