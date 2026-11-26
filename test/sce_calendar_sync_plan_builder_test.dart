import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/calendar_engine/application/calendar_sync_plan_builder.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/managed_calendar_event.dart';
import 'package:phakphum_calendar/features/diff_engine/domain/calendar_diff.dart';
import 'package:phakphum_calendar/features/diff_engine/domain/calendar_event_candidate.dart';

void main() {
  test('maps diff candidates to concrete event operations', () {
    final start = DateTime(2026, 8, 4, 8);
    final end = DateTime(2026, 8, 4, 16);

    CalendarEventCandidate candidate(String id) => CalendarEventCandidate(
      syncId: id,
      title: 'ER เช้า',
      start: start,
      end: end,
      shouldExist: true,
    );

    final plan = const CalendarSyncPlanBuilder().build(
      diff: CalendarDiff(
        toAdd: [candidate('add')],
        toUpdate: [candidate('update')],
        toDelete: [candidate('delete')],
        unchanged: const [],
      ),
      existingEvents: [
        ManagedCalendarEvent(
          eventId: 'google-update',
          syncId: 'update',
          title: 'Old',
          start: start,
          end: end,
          etag: 'etag-update',
        ),
        ManagedCalendarEvent(
          eventId: 'google-delete',
          syncId: 'delete',
          title: 'Delete',
          start: start,
          end: end,
          etag: 'etag-delete',
        ),
      ],
    );

    expect(plan.inserts.single.syncId, 'add');
    expect(plan.updates.single.eventId, 'google-update');
    expect(plan.updates.single.expectedEtag, 'etag-update');
    expect(plan.updates.single.expectedSyncId, 'update');
    expect(plan.deletes.single.eventId, 'google-delete');
    expect(plan.deletes.single.expectedEtag, 'etag-delete');
    expect(plan.deletes.single.expectedSyncId, 'delete');
  });
}
