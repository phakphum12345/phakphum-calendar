String buildEmptyRosterSyncDiagnostic({
  required String selectedPeriodsLabel,
  required int parsedShiftCount,
  required int filteredShiftCount,
  required int monthlyAssignmentCount,
  required int unconvertedAssignmentCount,
  required List<String> warnings,
}) {
  final summary = StringBuffer()
    ..write('ยังไม่มีเวรที่พร้อมซิงค์สำหรับเดือนที่เลือก ($selectedPeriodsLabel) ')
    ..write('อ่านเวรต้นทางได้ $parsedShiftCount รายการ; ')
    ..write('หลังกรองเดือน/ช่วงวันที่เหลือ $filteredShiftCount รายการ; ')
    ..write('อ่านช่องตารางรายเดือนได้ $monthlyAssignmentCount ช่อง; ')
    ..write('ยังแปลงเป็นเวรไม่ได้ $unconvertedAssignmentCount ช่อง.');

  if (warnings.isNotEmpty) {
    summary.write(' ข้อควรตรวจสอบ: ');
    summary.write(warnings.take(3).join('；'));
  } else {
    summary.write(' กรุณาตรวจสอบปี/เดือนที่เลือกและอ่านตารางเวรใหม่');
  }

  summary.write(' ระบบจะไม่สร้าง Preview หรือเขียน Google Calendar จากตารางว่าง');
  return summary.toString();
}
