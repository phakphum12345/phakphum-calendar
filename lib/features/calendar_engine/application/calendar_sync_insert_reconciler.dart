import '../domain/calendar_sync_command.dart';
import '../domain/calendar_sync_gateway.dart';
import '../domain/managed_calendar_event.dart';

/// Reconciles an insert by its deterministic sync ID before another write.
///
/// Google Calendar may accept an insert even when the client loses the response.
/// A follow-up lookup prevents retry/resume from creating a second managed event.
class CalendarSyncInsertReconciler {
  const CalendarSyncInsertReconciler(
    this._gateway, {
    this.lookupAttempts = 2,
    this.retryDelay = const Duration(milliseconds: 250),
  }) : assert(lookupAttempts > 0);

  final CalendarSyncGateway _gateway;
  final int lookupAttempts;
  final Duration retryDelay;

  Future<ManagedCalendarEvent?> findExisting(
    CalendarSyncCommand command,
  ) async {
    for (var attempt = 1; attempt <= lookupAttempts; attempt++) {
      final events = await _gateway.listManagedEvents(
        timeMin: command.start.subtract(const Duration(days: 1)),
        timeMax: command.end.add(const Duration(days: 1)),
        calendarId: command.calendarId,
      );
      final matches = events
          .where((event) => event.syncId == command.syncId)
          .toList(growable: false);

      if (matches.length > 1) {
        throw StateError(
          'Multiple managed Calendar events share sync ID ${command.syncId}.',
        );
      }
      if (matches.isNotEmpty) return matches.single;

      if (attempt < lookupAttempts && retryDelay > Duration.zero) {
        await Future<void>.delayed(retryDelay);
      }
    }
    return null;
  }
}
