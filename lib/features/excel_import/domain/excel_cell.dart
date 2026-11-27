class ExcelCell {
  const ExcelCell({
    required this.rowIndex,
    required this.columnIndex,
    required this.value,
    this.isMerged = false,
    this.mergedAnchorRowIndex,
    this.mergedAnchorColumnIndex,
  });

  final int rowIndex;
  final int columnIndex;
  final Object? value;
  final bool isMerged;
  final int? mergedAnchorRowIndex;
  final int? mergedAnchorColumnIndex;

  String get displayValue => value?.toString() ?? '';
}
