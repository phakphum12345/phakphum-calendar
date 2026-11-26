import '../domain/a1_notation.dart';
import '../domain/monthly_roster_section.dart';
import '../../../models/shift.dart';
import '../../../domain/entities/shift_template.dart';
import '../../../services/shift_color_service.dart';
import '../domain/shift_parser_input.dart';
import '../domain/roster_layout_profile.dart';
import '../domain/thai_roster_period_parser.dart';

/// Parses repeated monthly roster blocks without requiring known section or
/// row labels. A block is discovered from its numeric date-header row.
class MonthlyRosterSectionParser {
  const MonthlyRosterSectionParser({
    this.periodParser = const ThaiRosterPeriodParser(),
    this.layoutProfile,
  });

  final ThaiRosterPeriodParser periodParser;
  final RosterLayoutProfile? layoutProfile;
  static const _thaiMonths = <String, int>{
    'มกราคม': 1,
    'กุมภาพันธ์': 2,
    'มีนาคม': 3,
    'เมษายน': 4,
    'พฤษภาคม': 5,
    'มิถุนายน': 6,
    'กรกฎาคม': 7,
    'สิงหาคม': 8,
    'กันยายน': 9,
    'ตุลาคม': 10,
    'พฤศจิกายน': 11,
    'ธันวาคม': 12,
  };

  /// Runs both phases in order: build date/row structure, then fill workers.
  MonthlyRosterParseReport parse(ShiftParserInput input) {
    final structure = generateDateStructure(input);
    return populateAssignments(input, structure);
  }

