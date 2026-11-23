import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_exchange/application/shift_transaction_service.dart';
import 'package:phakphum_calendar/features/shift_exchange/domain/shift_transaction.dart';

void main() {
  final createdAt = DateTime(2026, 11, 1, 9);
  final clockValue = DateTime(2026, 11, 1, 10);

  ShiftTransaction request() => ShiftTransaction.create(
    id: 'tx-service',
    type: ShiftTransactionType.giveUp,
    mode: ShiftTransactionMode.organization,
    createdByAccountSubject: 'google-a',
    participants: const [
      ShiftTransactionParticipant(
        employeeId: 'employee-a',
        accountSubject: 'google-a',
        role: ShiftTransactionParticipantRole.requester,
      ),
      ShiftTransactionParticipant(
        employeeId: 'employee-b',
        accountSubject: 'google-b',
        role: ShiftTransactionParticipantRole.recipient,
      ),
    ],
    transfers: [
      ShiftTransfer(
        id: 'leg',
        shiftId: 'shift',
        fromEmployeeId: 'employee-a',
        toEmployeeId: 'employee-b',
        shiftCode: 'เช้า',
        startsAt: DateTime(2026, 11, 12, 8),
        endsAt: DateTime(2026, 11, 12, 16),
        purpose: ShiftTransferPurpose.giveUp,
      ),
    ],
    createdAt: createdAt,
    requiresOrganizationApproval: true,
    organizationId: 'org-1',
  );

  test('service uses server authorization before organization approval', () async {
    final repository = _MemoryRepository();
    final authorizer = _FakeAuthorizer(allowed: false);
    final service = ShiftTransactionService(
      repository: repository,
      approvalAuthorizer: authorizer,
      clock: () => clockValue,
    );
    await service.create(transaction: request(), idempotencyKey: 'request-1');
    await service.confirm(transactionId: 'tx-service', accountSubject: 'google-a');
    await service.confirm(transactionId: 'tx-service', accountSubject: 'google-b');

    await expectLater(
      service.approve(
        transactionId: 'tx-service',
        approverAccountSubject: 'manager',
        organizationId: 'org-1',
      ),
      throwsStateError,
    );
    expect(authorizer.calls, 1);
    expect(
      (await repository.findById('tx-service'))!.status,
      ShiftTransactionStatus.pendingApproval,
    );

    authorizer.allowed = true;
    final approved = await service.approve(
      transactionId: 'tx-service',
      approverAccountSubject: 'manager',
      organizationId: 'org-1',
    );
    expect(approved.status, ShiftTransactionStatus.approved);
    expect(approved.approvedByAccountSubject, 'manager');
  });

  test('service rejects stale writes using the expected transaction version', () async {
    final repository = _MemoryRepository();
    final service = ShiftTransactionService(
      repository: repository,
      approvalAuthorizer: _FakeAuthorizer(allowed: true),
      clock: () => clockValue,
    );
    final created = await service.create(
      transaction: request(),
      idempotencyKey: 'request-2',
    );
    final changed = created.confirm(
      accountSubject: 'google-a',
      at: clockValue,
    );
    await repository.save(changed, expectedVersion: created.version);

    await expectLater(
      repository.save(created, expectedVersion: created.version),
      throwsStateError,
    );
  });
}

class _MemoryRepository implements ShiftTransactionRepository {
  final Map<String, ShiftTransaction> values = {};
  final Map<String, String> idempotencyKeys = {};

  @override
  Future<ShiftTransaction> create(
    ShiftTransaction transaction, {
    required String idempotencyKey,
  }) async {
    final previousId = idempotencyKeys[idempotencyKey];
    if (previousId != null) {
      final previous = values[previousId]!;
      if (previous.id != transaction.id) {
        throw StateError('Idempotency key reused for a different request.');
      }
      return previous;
    }
    if (values.containsKey(transaction.id)) {
      throw StateError('Transaction already exists.');
    }
    values[transaction.id] = transaction;
    idempotencyKeys[idempotencyKey] = transaction.id;
    return transaction;
  }

  @override
  Future<ShiftTransaction?> findById(String id) async => values[id];

  @override
  Future<void> save(
    ShiftTransaction transaction, {
    required int expectedVersion,
  }) async {
    final current = values[transaction.id];
    if (current == null || current.version != expectedVersion) {
      throw StateError('Transaction version conflict.');
    }
    if (transaction.version != expectedVersion + 1) {
      throw StateError('Invalid next transaction version.');
    }
    values[transaction.id] = transaction;
  }
}

class _FakeAuthorizer implements ShiftTransactionApprovalAuthorizer {
  _FakeAuthorizer({required this.allowed});

  bool allowed;
  int calls = 0;

  @override
  Future<bool> canApprove({
    required String accountSubject,
    required String organizationId,
  }) async {
    calls++;
    return allowed && accountSubject == 'manager' && organizationId == 'org-1';
  }
}
