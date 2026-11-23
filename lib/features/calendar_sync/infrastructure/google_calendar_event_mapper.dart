import 'package:googleapis/calendar/v3.dart' as calendar;

import '../../diff_engine/domain/calendar_event_candidate.dart';
import '../domain/calendar_event_record.dart';

class GoogleCalendarEventMapper {
  const GoogleCalendarEventMapper();

  static const String syncIdKey = 'syncId';
  static const String managedByKey = 'managedBy';
  static const String managedByValue = 'phakphum-calendar';

  CalendarEventRecord? fromGoogleEvent(calendar.Event event) {
    final eventId = event.id?.trim();
    final syncId = event.extendedProperties?.private?[syncIdKey]?.trim();

    final title = event.summary?.trim();
    final start = event.start?.dateTime;
    final end = event.end?.dateTime;

    if (eventId == null || eventId.isEmpty) {
      return null;
    }

    if (syncId == null || syncId.isEmpty) {
      return null;
    }

    if (title == null || title.isEmpty) {
      return null;
    }

    if (start == null || end == null) {
      return null;
    }

    if (!end.isAfter(start)) {
      return null;
    }

    return CalendarEventRecord(
      providerEventId: eventId,
      candidate: CalendarEventCandidate(
        syncId: syncId,
        title: title,
        start: start,
        end: end,
        shouldExist: true,
        description: _normalizeDescription(event.description),
      ),
    );
  }

  calendar.Event toGoogleEvent(CalendarEventCandidate candidate) {
    return calendar.Event(
      summary: candidate.title,
      description: candidate.description,
      start: calendar.EventDateTime(dateTime: candidate.start),
      end: calendar.EventDateTime(dateTime: candidate.end),
      extendedProperties: calendar.EventExtendedProperties(
        private: <String, String>{
          syncIdKey: candidate.syncId,
          managedByKey: managedByValue,
        },
      ),
    );
  }

  String? _normalizeDescription(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    const marker = '--- Timeline ---';
    final markerIndex = normalized.indexOf(marker);
    // Timeline audit entries are preserved in Google Calendar but are not
    // part of the roster-generated description used by the sync diff engine.
    final rosterDescription = markerIndex < 0
        ? normalized
        : normalized.substring(0, markerIndex).trimRight();
    return rosterDescription.isEmpty ? null : rosterDescription;
  }
}