  /// Phase 1: identify each section, its own period, date columns, and shift rows.
  /// No worker names are read in this phase.
  MonthlyRosterParseReport generateDateStructure(ShiftParserInput input) {
    final cellsByRow = <int, List<dynamic>>{};
    for (final cell in input.cells) {
      cellsByRow.putIfAbsent(cell.rowIndex, () => []).add(cell);
    }

    final warnings = <String>[];
    final configuredHeaderRows = layoutProfile?.dateHeaderRows ?? const <int>[];
    final headerRows = (configuredHeaderRows.isNotEmpty
            ? configuredHeaderRows.where((row) =>
                cellsByRow.containsKey(row) &&
                _daysByColumn(cellsByRow[row] ?? const []).isNotEmpty)
            : cellsByRow.entries
                .where((entry) => _isDateHeaderRow(entry.value))
                .map((entry) => entry.key))
        .toSet()
        .toList()
      ..sort();
    if (configuredHeaderRows.isNotEmpty &&
        headerRows.length != configuredHeaderRows.toSet().length) {
      warnings.add('ไม่พบแถววันที่ตาม Layout Profile ครบทุกแถวที่กำหนด');
    }
    final sections = <MonthlyRosterSection>[];
    final tabPeriod = _tryParsePeriod(input.sheetTitle);
    final hasExplicitSectionPeriod = headerRows.any((row) {
      final title = _sectionTitle(
        input: input,
        cellsByRow: cellsByRow,
        headerRow: row,
      );
      return _tryParsePeriod(title) != null ||
          _hasExplicitRangeExpression(title);
    });

    for (var index = 0; index < headerRows.length; index++) {
      final headerRow = headerRows[index];
      final daysByColumn = _daysByColumn(cellsByRow[headerRow] ?? const []);
      final nextHeader = index + 1 < headerRows.length
          ? headerRows[index + 1]
          : (cellsByRow.keys.fold<int>(headerRow, (a, b) => a > b ? a : b) + 1);
      final title = _sectionTitle(
        input: input,
        cellsByRow: cellsByRow,
        headerRow: headerRow,
      );

      final explicitPeriod = _tryParsePeriod(title);
      final hasExplicitRange = _hasExplicitRangeExpression(title);
      // A worksheet month may fill in dates for genuinely undated sections
      // only when no section declares (or attempts to declare) its own range.
      // An invalid/ambiguous explicit range must never silently fall back to
      // the worksheet month, even when the sheet contains only one section.
      final canUseSheetFallback = !hasExplicitRange &&
          (headerRows.length == 1 ||
              (!hasExplicitSectionPeriod &&
                  _canUseSingleMonthTabFallback(tabPeriod, daysByColumn)));
      final period = explicitPeriod ?? (canUseSheetFallback ? tabPeriod : null);
      if (period == null) {
        const message =
            'ไม่พบช่วงวันที่เฉพาะของส่วนนี้; '
            'ไม่สามารถระบุช่วงวันที่ได้อย่างปลอดภัย และไม่ใช้เดือนจากชื่อชีตแทน';
        warnings.add('ส่วน "$title": $message');
        if (hasExplicitRange) {
          // Keep an explicitly malformed/conflicting section visible as
          // blocked evidence. Do not resolve dates or create assignments.
          sections.add(
            MonthlyRosterSection(
              title: title,
              headerRowIndex: headerRow,
              assignments: const [],
              sourceSpreadsheetId: input.spreadsheetId,
              sourceSheetId: input.sheetId,
              sourceSheetTitle: input.sheetTitle,
              dateAnomalies: const [
                MonthlyRosterDateAnomaly(
                  code: 'unresolved_period',
                  message: message,
                ),
              ],
            ),
          );
        }
        // A genuinely undated section is skipped rather than borrowing a
        // period from the sheet or another section.
        continue;
      }
      final start = period.start;
      final end = period.end;

      final datesByColumn = _resolveDatesByColumn(
        daysByColumn: daysByColumn,
        start: start,
        end: end,
        sectionTitle: title,
        warnings: warnings,
      );

      final dateAnomalies = _validateDateColumns(
        daysByColumn: daysByColumn,
        datesByColumn: datesByColumn,
        start: start,
        end: end,
      );
      warnings.addAll(
        dateAnomalies
            .where((anomaly) => anomaly.code != 'unresolved_date')
            .map(
              (anomaly) =>
                  'ต้องตรวจสอบวันที่ในส่วน "$title": ${anomaly.message}',
            ),
      );

      final dateColumns = <MonthlyRosterDateColumn>[
        for (final entry in datesByColumn.entries)
          MonthlyRosterDateColumn(
            columnIndex: entry.key,
            displayedDay: daysByColumn[entry.key]!,
            date: entry.value,
          ),
      ];
      final rosterRows = <MonthlyRosterRow>[];
      final configuredStart = layoutProfile?.dataStartRow;
      final configuredEnd = layoutProfile?.dataEndRow;
      final firstDataRow = configuredStart == null
          ? headerRow + 1
          : (configuredStart > headerRow ? configuredStart : headerRow + 1);
      final sectionEnd = configuredEnd == null ||
              configuredEnd < headerRow + 1
          ? nextHeader
          : (configuredEnd + 1 < nextHeader ? configuredEnd + 1 : nextHeader);
      var previousWasGen = false;
      for (var rowIndex = firstDataRow; rowIndex < sectionEnd; rowIndex++) {
        final rowCells = cellsByRow[rowIndex] ?? const [];
        final rowLabel = _rowLabelFor(rowCells, daysByColumn.keys);
        final hasAssignedWorker = rowCells.any(
          (cell) =>
              daysByColumn.containsKey(cell.columnIndex) &&
              (cell.text?.toString().trim().isNotEmpty ?? false),
        );
        final isGenAfternoon =
            rowLabel.isEmpty && previousWasGen && hasAssignedWorker;
        final effectiveRowLabel = isGenAfternoon ? 'GEN บ่าย' : rowLabel;
        previousWasGen = rowLabel
                .toUpperCase()
                .replaceAll(RegExp(r'[\s.\-_]+'), '') ==
            'GEN';
        if (effectiveRowLabel.isEmpty || _looksLikeHeading(effectiveRowLabel)) {
          continue;
        }
        rosterRows.add(
          MonthlyRosterRow(rowIndex: rowIndex, label: effectiveRowLabel),
        );
      }

      sections.add(
        MonthlyRosterSection(
          title: title,
          headerRowIndex: headerRow,
          assignments: const [],
          rowLabels: List.unmodifiable(rosterRows.map((row) => row.label)),
          dateColumns: List.unmodifiable(dateColumns),
          rosterRows: List.unmodifiable(rosterRows),
          startDate: start,
          endDate: end,
          sourceSpreadsheetId: input.spreadsheetId,
          sourceSheetId: input.sheetId,
          sourceSheetTitle: input.sheetTitle,
          dateAnomalies: List.unmodifiable(dateAnomalies),
        ),
      );
    }

    if (headerRows.isEmpty) {
      warnings.add('ไม่พบบล็อกตารางรายเดือนในชีต ${input.sheetTitle}');
    }
    return MonthlyRosterParseReport(
      sections: List.unmodifiable(sections),
      warnings: List.unmodifiable(warnings),
    );
  }

