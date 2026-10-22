import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/models/roster_period.dart';
import 'package:phakphum_calendar/models/selected_roster_period_range.dart';

void main() {
  test('uses the selected month rather than a cross-month sheet section', () {
    final range = SelectedRosterPeriodRange.fromPeriods([
      const RosterPeriod(year: 2026, month: 9),
    ]);

    expect(range, isNotNull);
    expect(range!.start, DateTime(2026, 9, 1));
    expect(range.end, DateTime(2026, 9, 30));
    expect(range.includes(DateTime(2026, 9, 15)), isTrue);
    expect(range.includes(DateTime(2026, 8, 31)), isFalse);
  });

  test('keeps non-contiguous selected months separate for filtering', () {
    final range = SelectedRosterPeriodRange.fromPeriods([
      const RosterPeriod(year: 2026, month: 11),
      const RosterPeriod(year: 2026, month: 9),
      const RosterPeriod(year: 2026, month: 9),
    ]);

    expect(range, isNotNull);
    expect(range!.start, DateTime(2026, 9, 1));
    expect(range.end, DateTime(2026, 11, 30));
    expect(range.includes(DateTime(2026, 9, 1)), isTrue);
    expect(range.includes(DateTime(2026, 10, 15)), isFalse);
    expect(range.includes(DateTime(2026, 11, 30)), isTrue);
  });

  test('handles year boundaries and leap February', () {
    final yearBoundary = SelectedRosterPeriodRange.fromPeriods([
      const RosterPeriod(year: 2027, month: 1),
      const RosterPeriod(year: 2026, month: 12),
    ]);
    final leapFebruary = SelectedRosterPeriodRange.fromPeriods([
      const RosterPeriod(year: 2028, month: 2),
    ]);

    expect(yearBoundary!.start, DateTime(2026, 12, 1));
    expect(yearBoundary.end, DateTime(2027, 1, 31));
    expect(leapFebruary!.end, DateTime(2028, 2, 29));
  });
}
