class ThaiRosterPeriod {
  const ThaiRosterPeriod({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class ThaiRosterPeriodParser {
  const ThaiRosterPeriodParser();

  static const Map<String, int> _months = <String, int>{
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

  ThaiRosterPeriod parse(String text) {
    final normalized = _normalizeText(text);

    final compactSameMonth = _tryParseCompactSameMonth(
      normalized,
      source: text,
    );
    if (compactSameMonth != null) return compactSameMonth;

    final explicitRange = _tryParseExplicitDateRange(
      normalized,
      source: text,
    );
    if (explicitRange != null) return explicitRange;

    final tokens = RegExp(
      r'(?<!\d)(0?[1-9]|[12]\d|3[01])\s*([ก-๙.]+)(?:\s*(\d{2,4}))?(?!\d)',
    ).allMatches(normalized).toList();

    if (tokens.length >= 2) {
      final startToken = _readToken(tokens.first);
      final endToken = _readToken(tokens[1]);
      return _buildPeriod(
        startToken: startToken,
        endToken: endToken,
        source: text,
      );
    }

    final contextualRange = _tryParseBareRangeWithContext(
      normalized,
      source: text,
    );
    if (contextualRange != null) return contextualRange;

    throw FormatException('ไม่พบช่วงวันที่ในข้อความ: $text');
  }

  String _normalizeText(String text) {
    return text
        .replaceAll('พ.ศ.', '')
        .replaceAll('พ.ศ', '')
        .replaceAll('พศ.', '')
        .replaceAll('พศ', '')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  ThaiRosterPeriod? _tryParseExplicitDateRange(
    String text, {
    required String source,
  }) {
    final tokens = RegExp(
      r'(?<!\d)(0?[1-9]|[12]\d|3[01])\s*([ก-๙.]+)(?:\s*(\d{2,4}))?(?!\d)',
    ).allMatches(text).toList();
    final ranges = <(RegExpMatch, RegExpMatch)>[];

    for (var index = 0; index + 1 < tokens.length; index++) {
      final start = tokens[index];
      final end = tokens[index + 1];
      final between = text.substring(start.end, end.start);
      if (RegExp(r'(?:-|ถึง|\bto\b)', caseSensitive: false)
          .hasMatch(between)) {
        ranges.add((start, end));
      }
    }

    if (ranges.isEmpty) return null;
    if (ranges.length > 1) {
      throw FormatException(
        'ช่วงวันที่ "$source" มีช่วงวันที่ที่ระบุไว้อย่างชัดเจนมากกว่าหนึ่งช่วง',
      );
    }

    return _buildPeriod(
      startToken: _readToken(ranges.single.$1),
      endToken: _readToken(ranges.single.$2),
      source: source,
    );
  }

  ThaiRosterPeriod? _tryParseCompactSameMonth(
    String text, {
    required String source,
  }) {
    final match = RegExp(
      r'(?<!\d)(0?[1-9]|[12]\d|3[01])\s*(?:-|ถึง)\s*(0?[1-9]|[12]\d|3[01])\s*([ก-๙.]+)\s*(\d{2,4})(?!\d)',
    ).firstMatch(text);
    if (match == null) return null;

    final month = _resolveMonth(match.group(3)!);
    final year = _normalizeYear(int.parse(match.group(4)!));
    return _buildPeriod(
      startToken: _DateToken(
        day: int.parse(match.group(1)!),
        month: month,
        year: year,
      ),
      endToken: _DateToken(
        day: int.parse(match.group(2)!),
        month: month,
        year: year,
      ),
      source: source,
    );
  }

  ThaiRosterPeriod? _tryParseBareRangeWithContext(
    String text, {
    required String source,
  }) {
    final range = RegExp(
      r'(?<!\d)(0?[1-9]|[12]\d|3[01])\s*(?:-|ถึง)\s*(0?[1-9]|[12]\d|3[01])(?!\d)',
    ).firstMatch(text);
    if (range == null) return null;

    final contexts = <(int, int)>{};
    final contextMatches = RegExp(r'([ก-๙.]+)\s*(\d{2,4})').allMatches(text);

    for (final match in contextMatches) {
      final monthText = match.group(1)!;
      final month = _tryResolveMonth(monthText);
      if (month == null) continue;
      final year = _normalizeYear(int.parse(match.group(2)!));
      contexts.add((month, year));
    }

    if (contexts.length != 1) {
      if (contexts.length > 1) {
        throw FormatException(
          'ช่วงวันที่ "$source" มีหลายเดือนหรือหลายปี กรุณาระบุเดือนและปีให้ชัดเจน',
        );
      }
      return null;
    }

    final context = contexts.single;
    return _buildPeriod(
      startToken: _DateToken(
        day: int.parse(range.group(1)!),
        month: context.$1,
        year: context.$2,
      ),
      endToken: _DateToken(
        day: int.parse(range.group(2)!),
        month: context.$1,
        year: context.$2,
      ),
      source: source,
    );
  }

  ThaiRosterPeriod _buildPeriod({
    required _DateToken startToken,
    required _DateToken endToken,
    required String source,
  }) {
    final years = _resolveYears(startToken: startToken, endToken: endToken);

    final start = _checkedDate(
      year: years.$1,
      month: startToken.month,
      day: startToken.day,
      source: source,
    );
    final end = _checkedDate(
      year: years.$2,
      month: endToken.month,
      day: endToken.day,
      source: source,
    );

    if (end.isBefore(start)) {
      throw FormatException('วันสิ้นสุดอยู่ก่อนวันเริ่มต้น: $source');
    }

    return ThaiRosterPeriod(start: start, end: end);
  }

  _DateToken _readToken(RegExpMatch match) {
    final rawYear = match.group(3);
    return _DateToken(
      day: int.parse(match.group(1)!),
      month: _resolveMonth(match.group(2)!),
      year: rawYear == null ? null : _normalizeYear(int.parse(rawYear)),
    );
  }

  int _resolveMonth(String value) {
    final month = _tryResolveMonth(value);
    if (month == null) {
      throw FormatException('ไม่รู้จักเดือนไทย: $value');
    }
    return month;
  }

  int? _tryResolveMonth(String value) {
    final original = value.trim();
    final normalized = original.replaceAll('.', '');
    return _months[original] ?? _months[normalized];
  }

  (int, int) _resolveYears({
    required _DateToken startToken,
    required _DateToken endToken,
  }) {
    final explicitStartYear = startToken.year;
    final explicitEndYear = endToken.year;

    if (explicitStartYear == null && explicitEndYear == null) {
      throw const FormatException('ช่วงวันที่ต้องระบุปีอย่างน้อยหนึ่งครั้ง');
    }

    if (explicitStartYear != null && explicitEndYear != null) {
      return (explicitStartYear, explicitEndYear);
    }

    if (explicitEndYear != null) {
      final startYear = startToken.month > endToken.month
          ? explicitEndYear - 1
          : explicitEndYear;
      return (startYear, explicitEndYear);
    }

    final startYear = explicitStartYear!;
    final endYear = endToken.month < startToken.month
        ? startYear + 1
        : startYear;
    return (startYear, endYear);
  }

  int _normalizeYear(int year) {
    if (year < 100) year += 2500;
    if (year >= 2400) year -= 543;
    return year;
  }

  DateTime _checkedDate({
    required int year,
    required int month,
    required int day,
    required String source,
  }) {
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw FormatException('วันที่ไม่มีอยู่จริงในปฏิทิน: $source');
    }
    return date;
  }
}

class _DateToken {
  const _DateToken({required this.day, required this.month, this.year});

  final int day;
  final int month;
  final int? year;
}