  /// Phase 2: populate the resolved date/shift grid with worker names.
  /// Dates are never recalculated or borrowed from another section here.
  MonthlyRosterParseReport populateAssignments(
    ShiftParserInput input,
    MonthlyRosterParseReport structure,
  ) {
    final cellsByCoordinate = <(int, int), dynamic>{
      for (final cell in input.cells)
        (cell.rowIndex, cell.columnIndex): cell,
    };
    final populatedSections = <MonthlyRosterSection>[];

    for (final section in structure.sections) {
      final assignments = <MonthlyRosterAssignment>[];
      final configuredNameColumns = layoutProfile?.nameColumns.toSet();
      for (final row in section.rosterRows) {
        for (final dateColumn in section.dateColumns) {
          if (configuredNameColumns != null &&
              configuredNameColumns.isNotEmpty &&
              !configuredNameColumns.contains(dateColumn.columnIndex)) {
            continue;
          }
          final workerCell =
              cellsByCoordinate[(row.rowIndex, dateColumn.columnIndex)];
          final worker = workerCell?.text?.toString().trim() ?? '';
          if (worker.isEmpty) continue;
          assignments.add(
            MonthlyRosterAssignment(
              sectionTitle: section.title,
              rowLabel: row.label,
              rowIndex: row.rowIndex,
              workerName: worker,
              date: dateColumn.date,
              sourceCell: A1Notation.fromZeroBased(
                rowIndex: row.rowIndex,
                columnIndex: dateColumn.columnIndex,
              ),
              backgroundColor: workerCell?.backgroundColor?.hex,
              spreadsheetId: input.spreadsheetId,
              sheetId: input.sheetId,
              sheetTitle: input.sheetTitle,
            ),
          );
        }
      }
      populatedSections.add(
        MonthlyRosterSection(
          title: section.title,
          headerRowIndex: section.headerRowIndex,
          assignments: List.unmodifiable(assignments),
          rowLabels: section.rowLabels,
          dateColumns: section.dateColumns,
          rosterRows: section.rosterRows,
          startDate: section.startDate,
          endDate: section.endDate,
          dateAnomalies: section.dateAnomalies,
          sourceSpreadsheetId: section.sourceSpreadsheetId,
          sourceSheetId: section.sourceSheetId,
          sourceSheetTitle: section.sourceSheetTitle,
        ),
      );
    }

    return MonthlyRosterParseReport(
      sections: List.unmodifiable(populatedSections),
      warnings: structure.warnings,
    );
  }

  ThaiRosterPeriod _parsePeriod(String text) {
    try {
      final period = periodParser.parse(text);

      return ThaiRosterPeriod(
        start: DateTime(
          period.start.year,
          period.start.month,
          period.start.day,
        ),
        end: DateTime(period.end.year, period.end.month, period.end.day),
      );
    } on FormatException {
      // Do not downgrade a malformed or ambiguous explicit range to a
      // month-only period. That would silently discard the dates in the title.
      if (_hasExplicitRangeExpression(text)) {
        rethrow;
      }

      final monthPattern = _thaiMonths.keys.join('|');
      final match = RegExp(
        '($monthPattern)\\s*(?:พ\.?\s*ศ\.?)?\\s*(\\d{2,4})',
      ).firstMatch(text);

      if (match == null) rethrow;

      var year = int.parse(match.group(2)!);

      if (year < 100) {
        year += 2500;
      }

      if (year >= 2400) {
        year -= 543;
      }

      final month = _thaiMonths[match.group(1)!]!;

      return ThaiRosterPeriod(
        start: DateTime(year, month, 1),
        end: DateTime(year, month + 1, 0),
      );
    }
  }

  ThaiRosterPeriod? _tryParsePeriod(String text) {
    try {
      return _parsePeriod(text);
    } on FormatException {
      return null;
    }
  }

  bool _hasExplicitRangeExpression(String text) {
    final rangeWithMonthsOnBothEnds = RegExp(
      r'(?<!\d)\d{1,2}\s*[ก-๙.]+(?:\s*\d{2,4})?\s*(?:-|ถึง|\bto\b)\s*\d{1,2}\s*[ก-๙.]+',
      caseSensitive: false,
    ).hasMatch(text);
    final compactSameMonthRange = RegExp(
      r'(?<!\d)\d{1,2}\s*(?:-|ถึง)\s*\d{1,2}\s*[ก-๙.]+(?:\s*(?:พ\.?\s*ศ\.?)?\s*\d{2,4})?(?!\d)',
    ).hasMatch(text);
    return rangeWithMonthsOnBothEnds || compactSameMonthRange;
  }

