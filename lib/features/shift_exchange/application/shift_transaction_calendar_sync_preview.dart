class ShiftTransactionCalendarSyncPreview {
  const ShiftTransactionCalendarSyncPreview({
    required this.transactionId,
    required this.transactionVersion,
    required this.insertCount,
    required this.updateCount,
    required this.deleteCount,
    required this.transferLines,
  });

  final String transactionId;
  final int transactionVersion;
  final int insertCount;
  final int updateCount;
  final int deleteCount;
  final List<String> transferLines;

  bool get hasChanges =>
      insertCount > 0 || updateCount > 0 || deleteCount > 0;
}
