import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/features/schedule/data/schedule_json_codec.dart';
import 'package:phakphum_calendar/features/shift_parser/data/backend_grid_roster_import_journal_gateway.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/grid_roster_import_provenance.dart';
import 'package:phakphum_calendar/features/shift_parser/data/grid_roster_import_provenance_json_codec.dart';

void main() {
  const scheduleCodec = ScheduleJsonCodec();
  const provenanceCodec = GridRosterImportProvenanceJsonCodec();
  final schedule = Schedule(id: 'schedule-1', name: 'November roster');
  final acceptedFingerprint =
      'sha256:${sha256.convert(utf8.encode(scheduleCodec.encode(schedule)))}';
  final prepared = _provenance(
    lifecycle: GridRosterImportLifecycle.prepared,
  );
  final committed = _provenance(
    lifecycle: GridRosterImportLifecycle.committed,
    acceptedScheduleFingerprint: acceptedFingerprint,
  );

  test('posts PREPARED and COMMITTED stages using backend fingerprint format', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode({'data': <String, Object?>{}}), 201);
    });
    final gateway = BackendGridRosterImportJournalGateway(
      baseUrl: 'https://api.example.test/',
      idTokenProvider: () async => 'google-id-token',
      httpClient: client,
    );

    await gateway.appendPrepared(scheduleId: schedule.id, provenance: prepared);
    await gateway.appendCommitted(schedule: schedule, provenance: committed);

    expect(requests, hasLength(2));
    expect(requests.every((request) => request.method == 'POST'), isTrue);
    expect(requests.every((request) => request.url.path ==
        '/api/v1/schedules/schedule-1/import-journals'), isTrue);
    expect(requests.every((request) =>
        request.headers['authorization'] == 'Bearer google-id-token'), isTrue);

    final preparedBody = jsonDecode(requests.first.body) as Map<String, dynamic>;
    expect(preparedBody['import_run_id'], 'grid-1795520000000000');
    expect(preparedBody['lifecycle'], 'prepared');
    expect(preparedBody['source_fingerprint'], 'a' * 64);
    expect(preparedBody['provenance']['sourceFingerprint'], 'sha256:${'a' * 64});
    expect(preparedBody.containsKey('schedule'), isFalse);

    final committedBody = jsonDecode(requests.last.body) as Map<String, dynamic>;
    expect(committedBody['lifecycle'], 'committed');
    expect(committedBody['accepted_schedule_fingerprint'],
        acceptedFingerprint.substring('sha256:'.length));
    expect(committedBody['schedule']['format'], ScheduleJsonCodec.format);
    expect(committedBody['schedule']['schedule']['id'], schedule.id);
  });

  test('recovers the newest committed canonical bundle from backend journal', () async {
    final scheduleEnvelope = jsonDecode(scheduleCodec.encode(schedule));
    final provenanceEnvelope = jsonDecode(provenanceCodec.encode(committed)) as Map;
    final provenancePayload = provenanceEnvelope['provenance'];
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      return http.Response(
        jsonEncode({
          'data': [
            {
              'schedule_id': schedule.id,
              'lifecycle': 'committed',
              'schedule': scheduleEnvelope,
              'provenance': provenancePayload,
              'created_at': '2026-11-25T10:00:00Z',
            },
          ],
        }),
        200,
      );
    });
    final gateway = BackendGridRosterImportJournalGateway(
      baseUrl: 'https://api.example.test',
      idTokenProvider: () async => 'google-id-token',
      httpClient: client,
    );

    final recovered = await gateway.recover(schedule.id);

    expect(recovered, isNotNull);
    expect(recovered!.schedule.id, schedule.id);
    expect(recovered.provenance.importRunId, committed.importRunId);
    expect(recovered.provenance.lifecycle, GridRosterImportLifecycle.committed);
    expect(recovered.provenance.acceptedScheduleFingerprint,
        acceptedFingerprint);
  });
}

GridRosterImportProvenance _provenance({
  required GridRosterImportLifecycle lifecycle,
  String? acceptedScheduleFingerprint,
}) {
  return GridRosterImportProvenance(
    importRunId: 'grid-1795520000000000',
    sourceFingerprint: 'sha256:${'a' * 64}',
    parserVersion: 'grid-roster/1',
    createdAtUtc: DateTime.utc(2026, 11, 25, 10),
    targetScheduleId: 'schedule-1',
    targetScheduleRevision: 'absent:schedule-1',
    lifecycle: lifecycle,
    acceptedScheduleFingerprint: acceptedScheduleFingerprint,
    sections: const [],
    assignments: const [],
    diagnostics: const [],
  );
}
