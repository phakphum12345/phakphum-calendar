import 'calendar_sync_command.dart';

/// Stable contract for a calendar synchronization request.
///
/// This protocol describes the lifecycle and safety boundary of a sync
/// operation. Provider-specific behavior must remain outside this contract.
abstract interface class CalendarSyncProtocol {
  /// Starts a synchronization operation.
  ///
  /// Implementations must:
  /// - validate the request before external writes,
  /// - produce deterministic commands,
  /// - preserve the sync ID for traceability,
  /// - respect dry-run semantics,
  /// - avoid executing the same command more than once when the command
  ///   has already been acknowledged as completed.
  Future<CalendarSyncProtocolResult> synchronize(
    CalendarSyncProtocolRequest request,
  );
}

class CalendarSyncProtocolRequest {
  const CalendarSyncProtocolRequest({
    required this.syncId,
    required this.timeMin,
    required this.timeMax,
    this.dryRun = false,
    this.continueOnError = false,
    this.commands = const <CalendarSyncCommand>[],
  });

  /// Stable identifier for the complete sync operation.
  final String syncId;

  /// Inclusive lower bound for the synchronization window.
  final DateTime timeMin;

  /// Exclusive upper bound for the synchronization window.
  final DateTime timeMax;

  /// When true, planning/validation may run but external writes must not run.
  final bool dryRun;

  /// When true, execution may continue after an individual command fails.
  final bool continueOnError;

  /// Optional pre-planned commands.
  ///
  /// An implementation may ignore this collection when it owns planning,
  /// but it must never silently execute commands outside its validated plan.
  final List<CalendarSyncCommand> commands;

  void validate() {
    final normalizedSyncId = syncId.trim();

    if (normalizedSyncId.isEmpty) {
      throw ArgumentError.value(
        syncId,
        'syncId',
        'Sync ID must not be empty.',
      );
    }

    if (!timeMin.isBefore(timeMax)) {
      throw ArgumentError(
        'timeMin must be earlier than timeMax.',
      );
    }
  }
}

enum CalendarSyncProtocolStatus {
  planned,
  dryRun,
  completed,
  completedWithErrors,
  failed,
}

class CalendarSyncProtocolResult {
  const CalendarSyncProtocolResult({
    required this.syncId,
    required this.status,
    required this.commandsPlanned,
    required this.commandsExecuted,
    required this.commandsSkipped,
    required this.errors,
  });

  final String syncId;
  final CalendarSyncProtocolStatus status;
  final int commandsPlanned;
  final int commandsExecuted;
  final int commandsSkipped;
  final List<CalendarSyncProtocolError> errors;

  bool get succeeded =>
      status == CalendarSyncProtocolStatus.completed ||
      status == CalendarSyncProtocolStatus.dryRun;

  bool get hasErrors => errors.isNotEmpty;
}

class CalendarSyncProtocolError {
  const CalendarSyncProtocolError({
    required this.code,
    required this.message,
    this.command,
  });

  final String code;
  final String message;
  final CalendarSyncCommand? command;

  @override
  String toString() {
    return 'CalendarSyncProtocolError('
        'code: $code, '
        'message: $message'
        ')';
  }
}
