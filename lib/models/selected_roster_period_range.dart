import 'roster_period.dart';

/// The selected roster months are authoritative for the default sync window.
/// A source sheet's section can span adjacent months and must not override the
/// month explicitly selected by the user.
class SelectedRosterPeriodRange {
  SelectedRosterPeriodRange._(List<RosterPeriod> periods)
    : periods = List<RosterPeriod>.unmodifiable(periods),
      start = DateTime(periods.first.year, periods.first.month),
      end = DateTime(periods.last.year, periods.last.month + 1, 0);

  final List<RosterPeriod> periods;
  final DateTime start;
  final DateTime end;

  static SelectedRosterPeriodRange? fromPeriods(
    Iterable<RosterPeriod> source,
  ) {
    final periods = source.toSet().toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    if (periods.isEmpty) return null;
    return SelectedRosterPeriodRange._(periods);
  }

  bool includes(DateTime date) =>
      periods.contains(RosterPeriod(year: date.year, month: date.month));
}
