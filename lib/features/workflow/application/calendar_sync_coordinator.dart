import '../../calendar_engine/application/calendar_sync_plan_builder.dart';
import '../../calendar_engine/application/calendar_sync_plan.dart';
import '../../calendar_engine/application/resilient_calendar_sync_executor.dart';
import '../../calendar_engine/domain/calendar_sync_gateway.dart';
import '../../calendar_engine/domain/managed_calendar_event.dart';
import '../../../core/utils/calendar_event_matcher.dart';
import '../../../domain/entities/schedule.dart';
import '../../diff_engine/application/calendar_diff_engine.dart';
import '../../diff_engine/domain/calendar_diff.dart';
import '../../diff_engine/domain/calendar_event_candidate.dart';
import 'canonical_schedule_event_mapper.dart';

/// Immutable provider comparison prepared before user confirmation.
class CalendarSyncPreparation {
  const CalendarSyncPreparation({
    required this.diff,
    required this.plan,
    required this.timeMin,
    required this.timeMax,
    this.existingEventIdsBySyncId = const {},
  });

  final CalendarDiff diff;
  final CalendarSyncPlan plan;
  final DateTime timeMin;
  final DateTime timeMax;
  final Map<String, String> existingEventIdsBySyncId;
}

class CalendarSyncCoordinator {
  const CalendarSyncCoordinator({
    required this._gateway,
    required this._planBuilder,
    required this._executor,
    this.scheduleMapper = const CanonicalScheduleEventMapper(),
    this.diffEngine = const CalendarDiffEngine(),
  });

  final CalendarSyncGateway _gateway;
  final CalendarSyncPlanBuilder _planBuilder;
  final ResilientCalendarSyncExecutor _executor;
  final CanonicalScheduleEventMapper scheduleMapper;
  final CalendarDiffEngine diffEngine;

  /// Builds a deterministic diff and plan directly from a canonical schedule.
  Future<CalendarSyncPreparation> prepareSchedule(
    Schedule schedule, {
    String calendarId = 'primary',
  }) async {
    final desired = scheduleMapper.map(schedule);
    final range = _range(desired);
    final managed = await _gateway.listManagedEvents(
      timeMin: range.$1,
      timeMax: range.$2,
      calendarId: calendarId,
    );
    final comparableGateway = _gateway is ComparableCalendarEventGateway
        ? _gateway as ComparableCalendarEventGateway
        : null;
    final legacy = comparableGateway == null
        ? const <ManagedCalendarEvent>[]
        : await comparableGateway.listComparableLegacyEvents(
            timeMin: range.$1,
            timeMax: range.$2,
            calendarId: calendarId,
          );
    final deduplicatedManaged = _deduplicateManaged(desired, managed);
    // Past provider events are historical records, not omissions from the
    // current schedule. Keep them in the desired set so the expanded lookback
    // window cannot turn them into deletion requests. Current desired IDs are
    // excluded so legitimate updates to past-dated assignments still work.
    final today = DateTime.now();
    final desiredIds = desired.map((candidate) => candidate.syncId).toSet();
    final selectedRanges = schedule.months
        .map((scheduleMonth) {
          final month = scheduleMonth.month;
          final start = DateTime(month.year, month.month, 1);
          final end = DateTime(month.year, month.month + 1, 1);
          return (start, end);
        })
        .toList(growable: false);
    final preservedOutsideSelection = deduplicatedManaged.where((event) {
      if (desiredIds.contains(event.syncId) ||
          event.syncId.startsWith('legacy:duplicate-managed:')) {
        return false;
      }

      final belongsToSelectedPeriod = selectedRanges.any(
        (selectedRange) =>
            !event.start.isBefore(selectedRange.$1) &&
            event.start.isBefore(selectedRange.$2),
      );

      // Keep every managed event outside the selected months, including
      // future events. Within selected months, keep past events as history.
      // This prevents a December-only sync from deleting unselected future
      // November events merely because the provider query includes lookback.
      return !belongsToSelectedPeriod || event.start.isBefore(today);
    });
    final effectiveDesired = <CalendarEventCandidate>[
      ...desired,
      ...preservedOutsideSelection.map(_candidateFromManaged),
    ];
    final adopted = _adoptEquivalentLegacy(
      effectiveDesired,
      deduplicatedManaged,
      legacy,
    );
    final existing = adopted.map(_candidateFromManaged).toList(growable: false);
    final diff = diffEngine.compare(
      desired: effectiveDesired,
      existing: existing,
    );
    final plan = _planBuilder.build(
      diff: diff,
      existingEvents: adopted,
      calendarId: calendarId,
    );
    return CalendarSyncPreparation(
      diff: diff,
      plan: plan,
      timeMin: range.$1,
      timeMax: range.$2,
      existingEventIdsBySyncId: Map.unmodifiable({
        for (final event in adopted)
          if (event.eventId.isNotEmpty) event.syncId: event.eventId,
      }),
    );
  }

  /// Executes a plan that was prepared before user confirmation.
  Future<ResilientCalendarSyncResult> execute(
    CalendarSyncPreparation preparation,
  ) {
    return _executor.execute(preparation.plan);
  }

  Future<ResilientCalendarSyncResult> synchronize({
    required CalendarDiff diff,
    required DateTime timeMin,
    required DateTime timeMax,
    String calendarId = 'primary',
  }) async {
    final existing = await _gateway.listManagedEvents(
      timeMin: timeMin,
      timeMax: timeMax,
      calendarId: calendarId,
    );
    final plan = _planBuilder.build(
      diff: diff,
      existingEvents: existing,
      calendarId: calendarId,
    );
    return _executor.execute(plan);
  }

