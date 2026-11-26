import '../domain/calendar_sync_command.dart';

class CalendarUpdateOperation {
  const CalendarUpdateOperation({required this.eventId, required this.command, this.expectedEtag, this.expectedSyncId});

  final String eventId;
  final CalendarSyncCommand command;
  final String? expectedEtag;
  final String? expectedSyncId;
}

class CalendarDeleteOperation {
  const CalendarDeleteOperation({
    required this.eventId,
    required this.calendarId,
    this.beforeWrites = false,
    this.expectedEtag,
    this.expectedSyncId,
  });

  final String eventId;
  final String calendarId;
  final bool beforeWrites;
  final String? expectedEtag;
  final String? expectedSyncId;
}

class CalendarSyncPlan {
  const CalendarSyncPlan({
    required this.inserts,
    required this.updates,
    required this.deletes,
    this.scheduleId = 'unknown',
    this.calendarId = 'primary',
  });

  final List<CalendarSyncCommand> inserts;
  final List<CalendarUpdateOperation> updates;
  final List<CalendarDeleteOperation> deletes;
  final String scheduleId;
  final String calendarId;

  int get operationCount => inserts.length + updates.length + deletes.length;
}
