import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_exchange/domain/shift_transaction.dart';

void main() {
  test('exchange requires two reciprocal movements between the participants', () {
    final transaction = ShiftTransaction.create(
      id: 'exchange-1',
      type: ShiftTransactionType.exchange,
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
          id: 'leg-a',
          shiftId: 'shift-a',
          fromEmployeeId: 'employee-a',
          toEmployeeId: 'employee-b',
          shiftCode: 'เช้า',
          startsAt: DateTime(2026, 11, 12, 8),
          endsAt: DateTime(2026, 11, 12, 16),
          purpose: ShiftTransferPurpose.exchange,
        ),
        ShiftTransfer(
          id: 'leg-b',
          shiftId: 'shift-b',
          fromEmployeeId: 'employee-b',
          toEmployeeId: 'employee-a',
          shiftCode: 'ดึก',
          startsAt: DateTime(2026, 11, 14, 0),
          endsAt: DateTime(2026, 11, 14, 8),
          purpose: ShiftTransferPurpose.exchange,
        ),
      ],
      createdAt: DateTime(2026, 11, 1),
      requiresOrganizationApproval: false,
    );

    expect(transaction.type, ShiftTransactionType.exchange);
    expect(transaction.transfers, hasLength(2));
  });

  test('exchange rejects non-reciprocal shift movements', () {
    expect(
      () => ShiftTransaction.create(
        id: 'exchange-invalid',
        type: ShiftTransactionType.exchange,
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
            id: 'leg-a',
            shiftId: 'shift-a',
            fromEmployeeId: 'employee-a',
            toEmployeeId: 'employee-b',
            shiftCode: 'เช้า',
            startsAt: DateTime(2026, 11, 12, 8),
            endsAt: DateTime(2026, 11, 12, 16),
            purpose: ShiftTransferPurpose.exchange,
          ),
          ShiftTransfer(
            id: 'leg-b',
            shiftId: 'shift-b',
            fromEmployeeId: 'employee-a',
            toEmployeeId: 'employee-b',
            shiftCode: 'ดึก',
            startsAt: DateTime(2026, 11, 14, 0),
            endsAt: DateTime(2026, 11, 14, 8),
            purpose: ShiftTransferPurpose.exchange,
          ),
        ],
        createdAt: DateTime(2026, 11, 1),
        requiresOrganizationApproval: false,
      ),
      throwsArgumentError,
    );
  });
}
