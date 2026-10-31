import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phakphum_calendar/models/shift.dart';
import 'package:phakphum_calendar/services/roster_revision_service.dart';
import 'package:phakphum_calendar/services/timeline_archive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores revisions idempotently and scopes them by account and file',
      () async {
    const archive = TimelineArchiveService();
    final document = RosterRevisionDocument(
      revisionId: 'revision-1',
      modifiedAt: DateTime.utc(2026, 9, 28),
      snapshots: const [
        SheetSnapshot(
          title: 'October roster',
          rows: [
            ['Name', 'Shift'],
            ['A', 'ER'],
          ],
          backgroundColors: [
            [null, null],
            [null, 0xFF00FF00],
          ],
        ),
      ],
    );

    await archive.putRevision(
      accountId: 'user@example.com',
      fileId: 'sheet-1',
      document: document,
    );
    await archive.putRevision(
      accountId: 'user@example.com',
      fileId: 'sheet-1',
      document: document,
    );

    final records = await archive.readRevisions(
      accountId: 'user@example.com',
      fileId: 'sheet-1',
    );
    expect(records, hasLength(1));
    expect(records.single.revisionId, 'revision-1');
    expect(records.single.snapshots.single.rows[1][0], 'A');
    expect(records.single.snapshots.single.backgroundColors[1][1], 0xFF00FF00);

    expect(
      await archive.readRevisions(
        accountId: 'other@example.com',
        fileId: 'sheet-1',
      ),
      isEmpty,
    );
    expect(
      await archive.readRevisions(
        accountId: 'user@example.com',
        fileId: 'sheet-2',
      ),
      isEmpty,
    );
  });

  test('persists and reloads a resumable sync checkpoint', () async {
    const archive = TimelineArchiveService();

    await archive.saveCheckpoint(
      accountId: 'user@example.com',
      fileId: 'sheet-1',
      nextIndex: 12,
      total: 62,
      complete: false,
      lastError: 'HTTP 429',
    );

    final checkpoint = await archive.readCheckpoint(
      accountId: 'user@example.com',
      fileId: 'sheet-1',
    );
    expect(checkpoint?['nextIndex'], 12);
    expect(checkpoint?['total'], 62);
    expect(checkpoint?['complete'], false);
    expect(checkpoint?['lastError'], 'HTTP 429');
  });
  test('does not download Drive exports already present in local archive',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        '''
        {
          "revisions": [
            {
              "id": "revision-1",
              "modifiedTime": "2026-09-28T00:00:00.000Z",
              "exportLinks": {
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
                    "https://example.test/revision-1.xlsx"
              }
            }
          ]
        }
        ''',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    try {
      final revisions = await const RosterRevisionService()
          .readHistoryTransient(
            client,
            'sheet-1',
            knownRevisionIds: {'revision-1'},
          );

      expect(revisions, isEmpty);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, contains('/revisions'));
    } finally {
      client.close();
    }
  });

}
