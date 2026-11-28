import 'package:flutter/foundation.dart';

import '../../../core/state/controller_state.dart';
import '../domain/sync_history_entry.dart';
import '../domain/sync_history_repository.dart';

typedef RecoverSyncHistory = Future<void> Function(String historyId);
typedef LoadServerSyncHistory = Future<List<SyncHistoryEntry>> Function();
typedef RecoverServerSyncHistory = Future<void> Function(String runId);

class SyncHistoryController extends ChangeNotifier implements ControllerState {
  SyncHistoryController(
    this._repository, {
    this.recoverHistory,
    this.loadServerHistory,
    this.recoverServerRun,
  });

  final SyncHistoryRepository _repository;
  final RecoverSyncHistory? recoverHistory;
  final LoadServerSyncHistory? loadServerHistory;
  final RecoverServerSyncHistory? recoverServerRun;

  List<SyncHistoryEntry> _entries = const <SyncHistoryEntry>[];
  bool _isLoading = false;
  String? _message;
  String? _recoveringHistoryId;
  String? _recoveryMessage;
  String? _serverHistoryError;

  List<SyncHistoryEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get recoveryMessage => _recoveryMessage;
  String? get serverHistoryError => _serverHistoryError;
  String? get recoveringHistoryId => _recoveringHistoryId;
  bool get hasRecoveryAction =>
      recoverHistory != null || recoverServerRun != null;
  bool get canRecover => hasRecoveryAction && _recoveringHistoryId == null;

  @override
  String? get message => _message;

  @override
  bool get loading => _isLoading || _recoveringHistoryId != null;

  @override
  Object? get error => _message ??
      (_recoveryMessage?.startsWith('กู้คืนไม่สำเร็จ') == true
          ? _recoveryMessage
          : null);

  @override
  bool get success => !_isLoading && error == null;

  Future<void> load() async {
    _isLoading = true;
    _message = null;
    notifyListeners();

    try {
      await _refreshEntries();
    } catch (_) {
      _message = 'โหลดประวัติการซิงก์ไม่สำเร็จ';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Performs an explicit recovery action; this is never called at startup.
  /// A remote-only run is recovered by its server run ID, never by a guessed
  /// local history identifier.
  Future<bool> recover(String historyId) async {
    if (_recoveringHistoryId != null) return false;
    final selectedIndex = _entries.indexWhere((entry) => entry.id == historyId);
    if (selectedIndex < 0) return false;
    final selected = _entries[selectedIndex];

    _recoveringHistoryId = historyId;
    _recoveryMessage = null;
    notifyListeners();

    try {
      final local = await _repository.findById(historyId);
      if (local != null && recoverHistory != null) {
        await recoverHistory!(historyId);
      } else if (selected.serverRunId != null && recoverServerRun != null) {
        await recoverServerRun!(selected.serverRunId!);
      } else if (recoverHistory != null) {
        await recoverHistory!(historyId);
      } else {
        throw StateError('No recovery action is available for this history entry.');
      }
      _recoveryMessage = 'กู้คืนการซิงก์เสร็จแล้ว';
      try {
        await _refreshEntries();
      } catch (_) {
        _serverHistoryError ??= 'ไม่สามารถรีเฟรชประวัติหลังการกู้คืนได้';
      }
      return true;
    } catch (error) {
      _recoveryMessage = 'กู้คืนไม่สำเร็จ: $error';
      try {
        await _refreshEntries();
      } catch (_) {
        // Keep the last visible history if the local store is unavailable.
      }
      return false;
    } finally {
      _recoveringHistoryId = null;
      notifyListeners();
    }
  }

  Future<void> _refreshEntries() async {
    final local = await _repository.list();
    var remote = <SyncHistoryEntry>[];
    final loader = loadServerHistory;
    if (loader != null) {
      try {
        remote = await loader();
        _serverHistoryError = null;
      } catch (error) {
        // Keep local history visible; never represent a server failure as an
        // empty authoritative history list.
        _serverHistoryError = error.toString();
      }
    }
    _entries = _mergeHistory(local, remote);
  }

  List<SyncHistoryEntry> _mergeHistory(
    List<SyncHistoryEntry> local,
    List<SyncHistoryEntry> remote,
  ) {
    final byRun = <String, SyncHistoryEntry>{};
    String key(SyncHistoryEntry entry) => entry.serverRunId == null
        ? 'local:${entry.id}'
        : 'server:${entry.serverRunId}';

    for (final entry in local) {
      byRun[key(entry)] = entry;
    }
    for (final serverEntry in remote) {
      final runKey = key(serverEntry);
      final existing = byRun[runKey];
      if (existing == null) {
        byRun[runKey] = serverEntry;
      } else {
        byRun[runKey] = SyncHistoryEntry(
          id: existing.id,
          startedAt: serverEntry.startedAt,
          finishedAt: serverEntry.finishedAt,
          status: serverEntry.status,
          inserted: serverEntry.inserted,
          updated: serverEntry.updated,
          deleted: serverEntry.deleted,
          failed: serverEntry.failed,
          pending: serverEntry.pending,
          message: serverEntry.message ?? existing.message,
          scheduleId: serverEntry.scheduleId,
          serverRunId: serverEntry.serverRunId,
        );
      }
    }
    final merged = byRun.values.toList()
      ..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    return merged.take(100).toList(growable: false);
  }
}
