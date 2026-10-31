import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;

import '../core/utils/calendar_event_matcher.dart';
import '../models/calendar_busy_period.dart';
import '../models/shift.dart';

/// Calendar operations required by the legacy application workflow.
abstract interface class LegacyCalendarGateway {
  bool matchesExistingShift(Shift shift, Set<String> keys);
  Future<CalendarReadResult> readCalendar(
    http.Client client, {
    required int year,
    required int month,
  });
  Future<int> insertMissing(
    http.Client client,
    List<Shift> shifts,
    Set<String> existingKeys,
  );
  Future<List<String>> findManagedDuplicateEventIds(
    http.Client client, {
    required int year,
    required int month,
    required List<Shift> desiredShifts,
  });
  Future<void> deleteEvent(http.Client client, {required String eventId});
}

class CalendarService implements LegacyCalendarGateway {
  const CalendarService();

  static const sourceApp = 'phakphum_shift_calendar';
  static const timeZone = 'Asia/Bangkok';

  Future<Set<String>> existingSourceKeys(
    http.Client client, {
    required int year,
    required int month,
  }) async {
    return (await readCalendar(client, year: year, month: month)).sourceKeys;
  }

  @override
  Future<CalendarReadResult> readCalendar(
    http.Client client, {
    required int year,
    required int month,
  }) async {
    final api = calendar.CalendarApi(client);
    final start = DateTime.utc(
      year,
      month,
      1,
    ).subtract(const Duration(hours: 7));
    final end = DateTime.utc(
      year,
      month + 1,
      1,
    ).subtract(const Duration(hours: 7));
    final sourceKeys = <String>{};
    final busyPeriods = <CalendarBusyPeriod>[];
    String? pageToken;
    do {
      final page = await api.events.list(
        'primary',
        timeMin: start,
        timeMax: end,
        singleEvents: true,
        showDeleted: false,
        maxResults: 2500,
        pageToken: pageToken,
      );
      for (final event in page.items ?? const <calendar.Event>[]) {
        final privateProperties = event.extendedProperties?.private;
        final isManaged =
            privateProperties?['sourceApp'] == sourceApp ||
            (privateProperties?['sceSyncId'] ?? '').isNotEmpty;
        if (isManaged && (privateProperties?['sourceKey'] ?? '').isNotEmpty) {
          sourceKeys.add(privateProperties!['sourceKey']!);
        }
        final wallStart = _wallTime(event.start);
        final wallEnd = _wallTime(event.end);
        if (isManaged &&
            wallStart != null &&
            wallEnd != null &&
            wallEnd.isAfter(wallStart)) {
          sourceKeys.add(
            _managedTimeKey(event.summary ?? '', wallStart, wallEnd),
          );
        }
        final startTime = event.start?.dateTime;
        final summary = event.summary;
        if (startTime != null && summary != null && summary.isNotEmpty) {
          final bangkokWall = startTime.toUtc().add(const Duration(hours: 7));
          sourceKeys.add(_legacyKey(summary, bangkokWall));
        }
        if (isManaged || event.transparency == 'transparent') continue;
        if (wallStart == null ||
            wallEnd == null ||
            !wallEnd.isAfter(wallStart)) {
          continue;
        }
        busyPeriods.add(
          CalendarBusyPeriod(
            id: event.id ?? '${event.iCalUID ?? 'calendar'}|$wallStart',
            title: (summary ?? '').trim().isEmpty
                ? 'กิจกรรมไม่มีชื่อ'
                : summary!,
            start: wallStart,
            end: wallEnd,
            legacyKey: _legacyKey(summary ?? '', wallStart),
            htmlLink: event.htmlLink,
          ),
        );
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return CalendarReadResult(sourceKeys: sourceKeys, busyPeriods: busyPeriods);
  }

  @override
  Future<int> insertMissing(
    http.Client client,
    List<Shift> shifts,
    Set<String> existingKeys,
  ) async {
    final api = calendar.CalendarApi(client);
    var inserted = 0;
    for (final shift in shifts) {
      final key = keyFor(shift);
      if (shift.excluded || matchesExisting(shift, existingKeys)) continue;
      final event = calendar.Event(
        summary: summaryFor(shift),
        description: descriptionFor(shift),
        colorId: shift.effectiveCalendarColorId,
        start: calendar.EventDateTime(
          dateTime: _bangkokInstant(shift.start),
          timeZone: timeZone,
        ),
        end: calendar.EventDateTime(
          dateTime: _bangkokInstant(shift.end),
          timeZone: timeZone,
        ),
        transparency: 'opaque',
        extendedProperties: calendar.EventExtendedProperties(
          private: {'sourceApp': sourceApp, 'sourceKey': key},
        ),
      );
      await api.events.insert(event, 'primary', sendUpdates: 'none');
      existingKeys.add(key);
      existingKeys.add(legacyKeyFor(shift));
      existingKeys.add(displayLegacyKeyFor(shift));
      inserted++;
    }
    return inserted;
  }

  @override
  Future<List<String>> findManagedDuplicateEventIds(
    http.Client client, {
    required int year,
    required int month,
    required List<Shift> desiredShifts,
  }) async {
    final api = calendar.CalendarApi(client);
    final start = DateTime.utc(
      year,
      month,
      1,
    ).subtract(const Duration(hours: 7));
    final end = DateTime.utc(
      year,
      month + 1,
      1,
    ).subtract(const Duration(hours: 7));
    final byManagedKey = <String, Map<String, calendar.Event>>{};
    String? pageToken;
    do {
      final page = await api.events.list(
        'primary',
        timeMin: start,
        timeMax: end,
        singleEvents: true,
        showDeleted: false,
        maxResults: 2500,
        pageToken: pageToken,
      );
      for (final event in page.items ?? const <calendar.Event>[]) {
        final eventId = event.id?.trim() ?? '';
        final properties = event.extendedProperties?.private;
        final sourceApp = properties?['sourceApp']?.trim() ?? '';
        final syncId = properties?['sceSyncId']?.trim() ?? '';
        final sourceKey = properties?['sourceKey']?.trim() ?? '';
        final managed =
            sourceApp == CalendarService.sourceApp || syncId.isNotEmpty;
        if (!managed || eventId.isEmpty) continue;
        final key = syncId.isNotEmpty
            ? 'sync:$syncId'
            : sourceKey.isNotEmpty
            ? 'source:$sourceKey'
            : '';
        if (key.isEmpty) continue;
        byManagedKey.putIfAbsent(
          key,
          () => <String, calendar.Event>{},
        )[eventId] = event;
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    final duplicates = <String>[];
    for (final eventsById in byManagedKey.values) {
      if (eventsById.length < 2) continue;
      final events = eventsById.values.toList()
        ..sort((left, right) => left.id!.compareTo(right.id!));
      final exactIndex = events.indexWhere(
        (event) => _matchesDesiredShift(event, desiredShifts),
      );
      final retainedIndex = exactIndex < 0 ? 0 : exactIndex;
      for (var index = 0; index < events.length; index++) {
        if (index != retainedIndex) duplicates.add(events[index].id!);
      }
    }
    duplicates.sort();
    return List.unmodifiable(duplicates);
  }

  bool _matchesDesiredShift(calendar.Event event, List<Shift> desiredShifts) {
    final start = _wallTime(event.start);
    final end = _wallTime(event.end);
    if (start == null || end == null) return false;
    final title = event.summary ?? '';
    return desiredShifts.any(
      (shift) => CalendarEventMatcher.isExactEquivalent(
        rosterTitle: summaryFor(shift),
        rosterStart: shift.start,
        rosterEnd: shift.end,
        calendarTitle: title,
        calendarStart: start,
        calendarEnd: end,
      ),
    );
  }

  @override
  Future<void> deleteEvent(
    http.Client client, {
    required String eventId,
  }) async {
    await calendar.CalendarApi(
      client,
    ).events.delete('primary', eventId, sendUpdates: 'none');
  }

  static String keyFor(Shift shift) =>
      sha256.convert(utf8.encode(shift.sourceKey)).toString().substring(0, 32);

  static String legacyKeyFor(Shift shift) =>
      _legacyKey(shift.code, shift.start);

  static String summaryFor(Shift shift) =>
      CalendarEventMatcher.calendarTitle(shift.displayName);

  /// Keeps one canonical Timeline section on a managed shift event.
  /// Detailed historical entries remain available as separate Timeline events;
  /// the source shift description must not accumulate repeated copies on sync.
  static String withTimelineRecord(String existingDescription, String record) {
    const marker = '--- Timeline ---';
    final markerIndex = existingDescription.indexOf(marker);
    var baseDescription = markerIndex < 0
        ? existingDescription
        : existingDescription.substring(0, markerIndex);
    // Remove malformed literal escape sequences written by older versions,
    // then trim real line endings before rebuilding the canonical section.
    while (baseDescription.endsWith(r'\n')) {
      baseDescription = baseDescription.substring(0, baseDescription.length - 2);
    }
    baseDescription = baseDescription.trimRight();
    return baseDescription.isEmpty
        ? '$marker\n$record'
        : '$baseDescription\n\n$marker\n$record';
  }

  static String descriptionFor(Shift shift) {
    final relationship = shift.relationshipComment?.trim() ?? '';
    return <String>[
      shift.generated
          ? 'สร้างอัตโนมัติเป็นเวรออฟหลังเวรดึก'
          : 'สร้างจากตารางเวร (อ่านอย่างเดียว)',
      'ชื่อเวรจากชีต: ${shift.rowLabel}',
      'ผู้ปฏิบัติงานในตาราง: ${shift.assignedName}',
      if (relationship.isNotEmpty) relationship,
      if (shift.sourceColorHex != null)
        'สีเซลล์ต้นฉบับ: ${shift.sourceColorHex}',
      'ชีต: ${shift.sheetTitle} เซลล์ ${shift.cell}',
      'ประเภท: ${shift.category.label}',
    ].join('\n');
  }

  static String displayLegacyKeyFor(Shift shift) =>
      _legacyKey(summaryFor(shift), shift.start);

  static bool matchesLegacyEvent(Shift shift, String legacyKey) =>
      legacyKey == legacyKeyFor(shift) ||
      legacyKey == displayLegacyKeyFor(shift);

  static bool matchesEquivalentPeriod(Shift shift, CalendarBusyPeriod period) =>
      CalendarEventMatcher.isEquivalent(
        rosterTitle: shift.displayName,
        sourceLabel: shift.rowLabel,
        rosterStart: shift.start,
        rosterEnd: shift.end,
        calendarTitle: period.title,
        calendarStart: period.start,
        calendarEnd: period.end,
      );

  static bool matchesExisting(Shift shift, Set<String> keys) =>
      keys.contains(keyFor(shift)) ||
      keys.contains(legacyKeyFor(shift)) ||
      keys.contains(displayLegacyKeyFor(shift)) ||
      keys.contains(managedTimeKeyFor(shift));

  static String managedTimeKeyFor(Shift shift) =>
      _managedTimeKey(summaryFor(shift), shift.start, shift.end);

  @override
  bool matchesExistingShift(Shift shift, Set<String> keys) =>
      matchesExisting(shift, keys);

  static String _legacyKey(String summary, DateTime wallTime) =>
      'legacy|$summary|${wallTime.year.toString().padLeft(4, '0')}-'
      '${wallTime.month.toString().padLeft(2, '0')}-'
      '${wallTime.day.toString().padLeft(2, '0')}T'
      '${wallTime.hour.toString().padLeft(2, '0')}:'
      '${wallTime.minute.toString().padLeft(2, '0')}';

  static String _managedTimeKey(String title, DateTime start, DateTime end) =>
      'managed-time|${_managedTitleIdentity(title)}|'
      '${_wallIdentity(start)}|${_wallIdentity(end)}';

  static String _managedTitleIdentity(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  static String _wallIdentity(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}T'
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}';

  DateTime? _wallTime(calendar.EventDateTime? value) {
    final instant = value?.dateTime;
    if (instant != null) {
      final bangkok = instant.toUtc().add(const Duration(hours: 7));
      return DateTime(
        bangkok.year,
        bangkok.month,
        bangkok.day,
        bangkok.hour,
        bangkok.minute,
        bangkok.second,
        bangkok.millisecond,
        bangkok.microsecond,
      );
    }
    final date = value?.date;
    return date == null ? null : DateTime(date.year, date.month, date.day);
  }

  DateTime _bangkokInstant(DateTime wallTime) => DateTime.utc(
    wallTime.year,
    wallTime.month,
    wallTime.day,
    wallTime.hour - 7,
    wallTime.minute,
  );
}
