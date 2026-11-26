import 'package:flutter/foundation.dart';

import '../../../core/state/controller_state.dart';
import '../domain/sync_history_entry.dart';
import '../domain/sync_history_repository.dart';

typedef RecoverSyncHistory = Future<void> Function(String historyId);

class SyncHistoryController extends ChangeNotifier implements ControllerState {
  SyncHistoryController(
    this._repository, {
    RecoverSyncHistory? recoverHistory,
  }) : _recoverHistory = recoverHistory;

  final SyncHistoryRepository _repository;
  final RecoverSyncHistory? _recoverHistory;

  List<SyncHistoryEntry> _entries = const <SyncHistoryEntry>[];
  bool _isLoading = false;
  String? _message;
  String? _recoveringHistoryId;
  String? _recoveryMessage;

  List<SyncHistoryEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get recoveryMessage => _recoveryMessage;
  String? get recoveringHistoryId => _recoveringHistoryId;
  bool get hasRecoveryAction => _recoverHistory != null;
  bool get canRecover => hasRecoveryAction && _recoveringHistoryId == null;

  @override
  String? get message => _message;

  @override
  bool get loading => _isLoading || _recoveringHistoryId != null;

  @override
  Object? get error => _message ?? _recoveryMessage;

  @override
  bool get success => !_isLoading && _message == null;

  Future<void> load() async {
    _isLoading = true;
    _message = null;
    notifyListeners();

    try {
      _entries = await _repository.list();
    } catch (_) {
      _message = 'โหลดประวัติการซิงก์ไม่สำเร็จ';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Performs an explicit recovery action; this is never called at startup.
  Future<bool> recover(String historyId) async {
    final recoverHistory = _recoverHistory;
    if (recoverHistory == null || _recoveringHistoryId != null) return false;

    _recoveringHistoryId = historyId;
    _recoveryMessage = null;
    notifyListeners();

    try {
      await recoverHistory(historyId);
      _entries = await _repository.list();
      _recoveryMessage = 'กู้คืนการซิงก์เสร็จแล้ว';
      return true;
    } catch (error) {
      _recoveryMessage = 'กู้คืนไม่สำเร็จ: $error';
      return false;
    } finally {
      _recoveringHistoryId = null;
      notifyListeners();
    }
  }
}
