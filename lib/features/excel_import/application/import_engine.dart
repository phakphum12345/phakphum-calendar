import '../../../core/utils/excel_column_name.dart';
import '../domain/column_mapping.dart';
import '../domain/excel_row.dart';
import '../domain/import_engine_result.dart';
import '../domain/import_issue.dart';
import '../domain/import_summary.dart';
import '../domain/shift_record.dart';

class ImportEngine {
  const ImportEngine();

  /// Infers column mappings from common Thai and English roster headers.
  ///
  /// The result is a suggestion only: callers should still let users review
  /// ambiguous or missing required columns before saving imported data.
  ColumnMapping suggestMapping({required List<ExcelRow> rows}) {
    if (rows.isEmpty) return const ColumnMapping();

    final headers = rows.first.cells
        .where((cell) => cell.displayValue.trim().isNotEmpty)
        .toList()
      ..sort((left, right) => left.columnIndex.compareTo(right.columnIndex));
    final usedColumns = <int>{};

    String? findColumn(List<String> aliases) {
      for (final alias in aliases) {
        final normalizedAlias = _normalizeHeader(alias);
        for (final cell in headers) {
          if (usedColumns.contains(cell.columnIndex)) continue;
          if (_normalizeHeader(cell.displayValue) == normalizedAlias) {
            usedColumns.add(cell.columnIndex);
            return ExcelColumnName.fromIndex(cell.columnIndex);
          }
        }
      }
      return null;
    }

    return ColumnMapping(
      dateColumn: findColumn(const [
        'date', 'shift date', 'roster date', 'วันที่', 'วันที่ปฏิบัติงาน',
        'วันที่เวร', 'วันปฏิบัติงาน',
      ]),
      shiftColumn: findColumn(const [
        'shift', 'shift type', 'duty', 'duty type', 'เวร', 'ชื่อเวร',
        'รหัสเวร', 'ประเภทเวร',
      ]),
      employeeColumn: findColumn(const [
        'employee', 'employee name', 'staff', 'staff name', 'person',
        'name', 'ชื่อ', 'ชื่อ-สกุล', 'ชื่อสกุล', 'ผู้ปฏิบัติงาน',
        'บุคลากร', 'พนักงาน',
      ]),
      departmentColumn: findColumn(const [
        'department', 'dept', 'unit', 'ward', 'แผนก', 'หน่วยงาน',
        'กลุ่มงาน',
      ]),
      locationColumn: findColumn(const [
        'location', 'site', 'hospital', 'workplace', 'place',
        'สถานที่', 'สถานที่ปฏิบัติงาน', 'จุดปฏิบัติงาน',
      ]),
      notesColumn: findColumn(const [
        'notes', 'note', 'remarks', 'remark', 'หมายเหตุ', 'รายละเอียด',
      ]),
    );
  }

  String _normalizeHeader(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-./():]+'), '');

  ImportEngineResult convertRows({
    required List<ExcelRow> rows,
    required ColumnMapping mapping,
    bool hasHeaderRow = true,
  }) {
    final dataRows = hasHeaderRow && rows.isNotEmpty ? rows.skip(1) : rows;
    final records = <ShiftRecord>[];
    final issues = <ImportIssue>[];
    final duplicateKeys = <String>{};
    var totalRows = 0;
    var skippedRows = 0;
    var errorRows = 0;

    for (final row in dataRows) {
      totalRows++;
      if (row.isEmpty) {
        skippedRows++;
        continue;
      }

      final rowIssues = validateRow(row: row, mapping: mapping);
      issues.addAll(rowIssues);
      if (rowIssues.any(
        (issue) => issue.severity == ImportIssueSeverity.error,
      )) {
        errorRows++;
        continue;
      }

      final record = createShiftRecord(row: row, mapping: mapping);
      final duplicateKey = _duplicateKey(record);
      if (!duplicateKeys.add(duplicateKey)) {
        issues.add(
          ImportIssue(
            rowNumber: record.rowNumber,
            column: 'Row',
            message: 'Duplicate shift record',
            severity: ImportIssueSeverity.warning,
          ),
        );
      }
      records.add(record);
    }

    return ImportEngineResult(
      records: records,
      summary: ImportSummary(
        totalRows: totalRows,
        importedRows: records.length,
        skippedRows: skippedRows,
        errorRows: errorRows,
        issues: issues,
      ),
    );
  }

  List<ImportIssue> validateRow({
    required ExcelRow row,
    required ColumnMapping mapping,
  }) {
    final issues = <ImportIssue>[];
    final dateValue = _value(row, mapping.dateColumn);
    final shiftValue = _text(row, mapping.shiftColumn);
    final employeeValue = _text(row, mapping.employeeColumn);

    if (dateValue == null || '$dateValue'.trim().isEmpty) {
      issues.add(
        _requiredIssue(row, mapping.dateColumn ?? 'Date', 'Date is required'),
      );
    } else if (_parseDate(dateValue) == null) {
      issues.add(
        ImportIssue(
          rowNumber: row.index + 1,
          column: mapping.dateColumn ?? 'Date',
          message: 'Invalid date: $dateValue',
          severity: ImportIssueSeverity.error,
        ),
      );
    }
    if (shiftValue.isEmpty) {
      issues.add(
        _requiredIssue(
          row,
          mapping.shiftColumn ?? 'Shift',
          'Shift is required',
        ),
      );
    }
    if (employeeValue.isEmpty) {
      issues.add(
        _requiredIssue(
          row,
          mapping.employeeColumn ?? 'Employee',
          'Employee is required',
        ),
      );
    }
    return issues;
  }

  ShiftRecord createShiftRecord({
    required ExcelRow row,
    required ColumnMapping mapping,
  }) {
    return ShiftRecord(
      date: _parseDate(_value(row, mapping.dateColumn)),
      shift: _text(row, mapping.shiftColumn),
      employee: _text(row, mapping.employeeColumn),
      department: _nullableText(row, mapping.departmentColumn),
      location: _nullableText(row, mapping.locationColumn),
      notes: _nullableText(row, mapping.notesColumn),
      rowNumber: row.index + 1,
    );
  }

  ImportIssue _requiredIssue(ExcelRow row, String column, String message) {
    return ImportIssue(
      rowNumber: row.index + 1,
      column: column,
      message: message,
      severity: ImportIssueSeverity.error,
    );
  }

  Object? _value(ExcelRow row, String? columnName) {
    if (columnName == null) return null;
    final columnIndex = ExcelColumnName.toIndex(columnName);
    for (final cell in row.cells) {
      if (cell.columnIndex == columnIndex) return cell.value;
    }
    return null;
  }

  String _text(ExcelRow row, String? columnName) {
    return _value(row, columnName)?.toString().trim() ?? '';
  }

  String? _nullableText(ExcelRow row, String? columnName) {
    final value = _text(row, columnName);
    return value.isEmpty ? null : value;
  }

  DateTime? _parseDate(Object? value) {
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final isoDate = DateTime.tryParse(text);
    if (isoDate != null) {
      return DateTime(isoDate.year, isoDate.month, isoDate.day);
    }

    final parts = text.split(RegExp(r'[/.-]'));
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    var year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (year > 2400) year -= 543;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  String _duplicateKey(ShiftRecord record) {
    return '${record.date?.toIso8601String()}|'
        '${record.shift.toLowerCase()}|'
        '${record.employee.toLowerCase()}';
  }
}
