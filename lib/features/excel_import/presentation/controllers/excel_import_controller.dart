import 'package:flutter/foundation.dart';

import '../../../../core/state/controller_state.dart';
import '../../../../core/utils/excel_column_name.dart';
import '../../application/import_engine.dart';
import '../../data/excel_reader_service.dart';
import '../../domain/column_mapping.dart';
import '../../domain/excel_cell.dart';
import '../../domain/excel_row.dart';
import '../../domain/import_error.dart';
import '../../domain/import_file.dart';
import '../../domain/import_summary.dart';
import '../../domain/shift_record.dart';
import '../../domain/workbook_info.dart';
import '../../domain/worksheet_info.dart';

enum ExcelImportState { idle, loading, workbookLoaded, worksheetLoaded, error }

class ExcelImportController extends ChangeNotifier implements ControllerState {
  ExcelImportController({
    ExcelReaderService? reader,
    ImportEngine? importEngine,
  }) : _reader = reader ?? ExcelReaderService(),
       _importEngine = importEngine ?? const ImportEngine();

  final ExcelReaderService _reader;
  final ImportEngine _importEngine;

  ExcelImportState state = ExcelImportState.idle;
  ImportFile? selectedFile;
  WorkbookInfo? workbook;
  WorksheetInfo? selectedWorksheet;
  List<ExcelRow> rows = const [];
  @override
  ImportError? error;
  List<ShiftRecord> shiftRecords = const [];
  ImportSummary? importSummary;
  List<ExcelRow>? _externalImportRows;
  List<ExcelRow>? _workingRows;
  ColumnMapping? _lastMapping;
  @override
  bool loading = false;
  bool completed = false;

  bool get isLoading => state == ExcelImportState.loading;

  @override
  bool get success => completed;

  @override
  String? get message => error?.message;

  Future<void> pickFile() async {
    _setLoading();
    try {
      final file = await _reader.pickFile();
      if (file == null) {
        _reset();
        return;
      }

      final openedWorkbook = _reader.openWorkbook(file);
      selectedFile = file;
      workbook = openedWorkbook;
      selectedWorksheet = null;
      rows = const [];
      _clearImportResult();
      error = null;
      state = ExcelImportState.workbookLoaded;
      notifyListeners();
    } on ExcelReaderException catch (exception) {
      _clearWorkbook();
      _setError(exception.error);
    } catch (_) {
      _clearWorkbook();
      _setError(
        const ImportError(
          code: ImportErrorCode.fileSelectionFailed,
          message: 'ไม่สามารถเปิดไฟล์ Excel ได้ กรุณาลองอีกครั้ง',
        ),
      );
    }
  }

  Future<void> selectWorksheet(WorksheetInfo worksheet) async {
    if (isLoading || workbook == null) return;

    _setLoading();
    try {
      final worksheetRows = _reader.readWorksheet(worksheet);
      selectedWorksheet = worksheet;
      rows = List.unmodifiable(worksheetRows);
      _externalImportRows = null;
      _workingRows = null;
      _clearImportResult();
      error = null;
      state = ExcelImportState.worksheetLoaded;
      notifyListeners();
    } on ExcelReaderException catch (exception) {
      _setError(exception.error);
    } catch (_) {
      _setError(
        ImportError(
          code: ImportErrorCode.worksheetReadFailed,
          message: 'ไม่สามารถอ่าน Worksheet ' + worksheet.name + ' ได้',
        ),
      );
    }
  }

  void cancel() {
    _reset();
  }

  /// Loads rows already converted by another tabular data source.
  void loadConvertedWorksheet({
    required WorksheetInfo worksheet,
    required List<ExcelRow> previewRows,
    required List<ExcelRow> importRows,
  }) {
    selectedFile = null;
    workbook = null;
    selectedWorksheet = worksheet;
    rows = List.unmodifiable(previewRows);
    _externalImportRows = List.unmodifiable(importRows);
    _workingRows = List.unmodifiable(importRows);
    _clearImportResult();
    error = null;
    state = ExcelImportState.worksheetLoaded;
    notifyListeners();
  }

  /// Suggests mappings from the full selected worksheet, not only its preview.
  ColumnMapping suggestMapping() {
    return _importEngine.suggestMapping(
      rows: _externalImportRows ?? rows,
    );
  }

