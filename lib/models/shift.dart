enum ShiftCategory {
  own,
  other,
  clinic,
  specialClinic,
  off,
  majorSwap,
  given,
  borrowedUnpaid,
  borrowedPaid,
}

extension ShiftCategoryInfo on ShiftCategory {
  String get label => switch (this) {
    ShiftCategory.own => 'เวรของตัวเอง',
    ShiftCategory.other => 'เวรคนอื่น',
    ShiftCategory.clinic => 'เวรคลินิก',
    ShiftCategory.specialClinic => 'เวรคลินิก (แบบพิเศษ)',
    ShiftCategory.off => 'เวรออฟหลังเวรดึก',
    ShiftCategory.majorSwap => 'แลกเวรใหญ่',
    ShiftCategory.given => 'ยกเวร',
    ShiftCategory.borrowedUnpaid => 'ยืมชื่อเวร (ไม่จ่าย)',
    ShiftCategory.borrowedPaid => 'ยืมชื่อเวร (จ่าย)',
  };

  String get colorName => switch (this) {
    ShiftCategory.own => 'กราไฟต์',
    ShiftCategory.other => 'มะเขือเทศ',
    ShiftCategory.clinic => 'ฟ้า',
    ShiftCategory.specialClinic => 'อะโวคาโด',
    ShiftCategory.off => 'ลาเวนเดอร์',
    ShiftCategory.majorSwap => 'มะเขือเทศ',
    ShiftCategory.given => 'ลาเวนเดอร์',
    ShiftCategory.borrowedUnpaid => 'กล้วย',
    ShiftCategory.borrowedPaid => 'เขียว',
  };

  String get googleColorId => switch (this) {
    ShiftCategory.own => '9',
    ShiftCategory.other => '11',
    ShiftCategory.clinic => '5',
    ShiftCategory.specialClinic => '6',
    ShiftCategory.off => '8',
    ShiftCategory.majorSwap => '9',
    ShiftCategory.given => '10',
    ShiftCategory.borrowedUnpaid => '5',
    ShiftCategory.borrowedPaid => '10',
  };

  int get colorValue => switch (this) {
    ShiftCategory.own => 0xFF3F51B5,
    ShiftCategory.other => 0xFFD50000,
    ShiftCategory.clinic => 0xFFF6BF26,
    ShiftCategory.specialClinic => 0xFFF4511E,
    ShiftCategory.off => 0xFF616161,
    ShiftCategory.majorSwap => 0xFF3F51B5,
    ShiftCategory.given => 0xFF0B8043,
    ShiftCategory.borrowedUnpaid => 0xFFF6BF26,
    ShiftCategory.borrowedPaid => 0xFF0B8043,
  };
}

class Shift {
  const Shift({
    required this.code,
    required this.rowLabel,
    required this.assignedName,
    required this.start,
    required this.end,
    required this.sheetTitle,
    required this.cell,
    required this.category,
    this.excluded = false,
    this.generated = false,
    this.linkedShiftKey,
    this.sourceColorValue,
    this.customTitle,
    this.calendarColorId,
    this.relationshipComment,
  });

  final String code;
  final String rowLabel;
  final String assignedName;
  final DateTime start;
  final DateTime end;
  final String sheetTitle;
  final String cell;
  final ShiftCategory category;
  final bool excluded;
  final bool generated;
  final String? linkedShiftKey;
  final int? sourceColorValue;
  final String? customTitle;
  final String? calendarColorId;
  final String? relationshipComment;

  bool get isNightShift {
    if (isOffDuty) return false;
    final normalizedCode = code.trim().toUpperCase();
    final normalizedLabel = rowLabel.trim().toLowerCase();
    return normalizedCode == 'N' ||
        normalizedCode.startsWith('N') ||
        normalizedLabel.contains('ดึก') ||
        normalizedLabel.contains('night') ||
        (start.hour == 0 && end.difference(start) == const Duration(hours: 8));
  }

  bool get isOffDuty => category == ShiftCategory.off || code == 'OFF';

  String get displayName {
    if (isOffDuty) return 'OFF — เวรออฟหลังเวรดึก';
    final custom = customTitle?.trim() ?? '';
    if (custom.isNotEmpty) return custom;
    final label = rowLabel.trim();
    if (label.isEmpty || label == code) return code;
    return '$label ($code)';
  }

  String? get sourceColorHex => sourceColorValue == null
      ? null
      : '#${(sourceColorValue! & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  String get sourceKey =>
      '${start.year.toString().padLeft(4, '0')}-'
      '${start.month.toString().padLeft(2, '0')}-'
      '${start.day.toString().padLeft(2, '0')}|$code|$assignedName';

  String get effectiveCalendarColorId =>
      calendarColorId ?? category.googleColorId;

  Shift copyWith({
    ShiftCategory? category,
    bool? excluded,
    bool? generated,
    DateTime? start,
    DateTime? end,
    String? customTitle,
    String? calendarColorId,
    bool clearCalendarColor = false,
    String? relationshipComment,
    bool clearRelationshipComment = false,
  }) => Shift(
    code: code,
    rowLabel: rowLabel,
    assignedName: assignedName,
    start: start ?? this.start,
    end: end ?? this.end,
    sheetTitle: sheetTitle,
    cell: cell,
    category: category ?? this.category,
    excluded: excluded ?? this.excluded,
    generated: generated ?? this.generated,
    linkedShiftKey: linkedShiftKey,
    sourceColorValue: sourceColorValue,
    customTitle: customTitle ?? this.customTitle,
    calendarColorId: clearCalendarColor
        ? null
        : calendarColorId ?? this.calendarColorId,
    relationshipComment: clearRelationshipComment
        ? null
        : relationshipComment ?? this.relationshipComment,
  );
}

class SheetSnapshot {
  const SheetSnapshot({
    required this.title,
    required this.rows,
    this.backgroundColors = const [],
  });

  final String title;
  final List<List<Object?>> rows;
  final List<List<int?>> backgroundColors;

  int? backgroundColorAt(int row, int column) =>
      row >= 0 &&
          row < backgroundColors.length &&
          column >= 0 &&
          column < backgroundColors[row].length
      ? backgroundColors[row][column]
      : null;
}
