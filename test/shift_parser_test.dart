import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/models/shift.dart';
import 'package:phakphum_calendar/services/shift_parser.dart';

void main() {
  const parser = ShiftParser();

  test('reads every worker when comparing an attached original roster', () {
    final days = <Object?>['วันที่', ...List.generate(31, (i) => i + 1)];
    final row = _row('P1 เช้า');
    row[1] = 'สมชาย';
    row[2] = 'ภาคภูมิ';

    final shifts = parser.parseAllWorkersAllPeriods(
      snapshots: [
        SheetSnapshot(
          title: 'สิงหาคม 2569',
          rows: [
            ['ประจำเดือน สิงหาคม 2569'],
            days,
            row,
          ],
        ),
      ],
    );

    expect(shifts.map((shift) => shift.assignedName), ['สมชาย', 'ภาคภูมิ']);
  });

  test('maps rollover dates and overnight shift times', () {
    final days = <Object?>[
      'เวร',
      ...List.generate(16, (i) => i + 16),
      ...List.generate(15, (i) => i + 1),
    ];
    final p1 = _row('P1 เช้า');
    final p2 = _row('P2 บ่าย');
    final ipd = _row('IPD บ่าย');
    p1[17] = 'ผู้ใช้งานทดสอบ';
    p2[18] = 'ผู้ใช้งานทดสอบ';
    ipd[19] = 'ผู้ใช้งานทดสอบ';

    final shifts = parser.parse(
      snapshots: [
        SheetSnapshot(
          title: '16 กค - 15 สค',
          rows: [
            ['ประจำเดือน 16 กรกฎาคม พ.ศ. 2569 - 15 สิงหาคม พ.ศ. 2569'],
            days,
            p1,
            p2,
            ipd,
          ],
        ),
      ],
      targetName: 'ผู้ใช้งานทดสอบ',
      year: 2026,
      month: 8,
    );

    expect(shifts.map((shift) => shift.code), ['UP1', 'AP2', 'AIPD']);
    expect(shifts[0].start, DateTime(2026, 8, 1, 8));
    expect(shifts[1].end, DateTime(2026, 8, 3));
    expect(shifts[2].end, DateTime(2026, 8, 4, 8));
  });

  test('keeps every requested duty time standard', () {
    final days = <Object?>['วันที่', ...List.generate(31, (i) => i + 1)];
    final labels = <String>[
      'P4 เช้า',
      'P3 บ่าย',
      'P2 ดึก',
      'IPD เช้า',
      'IPD บ่าย',
      'CT IPD เช้า',
      'CT IPD บ่าย',
      'CT ER เช้า',
      'CT ER บ่าย',
      'ER เช้า',
      'ER บ่าย',
      'ER ดึก',
      'GEN',
      '',
      'CT 14 ชั้น',
    ];
    final rows = <List<Object?>>[];
    for (var index = 0; index < labels.length; index++) {
      final row = _row(labels[index]);
      row[index + 1] = 'ผู้ใช้งานทดสอบ';
      rows.add(row);
    }

    final shifts = parser.parse(
      snapshots: [
        SheetSnapshot(title: 'กรกฎาคม 2569', rows: [days, ...rows]),
      ],
      targetName: 'ผู้ใช้งานทดสอบ',
      year: 2026,
      month: 7,
    );
    final byCode = {for (final shift in shifts) shift.code: shift};

    expect(byCode['UP4']?.start, DateTime(2026, 7, 1, 8));
    expect(byCode['UP4']?.end, DateTime(2026, 7, 1, 16));
    expect(byCode['AP3']?.start, DateTime(2026, 7, 2, 16));
    expect(byCode['AP3']?.end, DateTime(2026, 7, 3));
    expect(byCode['NP2']?.start, DateTime(2026, 7, 3));
    expect(byCode['NP2']?.end, DateTime(2026, 7, 3, 8));
    expect(byCode['UIPD']?.start, DateTime(2026, 7, 4, 8));
    expect(byCode['UIPD']?.end, DateTime(2026, 7, 4, 16));
    expect(byCode['AIPD']?.end, DateTime(2026, 7, 6, 8));
    expect(byCode['UCTIPD']?.start, DateTime(2026, 7, 6, 8));
    expect(byCode['ACTIPD']?.end, DateTime(2026, 7, 8, 8));
    expect(byCode['UCTER']?.start, DateTime(2026, 7, 8, 8));
    expect(byCode['ACTER']?.end, DateTime(2026, 7, 10, 8));
    expect(byCode['UER']?.end, DateTime(2026, 7, 10, 16));
    expect(byCode['AER']?.end, DateTime(2026, 7, 12));
    expect(byCode['NER']?.end, DateTime(2026, 7, 12, 8));
    expect(byCode['UG']?.start, DateTime(2026, 7, 13, 7, 30));
    expect(byCode['UG']?.end, DateTime(2026, 7, 13, 12));
    expect(byCode['AG']?.start, DateTime(2026, 7, 14, 16, 30));
    expect(byCode['AG']?.end, DateTime(2026, 7, 14, 20));
    expect(byCode['U14']?.start, DateTime(2026, 7, 15, 7));
    expect(byCode['U14']?.end, DateTime(2026, 7, 15, 8));
  });

  test('maps GEN morning, GEN afternoon, and 14 floor', () {
    final days = <Object?>['วันที่', ...List.generate(31, (i) => i + 1)];
    final genMorning = _row('GEN');
    final genAfternoon = _row('');
    final floor14 = _row('CT 14 ชั้น');
    genMorning[4] = 'ผู้ใช้งานทดสอบ';
    genAfternoon[5] = 'ผู้ใช้งานทดสอบ';
    floor14[6] = 'ผู้ใช้งานทดสอบ';

    final shifts = parser.parse(
      snapshots: [
        SheetSnapshot(
          title: 'สิงหาคม 2569',
          rows: [
            ['GEN คลินิกพิเศษ (1 สิงหาคม 2569 - 31 สิงหาคม 2569)'],
            days,
            genMorning,
            genAfternoon,
            floor14,
          ],
        ),
      ],
      targetName: 'ผู้ใช้งานทดสอบ',
      year: 2026,
      month: 8,
    );

    expect(shifts.map((shift) => shift.code), ['UG', 'AG', 'U14']);
    expect(shifts[0].category, ShiftCategory.clinic);
    expect(shifts[0].start, DateTime(2026, 8, 4, 7, 30));
    expect(shifts[1].start, DateTime(2026, 8, 5, 16, 30));
    expect(shifts[2].end, DateTime(2026, 8, 6, 8));
  });

  test('maps bare ER and CT rows in the daytime-duty section', () {
    final days = <Object?>[
      'วันที่',
      ...List.generate(16, (i) => i + 16),
      ...List.generate(15, (i) => i + 1),
    ];
    final er = _row('ER');
    final ct = _row('CT');
    er[8] = 'ผู้ใช้งานทดสอบ';
    ct[9] = 'ผู้ใช้งานทดสอบ';

    final shifts = parser.parse(
      snapshots: [
        SheetSnapshot(
          title: '16 กรกฎาคม 2569 - 15 สิงหาคม 2569',
          rows: [
            days,
            ['เวรกลางวัน'],
            er,
            ct,
          ],
        ),
      ],
      targetName: 'ผู้ใช้งานทดสอบ',
      year: 2026,
      month: 7,
    );

    expect(shifts.map((shift) => shift.code), ['UER', 'UCT']);
    expect(shifts[0].start, DateTime(2026, 7, 23, 8));
    expect(shifts[0].end, DateTime(2026, 7, 23, 16));
    expect(shifts[1].start, DateTime(2026, 7, 24, 8));
    expect(shifts[1].end, DateTime(2026, 7, 24, 16));
  });

  test('uses background colors read from the original sheet', () {
    final shifts = parser.parse(
      snapshots: [
        SheetSnapshot(
          title: 'กรกฎาคม 2569',
          rows: [
            ['วันที่', 1, 2, 3, 4, 5, 6, 7],
            ['P1 เช้า', 'ผู้ใช้งานทดสอบ'],
          ],
          backgroundColors: [
            const [],
            [null, 0xFFD50000],
          ],
        ),
      ],
      targetName: 'ผู้ใช้งานทดสอบ',
      year: 2026,
      month: 7,
    );

    expect(shifts, hasLength(1));
    expect(shifts.single.category, ShiftCategory.other);
    expect(shifts.single.sourceColorHex, '#D50000');
  });

  test('reads every dated worksheet without a manually selected month', () {
    final july = _row('P1 เช้า')..[1] = 'ผู้ใช้งานทดสอบ';
    final august = _row('ER ดึก')..[2] = 'ผู้ใช้งานทดสอบ';

    final shifts = parser.parseAllPeriods(
      snapshots: [
        SheetSnapshot(
          title: 'กรกฎาคม 2569',
          rows: [
            ['วันที่', ...List.generate(31, (index) => index + 1)],
            july,
          ],
        ),
        SheetSnapshot(
          title: 'ส.ค. 69',
          rows: [
            ['วันที่', ...List.generate(31, (index) => index + 1)],
            august,
          ],
        ),
        const SheetSnapshot(
          title: 'สรุป',
          rows: [
            ['ไม่มีตารางเวร'],
          ],
        ),
      ],
      targetName: 'ผู้ใช้งานทดสอบ',
    );

    expect(shifts, hasLength(2));
    expect(shifts[0].start, DateTime(2026, 7, 1, 8));
    expect(shifts[1].start, DateTime(2026, 8, 2));
  });

  test('prefers the monthly section heading over a conflicting worksheet title', () {
    final days = <Object?>['วันที่', ...List.generate(30, (i) => i + 1)];
    final gen = _row('GEN');
    final genAfternoon = _row('');
    genAfternoon[26] = 'ภาคภูมิ';

    final shifts = parser.parseAllPeriods(
      snapshots: [
        SheetSnapshot(
          title: 'ธันวาคม 2569',
          rows: [
            ...List.generate(12, (_) => <Object?>['']),
            ['ตารางเวรประจำเดือน พฤศจิกายน พ.ศ. 2569'],
            days,
            gen,
            genAfternoon,
          ],
        ),
      ],
      targetName: 'ภาคภูมิ',
    );

    expect(shifts, hasLength(1));
    expect(shifts.single.code, 'AG');
    expect(shifts.single.start, DateTime(2026, 11, 26, 16, 30));
    expect(shifts.single.end, DateTime(2026, 11, 26, 20));
  });

  test('uses the nearest month heading for each monthly block in one tab', () {
    final novemberDays = <Object?>['วันที่', ...List.generate(30, (i) => i + 1)];
    final decemberDays = <Object?>['วันที่', ...List.generate(31, (i) => i + 1)];
    final novemberGen = _row('GEN');
    final novemberAfternoon = _row('');
    novemberAfternoon[26] = 'ภาคภูมิ';
    final decemberGen = _row('GEN');
    final decemberAfternoon = _row('');
    decemberAfternoon[3] = 'ภาคภูมิ';

    final shifts = parser.parseAllPeriods(
      snapshots: [
        SheetSnapshot(
          title: 'ธันวาคม 2569',
          rows: [
            ['เวรประจำเดือน พฤศจิกายน พ.ศ. 2569'],
            novemberDays,
            novemberGen,
            novemberAfternoon,
            ['เวรประจำเดือน ธันวาคม พ.ศ. 2569'],
            decemberDays,
            decemberGen,
            decemberAfternoon,
          ],
        ),
      ],
      targetName: 'ภาคภูมิ',
    );

    expect(shifts, hasLength(2));
    expect(shifts.map((shift) => shift.start), [
      DateTime(2026, 11, 26, 16, 30),
      DateTime(2026, 12, 3, 16, 30),
    ]);
  });


  test('reads all twelve Thai full month names without a fixed month setting', () {
    const monthNames = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    final snapshots = [
      for (var month = 1; month <= 12; month++)
        () {
          final dayCount = DateTime(2026, month + 1, 0).day;
          final row = _row('P1 เช้า')..[15] = 'ผู้ใช้งานทดสอบ';
          return SheetSnapshot(
            title: 'ข้อมูลเวร',
            rows: [
              ['ตารางเวรเดือน ${monthNames[month - 1]} พ.ศ. 2569'],
              ['วันที่', ...List.generate(dayCount, (index) => index + 1)],
              row,
            ],
          );
        }(),
    ];

    final shifts = parser.parseAllPeriods(
      snapshots: snapshots,
      targetName: 'ผู้ใช้งานทดสอบ',
    );

    expect(shifts, hasLength(12));
    for (var month = 1; month <= 12; month++) {
      expect(
        shifts.any((shift) => shift.start == DateTime(2026, month, 15, 8)),
        isTrue,
        reason: 'Expected parser to detect month $month',
      );
    }
  });

  test('reads all twelve Thai month abbreviations and two-digit Buddhist years', () {
    const monthAbbreviations = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    final snapshots = [
      for (var month = 1; month <= 12; month++)
        () {
          final dayCount = DateTime(2026, month + 1, 0).day;
          final row = _row('P1 เช้า')..[15] = 'ผู้ใช้งานทดสอบ';
          return SheetSnapshot(
            title: 'sheet-$month',
            rows: [
              ['เวรเดือน ${monthAbbreviations[month - 1]} 69'],
              ['วันที่', ...List.generate(dayCount, (index) => index + 1)],
              row,
            ],
          );
        }(),
    ];

    final shifts = parser.parseAllPeriods(
      snapshots: snapshots,
      targetName: 'ผู้ใช้งานทดสอบ',
    );

    expect(shifts, hasLength(12));
    for (var month = 1; month <= 12; month++) {
      expect(
        shifts.any((shift) => shift.start == DateTime(2026, month, 15, 8)),
        isTrue,
        reason: 'Expected parser to detect abbreviation for month $month',
      );
    }
  });

}

List<Object?> _row(String label) => <Object?>[label, ...List.filled(31, '')];
