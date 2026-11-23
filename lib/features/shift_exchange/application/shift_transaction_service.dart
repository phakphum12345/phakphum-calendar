import '../domain/shift_transaction.dart';

/// Persistence contract for transactions shared between Google accounts.
///
/// Implementations must make create idempotent for an account/key pair and
/// implement save as an atomic compare-and-swap against expectedVersion.
abstract interface class ShiftTransactionRepository {
  Future<ShiftTransaction> create(
    ShiftTransaction transaction, {
    required String idempotencyKey,
  });

  Future<ShiftTransaction?> findById(String id);

  Future<void> save(
    ShiftTransaction transaction, {
    required int expectedVersion,
  });
}

/// Server-backed authorization check for organization approvers.
abstract interface class ShiftTransactionApprovalAuthorizer {
  Future<bool> canApprove({
    required String accountSubject,
    required String organizationId,
  });
}

/// Coordinates transaction state changes without performing provider writes.
class ShiftTransactionService {
  const ShiftTransactionService({
    required this.repository,
    required this.approvalAuthorizer,
    required this.clock,
  });

  final ShiftTransactionRepository repository;
  final ShiftTransactionApprovalAuthorizer approvalAuthorizer;
  final DateTime Function() clock;

  /// Creates a transaction using a repository-enforced idempotency key.
  ///
  /// The repository returns the existing transaction when the same key is
  /// retried, and rejects reuse of a key for a different request payload.
  Future<ShiftTransaction> create({
    required ShiftTransaction transaction,
    required String idempotencyKey,
  }) async {
    if (idempotencyKey.trim().isEmpty) {
      throw ArgumentError.value(idempotencyKey, 'idempotencyKey', 'Required');
    }
    return repository.create(transaction, idempotencyKey: idempotencyKey);
  }

  /// Records one participant's confirmation with optimistic concurrency.
  Future<ShiftTransaction> confirm({
    required String transactionId,
    required String accountSubject,
  }) async {
    final current = await _require(transactionId);
    if (current.participants.any((item) =>
        item.accountSubject == accountSubject && item.hasConfirmed)) {
      return current;
    }
    return _save(current, current.confirm(
      accountSubject: accountSubject,
      at: clock(),
    ));
  }

  /// Records a participant rejection.
  Future<ShiftTransaction> rejectByParticipant({
    required String transactionId,
    required String accountSubject,
    String? reason,
  }) async {
    final current = await _require(transactionId);
    return _save(current, current.rejectByParticipant(
      accountSubject: accountSubject,
      at: clock(),
      reason: reason,
    ));
  }

  /// Approves only after server-backed organization authorization succeeds.
  Future<ShiftTransaction> approve({
    required String transactionId,
    required String approverAccountSubject,
    required String organizationId,
    String? note,
  }) async {
    final current = await _require(transactionId);
    final authorized = await approvalAuthorizer.canApprove(
      accountSubject: approverAccountSubject,
      organizationId: organizationId,
    );
    return _save(current, current.approve(
      approverAccountSubject: approverAccountSubject,
      organizationId: organizationId,
      authorized: authorized,
      at: clock(),
      note: note,
    ));
  }

  /// Rejects an organization request after checking the approver's membership.
  Future<ShiftTransaction> rejectByApprover({
    required String transactionId,
    required String approverAccountSubject,
    required String organizationId,
    String? reason,
  }) async {
    final current = await _require(transactionId);
    final authorized = await approvalAuthorizer.canApprove(
      accountSubject: approverAccountSubject,
      organizationId: organizationId,
    );
    return _save(current, current.rejectByApprover(
      approverAccountSubject: approverAccountSubject,
      organizationId: organizationId,
      authorized: authorized,
      at: clock(),
      reason: reason,
    ));
  }

  /// Cancels a request before its Calendar write begins.
  Future<ShiftTransaction> cancel({
    required String transactionId,
    required String accountSubject,
  }) async {
    final current = await _require(transactionId);
    return _save(current, current.cancel(
      accountSubject: accountSubject,
      at: clock(),
    ));
  }

  /// Starts a Calendar synchronization after preview and explicit confirmation.
  Future<ShiftTransaction> startCalendarSync({
    required String transactionId,
    required bool previewConfirmed,
  }) async {
    final current = await _require(transactionId);
    return _save(current, current.startCalendarSync(
      previewConfirmed: previewConfirmed,
      at: clock(),
    ));
  }

  /// Records verified completion of the Calendar write.
  Future<ShiftTransaction> completeCalendarSync(String transactionId) async {
    final current = await _require(transactionId);
    return _save(current, current.completeCalendarSync(clock()));
  }

  /// Records a recoverable Calendar synchronization failure.
  Future<ShiftTransaction> failCalendarSync(
    String transactionId, {
    String? reason,
  }) async {
    final current = await _require(transactionId);
    return _save(current, current.failCalendarSync(clock(), reason: reason));
  }

  /// Settles one shift obligation; exchange-and-return remains open until both
  /// transfer legs are fulfilled.
  Future<ShiftTransaction> fulfillTransfer({
    required String transactionId,
    required String transferId,
  }) async {
    final current = await _require(transactionId);
    return _save(current, current.fulfillTransfer(
      transferId: transferId,
      at: clock(),
    ));
  }

  Future<ShiftTransaction> _require(String transactionId) async {
    final value = await repository.findById(transactionId);
    if (value == null) throw StateError('Shift transaction not found.');
    return value;
  }

  Future<ShiftTransaction> _save(
    ShiftTransaction current,
    ShiftTransaction updated,
  ) async {
    if (identical(current, updated)) return current;
    await repository.save(updated, expectedVersion: current.version);
    return updated;
  }
}
