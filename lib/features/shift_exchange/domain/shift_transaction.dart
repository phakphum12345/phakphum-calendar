import 'package:flutter/foundation.dart';
import 'shift_transaction_types.dart';

export 'shift_transaction_types.dart';

/// Immutable domain transaction for give-up, exchange, and exchange-and-return.
///
/// Participant agreement, organizational approval, Calendar synchronization,
/// and actual shift fulfillment are separate stages. This prevents a successful
/// Calendar write from being mistaken for fulfillment of a future return shift.
@immutable
class ShiftTransaction {
  ShiftTransaction._({
    required this.id,
    required this.type,
    required this.mode,
    required this.createdByAccountSubject,
    required List<ShiftTransactionParticipant> participants,
    required List<ShiftTransfer> transfers,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.syncStatus,
    required this.requiresOrganizationApproval,
    required this.version,
    this.organizationId,
    this.departmentId,
    this.note,
    this.approvedByAccountSubject,
    this.approvedAt,
    this.rejectedByAccountSubject,
    this.rejectedAt,
    this.decisionNote,
    this.syncError,
  }) : participants = List.unmodifiable(participants),
       transfers = List.unmodifiable(transfers);

  /// Creates and validates a new transaction in the response-pending state.
  factory ShiftTransaction.create({
    required String id,
    required ShiftTransactionType type,
    required ShiftTransactionMode mode,
    required String createdByAccountSubject,
    required List<ShiftTransactionParticipant> participants,
    required List<ShiftTransfer> transfers,
    required DateTime createdAt,
    required bool requiresOrganizationApproval,
    String? organizationId,
    String? departmentId,
    String? note,
  }) {
    final transaction = ShiftTransaction._(
      id: id,
      type: type,
      mode: mode,
      createdByAccountSubject: createdByAccountSubject,
      participants: participants,
      transfers: transfers,
      createdAt: createdAt,
      updatedAt: createdAt,
      status: ShiftTransactionStatus.pendingResponse,
      syncStatus: ShiftTransactionSyncStatus.notStarted,
      requiresOrganizationApproval: requiresOrganizationApproval,
      version: 1,
      organizationId: organizationId,
      departmentId: departmentId,
      note: note,
    );
    transaction._validate();
    return transaction;
  }

  final String id;
  final ShiftTransactionType type;
  final ShiftTransactionMode mode;
  final String createdByAccountSubject;
  final List<ShiftTransactionParticipant> participants;
  final List<ShiftTransfer> transfers;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ShiftTransactionStatus status;
  final ShiftTransactionSyncStatus syncStatus;
  final bool requiresOrganizationApproval;
  final int version;
  final String? organizationId;
  final String? departmentId;
  final String? note;
  final String? approvedByAccountSubject;
  final DateTime? approvedAt;
  final String? rejectedByAccountSubject;
  final DateTime? rejectedAt;
  final String? decisionNote;
  final String? syncError;

  bool get allParticipantsConfirmed => participants.every((item) => item.hasConfirmed);
  bool get allTransfersFulfilled => transfers.every((item) => item.isFulfilled);
  bool get isTerminal => status == ShiftTransactionStatus.rejected ||
      status == ShiftTransactionStatus.cancelled ||
      status == ShiftTransactionStatus.completed;

  /// Records one participant's agreement; repeated confirmation is idempotent.
  ShiftTransaction confirm({
    required String accountSubject,
    required DateTime at,
  }) {
    _ensureAwaitingParticipants();
    final index = participants.indexWhere(
      (item) => item.accountSubject == accountSubject,
    );
    if (index == -1) {
      throw StateError('Only transaction participants may confirm.');
    }
    if (participants[index].hasConfirmed) return this;

    final updated = List<ShiftTransactionParticipant>.of(participants);
    updated[index] = updated[index].confirm(at);
    final allConfirmed = updated.every((item) => item.hasConfirmed);
    final nextStatus = !allConfirmed
        ? ShiftTransactionStatus.partiallyAccepted
        : requiresOrganizationApproval
            ? ShiftTransactionStatus.pendingApproval
            : ShiftTransactionStatus.approved;
    return _copy(
      participants: updated,
      status: nextStatus,
      at: at,
    );
  }

  /// Rejects a request on behalf of a participating employee.
  ShiftTransaction rejectByParticipant({
    required String accountSubject,
    required DateTime at,
    String? reason,
  }) {
    _ensureAwaitingParticipants();
    if (!participants.any((item) => item.accountSubject == accountSubject)) {
      throw StateError('Only transaction participants may reject.');
    }
    return _copy(
      status: ShiftTransactionStatus.rejected,
      rejectedByAccountSubject: accountSubject,
      rejectedAt: at,
      decisionNote: reason,
      at: at,
    );
  }