  bool _canUseSingleMonthTabFallback(
    ThaiRosterPeriod? period,
    Map<int, int> daysByColumn,
  ) {
    if (period == null ||
        period.start.year != period.end.year ||
        period.start.month != period.end.month ||
        daysByColumn.isEmpty) {
      return false;
    }

    final daysInMonth = period.end.day;
    final orderedDays = daysByColumn.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    var previousDay = 0;
    for (final entry in orderedDays) {
      final day = entry.value;
      if (day < 1 || day > daysInMonth || day <= previousDay) {
        return false;
      }
      previousDay = day;
    }
    return true;
  }

  bool _isDateHeaderRow(List<dynamic> cells) {
    final days = _daysByColumn(cells);
    if (days.length >= 7) return true;
    final hasDateLabel = cells.any((cell) {
      final value = cell.text?.toString().trim() ?? '';
      return value == 'วันที่' || value.contains('วันที่');
    });
    return hasDateLabel && days.isNotEmpty;
  }

  String _rowLabelFor(List<dynamic> cells, Iterable<int> dateColumns) {
    if (cells.isEmpty || dateColumns.isEmpty) return '';
    final configuredColumns = layoutProfile?.shiftLabelColumns ?? const <int>[];
    final firstDateColumn = dateColumns.reduce((a, b) => a < b ? a : b);
    final candidateColumns = configuredColumns.isNotEmpty
        ? configuredColumns
        : cells
            .where((cell) => cell.columnIndex < firstDateColumn)
            .map((cell) => cell.columnIndex)
            .toSet()
            .toList();
    final candidates = cells
        .where((cell) => candidateColumns.contains(cell.columnIndex))
        .where((cell) => cell.text?.toString().trim().isNotEmpty ?? false)
        .toList()
      ..sort((a, b) => b.columnIndex.compareTo(a.columnIndex));
    return candidates.isEmpty ? '' : candidates.first.text.toString().trim();
  }

  Map<int, int> _daysByColumn(List<dynamic> cells) {
    final result = <int, int>{};
    for (final cell in cells) {
      final value = cell.rawValue ?? cell.text;
      // Excel can represent a numeric cell as a double. Accept values such as
      // 1.0, but never truncate 1.5 to day 1: that would silently assign a
      // worker to the wrong calendar date.
      final day = value is num
          ? (value.isFinite && value == value.roundToDouble()
                ? value.toInt()
                : null)
          : int.tryParse(value?.toString().trim() ?? '');
      if (day != null && day >= 1 && day <= 31) {
        result[cell.columnIndex as int] = day;
      }
    }
    return result;
  }

