import '../../calendar_engine/application/resilient_calendar_sync_executor.dart';
import '../../diff_engine/domain/calendar_event_candidate.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import '../../../models/calendar_busy_period.dart';
import '../../../models/roster_period.dart';
import '../../../models/shift.dart';
import '../../../services/calendar_service.dart';
import '../domain/workflow_preview.dart';
import 'calendar_workflow_factory.dart';
import 'shift_calendar_workflow_controller.dart';

class CalendarWorkflowComparison {
  const CalendarWorkflowComparison({
    required this.preview,
    required this.scheduleId,
    required this.sourceKeys,
    required this.busyPeriods,
  });

  final WorkflowPreview preview;
  final String scheduleId;
  final Set<String> sourceKeys;
  final List<CalendarBusyPeriod> busyPeriods;
}

class CalendarWorkflowSync {
  const CalendarWorkflowSync({required this.comparison, required this.result});

  final CalendarWorkflowComparison comparison;
  final ResilientCalendarSyncResult result;
}

class CalendarWorkflowFacade {
  const CalendarWorkflowFacade({CalendarService? calendarReader})
    : _calendarReader = calendarReader ?? const CalendarService();

  final CalendarService _calendarReader;

  Future<CalendarWorkflowComparison> compare({
    required auth.AuthClient client,
    required List<Shift> shifts,
    required List<RosterPeriod> periods,
    required String scheduleId,
    String calendarId = 'primary',
  }) async {
    final prepared = await _prepare(
      client: client,
      shifts: shifts,
      periods: periods,
      scheduleId: scheduleId,
      calendarId: calendarId,
    );
    return prepared.comparison;
  }

  Future<
    ({
      CalendarWorkflowComparison comparison,
      ShiftCalendarWorkflowController workflow,
    })
  >
  _prepare({
    required auth.AuthClient client,
    required List<Shift> shifts,
    required List<RosterPeriod> periods,
    required String scheduleId,
    required String calendarId,
  }) async {
    if (scheduleId.trim().isEmpty ||
        scheduleId.trim().toLowerCase() == 'unknown') {
      throw ArgumentError.value(
        scheduleId,
        'scheduleId',
        'A stable Schedule ID is required before Calendar reads.',
      );
    }
    final calendarSnapshot = await _readCalendarPeriods(client, periods);
    final workflow = CalendarWorkflowFactory.create(client: client);
    await workflow.prepareCandidatePreview(
      desired: _desiredEvents(shifts),
      scheduleId: scheduleId,
      calendarId: calendarId,
    );
    final preview = workflow.preview;
    if (preview == null) {
      throw StateError('ไม่สามารถเตรียมผลเปรียบเทียบ Calendar ได้');
    }
    final comparison = CalendarWorkflowComparison(
      preview: preview,
      scheduleId: scheduleId,
      sourceKeys: calendarSnapshot.sourceKeys,
      busyPeriods: calendarSnapshot.busyPeriods,
    );
    return (comparison: comparison, workflow: workflow);
  }

  Future<CalendarWorkflowSync> synchronize({
    required auth.AuthClient client,
    required List<Shift> shifts,
    required List<RosterPeriod> periods,
    CalendarWorkflowComparison? comparison,
    required String scheduleId,
    String calendarId = 'primary',
  }) async {
    if (comparison != null && comparison.scheduleId != scheduleId) {
      throw StateError(
        'The Calendar comparison belongs to a different Schedule. Prepare a new preview.',
      );
    }
    final prepared = comparison == null
        ? await _prepare(
            client: client,
            shifts: shifts,
            periods: periods,
            scheduleId: scheduleId,
            calendarId: calendarId,
          )
        : null;
    final workflow =
        prepared?.workflow ?? CalendarWorkflowFactory.create(client: client);
    if (prepared == null) {
      await workflow.prepareCandidatePreview(
        desired: _desiredEvents(shifts),
        scheduleId: scheduleId,
        calendarId: calendarId,
      );
    }
    await workflow.synchronize(calendarId: calendarId);
    final result = workflow.lastResult;
    if (result == null) {
      throw StateError(workflow.message ?? 'ไม่สามารถซิงก์ Calendar ได้');
    }
    return CalendarWorkflowSync(
      comparison: prepared?.comparison ?? comparison!,
      result: result,
    );
  }

  List<CalendarEventCandidate> _desiredEvents(List<Shift> shifts) {
    return shifts
        .where((shift) => !shift.excluded)
        .map(
          (shift) => CalendarEventCandidate(
            syncId: CalendarService.keyFor(shift),
            title: CalendarService.summaryFor(shift),
            start: shift.start,
            end: shift.end,
            description: CalendarService.descriptionFor(shift),
            colorId: shift.effectiveCalendarColorId,
            shouldExist: true,
          ),
        )
        .toList(growable: false);
  }

  Future<CalendarReadResult> _readCalendarPeriods(
    auth.AuthClient client,
    List<RosterPeriod> periods,
  ) async {
    final sourceKeys = <String>{};
    final busyByKey = <String, CalendarBusyPeriod>{};
    for (final period in periods) {
      final snapshot = await _calendarReader.readCalendar(
        client,
        year: period.year,
        month: period.month,
      );
      sourceKeys.addAll(snapshot.sourceKeys);
      for (final busyPeriod in snapshot.busyPeriods) {
        busyByKey['${busyPeriod.id}|${busyPeriod.start.toIso8601String()}'] =
            busyPeriod;
      }
    }
    return CalendarReadResult(
      sourceKeys: sourceKeys,
      busyPeriods: busyByKey.values.toList()
        ..sort((left, right) => left.start.compareTo(right.start)),
    );
  }
}
