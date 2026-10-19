class SavedSheet {
  const SavedSheet({
    required this.ownerAccountId,
    required this.spreadsheetId,
    required this.spreadsheetTitle,
    required this.url,
    required this.savedAt,
    this.sheetId,
    this.sheetTitle,
    this.isActive = false,
    this.hasExplicitActiveState = true,
  });

  final String ownerAccountId;
  final String spreadsheetId;
  final String spreadsheetTitle;
  final int? sheetId;
  final String? sheetTitle;
  final String url;
  final DateTime savedAt;

  /// Whether this source is explicitly selected for the current account.
  final bool isActive;

  /// False only when loading a legacy record that predates explicit selection.
  /// This is migration metadata and is intentionally not serialized.
  final bool hasExplicitActiveState;

  String get key => '$ownerAccountId:$spreadsheetId:${sheetId ?? 'all'}';

  String get displayTitle {
    final tab = sheetTitle?.trim();
    if (tab != null && tab.isNotEmpty) return tab;
    final book = spreadsheetTitle.trim();
    return book.isEmpty ? 'Google Sheets' : book;
  }

  String get contextLabel {
    final tab = sheetTitle?.trim();
    if (tab == null || tab.isEmpty || tab == spreadsheetTitle.trim()) {
      return spreadsheetTitle.trim().isEmpty
          ? 'ไฟล์ Google Sheets'
          : spreadsheetTitle.trim();
    }
    return spreadsheetTitle.trim().isEmpty
        ? 'แท็บใน Google Sheets'
        : spreadsheetTitle.trim();
  }

  Map<String, Object?> toJson() => {
    'ownerAccountId': ownerAccountId,
    'spreadsheetId': spreadsheetId,
    'spreadsheetTitle': spreadsheetTitle,
    'sheetId': sheetId,
    'sheetTitle': sheetTitle,
    'url': url,
    'savedAt': savedAt.toIso8601String(),
    'isActive': isActive,
  };

  factory SavedSheet.fromJson(Map<String, Object?> json) {
    final ownerAccountId = json['ownerAccountId']?.toString().trim() ?? '';
    final spreadsheetId =
        json['spreadsheetId']?.toString().replaceAll(RegExp(r'\\s+'), '') ?? '';
    final url = json['url']?.toString().trim() ?? '';
    if (ownerAccountId.isEmpty || spreadsheetId.isEmpty || url.isEmpty) {
      throw const FormatException('ข้อมูลชีตที่บันทึกไม่ครบถ้วน');
    }
    return SavedSheet(
      ownerAccountId: ownerAccountId,
      spreadsheetId: spreadsheetId,
      spreadsheetTitle: json['spreadsheetTitle']?.toString() ?? '',
      sheetId: switch (json['sheetId']) {
        final int value => value,
        final Object value => int.tryParse(value.toString()),
        null => null,
      },
      sheetTitle: json['sheetTitle']?.toString(),
      url: url,
      savedAt:
          DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isActive: json['isActive'] == true,
      hasExplicitActiveState: json.containsKey('isActive'),
    );
  }

  SavedSheet copyWith({DateTime? savedAt, bool? isActive}) => SavedSheet(
    ownerAccountId: ownerAccountId,
    spreadsheetId: spreadsheetId,
    spreadsheetTitle: spreadsheetTitle,
    sheetId: sheetId,
    sheetTitle: sheetTitle,
    url: url,
    savedAt: savedAt ?? this.savedAt,
    isActive: isActive ?? this.isActive,
    hasExplicitActiveState:
        isActive == null ? hasExplicitActiveState : true,
  );
}