  List<MonthlyRosterDateAnomaly> _validateDateColumns({
    required Map<int, int> daysByColumn,
    required Map<int, DateTime> datesByColumn,
    required DateTime start,
    required DateTime end,
  }) {
    final anomalies = <MonthlyRosterDateAnomaly>[];
    final columns = daysByColumn.keys.toList()..sort();
    final columnsByDay = <int, List<int>>{};
    for (final column in columns) {
      columnsByDay.putIfAbsent(daysByColumn[column]!, () => []).add(column);
    }

    // Repeated day numbers are valid across different months only when the
    // declared period actually contains that many occurrences of the day.
    for (final entry in columnsByDay.entries) {
      var possibleOccurrences = 0;
      for (
        var date = DateTime(start.year, start.month, start.day);
        !date.isAfter(end);
        date = DateTime(date.year, date.month, date.day + 1)
      ) {
        if (date.day == entry.key) possibleOccurrences++;
      }
      if (entry.value.length > 1 &&
          entry.value.length > possibleOccurrences) {
        anomalies.add(
          MonthlyRosterDateAnomaly(
            code: 'duplicate_day',
            displayedDay: entry.key,
            columnIndex: entry.value[1],
            message: 'พบเลขวันที่ ${entry.key} ซ้ำในช่วงวันที่ของส่วนนี้',
          ),
        );
      }
    }

    final expectedDayCount = DateTime.utc(
      end.year, end.month, end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays + 1;
    final completeRangeHeader = columns.length == expectedDayCount;
    // Treat near-full headers as complete enough to validate their endpoints;
    // short sample grids remain valid when they cover only part of a period.
    final nearCompleteRangeHeader =
        columns.length >= (expectedDayCount * 0.9).ceil();
    DateTime? previousResolved;
    for (final column in columns) {
      final resolved = datesByColumn[column];
      if (resolved == null) {
        if (!completeRangeHeader) {
          final day = daysByColumn[column]!;
          anomalies.add(
            MonthlyRosterDateAnomaly(
              code: 'unresolved_date',
              displayedDay: day,
              columnIndex: column,
              message: 'วันที่ $day ที่คอลัมน์ ${column + 1} เรียงผิดลำดับหรืออยู่นอกช่วงที่ระบุ',
            ),
          );
        }
        continue;
      }
      if (nearCompleteRangeHeader && previousResolved != null) {
        final gap = DateTime.utc(
          resolved.year, resolved.month, resolved.day,
        ).difference(DateTime.utc(
          previousResolved.year, previousResolved.month, previousResolved.day,
        )).inDays;
        if (gap > 1) {
          final missing = <String>[];
          for (var offset = 1; offset < gap; offset++) {
            final missingDate = DateTime(
              previousResolved.year,
              previousResolved.month,
              previousResolved.day + offset,
            );
            missing.add(_formatDate(missingDate));
          }
          anomalies.add(
            MonthlyRosterDateAnomaly(
              code: 'missing_dates',
              columnIndex: column,
              displayedDay: daysByColumn[column],
              message: 'ลำดับวันที่ขาด ${missing.join(', ')} ก่อนคอลัมน์ ${column + 1}',
            ),
          );
        } else if (gap <= 0) {
          anomalies.add(
            MonthlyRosterDateAnomaly(
              code: 'out_of_order',
              columnIndex: column,
              displayedDay: daysByColumn[column],
              message: 'วันที่ในคอลัมน์ ${column + 1} ไม่เรียงตามปฏิทิน',
            ),
          );
        }
      }
      previousResolved = resolved;
    }

    if (!completeRangeHeader && nearCompleteRangeHeader && columns.isNotEmpty) {
      final firstResolved = datesByColumn[columns.first];
      if (firstResolved == null ||
          firstResolved.year != start.year ||
          firstResolved.month != start.month ||
          firstResolved.day != start.day) {
        anomalies.add(
          MonthlyRosterDateAnomaly(
            code: 'missing_start_date',
            columnIndex: columns.first,
            displayedDay: daysByColumn[columns.first],
            message: 'หัวตารางขาดวันเริ่มต้น ${_formatDate(start)}',
          ),
        );
      }
      final lastResolved = datesByColumn[columns.last];
      if (lastResolved == null ||
          lastResolved.year != end.year ||
          lastResolved.month != end.month ||
          lastResolved.day != end.day) {
        anomalies.add(
          MonthlyRosterDateAnomaly(
            code: 'missing_end_date',
            columnIndex: columns.last,
            displayedDay: daysByColumn[columns.last],
            message: 'หัวตารางขาดวันสิ้นสุด ${_formatDate(end)}',
          ),
        );
      }
    }

    if (completeRangeHeader) {
      final resolvedKeys = datesByColumn.values
          .map((date) => '${date.year}-${date.month}-${date.day}')
          .toSet();
      final missing = <String>[];
      for (var offset = 0; offset < expectedDayCount; offset++) {
        final expected = DateTime(start.year, start.month, start.day + offset);
        final expectedKey = '${expected.year}-${expected.month}-${expected.day}';
        if (!resolvedKeys.contains(expectedKey)) {
          missing.add(_formatDate(expected));
        }
        final actualDay = daysByColumn[columns[offset]]!;
        if (actualDay != expected.day) {
          anomalies.add(
            MonthlyRosterDateAnomaly(
              code: 'day_sequence_mismatch',
              columnIndex: columns[offset],
              displayedDay: actualDay,
              message: 'คอลัมน์ ${columns[offset] + 1} แสดงวันที่ $actualDay แต่ตามช่วงที่ระบุควรเป็น ${expected.day}',
            ),
          );
        }
      }
      if (missing.isNotEmpty) {
        anomalies.add(
          MonthlyRosterDateAnomaly(
            code: 'missing_dates',
            message: 'ไม่สามารถจับคู่วันที่ในช่วงที่ระบุได้ครบ: ${missing.join(', ')}',
          ),
        );
      }
    }

    final unique = <String, MonthlyRosterDateAnomaly>{};
    for (final anomaly in anomalies) {
      final key = '${anomaly.code}|${anomaly.columnIndex ?? ''}|${anomaly.displayedDay ?? ''}|${anomaly.message}';
      unique.putIfAbsent(key, () => anomaly);
    }
    return List.unmodifiable(unique.values);
  }

  Map<int, DateTime> _resolveDatesByColumn({
    required Map<int, int> daysByColumn,
    required DateTime start,
    required DateTime end,
    required String sectionTitle,
    required List<String> warnings,
  }) {
    final result = <int, DateTime>{};
    final columns = daysByColumn.keys.toList()..sort();

    var cursor = DateTime(start.year, start.month, start.day);

    for (final column in columns) {
      final displayedDay = daysByColumn[column]!;

      final resolved = _resolveNextRosterDate(
        displayedDay: displayedDay,
        cursor: cursor,
        start: start,
        end: end,
      );

      if (resolved == null) {
        warnings.add(
          'วันที่ $displayedDay ในส่วน "$sectionTitle" '
          'อยู่นอกช่วง ${_formatDate(start)} - ${_formatDate(end)}',
        );
        continue;
      }

      result[column] = resolved;

      // Treat roster dates as calendar dates, not elapsed 24-hour durations.
      // Dart's local timezone has historical Bangkok offsets (e.g. year 1920),
      // so resolved.add(const Duration(days: 1)) can produce a cursor such as
      // 02/04/1920 00:17:56 while the next candidate is 02/04/1920 00:00:00.
      // Reconstructing the next calendar date avoids that historical timezone
      // comparison bug.
      cursor = DateTime(resolved.year, resolved.month, resolved.day + 1);
    }

    return result;
  }

  DateTime? _resolveNextRosterDate({
    required int displayedDay,
    required DateTime cursor,
    required DateTime start,
    required DateTime end,
  }) {
    var monthCursor = DateTime(cursor.year, cursor.month);
    final lastMonth = DateTime(end.year, end.month);

    while (!monthCursor.isAfter(lastMonth)) {
      final daysInMonth = DateTime(
        monthCursor.year,
        monthCursor.month + 1,
        0,
      ).day;

      if (displayedDay <= daysInMonth) {
        final candidate = DateTime(
          monthCursor.year,
          monthCursor.month,
          displayedDay,
        );

        if (!candidate.isBefore(cursor) &&
            !candidate.isBefore(start) &&
            !candidate.isAfter(end)) {
          return candidate;
        }
      }

      monthCursor = DateTime(monthCursor.year, monthCursor.month + 1);
    }

    return null;
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _sectionTitle({
    required ShiftParserInput input,
    required Map<int, List<dynamic>> cellsByRow,
    required int headerRow,
  }) {
    final candidates = <String>[];
    // Search back to the previous date grid, not a fixed number of rows.
    // Real workbooks often place section labels and merged headings far above
    // the date row, especially after inserted explanatory rows.
    for (var row = headerRow - 1; row >= 0; row--) {
      final rowCells = cellsByRow[row] ?? const [];
      if (_isDateHeaderRow(rowCells)) break;
      final texts = rowCells
          .map((cell) => cell.text?.toString().trim())
          .whereType<String>()
          .where((text) => text.isNotEmpty)
          .toList();
      candidates.addAll(texts);
    }
    // Some real workbooks place the explicit period heading immediately
    // below the numeric date row. Only consume consecutive period-heading
    // rows: scanning through assignment rows can accidentally borrow a later
    // section's heading when that section shares the same worksheet.
    final lastRow = cellsByRow.keys.fold<int>(
      headerRow,
      (current, row) => current > row ? current : row,
    );
    for (var row = headerRow + 1; row <= lastRow; row++) {
      final rowCells = cellsByRow[row] ?? const [];
      if (_isDateHeaderRow(rowCells)) break;
      final texts = rowCells
          .map((cell) => cell.text?.toString().trim())
          .whereType<String>()
          .where((text) => text.isNotEmpty)
          .toList();
      final hasPeriodHeading = texts.any(
        (text) => _tryParsePeriod(text) != null || text.contains('ประจำเดือน'),
      );
      if (!hasPeriodHeading) break;
      candidates.addAll(texts);
    }

    // An explicit month/range heading is authoritative even when the sheet
    // tab was named for a different month. Prefer the closest valid heading.
    final dated = candidates.where((text) => _tryParsePeriod(text) != null);
    if (dated.isNotEmpty) return dated.first;

    final periodTitle = candidates.where((text) => text.contains('ประจำเดือน'));
    if (periodTitle.isNotEmpty) return periodTitle.first;
    final descriptive = candidates.where(
      (text) => text.contains('เวร') || text.contains('คลิน'),
    );
    if (descriptive.isNotEmpty) return descriptive.first;
    return 'ส่วนตารางแถว ${headerRow + 1}';
  }

  bool _looksLikeHeading(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), '');
    return normalized == 'วันที่' ||
        normalized == 'เวร' ||
        normalized.contains('ประจำเดือน') ||
        _tryParsePeriod(value) != null;
  }
}