  /// Reads managed provider events for a pre-mapped compatibility workflow.
  Future<List<CalendarEventCandidate>> listExistingCandidates(
    List<CalendarEventCandidate> desired, {
    String calendarId = 'primary',
  }) async {
    final range = _range(desired);
    final managed = await _gateway.listManagedEvents(
      timeMin: range.$1,
      timeMax: range.$2,
      calendarId: calendarId,
    );
    return managed.map(_candidateFromManaged).toList(growable: false);
  }

  (DateTime, DateTime) _range(List<CalendarEventCandidate> candidates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lookbackStart = _subtractCalendarMonths(today, 3);
    if (candidates.isEmpty) {
      return (lookbackStart, today.add(const Duration(days: 1)));
    }
    final starts = candidates.map((candidate) => candidate.start);
    final ends = candidates.map((candidate) => candidate.end);
    final timeMin = starts.reduce(
      (left, right) => left.isBefore(right) ? left : right,
    );
    final timeMax = ends.reduce(
      (left, right) => left.isAfter(right) ? left : right,
    );
    final currentWindowEnd = today.add(const Duration(days: 1));
    return (
      lookbackStart.isBefore(timeMin) ? lookbackStart : timeMin,
      currentWindowEnd.isAfter(timeMax) ? currentWindowEnd : timeMax,
    );
  }

  /// Subtracts calendar months while clamping month-end dates (for example,
  /// May 31 minus three months becomes February 28/29, not March 3).
  DateTime _subtractCalendarMonths(DateTime value, int months) {
    final monthIndex = value.year * 12 + value.month - 1 - months;
    final year = monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = value.day > lastDay ? lastDay : value.day;
    return DateTime(year, month, day);
  }

  CalendarEventCandidate _candidateFromManaged(ManagedCalendarEvent event) {
    return CalendarEventCandidate(
      syncId: event.syncId,
      title: event.title,
      start: event.start,
      end: event.end,
      shouldExist: true,
      description: event.description,
      colorId: event.colorId,
    );
  }

  /// Retains one provider event per sync ID and marks older accidental copies
  /// as legacy cleanup operations. This lets the normal diff delete duplicates
  /// before any update or insert is executed.
  List<ManagedCalendarEvent> _deduplicateManaged(
    List<CalendarEventCandidate> desired,
    List<ManagedCalendarEvent> managed,
  ) {
    final desiredById = {
      for (final candidate in desired) candidate.syncId: candidate,
    };
    final grouped = <String, List<ManagedCalendarEvent>>{};
    for (final event in managed) {
      grouped.putIfAbsent(event.syncId, () => []).add(event);
    }

    final result = <ManagedCalendarEvent>[];
    for (final entry in grouped.entries) {
      final events = [...entry.value]
        ..sort((left, right) => left.eventId.compareTo(right.eventId));
      final desiredEvent = desiredById[entry.key];
      final exactIndex = desiredEvent == null
          ? -1
          : events.indexWhere(
              (event) =>
                  desiredEvent.contentEquals(_candidateFromManaged(event)),
            );
      final retainedIndex = exactIndex < 0 ? 0 : exactIndex;
      result.add(events[retainedIndex]);

      for (var index = 0; index < events.length; index++) {
        if (index == retainedIndex) continue;
        final duplicate = events[index];
        result.add(
          ManagedCalendarEvent(
            eventId: duplicate.eventId,
            syncId: 'legacy:duplicate-managed:${duplicate.eventId}',
            title: duplicate.title,
            start: duplicate.start,
            end: duplicate.end,
            description: duplicate.description,
            colorId: duplicate.colorId,
          ),
        );
      }
    }
    return List.unmodifiable(result);
  }

  List<ManagedCalendarEvent> _adoptEquivalentLegacy(
    List<CalendarEventCandidate> desired,
    List<ManagedCalendarEvent> managed,
    List<ManagedCalendarEvent> legacy,
  ) {
    final result = <ManagedCalendarEvent>[...managed];
    final managedIds = managed.map((event) => event.syncId).toSet();
    final adoptedProviderIds = <String>{};
    for (final candidate in desired) {
      if (managedIds.contains(candidate.syncId)) {
        final obsoleteDuplicates = legacy.where(
          (event) =>
              !adoptedProviderIds.contains(event.eventId) &&
              CalendarEventMatcher.isExactEquivalent(
                rosterTitle: candidate.title,
                rosterStart: candidate.start,
                rosterEnd: candidate.end,
                calendarTitle: event.title,
                calendarStart: event.start,
                calendarEnd: event.end,
              ),
        );
        for (final duplicate in obsoleteDuplicates) {
          adoptedProviderIds.add(duplicate.eventId);
          result.add(duplicate);
        }
        continue;
      }
      final matches = legacy
          .where(
            (event) =>
                !adoptedProviderIds.contains(event.eventId) &&
                CalendarEventMatcher.isEquivalent(
                  rosterTitle: candidate.title,
                  rosterStart: candidate.start,
                  rosterEnd: candidate.end,
                  calendarTitle: event.title,
                  calendarStart: event.start,
                  calendarEnd: event.end,
                ),
          )
          .toList(growable: false);
      if (matches.length != 1) continue;
      final event = matches.single;
      adoptedProviderIds.add(event.eventId);
      result.add(
        ManagedCalendarEvent(
          eventId: event.eventId,
          syncId: candidate.syncId,
          title: event.title,
          start: event.start,
          end: event.end,
          description: event.description,
          colorId: event.colorId,
        ),
      );
    }
    return List.unmodifiable(result);
  }
}
