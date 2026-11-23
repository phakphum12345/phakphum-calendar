class ShiftTimeService {
  const ShiftTimeService._();

  /// Attempts to derive canonical start/end [Duration] values from a
  /// freeform shift label. Returns `null` when no reasonable mapping found.
  static List<Duration>? parseDurations(String label) {
    final normalized = label.trim().toLowerCase();
    // Try explicit time ranges first (e.g. "16:00-08:00" or "16:00–08:00").
    final timeRegex = RegExp(r"(\d{1,2}:\d{2})");
    final matches = timeRegex.allMatches(normalized).map((m) => m.group(0)!).toList();
    if (matches.length >= 2) {
      final start = _parseTime(matches[0]);
      final end = _parseTime(matches[1]);
      if (start != null && end != null) return [start, end];
    }

    // Keyword based defaults for common templates.
    if (normalized == 'm' || normalized.contains('เช้า') || normalized.contains('morning')) {
      return [const Duration(hours: 8), const Duration(hours: 16)];
    }
    if (normalized == 'e' || normalized.contains('บ่าย') || normalized.contains('evening')) {
      return [const Duration(hours: 16), const Duration(hours: 24)];
    }
    if (normalized == 'n' || normalized.contains('ดึก') || normalized.contains('night')) {
      return [Duration.zero, const Duration(hours: 8)];
    }
    if (normalized == 'oc' || normalized.contains('on call') || normalized.contains('on-call')) {
      return [const Duration(hours: 17), const Duration(hours: 8)];
    }

    // Sometimes the code includes numeric single-hour markers like '16-08'.
    final numericRange = RegExp(r"(\d{1,2})\s*[-–]\s*(\d{1,2})");
    final nmatch = numericRange.firstMatch(normalized);
    if (nmatch != null) {
      final a = int.tryParse(nmatch.group(1)!);
      final b = int.tryParse(nmatch.group(2)!);
      if (a != null && b != null) {
        return [Duration(hours: a), Duration(hours: b)];
      }
    }

    return null;
  }

  static Duration? _parseTime(String token) {
    final parts = token.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return Duration(hours: h, minutes: m);
  }
}
