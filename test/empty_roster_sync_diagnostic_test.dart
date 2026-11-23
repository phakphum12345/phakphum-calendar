import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/ui/empty_roster_sync_diagnostic.dart';

void main() {
  group('buildEmptyRosterSyncDiagnostic', () {
    test('explains selected periods and each parser count when no shifts remain', () {
      final message = buildEmptyRosterSyncDiagnostic(
        selectedPeriodsLabel: '11/2569, 12/2569',
        parsedShiftCount: 42,
        filteredShiftCount: 0,
        monthlyAssignmentCount: 38,
        unconvertedAssignmentCount: 4,
        warnings: const ['ส่วนเวรเสริมไม่มีช่วงวันที่'],
      );

      expect(message, contains('11/2569, 12/2569'));
      expect(message, contains('อ่านเวรต้นทางได้ 42 รายการ'));
      expect(message, contains('หลังกรองเดือน/ช่วงวันที่เหลือ 0 รายการ'));
      expect(message, contains('อ่านช่องตารางรายเดือนได้ 38 ช่อง'));
      expect(message, contains('ยังแปลงเป็นเวรไม่ได้ 4 ช่อง'));
      expect(message, contains('ส่วนเวรเสริมไม่มีช่วงวันที่'));
      expect(message, contains('จะไม่สร้าง Preview หรือเขียน Google Calendar'));
    });

    test('provides a next step when parser warnings are absent', () {
      final message = buildEmptyRosterSyncDiagnostic(
        selectedPeriodsLabel: '11/2569',
        parsedShiftCount: 0,
        filteredShiftCount: 0,
        monthlyAssignmentCount: 0,
        unconvertedAssignmentCount: 0,
        warnings: const [],
      );

      expect(message, contains('ตรวจสอบปี/เดือนที่เลือกและอ่านตารางเวรใหม่'));
    });
  });
}
