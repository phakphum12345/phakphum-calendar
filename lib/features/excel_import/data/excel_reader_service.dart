import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';

import '../domain/excel_cell.dart';
import '../domain/excel_row.dart';
import '../domain/import_error.dart';
import '../domain/import_file.dart';
import '../domain/workbook_info.dart';
import '../domain/worksheet_info.dart';

typedef ExcelFilePicker = Future<ImportFile?> Function();

class ExcelReaderService {
  ExcelReaderService({this.filePicker});

  static const supportedExtension = 'xlsx';
  static const maxFileSizeInBytes = 15 * 1024 * 1024;
  static const maxPreviewRows = 50;

  final ExcelFilePicker? filePicker;
  excel.Excel? _workbook;

  Future<ImportFile?> pickFile() async {
    if (filePicker != null) return filePicker!();

    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [supportedExtension],
      allowMultiple: false,
      withData: true,
    );
    final platformFile = selection?.files.single;
    if (platformFile == null) return null;
    try {
      final bytes =
          platformFile.bytes ?? await platformFile.xFile.readAsBytes();
      return ImportFile(name: platformFile.name, bytes: bytes);
    } catch (_) {
      throw const ExcelReaderException(
        ImportError(
          code: ImportErrorCode.fileSelectionFailed,
          message: 'ไม่สามารถอ่านข้อมูลจากไฟล์ที่เลือกได้',
        ),
      );
    }
  }

  WorkbookInfo openWorkbook(ImportFile file) {
    final validationError = _validate(file);
    if (validationError != null) {
      throw ExcelReaderException(validationError);
    }

    try {
      _workbook = excel.Excel.decodeBytes(file.bytes);
      final worksheets = getWorksheets();
      if (worksheets.isEmpty) {
        throw const ExcelReaderException(
          ImportError(
            code: ImportErrorCode.invalidWorkbook,
            message: 'ไฟล์ Excel ไม่มี Worksheet ที่สามารถอ่านได้',
          ),
        );
      }
      return WorkbookInfo(file: file, worksheets: worksheets);
    } on ExcelReaderException {
      rethrow;
    } catch (_) {
      _workbook = null;
      throw const ExcelReaderException(
        ImportError(
          code: ImportErrorCode.invalidWorkbook,
          message: 'ไฟล์ Excel เสียหายหรือไม่ใช่ไฟล์ .xlsx ที่ถูกต้อง',
        ),
      );
    }
  }

  List<WorksheetInfo> getWorksheets() {
    final workbook = _workbook;
    if (workbook == null) return const [];

    return [
      for (final entry in workbook.tables.entries)
        _worksheetInfo(entry.key, entry.value),
    ];
  }

  WorksheetInfo _worksheetInfo(String name, excel.Sheet sheet) {
    final mergedCells = _mergedCellAnchors(sheet).keys;
    final mergedRowCount = mergedCells.fold<int>(
      0,
      (maximum, coordinate) =>
          coordinate.$1 + 1 > maximum ? coordinate.$1 + 1 : maximum,
    );
    final mergedColumnCount = mergedCells.fold<int>(
      0,
      (maximum, coordinate) =>
          coordinate.$2 + 1 > maximum ? coordinate.$2 + 1 : maximum,
    );
    final rowCount = sheet.rows.length > mergedRowCount
        ? sheet.rows.length
        : mergedRowCount;
    final columnCount = sheet.rows.fold<int>(
      mergedColumnCount,
      (maximum, row) => row.length > maximum ? row.length : maximum,
    );
    return WorksheetInfo(
      name: name,
      rowCount: rowCount,
      columnCount: columnCount,
    );
  }

  List<ExcelRow> readWorksheet(WorksheetInfo worksheet) {
    return _readWorksheetRows(worksheet, limit: maxPreviewRows);
  }

  /// Reads every available row from [worksheet] for import processing.
  List<ExcelRow> readWorksheetForImport(WorksheetInfo worksheet) {
    return _readWorksheetRows(worksheet);
  }

  List<ExcelRow> _readWorksheetRows(WorksheetInfo worksheet, {int? limit}) {
    final sheet = _workbook?.tables[worksheet.name];
    if (sheet == null) {
      throw ExcelReaderException(
        ImportError(
          code: ImportErrorCode.worksheetNotFound,
          message: 'ไม่พบ Worksheet "${worksheet.name}"',
        ),
      );
    }

    try {
      final mergedAnchors = _mergedCellAnchors(sheet);
      final mergedColumnsByRow = <int, int>{};
      for (final coordinate in mergedAnchors.keys) {
        final requiredColumnCount = coordinate.$2 + 1;
        final current = mergedColumnsByRow[coordinate.$1] ?? 0;
        if (requiredColumnCount > current) {
          mergedColumnsByRow[coordinate.$1] = requiredColumnCount;
        }
      }
      final availableRowCount = worksheet.rowCount;
      final rowCount = limit == null || availableRowCount < limit
          ? availableRowCount
          : limit;
      return [
        for (var rowIndex = 0; rowIndex < rowCount; rowIndex++)
          ExcelRow(
            index: rowIndex,
            cells: [
              for (
                var columnIndex = 0,
                rowCells = rowIndex < sheet.rows.length
                    ? sheet.rows[rowIndex]
                    : <dynamic>[];
                columnIndex <
                    (rowCells.length > (mergedColumnsByRow[rowIndex] ?? 0)
                        ? rowCells.length
                        : (mergedColumnsByRow[rowIndex] ?? 0));
                columnIndex++
              )
                ExcelCell(
                  rowIndex: rowIndex,
                  columnIndex: columnIndex,
                  value: columnIndex < rowCells.length
                      ? _cellValue(rowCells[columnIndex]?.value)
                      : null,
                  backgroundColorValue: columnIndex < rowCells.length
                      ? _backgroundColor(rowCells[columnIndex])
                      : null,
                  isMerged: mergedAnchors.containsKey((rowIndex, columnIndex)),
                  mergedAnchorRowIndex:
                      mergedAnchors[(rowIndex, columnIndex)]?.$1,
                  mergedAnchorColumnIndex:
                      mergedAnchors[(rowIndex, columnIndex)]?.$2,
                ),
            ],
          ),
      ];
    } catch (_) {
      throw ExcelReaderException(
        ImportError(
          code: ImportErrorCode.worksheetReadFailed,
          message: 'ไม่สามารถอ่าน Worksheet "${worksheet.name}" ได้',
        ),
      );
    }
  }

  Map<(int, int), (int, int)> _mergedCellAnchors(excel.Sheet sheet) {
    final anchors = <(int, int), (int, int)>{};
    for (final range in sheet.spannedItems) {
      final endpoints = range.toUpperCase().split(':');
      if (endpoints.length != 2) continue;
      final start = _parseCellAddress(endpoints[0]);
      final end = _parseCellAddress(endpoints[1]);
      if (start == null || end == null) continue;
      final (startRow, startColumn) = start;
      final (endRow, endColumn) = end;
      if (endRow < startRow || endColumn < startColumn) continue;
      for (var row = startRow; row <= endRow; row++) {
        for (var column = startColumn; column <= endColumn; column++) {
          anchors[(row, column)] = (startRow, startColumn);
        }
      }
    }
    return anchors;
  }

  (int, int)? _parseCellAddress(String address) {
    final match = RegExp(r'^([A-Z]+)([0-9]+)').firstMatch(address);
    if (match == null || match.group(0) != address) return null;
    final row = int.tryParse(match.group(2) ?? '');
    final column = _columnIndex(match.group(1) ?? '');
    if (row == null || row < 1 || column < 0) return null;
    return (row - 1, column);
  }

  int _columnIndex(String letters) {
    var value = 0;
    for (final code in letters.codeUnits) {
      if (code < 65 || code > 90) return -1;
      value = value * 26 + code - 64;
    }
    return value - 1;
  }

  ImportError? _validate(ImportFile file) {
    if (file.extension != supportedExtension) {
      return const ImportError(
        code: ImportErrorCode.unsupportedExtension,
        message: 'รองรับเฉพาะไฟล์ Excel นามสกุล .xlsx',
      );
    }
    if (file.sizeInBytes == 0) {
      return const ImportError(
        code: ImportErrorCode.emptyFile,
        message: 'ไฟล์ Excel ไม่มีข้อมูล',
      );
    }
    if (file.sizeInBytes > maxFileSizeInBytes) {
      return const ImportError(
        code: ImportErrorCode.fileTooLarge,
        message: 'ไฟล์ Excel ต้องมีขนาดไม่เกิน 15 MB',
      );
    }
    return null;
  }

  int? _backgroundColor(dynamic cell) {
    final color = cell?.cellStyle?.backgroundColor;
    if (color == null || color.colorHex == 'none') return null;
    return 0xFF000000 | (color.colorInt & 0xFFFFFF);
  }

  Object? _cellValue(excel.CellValue? value) => switch (value) {
    null => null,
    excel.TextCellValue() => value.value.text,
    excel.IntCellValue() => value.value,
    excel.DoubleCellValue() => value.value,
    excel.BoolCellValue() => value.value,
    excel.DateCellValue() => value.asDateTimeLocal(),
    excel.DateTimeCellValue() => value.asDateTimeLocal(),
    excel.TimeCellValue() => value.asDuration(),
    excel.FormulaCellValue() => value.formula,
  };
}

class ExcelReaderException implements Exception {
  const ExcelReaderException(this.error);

  final ImportError error;

  @override
  String toString() => error.message;
}
