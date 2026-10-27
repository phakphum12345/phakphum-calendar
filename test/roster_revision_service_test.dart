import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phakphum_calendar/services/roster_revision_service.dart';

void main() {
  test('downloads a revision export with HTTP GET', () async {
    var exportRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/revisions')) {
        return http.Response(
          jsonEncode({
            'revisions': [
              {
                'id': 'revision-1',
                'modifiedTime': '2026-10-01T00:00:00.000Z',
                'exportLinks': {
                  RosterRevisionService.xlsxMimeType:
                      'https://example.test/revision.xlsx',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.host == 'example.test') {
        exportRequests++;
        expect(request.method, 'GET');
        return http.Response('not found', 404);
      }

      return http.Response('{}', 404);
    });

    final skippedRevisionIds = <String>[];
    final documents = await const RosterRevisionService().readHistoryTransient(
      client,
      'spreadsheet-id',
      onRevisionSkipped: (revisionId, _) => skippedRevisionIds.add(revisionId),
    );

    // A failed export is reported but does not abort the entire history read.
    expect(documents, isEmpty);
    expect(skippedRevisionIds, ['revision-1']);
    expect(exportRequests, 1);
    client.close();
  });
}
