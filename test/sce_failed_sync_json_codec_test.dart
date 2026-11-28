import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_command.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_operation_result.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/failed_sync_operation.dart';
import 'package:phakphum_calendar/features/calendar_engine/infrastructure/failed_sync_json_codec.dart';

void main() {
  test('round-trips failed operation payloads', () {
    const codec = FailedSyncJsonCodec();
    final values = [
      FailedSyncOperation(
        historyId: 'h1',
        type: CalendarSyncOperationType.insert,
        referenceId: 'sync-1',
        attempts: 2,
        expectedEtag: 'etag-123',
        expectedSyncId: 'sync-1',
        command: CalendarSyncCommand(
          syncId: 'sync-1',
          title: 'ER เช้า',
          start: DateTime(2026, 8, 4, 8),
          end: DateTime(2026, 8, 4, 16),
        ),
      ),
    ];
    final decoded = codec.decode(codec.encode(values));
    expect(decoded.single.command!.title, 'ER เช้า');
    expect(decoded.single.attempts, 2);
    expect(decoded.single.expectedEtag, 'etag-123');
    expect(decoded.single.expectedSyncId, 'sync-1');
  });
}
