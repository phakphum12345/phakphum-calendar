```dart
import '../../diff_engine/domain/calendar_event_candidate.dart';
import '../domain/calendar_sync_protocol.dart';
import '../domain/calendar_sync_run_result.dart';
import 'calendar_sync_service.dart';

/// Application-level adapter that exposes the existing CalendarSyncService
/// through the stable CalendarSyncProtocol contract.
///
/// Provider-specific behavior remains inside CalendarSyncService and its
/// repository boundary.
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

    final status = _status(
      request: request,
      result: result,
      errors: errors,
    );

    return CalendarSyncProtocolResult(
      syncId: request.syncId,
      status: status,
      commandsPlanned: result.commands.length,
      commandsExecuted: result.executionResults.length,
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
```
