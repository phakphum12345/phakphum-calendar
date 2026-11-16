import '../domain/a1_notation.dart';
import '../domain/monthly_roster_section.dart';
import '../../../models/shift.dart';
import '../../../services/shift_color_service.dart';
import '../domain/shift_parser_input.dart';
import '../domain/thai_roster_period_parser.dart';

/// Parses repeated monthly roster blocks without requiring known section or
/// row labels. A block is discovered from its numeric date-header row.
class MonthlyRosterSectionParser {
  const MonthlyRosterSectionParser({
    this.periodParser = const ThaiRosterPeriodParser(),
  });

  final ThaiRosterPeriodParser periodParser;
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

    final headerRows =
        cellsByRow.entries
            .where((entry) => _daysByColumn(entry.value).length >= 7)
            .map((entry) => entry.key)
            .toList()
          ..sort();
    final sections = <MonthlyRosterSection>[];
    final warnings = <String>[];

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
      final sheetFallback = headerRows.length == 1
          ? _tryParsePeriod(input.sheetTitle)
          : null;
      final period = explicitPeriod ?? sheetFallback;
      if (period == null) {
        warnings.add(
          'ไม่พบช่วงวันที่เฉพาะของส่วน "$title"; '
          'ไม่ใช้เดือนจากชื่อชีตแทนเพื่อป้องกันวันที่ข้ามเดือนไม่ถูกต้อง',
        );
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

      final dateColumns = <MonthlyRosterDateColumn>[
        for (final entry in datesByColumn.entries)
          MonthlyRosterDateColumn(
            columnIndex: entry.key,
            displayedDay: daysByColumn[entry.key]!,
            date: entry.value,
          ),
      ];
      final rosterRows = <MonthlyRosterRow>[];
      for (var rowIndex = headerRow + 1; rowIndex < nextHeader; rowIndex++) {
        final labelCells = (cellsByRow[rowIndex] ?? const [])
            .where((cell) => cell.columnIndex == 0);
        final rowLabel = labelCells.isEmpty
            ? ''
            : labelCells.first.text?.toString().trim() ?? '';
        if (rowLabel.isEmpty || _looksLikeHeading(rowLabel)) continue;
        rosterRows.add(MonthlyRosterRow(rowIndex: rowIndex, label: rowLabel));
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
      for (final row in section.rosterRows) {
        for (final dateColumn in section.dateColumns) {
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
      final monthPattern = _thaiMonths.keys.join('|');
      final match = RegExp(
        '($monthPattern)\\s*(?:พ\\.?\\s*ศ\\.?)?\\s*(\\d{2,4})',
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

  Map<int, int> _daysByColumn(List<dynamic> cells) {
    final result = <int, int>{};
    for (final cell in cells) {
      if (cell.columnIndex == 0) continue;
      final value = cell.rawValue ?? cell.text;
      final day = value is num
          ? value.toInt()
          : int.tryParse(value?.toString().trim() ?? '');
      if (day != null && day >= 1 && day <= 31) {
        result[cell.columnIndex as int] = day;
      }
    }
    return result;
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
      if (_daysByColumn(rowCells).length >= 7) break;
      final texts = rowCells
          .map((cell) => cell.text?.toString().trim())
          .whereType<String>()
          .where((text) => text.isNotEmpty)
          .toList();
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
    return normalized == 'วันที่' || normalized == 'เวร';
  }
}


/// Converts recognizable monthly-grid assignments into calendar shifts.
/// This is the fallback when the legacy row parser cannot recognize a sheet.
class MonthlyRosterShiftAdapter {
  const MonthlyRosterShiftAdapter();

  List<Shift> parseForWorkers(
    MonthlyRosterParseReport report, {
    required Iterable<String> targetNames,
  }) {
    final targets = targetNames
        .map(_compact)
        .where((value) => value.length >= 2)
        .toSet();
    if (targets.isEmpty) return const [];

    final shiftsByKey = <String, Shift>{};
    for (final assignment in report.assignments) {
      final worker = assignment.workerName.trim();
      final normalizedWorker = _compact(worker);
      if (worker.isEmpty || !targets.any(normalizedWorker.contains)) {
        continue;
      }

      final rule = _ruleForLabel(assignment.rowLabel);
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

    return shiftsByKey.values.toList()
      ..sort((left, right) => left.start.compareTo(right.start));
  }

  _MonthlyShiftRule? _ruleForLabel(String label) {
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
