class RosterLayoutProfile {
  const RosterLayoutProfile({
    required this.profileId,
    required this.profileName,
    required this.dateHeaderRows,
    required this.nameColumns,
    required this.shiftLabelColumns,
    required this.dataStartRow,
    this.dataEndRow,
    this.acceptedDatePatterns = const <String>[],
    this.userAliases = const <String>[],
  });

  final String profileId;
  final String profileName;

  /// Zero-based row indices containing the numeric day headers.
  final List<int> dateHeaderRows;

  /// Zero-based columns containing worker assignments. When empty, every
  /// resolved date column is eligible for phase-two name extraction.
  final List<int> nameColumns;

  /// Zero-based columns containing shift labels. If several are configured,
  /// the rightmost non-empty cell is treated as the row label.
  final List<int> shiftLabelColumns;

  /// Zero-based first data row, inclusive.
  final int dataStartRow;

  /// Zero-based last data row, inclusive. Null means continue to the next
  /// detected date-header row or the end of the sheet.
  final int? dataEndRow;

  final List<String> acceptedDatePatterns;
  final List<String> userAliases;

  bool get isConfigured =>
      dateHeaderRows.isNotEmpty &&
      nameColumns.isNotEmpty &&
      shiftLabelColumns.isNotEmpty;
}
