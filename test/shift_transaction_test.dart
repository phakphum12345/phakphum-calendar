import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_exchange/domain/shift_transaction.dart';

void main() {
  final createdAt = DateTime(2026, 11, 1, 9);

  ShiftTransaction giveUp({bool organization = false}) => ShiftTransaction.create(
    id: 'tx-1',
    type: ShiftTransactionType.giveUp,
    mode: organization ? ShiftTransactionMode.organization : ShiftTransactionMode.personal,
    createdByAccountSubject: 'google-a',
    participants: [
      const ShiftTransactionParticipant(
        employeeId: 'employee-a',
        accountSubject: 'google-a',
        role: ShiftTransactionParticipantRole.requester,
      ),
      const ShiftTransactionParticipant(
        employeeId: 'employee-b',
        accountSubject: 'google-b',
        role: ShiftTransactionParticipantRole.recipient,
      ),
    ],
    transfers: [
      ShiftTransfer(
        id: 'leg-1',
        shiftId: 'shift-1',
        fromEmployeeId: 'employee-a',
        toEmployeeId: 'employee-b',
        shiftCode: 'GEN-บ่าย',
        startsAt: DateTime(2026, 11, 12, 16, 30),
        endsAt: DateTime(2026, 11, 12, 20),
        purpose: ShiftTransferPurpose.giveUp,
      ),
    ],
    createdAt: createdAt,
    requiresOrganizationApproval: organization,
    organizationId: organization ? 'org-1' : null,
  );

  ShiftTransaction exchangeAndReturn() => ShiftTransaction.create(
    id: 'tx-return',
    type: ShiftTransactionType.exchangeAndReturn,
    mode: ShiftTransactionMode.personal,
    createdByAccountSubject: 'google-a',
    participants: [
      const ShiftTransactionParticipant(
        employeeId: 'employee-a',
        accountSubject: 'google-a',
        role: ShiftTransactionParticipantRole.requester,
      ),
      const ShiftTransactionParticipant(
        employeeId: 'employee-b',
        accountSubject: 'google-b',
        role: ShiftTransactionParticipantRole.recipient,
      ),
    ],
    transfers: [
      ShiftTransfer(
        id: 'primary',
        shiftId: 'shift-a',
        fromEmployeeId: 'employee-a',
        toEmployeeId: 'employee-b',
        shiftCode: 'บ่าย',
        startsAt: DateTime(2026, 11, 12, 16),
        endsAt: DateTime(2026, 11, 13, 0),
        purpose: ShiftTransferPurpose.primary,
      ),
      ShiftTransfer(
        id: 'return',
        shiftId: 'shift-b',
        fromEmployeeId: 'employee-b',
        toEmployeeId: 'employee-a',
        shiftCode: 'เช้า',
        startsAt: DateTime(2026, 11, 18, 8),
        endsAt: DateTime(2026, 11, 18, 16),
        purpose: ShiftTransferPurpose.returnShift,
      ),
    ],
    createdAt: createdAt,
    requiresOrganizationApproval: false,
  );

  test('personal give-up becomes approved after both parties confirm', () {
    final request = giveUp()
        .confirm(accountSubject: 'google-a', at: createdAt.add(const Duration(minutes: 1)))
        .confirm(accountSubject: 'google-b', at: createdAt.add(const Duration(minutes: 2)));

    expect(request.status, ShiftTransactionStatus.approved);
    expect(request.requiresOrganizationApproval, isFalse);
  });

  test('organization request waits for approval after both confirmations', () {
    final request = giveUp(organization: true)
        .confirm(accountSubject: 'google-a', at: createdAt.add(const Duration(minutes: 1)))
        .confirm(accountSubject: 'google-b', at: createdAt.add(const Duration(minutes: 2)));

    expect(request.status, ShiftTransactionStatus.pendingApproval);
    expect(
      () => request.approve(
        approverAccountSubject: 'manager',
        organizationId: 'org-1',
        authorized: false,
        at: createdAt.add(const Duration(minutes: 3)),
      ),
      throwsStateError,
    );
    final approved = request.approve(
      approverAccountSubject: 'manager',
      organizationId: 'org-1',
      authorized: true,
      at: createdAt.add(const Duration(minutes: 3)),
    );
    expect(approved.status, ShiftTransactionStatus.approved);
    expect(approved.approvedByAccountSubject, 'manager');
  });

  test('exchange-and-return is not completed after only one obligation', () {
    final approved = exchangeAndReturn()
        .confirm(accountSubject: 'google-a', at: createdAt.add(const Duration(minutes: 1)))
        .confirm(accountSubject: 'google-b', at: createdAt.add(const Duration(minutes: 2)))
        .startCalendarSync(previewConfirmed: true, at: createdAt.add(const Duration(minutes: 3)))
        .completeCalendarSync(createdAt.add(const Duration(minutes: 4)));

    final firstFulfilled = approved.fulfillTransfer(
      transferId: 'primary',
      at: DateTime(2026, 11, 13),
    );
    expect(firstFulfilled.status, ShiftTransactionStatus.approved);
    expect(firstFulfilled.allTransfersFulfilled, isFalse);
    expect(
      identical(
        firstFulfilled,
        firstFulfilled.fulfillTransfer(
          transferId: 'primary',
          at: DateTime(2026, 11, 12, 23, 59),
        ),
      ),
      isTrue,
    );

    final completed = firstFulfilled.fulfillTransfer(
      transferId: 'return',
      at: DateTime(2026, 11, 19),
    );
    expect(completed.status, ShiftTransactionStatus.completed);
    expect(completed.allTransfersFulfilled, isTrue);
  });


  test('Calendar sync requires preview confirmation and fulfillment waits for shift end', () {
    final approved = exchangeAndReturn()
        .confirm(accountSubject: 'google-a', at: createdAt.add(const Duration(minutes: 1)))
        .confirm(accountSubject: 'google-b', at: createdAt.add(const Duration(minutes: 2)));
    expect(
      () => approved.startCalendarSync(
        previewConfirmed: false,
        at: createdAt.add(const Duration(minutes: 3)),
      ),
      throwsStateError,
    );
    final synced = approved
        .startCalendarSync(
          previewConfirmed: true,
          at: createdAt.add(const Duration(minutes: 3)),
        )
        .completeCalendarSync(createdAt.add(const Duration(minutes: 4)));
    expect(
      () => synced.fulfillTransfer(
        transferId: 'primary',
        at: DateTime(2026, 11, 12, 23, 59),
      ),
      throwsStateError,
    );
  });

  test('only participants may confirm and repeated confirmation is idempotent', () {
    final pending = giveUp();
    expect(
      () => pending.confirm(accountSubject: 'stranger', at: createdAt),
      throwsStateError,
    );
    final confirmed = pending.confirm(accountSubject: 'google-a', at: createdAt);
    expect(
      identical(
        confirmed,
        confirmed.confirm(accountSubject: 'google-a', at: createdAt),
      ),
      isTrue,
    );
  });

  test('personal transactions cannot be configured for organization approval', () {
    expect(
      () => ShiftTransaction.create(
        id: 'invalid',
        type: ShiftTransactionType.giveUp,
        mode: ShiftTransactionMode.personal,
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
      ),
      throwsArgumentError,
    );
  });
}
