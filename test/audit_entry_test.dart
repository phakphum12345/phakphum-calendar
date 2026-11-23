import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/models/audit_entry.dart';

void main() {
  group('AuditEntry JSON compatibility', () {
    test('reads legacy records without actor or entity metadata', () {
      final entry = AuditEntry.fromJson({
        'timestamp': '2026-10-26T12:00:00.000Z',
        'action': 'cancelled',
        'message': 'Request cancelled',
        'success': true,
      });

      expect(entry.action, 'cancelled');
      expect(entry.actorId, isNull);
      expect(entry.entityId, isNull);
      expect(entry.previousState, isNull);
      expect(entry.newState, isNull);
    });

    test('round-trips actor, entity, and state transition metadata', () {
      final entry = AuditEntry(
        timestamp: DateTime.utc(2026, 10, 26, 12),
        action: 'cancelled',
        message: 'Exchange request cancelled',
        success: true,
        actorId: 'account-123',
        entityType: 'shift_exchange',
        entityId: 'request-456',
        previousState: 'pending',
        newState: 'cancelled',
      );

      final restored = AuditEntry.fromJson(entry.toJson());

      expect(restored.actorId, 'account-123');
      expect(restored.entityType, 'shift_exchange');
      expect(restored.entityId, 'request-456');
      expect(restored.previousState, 'pending');
      expect(restored.newState, 'cancelled');
      expect(restored.timestamp, entry.timestamp);
    });

    test('normalizes empty actor identifiers to unknown', () {
      final entry = AuditEntry.fromJson({
        'timestamp': '2026-10-26T12:00:00.000Z',
        'action': 'created',
        'message': 'Request created',
        'success': true,
        'actorId': '   ',
      });

      expect(entry.actorId, isNull);
    });
  });
}
