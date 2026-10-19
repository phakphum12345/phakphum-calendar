import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/models/saved_sheet.dart';
import 'package:phakphum_calendar/services/sheets_service.dart';

Map<String, Object?> _record({Object? isActive}) => {
  'ownerAccountId': 'account-1',
  'spreadsheetId': 'spreadsheet-123',
  'spreadsheetTitle': 'Roster',
  'sheetId': 42,
  'sheetTitle': 'August',
  'url': 'https://docs.google.com/spreadsheets/d/spreadsheet-123/edit#gid=42',
  'savedAt': '2026-10-19T10:00:00.000',
  if (isActive != null) 'isActive': isActive,
};

void main() {
  group('SavedSheet source selection compatibility', () {
    test('recognizes a record from before explicit selection existed', () {
      final saved = SavedSheet.fromJson(_record());

      expect(saved.isActive, isFalse);
      expect(saved.hasExplicitActiveState, isFalse);
    });

    test('preserves an explicit inactive choice across serialization', () {
      final saved = SavedSheet.fromJson(_record(isActive: false));
      final restored = SavedSheet.fromJson(saved.toJson());

      expect(saved.hasExplicitActiveState, isTrue);
      expect(restored.isActive, isFalse);
      expect(restored.hasExplicitActiveState, isTrue);
    });

    test('serializes active selection and copyWith updates migration state', () {
      final legacy = SavedSheet.fromJson(_record());
      final selected = legacy.copyWith(isActive: true);
      final restored = SavedSheet.fromJson(selected.toJson());

      expect(selected.isActive, isTrue);
      expect(selected.hasExplicitActiveState, isTrue);
      expect(restored.isActive, isTrue);
      expect(restored.toJson()['isActive'], isTrue);
    });
  });

  group('Google Sheets tab URL selection', () {
    test('reads a gid from a URL with a fragment', () {
      expect(
        SheetsService.sheetIdFromUrl(
          'https://docs.google.com/spreadsheets/d/book123/edit#gid=42',
        ),
        42,
      );
    });

    test('reads a gid from a URL with a query parameter', () {
      expect(
        SheetsService.sheetIdFromUrl(
          'https://docs.google.com/spreadsheets/d/book123/edit?gid=7',
        ),
        7,
      );
    });

    test('builds a tab-specific URL when a sheet id is supplied', () {
      expect(
        SheetsService.sheetUrl('book123', 42),
        'https://docs.google.com/spreadsheets/d/book123/edit#gid=42',
      );
    });
  });
}