  Future<void> importRows(ColumnMapping mapping) async {
    if (loading || selectedWorksheet == null) return;
    loading = true;
    completed = false;
    notifyListeners();

    await Future<void>.delayed(Duration.zero);
    _workingRows ??= _externalImportRows ??
        _reader.readWorksheetForImport(selectedWorksheet!);
    _lastMapping = mapping;
    final result = _importEngine.convertRows(
      rows: _workingRows!,
      mapping: mapping,
    );
    shiftRecords = result.records;
    importSummary = result.summary;
    loading = false;
    completed = true;
    notifyListeners();
  }

  /// Returns the source value for a displayed worksheet row and Excel column.
  Object? valueAt({required int rowNumber, required String column}) {
    if (!_isExcelColumn(column)) return null;
    final columnIndex = ExcelColumnName.toIndex(column);
    final sourceRows = _workingRows ?? rows;
    for (final row in sourceRows) {
      if (row.index != rowNumber - 1) continue;
      for (final cell in row.cells) {
        if (cell.columnIndex == columnIndex) return cell.value;
      }
      return null;
    }
    return null;
  }

  /// Updates one source cell without mutating the original ExcelRow objects.
  /// Row numbers use the worksheet's one-based numbering shown in the UI.
  bool updateCellValue({
    required int rowNumber,
    required String column,
    required Object? value,
  }) {
    if (rowNumber <= 1 || !_isExcelColumn(column)) return false;
    final columnIndex = ExcelColumnName.toIndex(column);
    final sourceRows = _workingRows ?? _externalImportRows ?? rows;
    var found = false;
    final updatedRows = sourceRows.map((row) {
      if (row.index != rowNumber - 1) return row;
      found = true;
      final cells = <ExcelCell>[];
      var replaced = false;
      for (final cell in row.cells) {
        if (cell.columnIndex == columnIndex) {
          cells.add(ExcelCell(
            rowIndex: cell.rowIndex,
            columnIndex: cell.columnIndex,
            value: value,
          ));
          replaced = true;
        } else {
          cells.add(cell);
        }
      }
      if (!replaced) {
        cells.add(ExcelCell(
          rowIndex: row.index,
          columnIndex: columnIndex,
          value: value,
        ));
      }
      return ExcelRow(index: row.index, cells: cells);
    }).toList(growable: false);
    if (!found) return false;

    _workingRows = List.unmodifiable(updatedRows);
    if (_externalImportRows != null) {
      _externalImportRows = List.unmodifiable(updatedRows);
    }
    rows = List.unmodifiable(rows.map((previewRow) {
      if (previewRow.index != rowNumber - 1) return previewRow;
      return updatedRows.firstWhere(
        (candidate) => candidate.index == previewRow.index,
      );
    }));
    notifyListeners();
    return true;
  }

  /// Re-runs the last mapping against the corrected source rows.
  bool reprocessImport() {
    final mapping = _lastMapping;
    final sourceRows = _workingRows;
    if (mapping == null || sourceRows == null) return false;
    final result = _importEngine.convertRows(rows: sourceRows, mapping: mapping);
    shiftRecords = result.records;
    importSummary = result.summary;
    loading = false;
    completed = true;
    notifyListeners();
    return true;
  }

  bool _isExcelColumn(String column) {
    return column.isNotEmpty &&
        column.codeUnits.every((code) => code >= 65 && code <= 90);
  }

  void _setLoading() {
    error = null;
    state = ExcelImportState.loading;
    notifyListeners();
  }

  void _setError(ImportError nextError) {
    error = nextError;
    state = ExcelImportState.error;
    notifyListeners();
  }

  void _clearWorkbook() {
    selectedFile = null;
    workbook = null;
    selectedWorksheet = null;
    rows = const [];
    _externalImportRows = null;
    _workingRows = null;
    _clearImportResult();
  }

  void _clearImportResult() {
    _lastMapping = null;
    shiftRecords = const [];
    importSummary = null;
    loading = false;
    completed = false;
  }

  void _reset() {
    _clearWorkbook();
    error = null;
    state = ExcelImportState.idle;
    notifyListeners();
  }
}
