import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/hospital_roster_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/normalized_cell.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/shift_parser_input.dart';

void main() {
  test('scans the full sheet for period and date header before worker names', () {
    final days = <Object?>[
      'วันที่',
      ...List<int>.generate(16, (index) => index + 16),
      ...List<int>.generate(15, (index) => index + 1),
    ];
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 42,
      sheetTitle: 'ชื่อชีตไม่ตรงกับเดือน',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['คำอธิบายทั่วไป']),
        ..._row(5, ['ช่วงเวร ประจำเดือน 16 กรกฎาคม พ.ศ. 2569 - 15 สิงหาคม พ.ศ. 2569']),
        ..._row(10, days),
        ..._row(11, ['P2 บ่าย', 'นาย ก', ...List<String?>.filled(30, null)]),
        ..._row(12, ['ER เช้า', null, 'นาย ข', ...List<String?>.filled(29, null)]),
      ],
    );

    final report = const HospitalRosterParser().parse(input);

    expect(report.periodStart, DateTime(2026, 7, 16));
    expect(report.periodEnd, DateTime(2026, 8, 15));
    expect(report.warnings, isEmpty);
    expect(report.assignments, hasLength(2));
    expect(report.assignments[0].date, DateTime(2026, 7, 16));
    expect(report.assignments[0].workerName, 'นาย ก');
    expect(report.assignments[0].sourceCell, 'B12');
    expect(report.assignments[1].date, DateTime(2026, 7, 17));
    expect(report.assignments[1].workerName, 'นาย ข');
    expect(report.assignments[1].sourceCell, 'C13');
  });

  test('maps every header column through a month boundary in visual order', () {
    final days = <Object?>[
      'วันที่',
      ...List<int>.generate(16, (index) => index + 16),
      ...List<int>.generate(15, (index) => index + 1),
    ];
    final names = <Object?>[
      'ER เช้า',
      'วัน 16',
      ...List<Object?>.filled(15, null),
      'วัน 31',
      'วัน 1',
      ...List<Object?>.filled(13, null),
      'วัน 15',
    ];
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 7,
      sheetTitle: '16 ส.ค. 69 - 15 ก.ย. 69',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(7, days),
        ..._row(8, names),
      ],
    );

    final report = const HospitalRosterParser().parse(input);

    expect(report.assignments.map((item) => item.date), [
      DateTime(2026, 8, 16),
      DateTime(2026, 8, 31),
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 15),
    ]);
    expect(report.assignments.map((item) => item.workerName), [
      'วัน 16',
      'วัน 31',
      'วัน 1',
      'วัน 15',
    ]);
  });

  test('does not generate assignments for impossible dates or invalid headers', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: '16 ก.พ. 69 - 15 มี.ค. 69',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(4, ['วันที่', 16, 29, 'หมายเหตุ', 1]),
        ..._row(5, ['ER เช้า', 'ถูกต้อง', 'วันที่ไม่มีจริง', 'ข้าม', 'วันสุดท้าย']),
      ],
    );

    final report = const HospitalRosterParser().parse(input);

    expect(report.assignments, hasLength(2));
    expect(report.assignments[0].date, DateTime(2026, 2, 16));
    expect(report.assignments[0].workerName, 'ถูกต้อง');
    expect(report.assignments[1].date, DateTime(2026, 3, 1));
    expect(report.assignments[1].workerName, 'วันสุดท้าย');
    expect(report.warnings, hasLength(2));
    expect(report.warnings.join(' '), contains('วันที่ 29 อยู่นอกช่วง'));
    expect(report.warnings.join(' '), contains('ไม่ใช่วันที่ 1-31'));
  });

  test('finds date header beyond first two rows and rejects missing date row', () {
    final valid = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: '1-31 กรกฎาคม 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(9, ['วันที่', 1, 2]),
        ..._row(10, ['ER เช้า', 'นาย ก', 'นาย ข']),
      ],
    );
    expect(
      const HospitalRosterParser().parse(valid).assignments,
      hasLength(2),
    );

    final invalid = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'กรกฎาคม 2569',
      timeZone: 'Asia/Bangkok',
      cells: [..._row(9, ['ER เช้า', 'นาย ก'])],
    );
    expect(
      () => const HospitalRosterParser().parse(invalid),
      throwsA(isA<FormatException>()),
    );
  });
}

List<NormalizedCell> _row(int rowIndex, List<Object?> values) {
  return [
    for (var columnIndex = 0; columnIndex < values.length; columnIndex++)
      if (values[columnIndex] != null)
        NormalizedCell(
          sheetId: 1,
          sheetTitle: 'Sheet',
          a1: '',
          rowIndex: rowIndex,
          columnIndex: columnIndex,
          text: values[columnIndex] is String
              ? values[columnIndex] as String
              : null,
          rawValue: values[columnIndex] is num ? values[columnIndex] : null,
        ),
  ];
}
