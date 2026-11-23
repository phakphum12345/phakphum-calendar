import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/google_drive/application/multi_sheet_picker_selection.dart';

void main() {
  group('MultiSheetPickerSelection', () {
    test('starts existing files checked and can uncheck then recheck them', () {
      final selection = MultiSheetPickerSelection(
        alreadyAddedIds: {'sheet-a'},
      );

      expect(selection.isChecked('sheet-a'), isTrue);
      expect(selection.hasChanges, isFalse);

      selection.toggle('sheet-a');
      expect(selection.isChecked('sheet-a'), isFalse);
      expect(selection.removedIds, {'sheet-a'});
      expect(selection.hasChanges, isTrue);

      selection.toggle('sheet-a');
      expect(selection.isChecked('sheet-a'), isTrue);
      expect(selection.removedIds, isEmpty);
      expect(selection.hasChanges, isFalse);
    });

    test('new files can be selected and deselected without changing existing', () {
      final selection = MultiSheetPickerSelection(
        alreadyAddedIds: {'sheet-a'},
      );

      selection.toggle('sheet-b');
      expect(selection.isChecked('sheet-b'), isTrue);
      expect(selection.selectedIds, {'sheet-b'});
      expect(selection.isChecked('sheet-a'), isTrue);
      expect(selection.removedIds, isEmpty);

      selection.toggle('sheet-b');
      expect(selection.isChecked('sheet-b'), isFalse);
      expect(selection.selectedIds, isEmpty);
      expect(selection.hasChanges, isFalse);
    });

    test('additions and removals are staged independently', () {
      final selection = MultiSheetPickerSelection(
        alreadyAddedIds: {'sheet-a'},
      );

      selection.toggle('sheet-a');
      selection.toggle('sheet-b');

      expect(selection.addedCount, 1);
      expect(selection.removedCount, 1);
      expect(selection.selectedIds, {'sheet-b'});
      expect(selection.removedIds, {'sheet-a'});
    });
  });
}
