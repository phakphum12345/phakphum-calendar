import 'package:flutter/foundation.dart';

import '../../../../core/state/controller_state.dart';
import '../../domain/column_mapping.dart';

enum DestinationField {
  date(label: 'Date', isRequired: true),
  shift(label: 'Shift', isRequired: true),
  employee(label: 'Employee', isRequired: true),
  department(label: 'Department'),
  location(label: 'Location'),
  notes(label: 'Notes');

  const DestinationField({required this.label, this.isRequired = false});

  final String label;
  final bool isRequired;
}

class ColumnMappingController extends ChangeNotifier
    implements ControllerState {
  ColumnMappingController({ColumnMapping? initialMapping})
    : mapping = initialMapping ?? const ColumnMapping();

  List<String> availableColumns = const [];
  ColumnMapping mapping;
  List<String> errors = const [];
  Set<String> duplicateColumns = const {};
  bool hasValidated = false;

  @override
  bool get loading => false;

  @override
  Object? get error => errors.isEmpty ? null : errors.first;

  @override
  bool get success => isValid;

  @override
  String? get message => errors.isEmpty ? null : errors.join('\n');

  bool get isValid {
    return mapping.dateColumn != null &&
        mapping.shiftColumn != null &&
        mapping.employeeColumn != null &&
        duplicateColumns.isEmpty;
  }

  void loadAvailableColumns(Iterable<String> columns) {
    availableColumns = List.unmodifiable(columns.toSet());
    mapping = ColumnMapping(
      dateColumn: _availableOrNull(mapping.dateColumn),
      shiftColumn: _availableOrNull(mapping.shiftColumn),
      employeeColumn: _availableOrNull(mapping.employeeColumn),
      departmentColumn: _availableOrNull(mapping.departmentColumn),
      locationColumn: _availableOrNull(mapping.locationColumn),
      notesColumn: _availableOrNull(mapping.notesColumn),
    );
    hasValidated = false;
    _refreshValidation();
    notifyListeners();
  }

  /// Applies detected columns only when they exist in the current worksheet.
  /// Existing explicit mapping is replaced; the caller should invoke this after
  /// resetting the mapping for a newly selected worksheet.
  void applySuggestedMapping(ColumnMapping suggestion) {
    String? available(String? value) => _availableOrNull(value);
    mapping = ColumnMapping(
      dateColumn: available(suggestion.dateColumn),
      shiftColumn: available(suggestion.shiftColumn),
      employeeColumn: available(suggestion.employeeColumn),
      departmentColumn: available(suggestion.departmentColumn),
      locationColumn: available(suggestion.locationColumn),
      notesColumn: available(suggestion.notesColumn),
    );
    hasValidated = false;
    _refreshValidation();
    notifyListeners();
  }

  void updateMapping(DestinationField field, String? sourceColumn) {
    if (sourceColumn != null && !availableColumns.contains(sourceColumn)) {
      throw ArgumentError.value(
        sourceColumn,
        'sourceColumn',
        'Column is not available',
      );
    }
    mapping = switch (field) {
      DestinationField.date => mapping.copyWith(dateColumn: sourceColumn),
      DestinationField.shift => mapping.copyWith(shiftColumn: sourceColumn),
      DestinationField.employee => mapping.copyWith(
        employeeColumn: sourceColumn,
      ),
      DestinationField.department => mapping.copyWith(
        departmentColumn: sourceColumn,
      ),
      DestinationField.location => mapping.copyWith(
        locationColumn: sourceColumn,
      ),
      DestinationField.notes => mapping.copyWith(notesColumn: sourceColumn),
    };
    _refreshValidation();
    notifyListeners();
  }

  void resetMapping() {
    mapping = const ColumnMapping();
    hasValidated = false;
    _refreshValidation();
    notifyListeners();
  }

  bool validateMapping() {
    hasValidated = true;
    _refreshValidation();
    notifyListeners();
    return isValid;
  }

  String? valueFor(DestinationField field) => switch (field) {
    DestinationField.date => mapping.dateColumn,
    DestinationField.shift => mapping.shiftColumn,
    DestinationField.employee => mapping.employeeColumn,
    DestinationField.department => mapping.departmentColumn,
    DestinationField.location => mapping.locationColumn,
    DestinationField.notes => mapping.notesColumn,
  };

  String? errorFor(DestinationField field) {
    final value = valueFor(field);
    if (value != null && duplicateColumns.contains(value)) {
      return 'คอลัมน์นี้ถูกเลือกซ้ำ';
    }
    if (hasValidated && field.isRequired && value == null) {
      return 'จำเป็นต้องเลือกคอลัมน์';
    }
    return null;
  }

  void _refreshValidation() {
    duplicateColumns = _findDuplicateColumns();
    final nextErrors = <String>[];
    if (hasValidated) {
      final missing = DestinationField.values
          .where((field) => field.isRequired && valueFor(field) == null)
          .map((field) => field.label)
          .toList(growable: false);
      if (missing.isNotEmpty) {
        nextErrors.add('กรุณาเลือกฟิลด์ที่จำเป็น: ${missing.join(', ')}');
      }
    }
    if (duplicateColumns.isNotEmpty) {
      nextErrors.add('ห้ามใช้คอลัมน์ซ้ำ: ${duplicateColumns.join(', ')}');
    }
    errors = List.unmodifiable(nextErrors);
  }

  Set<String> _findDuplicateColumns() {
    final counts = <String, int>{};
    for (final field in DestinationField.values) {
      final value = valueFor(field);
      if (value != null) counts[value] = (counts[value] ?? 0) + 1;
    }
    return {
      for (final entry in counts.entries)
        if (entry.value > 1) entry.key,
    };
  }

  String? _availableOrNull(String? value) {
    return value != null && availableColumns.contains(value) ? value : null;
  }
}
