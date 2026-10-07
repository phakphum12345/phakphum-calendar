import 'package:flutter_test/flutter_test.dart';

import 'package:phakphum_calendar/features/calendar_sync/domain/calendar_sync_protocol.dart';

void main() {
  group('CalendarSyncProtocolRequest', () {
    test('accepts a valid sync request', () {
      final request = CalendarSyncProtocolRequest(
        syncId: 'sync-001',
        timeMin: DateTime(2026, 10, 1),
        timeMax: DateTime(2026, 11, 1),
      );

      expect(() => request.validate(), returnsNormally);
    });

    test('rejects an empty sync ID', () {
      final request = CalendarSyncProtocolRequest(
        syncId: '   ',
        timeMin: DateTime(2026, 10, 1),
        timeMax: DateTime(2026, 11, 1),
      );

      expect(
        request.validate,
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects an invalid time range', () {
      final request = CalendarSyncProtocolRequest(
        syncId: 'sync-001',
        timeMin: DateTime(2026, 11, 1),
        timeMax: DateTime(2026, 10, 1),
      );

      expect(
        request.validate,
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts dry-run requests', () {
      final request = CalendarSyncProtocolRequest(
        syncId: 'sync-dry-run',
        timeMin: DateTime(2026, 10, 1),
        timeMax: DateTime(2026, 11, 1),
        dryRun: true,
      );

      expect(request.dryRun, isTrue);
      expect(() => request.validate(), returnsNormally);
    });
  });

  group('CalendarSyncProtocolResult', () {
    test('completed result is successful', () {
      final result = CalendarSyncProtocolResult(
        syncId: 'sync-001',
        status: CalendarSyncProtocolStatus.completed,
        commandsPlanned: 3,
        commandsExecuted: 3,
        commandsSkipped: 0,
        errors: const [],
      );

      expect(result.succeeded, isTrue);
      expect(result.hasErrors, isFalse);
    });

    test('dry-run result is successful', () {
      final result = CalendarSyncProtocolResult(
        syncId: 'sync-dry-run',
        status: CalendarSyncProtocolStatus.dryRun,
        commandsPlanned: 3,
        commandsExecuted: 0,
        commandsSkipped: 3,
        errors: const [],
      );

      expect(result.succeeded, isTrue);
      expect(result.commandsExecuted, 0);
    });

    test('failed result reports errors', () {
      final result = CalendarSyncProtocolResult(
        syncId: 'sync-001',
        status: CalendarSyncProtocolStatus.failed,
        commandsPlanned: 1,
        commandsExecuted: 0,
        commandsSkipped: 1,
        errors: const [
          CalendarSyncProtocolError(
            code: 'PROVIDER_ERROR',
            message: 'Provider request failed.',
          ),
        ],
      );

      expect(result.succeeded, isFalse);
      expect(result.hasErrors, isTrue);
      expect(result.errors, hasLength(1));
    });
  });
}
