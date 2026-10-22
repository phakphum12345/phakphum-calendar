import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/roster_sync_period_filter.dart';
import 'package:phakphum_calendar/models/roster_period.dart';

void main() {
  group('RosterSyncPeriodFilter', () {
    test('uses exact calendar month boundaries for one selected month', () {
      final range = RosterSyncPeriodFilter.rangeFor([
        const RosterPeriod(year: 2026, month: 9),
      ]);

      expect(range, isNotNull);
      expect(range!.start, DateTime(2026, 9, 1));
      expect(range.end, DateTime(2026, 9, 30));
    });

    test('covers multiple selected months across years', () {
      final range = RosterSyncPeriodFilter.rangeFor([
        const RosterPeriod(year: 2027, month: 1),
        const RosterPeriod(year: 2026, month: 12),
      ]);

      expect(range!.start, DateTime(2026, 12, 1));
      expect(range.end, DateTime(2027, 1, 31));
    });

    test('excludes months between non-consecutive selections', () {
      const selected = [
        RosterPeriod(year: 2026, month: 7),
        RosterPeriod(year: 2026, month: 9),
      ];

      expect(
        RosterSyncPeriodFilter.includes(DateTime(2026, 7, 31), selected),
        isTrue,
      );
      expect(
        RosterSyncPeriodFilter.includes(DateTime(2026, 8, 15), selected),
        isFalse,
      );
      expect(
        RosterSyncPeriodFilter.includes(DateTime(2026, 9, 1), selected),
        isTrue,
      );
    });

    test('re-filters the same complete roster when the selected month changes', () {
      final completeRoster = [
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 15),
        DateTime(2026, 9, 1),
      ];

      final august = completeRoster
          .where((date) => RosterSyncPeriodFilter.includes(date, const [
                RosterPeriod(year: 2026, month: 8),
              ]))
          .toList();
      final september = completeRoster
          .where((date) => RosterSyncPeriodFilter.includes(date, const [
                RosterPeriod(year: 2026, month: 9),
              ]))
          .toList();

      expect(august, [DateTime(2026, 8, 1), DateTime(2026, 8, 15)]);
      expect(september, [DateTime(2026, 9, 1)]);
      // Filtering a view must not mutate/truncate the original roster.
      expect(completeRoster, hasLength(3));
    });

    test('does not filter when no month is selected', () {
      expect(
        RosterSyncPeriodFilter.includes(DateTime(2026, 8, 15), const []),
        isTrue,
      );
      expect(RosterSyncPeriodFilter.rangeFor(const []), isNull);
    });
  });
}
