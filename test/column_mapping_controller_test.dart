import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/excel_import/domain/column_mapping.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/controllers/column_mapping_controller.dart';

void main() {
  test('applies automatic suggestions only for available columns', () {
    final controller = ColumnMappingController();
    addTearDown(controller.dispose);
    controller.loadAvailableColumns(['A', 'B', 'C']);

    controller.applySuggestedMapping(
      const ColumnMapping(
        dateColumn: 'A',
        shiftColumn: 'B',
        employeeColumn: 'C',
        departmentColumn: 'D',
      ),
    );

    expect(controller.mapping.dateColumn, 'A');
    expect(controller.mapping.shiftColumn, 'B');
    expect(controller.mapping.employeeColumn, 'C');
    expect(controller.mapping.departmentColumn, isNull);
    expect(controller.isValid, isTrue);
  });

  test('loads available columns and validates required mappings', () {
    final controller = ColumnMappingController();
    addTearDown(controller.dispose);

    controller.loadAvailableColumns(['A', 'B', 'C', 'C']);

    expect(controller.availableColumns, ['A', 'B', 'C']);
    expect(controller.isValid, isFalse);
    expect(controller.validateMapping(), isFalse);
    expect(controller.errors.single, contains('Date, Shift, Employee'));
    expect(controller.errorFor(DestinationField.date), isNotNull);
  });

  test('detects duplicates and exposes affected source columns', () {
    final controller = ColumnMappingController();
    addTearDown(controller.dispose);
    controller.loadAvailableColumns(['A', 'B', 'C']);

    controller.updateMapping(DestinationField.date, 'A');
    controller.updateMapping(DestinationField.shift, 'A');
    controller.updateMapping(DestinationField.employee, 'C');

    expect(controller.duplicateColumns, {'A'});
    expect(controller.isValid, isFalse);
    expect(controller.errorFor(DestinationField.date), isNotNull);
    expect(controller.errorFor(DestinationField.shift), isNotNull);
  });

  test('keeps a valid mapping in memory and resets it', () {
    final controller = ColumnMappingController();
    addTearDown(controller.dispose);
    controller.loadAvailableColumns(['A', 'B', 'C', 'D']);

    controller.updateMapping(DestinationField.date, 'A');
    controller.updateMapping(DestinationField.shift, 'B');
    controller.updateMapping(DestinationField.employee, 'C');
    controller.updateMapping(DestinationField.department, 'D');

    expect(controller.validateMapping(), isTrue);
    expect(controller.isValid, isTrue);
    expect(controller.mapping.dateColumn, 'A');
    expect(controller.mapping.departmentColumn, 'D');

    controller.resetMapping();

    expect(controller.isValid, isFalse);
    expect(controller.mapping.dateColumn, isNull);
    expect(controller.errors, isEmpty);
  });
}
