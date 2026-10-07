import '../../diff_engine/domain/calendar_event_candidate.dart';
import '../domain/calendar_sync_protocol.dart';
import '../domain/calendar_sync_run_result.dart';
import 'calendar_sync_service.dart';

/// Application adapter that exposes the existing calendar synchronization
/// service through the stable [CalendarSyncProtocol] contract.
///
/// Provider-specific behavior remains behind [CalendarSyncService] and its
/// repository boundary. This keeps the protocol suitable as a long-lived
/// application boundary while the synchronization implementation evolves.
///
/// The current protocol request contains pre-planned commands. The adapter
/// translates those commands into the desired-event input expected by the
/// existing service, while keeping planning and provider execution inside
/// the established application layer.
class CalendarSyncProtocolService implements CalendarSyncProtocol {
  const CalendarSyncProtocolService({
    required CalendarSyncService service,
  }) : _service = service;

  final CalendarSyncService _service;

  @override
  Future<CalendarSyncProtocolResult> synchronize(
    CalendarSyncProtocolRequest request,
  ) async {
    request.validate();

    try {
      final result = await _service.sync(
        desiredEvents: _desiredEventsFromRequest(request),
        timeMin: request.timeMin,
        timeMax: request.timeMax,
        dryRun: request.dryRun,
        continueOnError: request.continueOnError,
      );

      return _toProtocolResult(
        request: request,
        result: result,
      );
    } on Object catch (error) {
      return CalendarSyncProtocolResult(
        syncId: request.syncId,
        status: CalendarSyncProtocolStatus.failed,
        commandsPlanned: request.commands.length,
        commandsExecuted: 0,
        commandsSkipped: request.commands.length,
        errors: <CalendarSyncProtocolError>[
          CalendarSyncProtocolError(
            code: 'SYNC_EXECUTION_ERROR',
            message: error.toString(),
          ),
        ],
      );
    }
  }

  List<CalendarEventCandidate> _desiredEventsFromRequest(
    CalendarSyncProtocolRequest request,
  ) {
    return List<CalendarEventCandidate>.unmodifiable(
      request.commands
          .where(
            (command) =>
                command.action.name == 'create' ||
                command.action.name == 'update',
          )
          .map((command) => command.candidate),
    );
  }

  CalendarSyncProtocolResult _toProtocolResult({
    required CalendarSyncProtocolRequest request,
    required CalendarSyncRunResult result,
  }) {
    final errors = result.executionResults
        .where((execution) => !execution.succeeded)
        .map(
          (execution) => CalendarSyncProtocolError(
            code: 'SYNC_COMMAND_FAILED',
            message: execution.error?.toString() ??
                'Calendar synchronization command failed.',
            command: execution.command,
          ),
        )
        .toList(growable: false);

    return CalendarSyncProtocolResult(
      syncId: request.syncId,
      status: _status(
        request: request,
        result: result,
        errors: errors,
      ),
      commandsPlanned: result.commands.length,
      commandsExecuted: result.executionResults
          .where((execution) => execution.applied)
          .length,
      commandsSkipped: result.executionResults
          .where((execution) => !execution.applied)
          .length,
      errors: errors,
    );
  }

  CalendarSyncProtocolStatus _status({
    required CalendarSyncProtocolRequest request,
    required CalendarSyncRunResult result,
    required List<CalendarSyncProtocolError> errors,
  }) {
    if (request.dryRun) {
      return CalendarSyncProtocolStatus.dryRun;
    }

    if (errors.isEmpty) {
      return CalendarSyncProtocolStatus.completed;
    }

    if (result.executionResults.isNotEmpty) {
      return CalendarSyncProtocolStatus.completedWithErrors;
    }

    return CalendarSyncProtocolStatus.failed;
  }
}

