import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/services/shift_time_service.dart';

void main() {
  test('parses known codes M/E/N/OC', () {
    expect(ShiftTimeService.parseDurations('M'), [Duration(hours: 8), Duration(hours: 16)]);
    expect(ShiftTimeService.parseDurations('E'), [Duration(hours: 16), Duration(hours: 24)]);
    expect(ShiftTimeService.parseDurations('N'), [Duration.zero, Duration(hours: 8)]);
    expect(ShiftTimeService.parseDurations('OC'), [Duration(hours: 17), Duration(hours: 8)]);
  });

  test('parses explicit time ranges', () {
    final parsed = ShiftTimeService.parseDurations('16:00-08:00');
    expect(parsed, isNotNull);
    expect(parsed![0], Duration(hours: 16));
    expect(parsed[1], Duration(hours: 8));
  });

  test('parses thai labels', () {
    expect(ShiftTimeService.parseDurations('เวรเช้า'), [Duration(hours: 8), Duration(hours: 16)]);
    expect(ShiftTimeService.parseDurations('เวรบ่าย'), [Duration(hours: 16), Duration(hours: 24)]);
    expect(ShiftTimeService.parseDurations('เวรดึก'), [Duration.zero, Duration(hours: 8)]);
  });
}
