import '../../diff_engine/domain/calendar_diff.dart';
import '../../diff_engine/domain/calendar_event_candidate.dart';
import '../domain/calendar_sync_command.dart';
import '../domain/managed_calendar_event.dart';
import 'calendar_sync_plan.dart';

class CalendarSyncPlanBuilder {
  const CalendarSyncPlanBuilder();

  CalendarSyncPlan build({
    required CalendarDiff diff,
    required List<ManagedCalendarEvent> existingEvents,
    String calendarId = 'primary',
  }) {
    final existingBySyncId = <String, ManagedCalendarEvent>{
      for (final event in existingEvents) event.syncId: event,
    };

    final inserts = <CalendarSyncCommand>[];
    final updates = <CalendarUpdateOperation>[];
    final deletes = <CalendarDeleteOperation>[];

    for (final candidate in diff.toAdd) {
      inserts.add(_toCommand(candidate, calendarId));
    }

    for (final candidate in diff.toUpdate) {
      final existing = existingBySyncId[candidate.syncId];
      if (existing == null) {
        inserts.add(_toCommand(candidate, calendarId));
        continue;
      }

      updates.add(
        CalendarUpdateOperation(
          eventId: existing.eventId,
          command: _toCommand(candidate, calendarId),
          expectedEtag: existing.etag,
          expectedSyncId: existing.providerSyncId,
        ),
      );
    }

    for (final candidate in diff.toDelete) {
      final existing = existingBySyncId[candidate.syncId];
      if (existing == null) {
        continue;
      }

      deletes.add(
        CalendarDeleteOperation(
          eventId: existing.eventId,
          calendarId: calendarId,
          beforeWrites: candidate.syncId.startsWith('legacy:'),
          expectedEtag: existing.etag,
          expectedSyncId: existing.providerSyncId,
        ),
      );
    }

    return CalendarSyncPlan(
      inserts: inserts,
      updates: updates,
      deletes: deletes,
    );
  }

  CalendarSyncCommand _toCommand(
    CalendarEventCandidate candidate,
    String calendarId,
  ) {
    return CalendarSyncCommand(
      syncId: candidate.syncId,
      title: candidate.title,
      start: candidate.start,
      end: candidate.end,
      description: candidate.description,
      colorId: candidate.colorId,
      calendarId: calendarId,
    );
  }
}
