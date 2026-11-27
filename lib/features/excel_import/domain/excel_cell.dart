class ExcelCell {
  const ExcelCell({
    required this.rowIndex,
    required this.columnIndex,
    required this.value,
    this.isMerged = false,
    this.mergedAnchorRowIndex,
    this.mergedAnchorColumnIndex,
    this.backgroundColorValue,
  });

  final int rowIndex;
  final int columnIndex;
  final Object? value;
  final bool isMerged;
  final int? mergedAnchorRowIndex;
  final int? mergedAnchorColumnIndex;
  final int? backgroundColorValue;

  String get displayValue => value?.toString() ?? '';
}