/// Converts recognizable monthly-grid assignments into calendar shifts.
/// This is the fallback when the legacy row parser cannot recognize a sheet.
class MonthlyRosterShiftAdapter {
  const MonthlyRosterShiftAdapter();

  List<Shift> parseForWorkers(
    MonthlyRosterParseReport report, {
    required Iterable<String> targetNames,
    Iterable<ShiftTemplate> shiftTemplates = const [],
  }) {
    final targets = targetNames
        .map(_compact)
        .where((value) => value.length >= 2)
        .toSet();
    if (targets.isEmpty) return const [];

    final shiftsByKey = <String, Shift>{};
    for (final section in report.sections) {
      if (section.hasBlockingDateAnomalies) continue;
      for (final assignment in section.assignments) {
        final worker = assignment.workerName.trim();
        final normalizedWorker = _compact(worker);
        if (worker.isEmpty || !targets.any(normalizedWorker.contains)) {
          continue;
        }
  
        final rule = _ruleForLabel(
          assignment.rowLabel,
          shiftTemplates: shiftTemplates,
        );
        if (rule == null) continue;
  
        final date = assignment.date;
        final start = DateTime(
          date.year,
          date.month,
          date.day,
          rule.startHour,
          rule.startMinute,
        );
        var end = DateTime(
          date.year,
          date.month,
          date.day,
          rule.endHour,
          rule.endMinute,
        );
        if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
  
        final sourceColor = _colorValue(assignment.backgroundColor);
        final colorMatch = ShiftColorService.classify(sourceColor);
        final shift = Shift(
          code: rule.code,
          rowLabel: assignment.rowLabel,
          assignedName: worker,
          start: start,
          end: end,
          sheetTitle: assignment.sheetTitle ?? assignment.sectionTitle,
          cell: assignment.sourceCell,
          category: colorMatch?.category ?? rule.category,
          sourceColorValue: sourceColor,
          sourceSpreadsheetId: assignment.spreadsheetId,
          sourceSheetId: assignment.sheetId,
        );
        shiftsByKey.putIfAbsent(shift.sourceIdentityKey, () => shift);
      }
    }

    return shiftsByKey.values.toList()
      ..sort((left, right) => left.start.compareTo(right.start));
  }