  /// Records an organization decision after the application authorizes it.
  ShiftTransaction approve({
    required String approverAccountSubject,
    required String organizationId,
    required bool authorized,
    required DateTime at,
    String? note,
  }) {
    if (!authorized || approverAccountSubject.trim().isEmpty) {
      throw StateError('Organization approval is not authorized.');
    }
    if (mode != ShiftTransactionMode.organization ||
        !requiresOrganizationApproval ||
        status != ShiftTransactionStatus.pendingApproval ||
        !allParticipantsConfirmed ||
        this.organizationId != organizationId) {
      throw StateError('This transaction is not awaiting this organization approval.');
    }
    return _copy(
      status: ShiftTransactionStatus.approved,
      approvedByAccountSubject: approverAccountSubject,
      approvedAt: at,
      decisionNote: note,
      at: at,
    );
  }

  /// Rejects a transaction by an authorized organization approver.
  ShiftTransaction rejectByApprover({
    required String approverAccountSubject,
    required String organizationId,
    required bool authorized,
    required DateTime at,
    String? reason,
  }) {
    if (!authorized || approverAccountSubject.trim().isEmpty) {
      throw StateError('Organization approval is not authorized.');
    }
    if (mode != ShiftTransactionMode.organization ||
        !requiresOrganizationApproval ||
        status != ShiftTransactionStatus.pendingApproval ||
        this.organizationId != organizationId) {
      throw StateError('This transaction is not awaiting this organization decision.');
    }
    return _copy(
      status: ShiftTransactionStatus.rejected,
      rejectedByAccountSubject: approverAccountSubject,
      rejectedAt: at,
      decisionNote: reason,
      at: at,
    );
  }

  /// Allows only the requester to cancel before Calendar synchronization starts.
  ShiftTransaction cancel({
    required String accountSubject,
    required DateTime at,
  }) {
    if (accountSubject != createdByAccountSubject ||
        isTerminal ||
        syncStatus == ShiftTransactionSyncStatus.pending ||
        syncStatus == ShiftTransactionSyncStatus.synced) {
      throw StateError('This transaction cannot be cancelled by this account.');
    }
    return _copy(status: ShiftTransactionStatus.cancelled, at: at);
  }

  /// Marks the approved transaction ready for a user-confirmed Calendar write.
  ShiftTransaction startCalendarSync({
    required bool previewConfirmed,
    required DateTime at,
  }) {
    if (!previewConfirmed) {
      throw StateError('Calendar sync requires explicit preview confirmation.');
    }
    if (status != ShiftTransactionStatus.approved) {
      throw StateError('Only approved transactions may be synchronized.');
    }
    if (syncStatus == ShiftTransactionSyncStatus.pending ||
        syncStatus == ShiftTransactionSyncStatus.synced) {
      return this;
    }
    return _copy(
      syncStatus: ShiftTransactionSyncStatus.pending,
      clearSyncError: true,
      at: at,
    );
  }

  /// Records a verified successful Calendar synchronization.
  ShiftTransaction completeCalendarSync(DateTime at) {
    if (syncStatus == ShiftTransactionSyncStatus.synced) return this;
    if (syncStatus != ShiftTransactionSyncStatus.pending) {
      throw StateError('Calendar synchronization has not started.');
    }
    return _copy(
      syncStatus: ShiftTransactionSyncStatus.synced,
      clearSyncError: true,
      at: at,
    );
  }

  /// Records a recoverable Calendar synchronization failure.
  ShiftTransaction failCalendarSync(DateTime at, {String? reason}) {
    if (syncStatus != ShiftTransactionSyncStatus.pending) {
      throw StateError('Calendar synchronization is not pending.');
    }
    return _copy(
      syncStatus: ShiftTransactionSyncStatus.failed,
      syncError: reason,
      at: at,
    );
  }

  /// Records actual fulfillment of one shift obligation after Calendar sync.
  ShiftTransaction fulfillTransfer({
    required String transferId,
    required DateTime at,
  }) {
    if (syncStatus != ShiftTransactionSyncStatus.synced ||
        status != ShiftTransactionStatus.approved) {
      throw StateError('A synchronized, approved transaction is required.');
    }
    final index = transfers.indexWhere((item) => item.id == transferId);
    if (index == -1) throw StateError('Unknown shift transfer.');
    if (transfers[index].isFulfilled) return this;
    if (at.isBefore(transfers[index].endsAt)) {
      throw StateError('A shift cannot be fulfilled before its scheduled end.');
    }

    final updated = List<ShiftTransfer>.of(transfers);
    updated[index] = updated[index].fulfill(at);
    final allFulfilled = updated.every((item) => item.isFulfilled);
    return _copy(
      transfers: updated,
      status: allFulfilled
          ? ShiftTransactionStatus.completed
          : ShiftTransactionStatus.approved,
      at: at,
    );
  }

  void _ensureAwaitingParticipants() {
    if (status != ShiftTransactionStatus.pendingResponse &&
        status != ShiftTransactionStatus.partiallyAccepted) {
      throw StateError('This transaction is not awaiting participant responses.');
    }
  }

