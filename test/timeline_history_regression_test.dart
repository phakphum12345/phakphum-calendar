import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phakphum_calendar/features/calendar_sync/infrastructure/google_calendar_event_repository.dart';
import 'package:phakphum_calendar/features/calendar_sync/infrastructure/google_calendar_event_mapper.dart';
import 'package:phakphum_calendar/features/diff_engine/domain/calendar_event_candidate.dart';
import 'package:phakphum_calendar/models/roster_assignment_timeline.dart';
import 'package:phakphum_calendar/models/shift.dart';
import 'package:phakphum_calendar/services/calendar_service.dart';
import 'package:phakphum_calendar/services/roster_revision_service.dart';
import 'package:phakphum_calendar/services/timeline_archive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('appends Timeline records and keeps earlier entries idempotently', () {
    final first = CalendarService.withTimelineRecord(
      'Roster details',
      '[SHIFT_UPDATED] first change\nผู้แก้ไข: A\nรายละเอียด: แก้ไขเวร',
    );
    final second = CalendarService.withTimelineRecord(
      first,
      '[SHIFT_EXCHANGED] second change',
    );
    final duplicate = CalendarService.withTimelineRecord(
      second,
      '[SHIFT_EXCHANGED] second change',
    );

    expect(second, contains('[SHIFT_UPDATED] first change'));
    expect(second, contains('รายละเอียด: แก้ไขเวร'));
    expect(second, contains('[SHIFT_EXCHANGED] second change'));
    expect(RegExp('--- Timeline ---').allMatches(second), hasLength(1));
    expect(duplicate, second);
  });

  test('preserves the existing Timeline section when syncing an event update', () async {
    final requests = <http.Request>[];
    Map<String, dynamic>? updatedEvent;
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'id': 'event-1',
            'summary': 'เวรเช้า',
            'description':
                'Old roster details\n\n--- Timeline ---\n'
                '[SHIFT_UPDATED] first historical change\n'
                '[SHIFT_EXCHANGED] second historical change',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'PUT') {
        updatedEvent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'id': 'event-1'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Unexpected request', 500);
    });
    addTearDown(client.close);

    final repository = GoogleCalendarEventRepository(
      calendarApi: calendar.CalendarApi(client),
      calendarId: 'primary',
    );
    await repository.updateEvent(
      providerEventId: 'event-1',
      candidate: CalendarEventCandidate(
        syncId: 'shift-1',
        title: 'เวรเช้า',
        start: DateTime.utc(2026, 11, 7, 1),
        end: DateTime.utc(2026, 11, 7, 9),
        shouldExist: true,
        description: 'New roster details',
      ),
    );

    expect(requests.map((request) => request.method), ['GET', 'PUT']);
    expect(updatedEvent?['description'],
        'New roster details\n\n--- Timeline ---\n'
        '[SHIFT_UPDATED] first historical change\n'
        '[SHIFT_EXCHANGED] second historical change');
  });

  test('excludes the preserved audit section from roster sync comparisons', () {
    final record = const GoogleCalendarEventMapper().fromGoogleEvent(
      calendar.Event(
        id: 'event-1',
        summary: 'เวรเช้า',
        description: 'Roster details\n\n--- Timeline ---\n'
            '[SHIFT_UPDATED] historical change',
        start: calendar.EventDateTime(dateTime: DateTime.utc(2026, 11, 7, 1)),
        end: calendar.EventDateTime(dateTime: DateTime.utc(2026, 11, 7, 9)),
        extendedProperties: calendar.EventExtendedProperties(
          private: <String, String>{'syncId': 'shift-1'},
        ),
      ),
    );

    expect(record, isNotNull);
    expect(record!.candidate.description, 'Roster details');
  });

  test('migrates email-scoped local revisions to stable account ID without deleting legacy data', () async {
    SharedPreferences.setMockInitialValues({});
    const archive = TimelineArchiveService();
    final revision = RosterRevisionDocument(
      revisionId: 'revision-legacy-1',
      modifiedAt: DateTime.utc(2026, 11, 1, 10),
      snapshots: const [
        SheetSnapshot(
          title: 'Roster',
          spreadsheetId: 'sheet-1',
          sheetId: 12,
          rows: [
            ['Name', 'Shift'],
            ['A', 'ER'],
          ],
        ),
      ],
    );
    await archive.putRevision(
      accountId: 'person@example.com',
      fileId: 'sheet-1',
      document: revision,
    );

    final migrated = await archive.readRevisionsWithLegacyAccountScope(
      accountId: 'stable-google-subject',
      legacyAccountId: 'person@example.com',
      fileId: 'sheet-1',
    );

    expect(migrated.map((item) => item.revisionId), ['revision-legacy-1']);
    expect(
      (await archive.readRevisions(
        accountId: 'stable-google-subject',
        fileId: 'sheet-1',
      )).map((item) => item.revisionId),
      ['revision-legacy-1'],
    );
    expect(
      (await archive.readRevisions(
        accountId: 'person@example.com',
        fileId: 'sheet-1',
      )).map((item) => item.revisionId),
      ['revision-legacy-1'],
    );
  });

  test('keeps assignment identity when roster rows move within a sheet', () {
    Shift source(
      String worker,
      String cell, {
      bool hasGoogleSheetMetadata = false,
    }) => Shift(
      code: 'UP1',
      rowLabel: 'P1 เช้า',
      assignedName: worker,
      start: DateTime(2026, 11, 10, 8),
      end: DateTime(2026, 11, 10, 16),
      sheetTitle: 'Old sheet title',
      cell: cell,
      category: ShiftCategory.own,
      sourceSpreadsheetId:
          hasGoogleSheetMetadata ? 'spreadsheet-1' : null,
      sourceSheetId: hasGoogleSheetMetadata ? 42 : null,
    );

    // Drive XLSX exports have no Google sheet ID; the live Sheets snapshot does.
    final before = source('A', 'D11');
    final after = source('B', 'D17', hasGoogleSheetMetadata: true);
    expect(rosterPositionKey(before), rosterPositionKey(after));

    final timeline = buildRosterAssignmentTimelines([
      RosterRevisionShifts(
        revisionId: 'revision-1',
        modifiedAt: DateTime.utc(2026, 11, 1),
        shifts: [before],
      ),
      RosterRevisionShifts(
        revisionId: 'revision-2',
        modifiedAt: DateTime.utc(2026, 11, 2),
        shifts: [after],
      ),
    ]);
    expect(timeline.values.single.workerChain, ['A', 'B']);
  });
}