  /// Exposes the source of a row-label mapping without changing the
  /// legacy conversion behavior. A resolved rule is still review-only.
  MonthlyRosterShiftRuleResolution resolveRuleForLabel(
    String label, {
    Iterable<ShiftTemplate> shiftTemplates = const [],
  }) {
    final normalizedLabel = _compact(label);
    if (normalizedLabel.isEmpty) {
      return const MonthlyRosterShiftRuleResolution(
        status: MonthlyRosterShiftRuleStatus.emptyLabel,
      );
    }

    final templates = shiftTemplates.toList(growable: false);
    final matchingTemplates = templates.where((template) {
      if (!template.active) return false;
      return [
        template.code,
        template.name,
        template.shortName,
      ].any(
        (alias) =>
            alias.trim().isNotEmpty && _compact(alias) == normalizedLabel,
      );
    }).toList(growable: false);

    if (matchingTemplates.length > 1) {
      return const MonthlyRosterShiftRuleResolution(
        status: MonthlyRosterShiftRuleStatus.ambiguousTemplate,
      );
    }

    final rule = _ruleForLabel(
      label,
      shiftTemplates: templates,
    );
    if (rule == null) {
      return const MonthlyRosterShiftRuleResolution(
        status: MonthlyRosterShiftRuleStatus.unsupportedLabel,
      );
    }

    return MonthlyRosterShiftRuleResolution(
      status: matchingTemplates.isEmpty
          ? MonthlyRosterShiftRuleStatus.builtInRule
          : MonthlyRosterShiftRuleStatus.configuredTemplate,
      code: rule.code,
      startTime: Duration(
        hours: rule.startHour,
        minutes: rule.startMinute,
      ),
      endTime: Duration(
        hours: rule.endHour,
        minutes: rule.endMinute,
      ),
      category: rule.category,
      templateId: matchingTemplates.isEmpty
          ? null
          : matchingTemplates.single.id,
    );
  }

