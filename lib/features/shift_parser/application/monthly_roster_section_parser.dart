import '../domain/a1_notation.dart';
import '../domain/monthly_roster_section.dart';
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

  MonthlyRosterParseReport parse(ShiftParserInput input) {
    final cellsByRow = <int, List<dynamic>>{};
    final cellsByCoordinate = <(int, int), dynamic>{};
    for (final cell in input.cells) {
      cellsByRow.putIfAbsent(cell.rowIndex, () => []).add(cell);
      cellsByCoordinate[(cell.rowIndex, cell.columnIndex)] = cell;
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

      DateTime start;
      DateTime end;
      try {
        final period = _parsePeriod('$title ${input.sheetTitle}');
        start = period.start;
        end = period.end;
      } on FormatException {
        warnings.add('ไม่พบช่วงเดือนของส่วน "$title"');
        continue;
      }

      final datesByColumn = _resolveDatesByColumn(
        daysByColumn: daysByColumn,
        start: start,
        end: end,
        sectionTitle: title,
        warnings: warnings,
      );

      final assignments = <MonthlyRosterAssignment>[];
      for (var rowIndex = headerRow + 1; rowIndex < nextHeader; rowIndex++) {
        final rowLabel =
            cellsByCoordinate[(rowIndex, 0)]?.text?.toString().trim() ?? '';
        if (rowLabel.isEmpty || _looksLikeHeading(rowLabel)) continue;

        for (final entry in datesByColumn.entries) {
          final workerCell = cellsByCoordinate[(rowIndex, entry.key)];
          final worker = workerCell?.text?.toString().trim() ?? '';
          if (worker.isEmpty) continue;
          assignments.add(
            MonthlyRosterAssignment(
              sectionTitle: title,
              rowLabel: rowLabel,
              rowIndex: rowIndex,
              workerName: worker,
              date: entry.value,
              sourceCell: A1Notation.fromZeroBased(
                rowIndex: rowIndex,
                columnIndex: entry.key,
              ),
              backgroundColor: workerCell?.backgroundColor?.hex,
            ),
          );
        }
      }

      sections.add(
        MonthlyRosterSection(
          title: title,
          headerRowIndex: headerRow,
          assignments: List.unmodifiable(assignments),
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

  ThaiRosterPeriod _parsePeriod(String text) {
    try {
      return periodParser.parse(text);
    } on FormatException {
      final monthPattern = _thaiMonths.keys.join('|');
      final match = RegExp(
        '($monthPattern)\\s*(?:พ\\.?\\s*ศ\\.?)?\\s*(\\d{2,4})',
      ).firstMatch(text);
      if (match == null) rethrow;
      var year = int.parse(match.group(2)!);
      if (year < 100) year += 2500;
      if (year >= 2400) year -= 543;
      final month = _thaiMonths[match.group(1)!]!;
      return ThaiRosterPeriod(
        start: DateTime(year, month),
        end: DateTime(year, month + 1, 0),
      );
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
      final resolved = _nextDateWithDay(
        displayedDay: displayedDay,
        cursor: cursor,
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
      cursor = resolved.add(const Duration(days: 1));
    }

    return result;
  }

  DateTime? _nextDateWithDay({
    required int displayedDay,
    required DateTime cursor,
    required DateTime end,
  }) {
    var monthCursor = DateTime(cursor.year, cursor.month);
    final lastMonth = DateTime(end.year, end.month);

    while (!monthCursor.isAfter(lastMonth)) {
      final candidate = DateTime(
        monthCursor.year,
        monthCursor.month,
        displayedDay,
      );
      final isValidDay =
          candidate.year == monthCursor.year &&
          candidate.month == monthCursor.month &&
          candidate.day == displayedDay;

      if (isValidDay &&
          !candidate.isBefore(cursor) &&
          !candidate.isAfter(end)) {
        return candidate;
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
    for (var row = headerRow - 1; row >= 0 && row >= headerRow - 5; row--) {
      final texts = (cellsByRow[row] ?? const [])
          .map((cell) => cell.text?.toString().trim())
          .whereType<String>()
          .where((text) => text.isNotEmpty)
          .toList();
      candidates.addAll(texts);
    }
    final periodTitle = candidates.where((text) => text.contains('ประจำเดือน'));
    if (periodTitle.isNotEmpty) return periodTitle.first;
    final descriptive = candidates.where(
      (text) => text.contains('เวร') || text.contains('คลิน'),
    );
    if (descriptive.isNotEmpty) return descriptive.first;
    return '${input.sheetTitle} แถว ${headerRow + 1}';
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
        sheetTitle: assignment.sectionTitle,
        cell: assignment.sourceCell,
        category: colorMatch?.category ?? rule.category,
        sourceColorValue: sourceColor,
      );
      shiftsByKey.putIfAbsent(shift.sourceKey, () => shift);
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
      final base = 'P\${p.group(1)}';
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
