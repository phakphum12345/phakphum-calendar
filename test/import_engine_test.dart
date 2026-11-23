import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/excel_import/application/import_engine.dart';
import 'package:phakphum_calendar/features/excel_import/domain/column_mapping.dart';
import 'package:phakphum_calendar/features/excel_import/domain/excel_cell.dart';
import 'package:phakphum_calendar/features/excel_import/domain/excel_row.dart';
import 'package:phakphum_calendar/features/excel_import/domain/import_issue.dart';

void main() {
  const engine = ImportEngine();
  const mapping = ColumnMapping(
    dateColumn: 'A',
    shiftColumn: 'B',
    employeeColumn: 'C',
    departmentColumn: 'D',
    locationColumn: 'E',
    notesColumn: 'F',
  );

  test('suggests mappings for Thai roster headers', () {
    final mapping = engine.suggestMapping(
      rows: [
        _row(0, ['วันที่', 'ชื่อเวร', 'ชื่อ-สกุล', 'หน่วยงาน', 'สถานที่', 'หมายเหตุ']),
        _row(1, ['2026-07-24', 'เช้า', 'Anan', 'ER', 'Building A', 'On call']),
      ],
    );

    expect(mapping.dateColumn, 'A');
    expect(mapping.shiftColumn, 'B');
    expect(mapping.employeeColumn, 'C');
    expect(mapping.departmentColumn, 'D');
    expect(mapping.locationColumn, 'E');
    expect(mapping.notesColumn, 'F');
  });

  test('suggests mappings for common English roster headers', () {
    final mapping = engine.suggestMapping(
      rows: [
        _row(0, ['Shift Date', 'Duty Type', 'Staff Name', 'Ward', 'Workplace', 'Remarks']),
      ],
    );

    expect(mapping.dateColumn, 'A');
    expect(mapping.shiftColumn, 'B');
    expect(mapping.employeeColumn, 'C');
    expect(mapping.departmentColumn, 'D');
    expect(mapping.locationColumn, 'E');
    expect(mapping.notesColumn, 'F');
  });

  test('returns an empty suggestion when there are no rows', () {
    expect(engine.suggestMapping(rows: []).dateColumn, isNull);
    expect(engine.suggestMapping(rows: []).shiftColumn, isNull);
  });

  test('converts a valid Excel row into a ShiftRecord', () {
    final result = engine.convertRows(
      rows: [
        _row(0, ['Date', 'Shift', 'Employee']),
        _row(1, [
          '2026-07-24',
          'Morning',
          'Anan',
          'ER',
          'Building A',
          'On call',
        ]),
      ],
      mapping: mapping,
    );

    expect(result.records, hasLength(1));
    final record = result.records.single;
    expect(record.date, DateTime(2026, 7, 24));
    expect(record.shift, 'Morning');
    expect(record.employee, 'Anan');
    expect(record.department, 'ER');
    expect(record.location, 'Building A');
    expect(record.notes, 'On call');
    expect(record.rowNumber, 2);
  });

  test('reports invalid dates', () {
    final result = engine.convertRows(
      rows: [
        _row(0, ['Date', 'Shift', 'Employee']),
        _row(1, ['not-a-date', 'Morning', 'Anan']),
      ],
      mapping: mapping,
    );

    expect(result.records, isEmpty);
    expect(result.summary.errorRows, 1);
    expect(
      result.summary.issues.single,
      isA<ImportIssue>()
          .having(
            (issue) => issue.severity,
            'severity',
            ImportIssueSeverity.error,
          )
          .having((issue) => issue.column, 'column', 'A'),
    );
  });

  test('reports missing required fields', () {
    final result = engine.convertRows(
      rows: [
        _row(0, ['Date', 'Shift', 'Employee']),
        _row(1, ['2026-07-24', '', '']),
      ],
      mapping: mapping,
    );

    expect(result.records, isEmpty);
    expect(result.summary.errorRows, 1);
    expect(
      result.summary.issues.map((issue) => issue.message),
      containsAll(['Shift is required', 'Employee is required']),
    );
  });

  test('warns about duplicates while retaining valid records', () {
    final result = engine.convertRows(
      rows: [
        _row(0, ['Date', 'Shift', 'Employee']),
        _row(1, ['24/07/2026', 'Morning', 'Anan']),
        _row(2, ['24/07/2026', 'Morning', 'Anan']),
      ],
      mapping: mapping,
    );

    expect(result.records, hasLength(2));
    expect(result.summary.warningCount, 1);
    expect(result.summary.issues.single.severity, ImportIssueSeverity.warning);
  });

  test('generates totals for imported, skipped, and error rows', () {
    final result = engine.convertRows(
      rows: [
        _row(0, ['Date', 'Shift', 'Employee']),
        _row(1, ['2026-07-24', 'Morning', 'Anan']),
        _row(2, []),
        _row(3, ['invalid', 'Evening', 'Boon']),
        _row(4, ['2026-07-24', 'Morning', 'Anan']),
      ],
      mapping: mapping,
    );

    expect(result.summary.totalRows, 4);
    expect(result.summary.importedRows, 2);
    expect(result.summary.skippedRows, 1);
    expect(result.summary.errorRows, 1);
    expect(result.summary.errorCount, 1);
    expect(result.summary.warningCount, 1);
    expect(result.summary.successPercentage, 50);
  });
}

ExcelRow _row(int index, List<Object?> values) {
  return ExcelRow(
    index: index,
    cells: [
      for (var columnIndex = 0; columnIndex < values.length; columnIndex++)
        ExcelCell(
          rowIndex: index,
          columnIndex: columnIndex,
          value: values[columnIndex],
        ),
    ],
  );
}
