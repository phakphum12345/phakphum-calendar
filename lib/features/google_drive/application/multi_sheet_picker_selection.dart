/// Tracks additions and removals staged in the multi-file Google Sheets picker.
///
/// Existing files start checked. Unchecking an existing file stages removal of
/// its local saved reference; it never deletes the actual Drive file.
class MultiSheetPickerSelection {
  MultiSheetPickerSelection({required Set<String> alreadyAddedIds})
    : _alreadyAddedIds = Set<String>.of(alreadyAddedIds);

  final Set<String> _alreadyAddedIds;
  final Set<String> _selectedIds = <String>{};
  final Set<String> _removedIds = <String>{};

  Set<String> get selectedIds => Set<String>.unmodifiable(_selectedIds);
  Set<String> get removedIds => Set<String>.unmodifiable(_removedIds);

  bool isChecked(String id) => _alreadyAddedIds.contains(id)
      ? !_removedIds.contains(id)
      : _selectedIds.contains(id);

  void toggle(String id) {
    if (_alreadyAddedIds.contains(id)) {
      if (!_removedIds.add(id)) _removedIds.remove(id);
      return;
    }
    if (!_selectedIds.add(id)) _selectedIds.remove(id);
  }

  bool get hasChanges => _selectedIds.isNotEmpty || _removedIds.isNotEmpty;
  int get addedCount => _selectedIds.length;
  int get removedCount => _removedIds.length;
}