  _MonthlyShiftRule? _ruleForLabel(
    String label, {
    required Iterable<ShiftTemplate> shiftTemplates,
  }) {
    final normalizedLabel = _compact(label);
    final matchingTemplates = shiftTemplates.where((template) {
      if (!template.active) return false;
      return [
        template.code,
        template.name,
        template.shortName,
      ].any((alias) => alias.trim().isNotEmpty && _compact(alias) == normalizedLabel);
    }).toList(growable: false);

    // A configured template is authoritative. Never choose arbitrarily when
    // two active templates share an alias (for example, across departments).
    if (matchingTemplates.isNotEmpty) {
      if (matchingTemplates.length != 1) return null;
      final template = matchingTemplates.single;
      return _MonthlyShiftRule(
        code: template.code,
        startHour: template.startTime.inHours.remainder(24),
        startMinute: template.startTime.inMinutes.remainder(60),
        endHour: template.endTime.inHours.remainder(24),
        endMinute: template.endTime.inMinutes.remainder(60),
        category: ShiftCategory.own,
      );
    }

    final value = label
        .toUpperCase()
        .replaceAll(RegExp(r'[\s.\-_]+'), '');
    if (value == 'ER' || value == 'CT') {
      return _MonthlyShiftRule(
        code: 'U$value',
        startHour: 8,
        startMinute: 0,
        endHour: 16,
        endMinute: 0,
      );
    }
    if (value == 'GEN') {
      return const _MonthlyShiftRule(
        code: 'UG',
        startHour: 7,
        startMinute: 30,
        endHour: 12,
        endMinute: 0,
        category: ShiftCategory.clinic,
      );
    }
    if (value == 'GENบ่าย' || value == 'AG') {
      return const _MonthlyShiftRule(
        code: 'AG',
        startHour: 16,
        startMinute: 30,
        endHour: 20,
        endMinute: 0,
        category: ShiftCategory.clinic,
      );
    }
    if (value.contains('14ชั้น')) {
      return const _MonthlyShiftRule(
        code: 'U14',
        startHour: 7,
        startMinute: 0,
        endHour: 8,
        endMinute: 0,
      );
    }

    final p = RegExp(r'^P([1-4])(เช้า|บ่าย|ดึก)$').firstMatch(value);
    if (p != null) {
      final base = 'P${p.group(1)}';
      return switch (p.group(2)) {
        'เช้า' => _MonthlyShiftRule(
          code: 'U$base',
          startHour: 8,
          startMinute: 0,
          endHour: 16,
          endMinute: 0,
        ),
        'บ่าย' => _MonthlyShiftRule(
          code: 'A$base',
          startHour: 16,
          startMinute: 0,
          endHour: 0,
          endMinute: 0,
        ),
        'ดึก' => _MonthlyShiftRule(
          code: 'N$base',
          startHour: 0,
          startMinute: 0,
          endHour: 8,
          endMinute: 0,
        ),
        _ => null,
      };
    }

    for (final base in const ['CTIPD', 'CTER', 'IPD', 'ER']) {
      if (!value.startsWith(base)) continue;
      final period = value.substring(base.length);
      if (period == 'เช้า') {
        return _MonthlyShiftRule(
          code: 'U$base',
          startHour: 8,
          startMinute: 0,
          endHour: 16,
          endMinute: 0,
        );
      }
      if (period == 'บ่าย') {
        final overnight = base != 'ER';
        return _MonthlyShiftRule(
          code: 'A$base',
          startHour: 16,
          startMinute: 0,
          endHour: overnight ? 8 : 0,
          endMinute: 0,
        );
      }
      if (period == 'ดึก' && base == 'ER') {
        return const _MonthlyShiftRule(
          code: 'NER',
          startHour: 0,
          startMinute: 0,
          endHour: 8,
          endMinute: 0,
        );
      }
    }
    return null;
  }

  String _compact(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();

  int? _colorValue(String? hex) {
    if (hex == null) return null;
    final value = hex.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
    return int.parse('FF$value', radix: 16);
  }
}

class _MonthlyShiftRule {
  const _MonthlyShiftRule({
    required this.code,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.category = ShiftCategory.own,
  });

  final String code;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final ShiftCategory category;
}


enum MonthlyRosterShiftRuleStatus {
  configuredTemplate,
  builtInRule,
  ambiguousTemplate,
  unsupportedLabel,
  emptyLabel,
}

/// Review-only description of the existing monthly-grid shift mapping rule.
class MonthlyRosterShiftRuleResolution {
  const MonthlyRosterShiftRuleResolution({
    required this.status,
    this.code,
    this.startTime,
    this.endTime,
    this.category,
    this.templateId,
  });

  final MonthlyRosterShiftRuleStatus status;
  final String? code;
  final Duration? startTime;
  final Duration? endTime;
  final ShiftCategory? category;
  final String? templateId;

  bool get isResolved =>
      status == MonthlyRosterShiftRuleStatus.configuredTemplate ||
      status == MonthlyRosterShiftRuleStatus.builtInRule;

  bool get requiresHumanConfirmation => true;

  /// Mapping evidence alone never authorizes persistence.
  bool get canCommit => false;
}
