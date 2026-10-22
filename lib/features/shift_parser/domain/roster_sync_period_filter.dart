import '../../../models/roster_period.dart';

/// Applies the user's selected calendar months independently from the source
/// roster's section boundaries and any previously customized sync range.
class RosterSyncPeriodFilter {
  const RosterSyncPeriodFilter._();

  /// Returns the inclusive calendar-month range covering [periods].
  ///
  /// The caller must still use [includes] to exclude gaps when the selection
  /// contains non-consecutive months.
  static ({DateTime start, DateTime end})? rangeFor(
    Iterable<RosterPeriod> periods,
  ) {
    final sorted = periods.toSet().toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    if (sorted.isEmpty) return null;

    final first = sorted.first;
    final last = sorted.last;
    return (
      start: DateTime(first.year, first.month, 1),
      end: DateTime(last.year, last.month + 1, 0),
    );
  }

  /// Returns true only for a selected month, unless no month filter exists.
  static bool includes(
    DateTime date,
    Iterable<RosterPeriod> selectedPeriods,
  ) {
    final selected = selectedPeriods.toSet();
    return selected.isEmpty ||
        selected.contains(RosterPeriod(year: date.year, month: date.month));
  }
}
