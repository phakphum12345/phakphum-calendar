import 'package:flutter/foundation.dart';


/// The business operation represented by a shift transaction.
enum ShiftTransactionType { giveUp, exchange, exchangeAndReturn }

/// The authorization boundary used to negotiate a shift transaction.
enum ShiftTransactionMode { personal, organization }

/// The participant's role in one transaction.
enum ShiftTransactionParticipantRole { requester, recipient }

/// The purpose of one shift movement within a transaction.
enum ShiftTransferPurpose { giveUp, exchange, primary, returnShift }

/// The lifecycle state of a shift transaction.
enum ShiftTransactionStatus {
  pendingResponse,
  partiallyAccepted,
  pendingApproval,
  approved,
  rejected,
  cancelled,
  completed,
}

/// The independent state of Google Calendar synchronization.
enum ShiftTransactionSyncStatus { notStarted, pending, synced, failed }

/// One employee/account pair participating in a shift transaction.
@immutable
class ShiftTransactionParticipant {
  const ShiftTransactionParticipant({
    required this.employeeId,
    required this.accountSubject,
    required this.role,
    this.confirmedAt,
  });

  final String employeeId;
  final String accountSubject;
  final ShiftTransactionParticipantRole role;
  final DateTime? confirmedAt;

  bool get hasConfirmed => confirmedAt != null;

  ShiftTransactionParticipant confirm(DateTime at) => ShiftTransactionParticipant(
    employeeId: employeeId,
    accountSubject: accountSubject,
    role: role,
    confirmedAt: at,
  );
}

/// A single shift movement, including its stable source identity and times.
@immutable
class ShiftTransfer {
  const ShiftTransfer({
    required this.id,
    required this.shiftId,
    required this.fromEmployeeId,
    required this.toEmployeeId,
    required this.shiftCode,
    required this.startsAt,
    required this.endsAt,
    required this.purpose,
    this.fulfilledAt,
  });

  final String id;
  final String shiftId;
  final String fromEmployeeId;
  final String toEmployeeId;
  final String shiftCode;
  final DateTime startsAt;
  final DateTime endsAt;
  final ShiftTransferPurpose purpose;
  final DateTime? fulfilledAt;

  bool get isFulfilled => fulfilledAt != null;

  ShiftTransfer fulfill(DateTime at) => ShiftTransfer(
    id: id,
    shiftId: shiftId,
    fromEmployeeId: fromEmployeeId,
    toEmployeeId: toEmployeeId,
    shiftCode: shiftCode,
    startsAt: startsAt,
    endsAt: endsAt,
    purpose: purpose,
    fulfilledAt: at,
  );
}

