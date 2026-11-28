import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/history/domain/sync_history_entry.dart';
import 'package:phakphum_calendar/features/history/infrastructure/sync_history_json_codec.dart';

void main() {
  test('round-trips history entries', () {
    const codec = SyncHistoryJsonCodec();
    final source = [
      SyncHistoryEntry(
        id: 'h1',
        startedAt: DateTime(2026, 7, 22),
        status: SyncHistoryStatus.partialSuccess,
        inserted: 1,
        updated: 2,
        deleted: 3,
        failed: 1,
        pending: 2,
      ),
    ];
    final decoded = codec.decodeList(codec.encodeList(source));
    expect(decoded.single.id, 'h1');
    expect(decoded.single.failed, 1);
    expect(decoded.single.pending, 2);
  });

  test('older history records without pending count decode as zero', () {
    const codec = SyncHistoryJsonCodec();
    final decoded = codec.decodeList(
      '[{"id":"legacy","startedAt":"2026-07-22T00:00:00.000",'
      '"status":"success","inserted":1,"updated":0,"deleted":0,"failed":0}]',
    );
    expect(decoded.single.pending, 0);
  });
}
