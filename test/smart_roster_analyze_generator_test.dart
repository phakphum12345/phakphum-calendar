import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/smart_roster_analyze_generator.dart';
import 'package:phakphum_calendar/models/shift.dart';

void main() {
  const analyzer = SmartRosterAnalyzeGenerator();

  Shift shift({
    required String code,
    required String label,
    required String cell,
    DateTime? start,
    String worker = 'ภาคภูมิ',
  }) => Shift(
    code: code,
    rowLabel: label,
    assignedName: worker,
    start: start ?? DateTime(2026, 8, 1, 8),
    end: (start ?? DateTime(2026, 8, 1, 8)).add(const Duration(hours: 8)),
    sheetTitle: 'สิงหาคม 2569',
    cell: cell,
    category: ShiftCategory.own,
  );

  test('generates only monthly records absent from the legacy source keys', () {
    final legacy = shift(code: 'UP1', label: 'P1 เช้า', cell: 'B2');
    final monthlyDuplicate =
        shift(code: 'UP1', label: 'P1 เช้า', cell: 'B2');
    final recovered = shift(
      code: 'NP2',
      label: 'P2 ดึก',
      cell: 'C3',
      start: DateTime(2026, 8, 2),
    );

    final result = analyzer.analyze(
      legacyShifts: [legacy],
      monthlyShifts: [monthlyDuplicate, recovered],
    );

    expect(result.mergedShifts, hasLength(2));
    expect(result.recoveredShifts, [recovered]);
    expect(result.recoveredCount, 1);
    expect(result.possibleDuplicates, isEmpty);
  });

  test('flags same-day same-worker candidates with a different source key', () {
    final legacy = shift(code: 'UP1', label: 'P1 เช้า', cell: 'B2');
    final candidate = shift(
      code: 'CUSTOM',
      label: 'เวรที่อ่านเพิ่ม',
      cell: 'C2',
    );

    final result = analyzer.analyze(
      legacyShifts: [legacy],
      monthlyShifts: [candidate],
    );

    expect(result.recoveredShifts, [candidate]);
    expect(result.possibleDuplicates, hasLength(1));
    expect(result.mergedShifts, hasLength(2));
  });

  test('does not mutate the input iterables or auto-sync candidates', () {
    final candidate = shift(code: 'UP2', label: 'P2 เช้า', cell: 'D4');
    final result = analyzer.analyze(
      legacyShifts: const [],
      monthlyShifts: [candidate],
    );

    expect(result.recoveredShifts.single, same(candidate));
    expect(result.mergedShifts.single, same(candidate));
  });
}
