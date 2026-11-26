import 'calendar_sync_command.dart';
import 'managed_calendar_event.dart';

abstract interface class CalendarSyncGateway {
  Future<List<ManagedCalendarEvent>> listManagedEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    String calendarId = 'primary',
  });

  Future<ManagedCalendarEvent> insert(CalendarSyncCommand command);

  Future<ManagedCalendarEvent> update({
    required String eventId,
    required CalendarSyncCommand command,
  });

  Future<void> delete({required String eventId, String calendarId = 'primary'});
}

/// Optional provider capability used to adopt equivalent pre-metadata events.
/// Optional provider capability for race-safe Calendar mutations.
/// Implementations must verify event ownership and use provider preconditions.
abstract interface class ConditionalCalendarSyncGateway {
  Future<ManagedCalendarEvent> updateConditionally({
    required String eventId,
    required String expectedEtag,
    required String expectedSyncId,
    required CalendarSyncCommand command,
  });

  Future<void> deleteConditionally({
    required String eventId,
    required String calendarId,
    required String expectedEtag,
    required String expectedSyncId,
  });
}

abstract interface class ComparableCalendarEventGateway {
  Future<List<ManagedCalendarEvent>> listComparableLegacyEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    String calendarId = 'primary',
  });
}
