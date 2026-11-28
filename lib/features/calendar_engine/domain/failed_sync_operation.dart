import 'calendar_sync_command.dart';
import 'calendar_sync_operation_result.dart';

class FailedSyncOperation {
  const FailedSyncOperation({
    required this.historyId,
    required this.type,
    required this.referenceId,
    required this.attempts,
    this.command,
    this.eventId,
    this.calendarId = 'primary',
    this.message,
    this.expectedEtag,
    this.expectedSyncId,
  });

  final String historyId;
  final CalendarSyncOperationType type;
  final String referenceId;
  final int attempts;
  final CalendarSyncCommand? command;
  final String? eventId;
  final String calendarId;
  final String? message;
  final String? expectedEtag;
  final String? expectedSyncId;
}