  void _validate() {
    if (id.trim().isEmpty || createdByAccountSubject.trim().isEmpty ||
        version < 1 || updatedAt.isBefore(createdAt)) {
      throw ArgumentError('Transaction identifiers, version, and timestamps are invalid.');
    }
    if (participants.length != 2 || transfers.isEmpty) {
      throw ArgumentError('A transaction requires two participants and shift transfers.');
    }
    final employeeIds = participants.map((item) => item.employeeId).toSet();
    final accountIds = participants.map((item) => item.accountSubject).toSet();
    final requester = participants.where(
      (item) => item.role == ShiftTransactionParticipantRole.requester,
    );
    final recipient = participants.where(
      (item) => item.role == ShiftTransactionParticipantRole.recipient,
    );
    if (employeeIds.length != 2 || accountIds.length != 2 ||
        requester.length != 1 || recipient.length != 1 ||
        participants.any((item) => item.employeeId.trim().isEmpty ||
            item.accountSubject.trim().isEmpty) ||
        requester.single.accountSubject != createdByAccountSubject) {
      throw ArgumentError('Participants and creator must have distinct stable identities and roles.');
    }
    if (mode == ShiftTransactionMode.personal &&
        (organizationId != null || requiresOrganizationApproval)) {
      throw ArgumentError('Personal transactions cannot require organization approval.');
    }
    if (mode == ShiftTransactionMode.organization &&
        (organizationId == null || organizationId!.trim().isEmpty)) {
      throw ArgumentError('Organization transactions require an organization ID.');
    }
    final transferIds = transfers.map((item) => item.id).toSet();
    final shiftIds = transfers.map((item) => item.shiftId).toSet();
    if (transferIds.length != transfers.length ||
        shiftIds.length != transfers.length ||
        transfers.any((item) =>
            item.id.trim().isEmpty ||
            item.shiftId.trim().isEmpty ||
            item.shiftCode.trim().isEmpty ||
            item.fromEmployeeId == item.toEmployeeId ||
            !employeeIds.contains(item.fromEmployeeId) ||
            !employeeIds.contains(item.toEmployeeId) ||
            !item.endsAt.isAfter(item.startsAt))) {
      throw ArgumentError('Shift transfers must have unique valid identities and times.');
    }

    final requesterId = requester.single.employeeId;
    final recipientId = recipient.single.employeeId;
    switch (type) {
      case ShiftTransactionType.giveUp:
        if (transfers.length != 1 ||
            transfers.single.purpose != ShiftTransferPurpose.giveUp ||
            transfers.single.fromEmployeeId != requesterId ||
            transfers.single.toEmployeeId != recipientId) {
          throw ArgumentError('A give-up transaction requires one transfer from requester to recipient.');
        }
        break;
      case ShiftTransactionType.exchange:
        if (transfers.length != 2 ||
            transfers.any((item) => item.purpose != ShiftTransferPurpose.exchange) ||
            !_areReciprocal(transfers) ||
            !transfers.any((item) =>
                item.fromEmployeeId == requesterId && item.toEmployeeId == recipientId)) {
          throw ArgumentError('An exchange requires two reciprocal shift transfers.');
        }
        break;
      case ShiftTransactionType.exchangeAndReturn:
        final primary = transfers.where(
          (item) => item.purpose == ShiftTransferPurpose.primary,
        );
        final returnShift = transfers.where(
          (item) => item.purpose == ShiftTransferPurpose.returnShift,
        );
        if (transfers.length != 2 ||
            primary.length != 1 ||
            returnShift.length != 1 ||
            primary.single.fromEmployeeId != requesterId ||
            primary.single.toEmployeeId != recipientId ||
            returnShift.single.fromEmployeeId != recipientId ||
            returnShift.single.toEmployeeId != requesterId) {
          throw ArgumentError('Exchange-and-return requires one primary and one reciprocal return transfer.');
        }
        break;
    }
  }

  bool _areReciprocal(List<ShiftTransfer> values) =>
      values[0].fromEmployeeId == values[1].toEmployeeId &&
      values[0].toEmployeeId == values[1].fromEmployeeId;

  ShiftTransaction _copy({
    List<ShiftTransactionParticipant>? participants,
    List<ShiftTransfer>? transfers,
    ShiftTransactionStatus? status,
    ShiftTransactionSyncStatus? syncStatus,
    String? approvedByAccountSubject,
    DateTime? approvedAt,
    String? rejectedByAccountSubject,
    DateTime? rejectedAt,
    String? decisionNote,
    String? syncError,
    bool clearSyncError = false,
    required DateTime at,
  }) {
    final next = ShiftTransaction._(
      id: id,
      type: type,
      mode: mode,
      createdByAccountSubject: createdByAccountSubject,
      participants: participants ?? this.participants,
      transfers: transfers ?? this.transfers,
      createdAt: createdAt,
      updatedAt: at,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      requiresOrganizationApproval: requiresOrganizationApproval,
      version: version + 1,
      organizationId: organizationId,
      departmentId: departmentId,
      note: note,
      approvedByAccountSubject: approvedByAccountSubject ?? this.approvedByAccountSubject,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedByAccountSubject: rejectedByAccountSubject ?? this.rejectedByAccountSubject,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      decisionNote: decisionNote ?? this.decisionNote,
      syncError: clearSyncError ? null : syncError ?? this.syncError,
    );
    next._validate();
    return next;
  }
}
