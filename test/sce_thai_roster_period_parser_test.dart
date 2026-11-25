import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/thai_roster_period_parser.dart';

void main() {
  const parser = ThaiRosterPeriodParser();

  test('parses full Thai Buddhist year period', () {
    final period = parser.parse(
      'ประจำเดือน 16 กรกฎาคม พ.ศ. 2569 - 15 สิงหาคม พ.ศ. 2569',
    );
    expect(period.start, DateTime(2026, 7, 16));
    expect(period.end, DateTime(2026, 8, 15));
  });

  test('prefers an explicit parenthesized range over a unit number', () {
    final period = parser.parse(
      'GEN คลินิคพิเศษ ภปร. 4 พฤศจิกายน พ.ศ. 2569 '
      '(1 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569)',
    );
    expect(period.start, DateTime(2026, 11, 1));
    expect(period.end, DateTime(2026, 11, 30));
  });

  test('rejects headings containing multiple explicit date ranges', () {
    expect(
      () => parser.parse(
        'GEN ภปร. 4 พฤศจิกายน 2569 '
        '(1 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569) '
        '(1 ธันวาคม 2569 - 31 ธันวาคม 2569)',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('parses abbreviated month and two-digit Buddhist year', () {
    final period = parser.parse('16 กค69-15 สค.69');
    expect(period.start, DateTime(2026, 7, 16));
    expect(period.end, DateTime(2026, 8, 15));
  });

  test('parses dotted abbreviated months with flexible spacing', () {
    final period = parser.parse('16 ก.ค. 2569 – 15 ส.ค. 2569');
    expect(period.start, DateTime(2026, 7, 16));
    expect(period.end, DateTime(2026, 8, 15));
  });

  test('parses compact same-month period', () {
    final period = parser.parse('7-14 มิ.ย. 2569');
    expect(period.start, DateTime(2026, 6, 7));
    expect(period.end, DateTime(2026, 6, 14));
  });

  test('parses bare day range from one month-year context', () {
    final period = parser.parse('เวรวันที่ 2-5 ประจำเดือน มิถุนายน 2569');
    expect(period.start, DateTime(2026, 6, 2));
    expect(period.end, DateTime(2026, 6, 5));
  });

  test('rejects bare day range when month-year context is missing', () {
    expect(() => parser.parse('วันที่ 2-5'), throwsA(isA<FormatException>()));
  });

  test('rejects bare day range when context contains multiple months', () {
    expect(
      () => parser.parse('วันที่ 2-5 ในช่วง 16 สิงหาคม 2569 - 15 กันยายน 2569'),
      throwsA(isA<FormatException>()),
    );
  });

  test('uses one trailing Buddhist year for both dates', () {
    final period = parser.parse('16 ส.ค. - 15 ก.ย. 69');
    expect(period.start, DateTime(2026, 8, 16));
    expect(period.end, DateTime(2026, 9, 15));
  });

  test('uses one leading Buddhist year for both dates', () {
    final period = parser.parse('16 ส.ค. 69 - 15 ก.ย.');
    expect(period.start, DateTime(2026, 8, 16));
    expect(period.end, DateTime(2026, 9, 15));
  });

  test('infers the previous year when trailing year crosses January', () {
    final period = parser.parse('16 ธ.ค. - 15 ม.ค. 70');
    expect(period.start, DateTime(2026, 12, 16));
    expect(period.end, DateTime(2027, 1, 15));
  });

  test('infers the next year when leading year crosses January', () {
    final period = parser.parse('16 ธ.ค. 69 - 15 ม.ค.');
    expect(period.start, DateTime(2026, 12, 16));
    expect(period.end, DateTime(2027, 1, 15));
  });

  test('accepts leap day in a leap year', () {
    final period = parser.parse('16 ก.พ. - 15 มี.ค. 67');
    expect(period.start, DateTime(2024, 2, 16));
    expect(period.end, DateTime(2024, 3, 15));
  });

  test('rejects an impossible leap day in a non-leap year', () {
    expect(
      () => parser.parse('29 ก.พ. 69 - 15 มี.ค. 69'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a year followed by a day as an invalid range', () {
    expect(
      () => parser.parse('2502 - 31 มกราคม 2502'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'throws FormatException when a period contains fewer than two dates',
    () {
      expect(
        () => parser.parse('16 กรกฎาคม 2569'),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('throws FormatException when no year is provided', () {
    expect(
      () => parser.parse('16 ส.ค. - 15 ก.ย.'),
      throwsA(isA<FormatException>()),
    );
  });
}
