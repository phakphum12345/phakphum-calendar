import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';

import '../models/shift.dart';

class LocalRosterDocument {
  const LocalRosterDocument({
    required this.extension,
    required this.snapshots,
    this.sourceFingerprint,
  });

  final String extension;
  final List<SheetSnapshot> snapshots;
  final String? sourceFingerprint;
}

/// Selects and reads roster files from the local device.
abstract interface class LocalRosterSource {
  Future<LocalRosterDocument?> pickAndRead();
}

class LocalRosterFileService implements LocalRosterSource {
  const LocalRosterFileService();

  static const supportedExtensions = ['xlsx', 'csv', 'tsv', 'txt'];
  static const maxBytes = 15 * 1024 * 1024;
  static const maxCells = 200000;

  @override
  Future<LocalRosterDocument?> pickAndRead() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'ตารางเวร',
          extensions: supportedExtensions,
          mimeTypes: [
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'text/csv',
            'text/tab-separated-values',
            'text/plain',
          ],
        ),
      ],
      confirmButtonText: 'อ่านตารางเวร',
    );
    if (file == null) return null;
    return readBytes(name: file.name, bytes: await file.readAsBytes());
  }

  LocalRosterDocument readBytes({
    required String name,
    required Uint8List bytes,
  }) {
    if (bytes.length > maxBytes) {
      throw const FormatException('ไฟล์ใหญ่เกิน 15 MB กรุณาแบ่งไฟล์ก่อนอ่าน');
    }
    final extension = name.split('.').last.toLowerCase();
    if (!supportedExtensions.contains(extension)) {
      throw FormatException(
        'ไม่รองรับ .$extension กรุณาใช้ .xlsx, .csv, .tsv หรือ .txt',
      );
    }
    final snapshots = extension == 'xlsx'
        ? _readExcel(bytes)
        : [_readDelimited(bytes, extension: extension)];
    final cellCount = snapshots.fold<int>(
      0,
      (count, sheet) =>
          count + sheet.rows.fold(0, (sum, row) => sum + row.length),
    );
    if (cellCount > maxCells) {
      throw const FormatException(
        'ไฟล์มีข้อมูลเกิน 200,000 เซลล์ กรุณาแบ่งไฟล์ก่อนอ่าน',
      );
    }
    return LocalRosterDocument(
      extension: extension,
      snapshots: snapshots,
      sourceFingerprint: 'sha256:' + sha256.convert(bytes).toString(),
    );
  }

  List<SheetSnapshot> _readExcel(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    return [
      for (final entry in workbook.tables.entries)
          SheetSnapshot(
            title: entry.key,
            rows: [
              for (final row in entry.value.rows)
                [for (final cell in row) _cellValue(cell?.value)],
            ],
            backgroundColors: [
              for (final row in entry.value.rows)
                [for (final cell in row) _backgroundColor(cell)],
            ],
          ),
    ];
  }

  SheetSnapshot _readDelimited(Uint8List bytes, {required String extension}) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final delimiter = extension == 'tsv'
        ? '\t'
        : extension == 'csv'
        ? ','
        : text.contains('\t')
        ? '\t'
        : ',';
    return SheetSnapshot(
      title: 'ไฟล์ในเครื่อง',
      rows: _parseDelimited(text, delimiter),
    );
  }

  List<List<Object?>> _parseDelimited(String text, String delimiter) {
    final rows = <List<Object?>>[];
    var row = <Object?>[];
    var field = StringBuffer();
    var quoted = false;
    for (var index = 0; index < text.length; index++) {
      final character = text[index];
      if (character == '"') {
        if (quoted && index + 1 < text.length && text[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && character == delimiter) {
        row.add(field.toString());
        field = StringBuffer();
      } else if (!quoted && (character == '\n' || character == '\r')) {
        if (character == '\r' &&
            index + 1 < text.length &&
            text[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString());
        if (row.any((value) => '$value'.trim().isNotEmpty)) rows.add(row);
        row = <Object?>[];
        field = StringBuffer();
      } else {
        field.write(character);
      }
    }
    row.add(field.toString());
    if (row.any((value) => '$value'.trim().isNotEmpty)) rows.add(row);
    return rows;
  }

  Object? _cellValue(CellValue? value) => switch (value) {
    null => null,
    TextCellValue() => value.value.text,
    IntCellValue() => value.value,
    DoubleCellValue() => value.value,
    BoolCellValue() => value.value,
    DateCellValue() => value.asDateTimeLocal(),
    DateTimeCellValue() => value.asDateTimeLocal(),
    TimeCellValue() => value.asDuration().toString(),
    FormulaCellValue() => value.formula,
  };

  int? _backgroundColor(Data? cell) {
    final color = cell?.cellStyle?.backgroundColor;
    if (color == null || color.colorHex == 'none') return null;
    return 0xFF000000 | (color.colorInt & 0xFFFFFF);
  }
}
