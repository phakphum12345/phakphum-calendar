import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/history/application/sync_history_controller.dart';
import 'package:phakphum_calendar/features/history/domain/sync_history_entry.dart';
import 'package:phakphum_calendar/features/history/domain/sync_history_repository.dart';
import 'package:phakphum_calendar/features/history/presentation/sync_history_screen.dart';

void main() {
  test('explicit recovery reloads history after the service completes', () async {
    final entry = _failedEntry();
    final repository = _MemorySyncHistoryRepository([entry]);
    var recoveredId = '';

    final controller = SyncHistoryController(
      repository,
      recoverHistory: (historyId) async {
        recoveredId = historyId;
        repository.entries = [
          entry.copyWith(
            status: SyncHistoryStatus.success,
            failed: 0,
            finishedAt: DateTime(2026, 11, 26, 10),
            message: 'Recovered successfully.',
          ),
        ];
      },
    );

    await controller.load();
    expect(controller.entries.single.status, SyncHistoryStatus.failure);

    final recovered = await controller.recover(entry.id);

    expect(recovered, isTrue);
    expect(recoveredId, entry.id);
    expect(controller.entries.single.status, SyncHistoryStatus.success);
    expect(controller.recoveryMessage, 'กู้คืนการซิงก์เสร็จแล้ว');
    controller.dispose();
  });

  test('failed recovery reports an error and keeps the failed history', () async {
    final entry = _failedEntry();
    final controller = SyncHistoryController(
      _MemorySyncHistoryRepository([entry]),
      recoverHistory: (_) async => throw StateError('server run not found'),
    );

    await controller.load();
    final recovered = await controller.recover(entry.id);

    expect(recovered, isFalse);
    expect(controller.entries.single.status, SyncHistoryStatus.failure);
    expect(controller.recoveryMessage, contains('server run not found'));
    controller.dispose();
  });

  testWidgets('local-only history does not expose cross-session recovery', (
    tester,
  ) async {
    final entry = _failedEntry().copyWith(serverRunId: null);
    final controller = SyncHistoryController(
      _MemorySyncHistoryRepository([entry]),
      recoverHistory: (_) async {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncHistoryPanel(controllerFactory: () => controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('กู้คืน'), findsNothing);
    expect(find.textContaining('ไม่มี Server Run ID'), findsOneWidget);
  });

  testWidgets('history panel requires confirmation before recovery', (
    tester,
  ) async {
    final entry = _failedEntry();
    final repository = _MemorySyncHistoryRepository([entry]);
    var recovered = false;
    final controller = SyncHistoryController(
      repository,
      recoverHistory: (_) async {
        recovered = true;
        repository.entries = [
          entry.copyWith(
            status: SyncHistoryStatus.success,
            failed: 0,
            finishedAt: DateTime(2026, 11, 26, 10),
          ),
        ];
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncHistoryPanel(controllerFactory: () => controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('กู้คืน'), findsOneWidget);
    expect(recovered, isFalse);

    await tester.tap(find.text('กู้คืน'));
    await tester.pumpAndSettle();
    expect(find.text('ยืนยันการกู้คืนการซิงก์'), findsOneWidget);
    expect(recovered, isFalse);

    await tester.tap(find.text('ยืนยันกู้คืน'));
    await tester.pumpAndSettle();

    expect(recovered, isTrue);
    expect(find.text('สำเร็จ'), findsOneWidget);
  });
}

SyncHistoryEntry _failedEntry() => SyncHistoryEntry(
  id: 'local-history-1',
  startedAt: DateTime(2026, 11, 26, 8),
  status: SyncHistoryStatus.failure,
  inserted: 0,
  updated: 0,
  deleted: 0,
  failed: 1,
  scheduleId: 'schedule-1',
  serverRunId: 'remote-run-1',
);

class _MemorySyncHistoryRepository implements SyncHistoryRepository {
  _MemorySyncHistoryRepository(this.entries);

  List<SyncHistoryEntry> entries;

  @override
  Future<SyncHistoryEntry?> findById(String id) async {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Future<List<SyncHistoryEntry>> list({int limit = 100}) async =>
      entries.take(limit).toList(growable: false);

  @override
  Future<void> save(SyncHistoryEntry entry) async {
    entries = [
      entry,
      ...entries.where((existing) => existing.id != entry.id),
    ];
  }
}
