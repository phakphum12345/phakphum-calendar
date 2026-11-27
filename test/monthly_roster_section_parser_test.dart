import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/monthly_roster_section.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/normalized_cell.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/shift_parser_input.dart';
import 'package:phakphum_calendar/models/shift.dart';

void main() {
  test('discovers monthly blocks and keeps section and row labels dynamic', () {
    final cells = <NormalizedCell>[
      ..._row(0, ['เวรใหญ่ ประจำเดือน กรกฎาคม พ.ศ. 2569']),
      ..._row(1, ['เวร', 'พ', 'พฤ', 'ศ', 'ส', 'อา', 'จ', 'อ']),
      ..._row(2, ['วันที่', 1, 2, 3, 4, 5, 6, 7]),
      ..._row(3, ['MRI', 'ก', 'ข', null, null, null, null, null]),
      ..._row(4, ['MRI', 'ง', null, null, null, null, null, null]),
      ..._row(6, ['GEN คลินิคพิเศษ ประจำเดือน กรกฎาคม พ.ศ. 2569']),
      ..._row(7, ['เวร', 'พ', 'พฤ', 'ศ', 'ส', 'อา', 'จ', 'อ']),
      ..._row(8, ['วันที่', 1, 2, 3, 4, 5, 6, 7]),
      ..._row(9, ['คลินิก A', 'ค', null, null, null, null, null, null]),
    ];
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1666384927,
      sheetTitle: 'ตารางเวรรายเดือน',
      timeZone: 'Asia/Bangkok',
      cells: cells,
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.warnings, isEmpty);
    expect(report.sections, hasLength(2));
    expect(report.sections.first.title, contains('เวรใหญ่'));
    expect(report.sections.last.title, contains('คลินิคพิเศษ'));
    expect(report.assignments, hasLength(4));
    expect(report.assignments.first.rowLabel, 'MRI');
    expect(report.assignments.first.date, DateTime(2026, 7, 1));
    expect(
      report.sections.first.assignments.map((item) => item.rowIndex).toSet(),
      containsAll(<int>{3, 4}),
    );
    expect(report.assignments.last.rowLabel, 'คลินิก A');
    expect(report.assignments.last.sourceCell, 'B10');
  });

  test('preserves row 33 เวรเช้า14 ชั้น across a 16th-to-15th schedule block', () {
    const workers = <Object?>[
      'ธราวุธ',
      'บุบผา',
      'บุบผา',
      'ประภาพร',
      'บุบผา',
      null,
      null,
      'ธราวุธ',
      'อดิศักดิ์',
      'ธราวุธ',
      'ธนพร',
      'วรรณิกานต์',
      null,
      null,
      'อัมพร',
      'ธราวุธ',
      'จักรกฤษณ์',
      'สุวดี',
      'ธราวุธ',
      null,
      null,
      null,
      'กรรทร',
      'ธราวุธ',
      null,
      'ธราวุธ',
      null,
      null,
      'วรวุฒิ',
      'ธราวุธ',
    ];
    expect(workers, hasLength(30));
    final days = [
      ...List<int>.generate(15, (index) => index + 16),
      ...List<int>.generate(15, (index) => index + 1),
    ];
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'ตารางเวร',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(1, [
          '',
          ...List<String>.generate(30, (index) => [
            'จันทร์',
            'อังคาร',
            'พุธ',
            'พฤหัสบดี',
            'ศุกร์',
            'เสาร์',
            'อาทิตย์',
          ][index % 7]),
        ]),
        ..._row(2, ['วันที่', ...days]),
        ..._row(3, ['ประจำเดือน 16 พฤศจิกายน พ.ศ. 2569 - 15 ธันวาคม พ.ศ. 2569']),
        ..._row(32, ['เวรเช้า14 ชั้น', ...workers]),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);
    final rowAssignments = report.assignments
        .where((assignment) => assignment.rowIndex == 32)
        .toList();
    final shifts = const MonthlyRosterShiftAdapter().parseForWorkers(
      report,
      targetNames: const ['ธราวุธ'],
    );

    expect(report.warnings, isEmpty);
    expect(report.sections, hasLength(1));
    expect(report.sections.single.startDate, DateTime(2026, 11, 16));
    expect(report.sections.single.endDate, DateTime(2026, 12, 15));
    expect(report.sections.single.rosterRows.single.label, 'เวรเช้า14 ชั้น');
    expect(rowAssignments, hasLength(20));
    expect(rowAssignments.first.date, DateTime(2026, 11, 16));
    expect(rowAssignments.first.sourceCell, 'B33');
    expect(rowAssignments.last.date, DateTime(2026, 12, 15));
    expect(rowAssignments.last.sourceCell, 'AE33');
    expect(shifts, hasLength(8));
    expect(shifts.every((shift) => shift.code == 'U14'), isTrue);
    expect(shifts.first.start, DateTime(2026, 11, 16, 7));
    expect(shifts.last.start, DateTime(2026, 12, 15, 7));
    expect(shifts.last.end, DateTime(2026, 12, 15, 8));
  });

  test('rebuilds assignments and revalidates an explicit date correction', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'November 2026',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['GEN 1 พฤศจิกายน 2569 - 7 พฤศจิกายน 2569']),
        ..._row(1, ['วันที่', 1, 2, 3, 4, 5, 5, 7]),
        ..._row(2, ['GEN', 'ก', null, null, null, null, 'ข', 'ค']),
      ],
    );
    const parser = MonthlyRosterSectionParser();
    final parsed = parser.parse(input);
    final original = parsed.sections.single;

    expect(original.dateAnomalies, isNotEmpty);
    expect(original.assignments, hasLength(2));
    expect(original.sourceCells, isNotEmpty);
    expect(original.startDate, DateTime(2026, 11, 1));
    expect(original.endDate, DateTime(2026, 11, 7));
    expect(
      original.dateAnomalies.any((anomaly) => anomaly.columnIndex == 6),
      isTrue,
    );

    final corrected = parser.correctDateColumns(
      section: original,
      correctedDatesByColumn: {6: DateTime(2026, 11, 6)},
    );

    expect(corrected.dateAnomalies, isEmpty);
    expect(corrected.dateColumns, hasLength(7));
    expect(corrected.assignments, hasLength(3));
    expect(
      corrected.assignments.singleWhere((item) => item.workerName == 'ข').date,
      DateTime(2026, 11, 6),
    );
    expect(
      corrected.assignments.singleWhere((item) => item.workerName == 'ข').sourceCell,
      'G3',
    );
  });

  test('does not apply a date correction without a source header column', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'November 2026',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['GEN 1 พฤศจิกายน 2569 - 7 พฤศจิกายน 2569']),
        ..._row(1, ['วันที่', 1, 2, 3, 4, 5, 5, 7]),
        ..._row(2, ['GEN', 'ก', null, null, null, 'ข', null, 'ค']),
      ],
    );
    const parser = MonthlyRosterSectionParser();
    final section = parser.parse(input).sections.single;

    expect(
      () => parser.correctDateColumns(
        section: section,
        correctedDatesByColumn: {99: DateTime(2026, 11, 6)},
      ),
      throwsArgumentError,
    );
  });

  test('supports two departments across a six-month date block', () {
    final dates = List<DateTime>.generate(
      181,
      (index) => DateTime(2026, 11, 1).add(Duration(days: index)),
    );
    final secondDepartmentWorkers = List<Object?>.filled(dates.length, null)
      ..[0] = 'นาง ค';
    final firstDepartmentWorkers = List<Object?>.filled(dates.length, null)
      ..[0] = 'นาย ก'
      ..[180] = 'นาย ข';
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'ตารางเวรหลายแผนก',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, [
          'เวรใหญ่ อายุรกรรม ประจำเดือน 1 พฤศจิกายน พ.ศ. 2569 - 30 เมษายน พ.ศ. 2570',
        ]),
        ..._row(1, ['วันที่', ...dates]),
        ..._row(2, ['เวรเช้า', ...firstDepartmentWorkers]),
        ..._row(4, [
          'คลินิกพิเศษ กุมารเวช ประจำเดือน 1 พฤศจิกายน พ.ศ. 2569 - 30 เมษายน พ.ศ. 2570',
        ]),
        ..._row(5, ['วันที่', ...dates]),
        ..._row(6, ['คลินิก', ...secondDepartmentWorkers]),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.warnings, isEmpty);
    expect(report.sections, hasLength(2));
    expect(report.sections[0].title, contains('อายุรกรรม'));
    expect(report.sections[1].title, contains('กุมารเวช'));
    expect(report.sections[0].dateColumns, hasLength(181));
    expect(report.sections[1].dateColumns, hasLength(181));
    expect(report.sections[0].startDate, DateTime(2026, 11, 1));
    expect(report.sections[0].endDate, DateTime(2027, 4, 30));
    expect(report.sections[1].startDate, DateTime(2026, 11, 1));
    expect(report.sections[1].endDate, DateTime(2027, 4, 30));
    expect(report.assignments, hasLength(3));
    expect(report.assignments.map((item) => item.workerName), [
      'นาย ก',
      'นาย ข',
      'นาง ค',
    ]);
    expect(report.assignments[1].date, DateTime(2027, 4, 30));
  });

  test('does not require fixed names for exten or future sections', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'รายเดือน',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['Exten ใหม่ ประจำเดือน สิงหาคม พ.ศ. 2569']),
        ..._row(1, ['วันที่', 1, 2, 3, 4, 5, 6, 7]),
        ..._row(2, ['พื้นที่ A', 'บุคลากร A']),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.sections.single.title, startsWith('Exten ใหม่'));
    expect(report.assignments.single.rowLabel, 'พื้นที่ A');
    expect(report.assignments.single.workerName, 'บุคลากร A');
    expect(report.assignments.single.date, DateTime(2026, 8, 1));
  });

  test('keeps the exact cross-month range declared by the roster', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: '16 ส.ค. - 15 ก.ย. 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวร 16 สิงหาคม 2569 - 15 กันยายน 2569']),
        ..._row(1, ['วันที่', 16, 17, 18, 19, 20, 21, 22]),
        ..._row(2, ['พื้นที่ A', 'บุคลากร A']),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.dateRanges, hasLength(1));
    expect(report.dateRanges.single.start, DateTime(2026, 8, 16));
    expect(report.dateRanges.single.end, DateTime(2026, 9, 15));
  });

  test('uses the explicit GEN section range instead of the unit number', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'พฤศจิกายน 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, [
          'GEN คลินิคพิเศษ ภปร. 4 พฤศจิกายน พ.ศ. 2569 '
          '(1 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569)',
        ]),
        ..._row(1, ['วันที่', 1, 2, 3, 4, 5, 6, 7]),
        ..._row(2, ['GEN', 'บุคลากร A']),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.sections, hasLength(1));
    expect(report.sections.single.startDate, DateTime(2026, 11, 1));
    expect(report.sections.single.endDate, DateTime(2026, 11, 30));
    expect(report.assignments.single.date, DateTime(2026, 11, 1));
    expect(report.assignments.single.workerName, 'บุคลากร A');
  });

  test('does not fall back to the sheet month when a compact explicit range is invalid', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'กุมภาพันธ์ 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['GEN 31-31 กุมภาพันธ์ 2569']),
        ..._row(1, ['วันที่', 1, 2, 3, 4, 5, 6, 7]),
        ..._row(2, ['GEN', 'บุคลากร A']),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.sections, hasLength(1));
    expect(report.assignments, isEmpty);
    expect(report.sections.single.dateAnomalies.single.code, 'unresolved_period');
    expect(report.sections.single.startDate, isNull);
    expect(report.sections.single.endDate, isNull);
    expect(report.warnings.single, contains('ไม่ใช้เดือนจากชื่อชีตแทน'));
  });

  test('does not use worksheet month when a section declares conflicting ranges', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'พฤศจิกายน 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, [
          'GEN ประจำเดือน พฤศจิกายน 2569 '
          '(1 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569) '
          '(1 ธันวาคม 2569 - 31 ธันวาคม 2569)',
        ]),
        ..._row(1, ['วันที่', 1, 2, 3, 4, 5, 6, 7]),
        ..._row(2, ['GEN', 'บุคลากร A']),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.sections, hasLength(1));
    expect(report.assignments, isEmpty);
    expect(
      report.sections.single.dateAnomalies.single.code,
      'unresolved_period',
    );
    expect(report.sections.single.startDate, isNull);
    expect(report.sections.single.endDate, isNull);
    expect(report.warnings, hasLength(1));
    expect(report.warnings.single, contains('ไม่ใช้เดือนจากชื่อชีตแทน'));
  });

  test('blocks malformed X-OPD dates without blocking a valid section', () {
    final portableDays = [
      ...List<int>.generate(15, (index) => index + 16),
      ...List<int>.generate(15, (index) => index + 1),
    ];
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'พฤศจิกายน 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['PORTABLE 16 พฤศจิกายน 2569 - 15 ธันวาคม 2569']),
        ..._row(1, ['วันที่', ...portableDays]),
        ..._row(2, ['ER', ...List<String>.filled(30, 'นาย ก')]),
        ..._row(4, [
          'X-OPD ประจำเดือน พฤศจิกายน พ.ศ. 2569 '
          '(1 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569)',
        ]),
        ..._row(5, [
          'วันที่',
          ...List<int>.generate(16, (index) => index + 1),
          30,
          30,
        ]),
        ..._row(6, ['X-OPD', ...List<String>.filled(18, 'นาย ข')]),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);
    final portable = report.sections.singleWhere(
      (section) => section.title.startsWith('PORTABLE'),
    );
    final xopd = report.sections.singleWhere(
      (section) => section.title.startsWith('X-OPD'),
    );

    expect(portable.dateAnomalies, isEmpty);
    expect(portable.dateColumns, hasLength(30));
    expect(xopd.dateAnomalies.map((item) => item.code), contains('duplicate_day'));
    expect(xopd.dateAnomalies.map((item) => item.code), contains('missing_dates'));
    expect(
      xopd.dateAnomalies.singleWhere((item) => item.code == 'missing_dates').message,
      contains('17/11/2026'),
    );
    expect(
      xopd.dateAnomalies.singleWhere((item) => item.code == 'missing_dates').message,
      contains('29/11/2026'),
    );
    expect(xopd.dateAnomalies, isNotEmpty);

    final shifts = const MonthlyRosterShiftAdapter().parseForWorkers(
      report,
      targetNames: ['นาย ก', 'นาย ข'],
    );
    expect(shifts, hasLength(30));
    expect(shifts.every((shift) => shift.assignedName == 'นาย ก'), isTrue);
  });

  test('generates independent section dates before populating worker names', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'พฤศจิกายน 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวรหลัก 16 พฤศจิกายน 2569 - 15 ธันวาคม 2569']),
        ..._row(1, ['วันที่', 16, 17, 18, 19, 20, 21, 22]),
        ..._row(2, ['เวรเช้า', 'นาย ก', null, null, null, null, null, null]),
        ..._row(4, ['MRI ประจำเดือน พฤศจิกายน พ.ศ. 2569']),
        ..._row(5, ['วันที่', 1, 2, 3, 4, 5, 6, 7]),
        ..._row(6, ['MRI', 'นาย ข', null, null, null, null, null, null]),
      ],
    );
    const parser = MonthlyRosterSectionParser();

    final dateStructure = parser.generateDateStructure(input);

    expect(dateStructure.sections, hasLength(2));
    expect(dateStructure.assignments, isEmpty);
    expect(dateStructure.sections[0].dateColumns.first.date,
        DateTime(2026, 11, 16));
    expect(dateStructure.sections[1].dateColumns.first.date,
        DateTime(2026, 11, 1));
    expect(dateStructure.sections[0].rosterRows.single.label, 'เวรเช้า');
    expect(dateStructure.sections[1].rosterRows.single.label, 'MRI');

    final populated = parser.populateAssignments(input, dateStructure);

    expect(populated.assignments, hasLength(2));
    expect(populated.assignments[0].workerName, 'นาย ก');
    expect(populated.assignments[0].date, DateTime(2026, 11, 16));
    expect(populated.assignments[1].workerName, 'นาย ข');
    expect(populated.assignments[1].date, DateTime(2026, 11, 1));
  });

  test('resolves every column across a declared month boundary', () {
    final days = <Object?>[
      'วันที่',
      ...List<int>.generate(15, (index) => index + 16),
      ...List<int>.generate(15, (index) => index + 1),
    ];
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'พฤศจิกายน 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวรหลัก 16 พฤศจิกายน 2569 - 15 ธันวาคม 2569']),
        ..._row(1, days),
        ..._row(2, ['เวรเช้า', 'นาย ก']),
      ],
    );

    final structure = const MonthlyRosterSectionParser()
        .generateDateStructure(input);

    expect(structure.sections.single.dateColumns, hasLength(30));
    expect(structure.sections.single.dateColumns.first.date,
        DateTime(2026, 11, 16));
    expect(structure.sections.single.dateColumns[14].date,
        DateTime(2026, 11, 30));
    expect(structure.sections.single.dateColumns[15].date,
        DateTime(2026, 12, 1));
    expect(structure.sections.single.dateColumns.last.date,
        DateTime(2026, 12, 15));
  });

  test('resolves Excel DateTime header cells to their exact cross-month dates', () {
    final dates = <DateTime>[
      for (var day = 16; day <= 30; day++) DateTime(2026, 11, day),
      for (var day = 1; day <= 15; day++) DateTime(2026, 12, day),
    ];
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'พฤศจิกายน 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวร 16 พฤศจิกายน 2569 - 15 ธันวาคม 2569']),
        ..._row(1, ['วันที่', ...dates]),
        ..._row(2, ['ER', ...List<String>.filled(30, 'นาย ก')]),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);
    final section = report.sections.single;

    expect(section.dateColumns, hasLength(30));
    expect(section.dateColumns.first.date, DateTime(2026, 11, 16));
    expect(section.dateColumns[14].date, DateTime(2026, 11, 30));
    expect(section.dateColumns[15].date, DateTime(2026, 12, 1));
    expect(section.dateColumns.last.date, DateTime(2026, 12, 15));
    expect(section.dateAnomalies, isEmpty);
  });

  test('blocks Excel DateTime header cells outside the declared date range', () {
    final dates = <DateTime>[
      for (var day = 16; day <= 30; day++) DateTime(2026, 11, day),
      for (var day = 1; day <= 15; day++) DateTime(2026, 12, day),
    ]..[15] = DateTime(2025, 12, 1);
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'พฤศจิกายน 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวร 16 พฤศจิกายน 2569 - 15 ธันวาคม 2569']),
        ..._row(1, ['วันที่', ...dates]),
        ..._row(2, ['ER', ...List<String>.filled(30, 'นาย ก')]),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);
    final section = report.sections.single;

    expect(section.dateAnomalies.map((item) => item.code), contains('missing_dates'));
    expect(section.hasBlockingDateAnomalies, isTrue);
  });

  test('uses a single-month tab title for multiple ordered split sections', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'พฤศจิกายน 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวรหลัก']),
        ..._row(1, ['วันที่', ...List<int>.generate(15, (i) => i + 1)]),
        ..._row(2, ['เวรเช้า', 'นาย ก']),
        ..._row(4, ['เวรเสริม']),
        ..._row(5, ['วันที่', ...List<int>.generate(15, (i) => i + 16)]),
        ..._row(6, ['เวรบ่าย', 'นาย ข']),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.warnings, isEmpty);
    expect(report.sections, hasLength(2));
    expect(report.assignments, hasLength(2));
    expect(report.assignments.map((item) => item.date), [
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 16),
    ]);
    expect(report.assignments.map((item) => item.workerName), ['นาย ก', 'นาย ข']);
  });

  test('does not infer a single-month tab for a split section that wraps months', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'พฤศจิกายน 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวรหลัก']),
        ..._row(1, [
          'วันที่',
          ...List<int>.generate(15, (i) => i + 16),
          ...List<int>.generate(15, (i) => i + 1),
        ]),
        ..._row(2, ['เวรเช้า', 'นาย ก']),
        ..._row(4, ['เวรเสริม']),
        ..._row(5, ['วันที่', ...List<int>.generate(15, (i) => i + 16)]),
        ..._row(6, ['เวรบ่าย', 'นาย ข']),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.sections, hasLength(1));
    expect(report.sections.single.title, 'เวรเสริม');
    expect(report.assignments.single.workerName, 'นาย ข');
    expect(report.assignments.single.date, DateTime(2026, 11, 16));
    expect(report.warnings, hasLength(1));
    expect(report.warnings.single, contains('ไม่ใช้เดือนจากชื่อชีตแทน'));
  });

  test('does not borrow the tab month for an undated section in a multi-section sheet', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'พฤศจิกายน 2569',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['เวรหลัก']),
        ..._row(1, ['วันที่', 1, 2, 3, 4, 5, 6, 7]),
        ..._row(2, ['เวรเช้า', 'นาย ก', null, null, null, null, null, null]),
        ..._row(4, ['MRI ประจำเดือน พฤศจิกายน พ.ศ. 2569']),
        ..._row(5, ['วันที่', 1, 2, 3, 4, 5, 6, 7]),
        ..._row(6, ['MRI', 'นาย ข', null, null, null, null, null, null]),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(report.sections, hasLength(1));
    expect(report.sections.single.title, contains('MRI'));
    expect(report.assignments.single.workerName, 'นาย ข');
    expect(report.warnings, hasLength(1));
    expect(report.warnings.single, contains('ไม่ใช้เดือนจากชื่อชีตแทน'));
  });

  test('filters assignments by query, section, and selected month', () {
    final report = MonthlyRosterParseReport(
      sections: [
        MonthlyRosterSection(
          title: 'เวรใหญ่',
          headerRowIndex: 0,
          assignments: [
            MonthlyRosterAssignment(
              sectionTitle: 'เวรใหญ่',
              rowLabel: 'ER',
              rowIndex: 1,
              workerName: 'สมชาย',
              date: DateTime(2026, 7, 1),
              sourceCell: 'B2',
            ),
            MonthlyRosterAssignment(
              sectionTitle: 'เวรใหญ่',
              rowLabel: 'CT',
              rowIndex: 2,
              workerName: 'สมหญิง',
              date: DateTime(2026, 8, 1),
              sourceCell: 'B3',
            ),
          ],
        ),
      ],
      warnings: const [],
    );

    final filtered = report.filtered(
      query: 'สมชาย',
      sectionTitle: 'เวรใหญ่',
      includesDate: (date) => date.month == 7,
    );

    expect(filtered.sections, hasLength(1));
    expect(filtered.assignments, hasLength(1));
    expect(filtered.assignments.single.workerName, 'สมชาย');
    expect(filtered.assignments.single.date.month, 7);
  });

  test('creates a source-neutral monthly report from imported shifts', () {
    final report = MonthlyRosterParseReport.fromShifts([
      Shift(
        code: 'CUSTOM',
        rowLabel: 'รายการ A',
        assignedName: '',
        start: DateTime(2026, 9, 4, 8),
        end: DateTime(2026, 9, 4, 16),
        sheetTitle: 'ไฟล์ที่นำเข้า',
        cell: 'B2',
        category: ShiftCategory.own,
      ),
    ]);

    expect(report.sections.single.title, 'ไฟล์ที่นำเข้า');
    expect(report.assignments.single.rowLabel, 'รายการ A');
    expect(report.assignments.single.workerName, isEmpty);
    expect(report.assignments.single.date, DateTime(2026, 9, 4));
    expect(report.dateRanges.single.start, DateTime(2026, 9, 4));
    expect(report.dateRanges.single.end, DateTime(2026, 9, 4));
  });

  test('appends a confirmed camera entry to the monthly report', () {
    const empty = MonthlyRosterParseReport(sections: [], warnings: []);
    final report = empty.appendShift(
      Shift(
        code: 'MANUAL',
        rowLabel: 'รายการจากกล้อง',
        assignedName: '',
        start: DateTime(2026, 9, 5, 9),
        end: DateTime(2026, 9, 5, 12),
        sheetTitle: 'ต้นฉบับ: กล้อง',
        cell: 'ผู้ใช้กำหนด',
        category: ShiftCategory.own,
      ),
    );

    expect(report.sections.single.title, 'ต้นฉบับ: กล้อง');
    expect(report.assignments.single.rowLabel, 'รายการจากกล้อง');
  });
  test('preserves unlabeled GEN afternoon continuation rows', () {
    final input = ShiftParserInput(
      spreadsheetId: 'spreadsheet',
      spreadsheetTitle: 'Roster',
      sheetId: 1,
      sheetTitle: 'คลินิกพิเศษ',
      timeZone: 'Asia/Bangkok',
      cells: [
        ..._row(0, ['GEN คลินิกพิเศษ ประจำเดือน พฤศจิกายน พ.ศ. 2569']),
        ..._row(1, ['วันที่', 1, 2, 3, 4, 5, 6, 7]),
        ..._row(2, ['GEN', 'บุคลากรเช้า']),
        ..._row(3, [null, 'บุคลากรบ่าย']),
      ],
    );

    final report = const MonthlyRosterSectionParser().parse(input);

    expect(
      report.sections.single.rosterRows.map((row) => row.label),
      ['GEN', 'GEN บ่าย'],
    );
    expect(report.assignments, hasLength(2));
    expect(report.assignments.last.workerName, 'บุคลากรบ่าย');

    final shifts = const MonthlyRosterShiftAdapter().parseForWorkers(
      report,
      targetNames: ['บุคลากรบ่าย'],
    );
    expect(shifts, hasLength(1));
    expect(shifts.single.code, 'AG');
    expect(shifts.single.start, DateTime(2026, 11, 1, 16, 30));
    expect(shifts.single.end, DateTime(2026, 11, 1, 20));
  });

  test('converts monthly roster assignments to calendar shifts for the selected worker', () {
    final labels = <String>[
      'P1 เช้า',
      'P2 ดึก',
      'GEN',
      'ER',
      'CT',
      '14ชั้น',
      'CTIPD บ่าย',
    ];
    final assignments = [
      for (var index = 0; index < labels.length; index++)
        MonthlyRosterAssignment(
          sectionTitle: 'ตารางเวรเดือนสิงหาคม 2569',
          rowLabel: labels[index],
          rowIndex: index + 3,
          workerName: 'นายสมชาย ใจดี',
          date: DateTime(2026, 8, index + 1),
          sourceCell: 'B${index + 4}',
        ),
      MonthlyRosterAssignment(
        sectionTitle: 'ตารางเวรเดือนสิงหาคม 2569',
        rowLabel: 'P3 เช้า',
        rowIndex: 20,
        workerName: 'นางสมหญิง',
        date: DateTime(2026, 8, 20),
        sourceCell: 'U21',
      ),
    ];
    final report = MonthlyRosterParseReport(
      sections: [
        MonthlyRosterSection(
          title: 'ตารางเวรเดือนสิงหาคม 2569',
          headerRowIndex: 1,
          assignments: assignments,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
        ),
      ],
      warnings: const [],
    );

    final shifts = const MonthlyRosterShiftAdapter().parseForWorkers(
      report,
      targetNames: ['สมชาย', 'ใจดี'],
    );

    expect(shifts, hasLength(7));
    expect(shifts.map((shift) => shift.code), [
      'UP1',
      'NP2',
      'UG',
      'UER',
      'UCT',
      'U14',
      'ACTIPD',
    ]);
    expect(shifts.first.start, DateTime(2026, 8, 1, 8));
    expect(shifts[1].start, DateTime(2026, 8, 2));
    expect(shifts[1].end, DateTime(2026, 8, 2, 8));
    expect(shifts.last.start, DateTime(2026, 8, 7, 16));
    expect(shifts.last.end, DateTime(2026, 8, 8, 8));
    expect(shifts.every((shift) => shift.assignedName == 'นายสมชาย ใจดี'), isTrue);
    expect(shifts.map((shift) => shift.cell), [
      'B4', 'B5', 'B6', 'B7', 'B8', 'B9', 'B10',
    ]);
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
          rawValue: values[columnIndex],
        ),
  ];



}
