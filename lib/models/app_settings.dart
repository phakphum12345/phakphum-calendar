import 'roster_period.dart';

class AppSettings {
  const AppSettings({
    required this.targetName,
    required this.year,
    required this.month,
    this.periods = const [],
    required this.archiveOriginal,
    required this.autoRefresh,
    required this.refreshSeconds,
    required this.autoSync,
    required this.googleWebClientId,
    this.organizationName = '', this.officerName = '', this.defaultShiftName = '',
    this.defaultShiftColor = '#616161', this.defaultShiftStart = '08:00', this.defaultShiftEnd = '16:00',
    this.defaultShiftReceiver = '', this.shiftExchangeNote = '', this.shiftCancellationNote = '', this.setupComplete = false,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      targetName: '',
      year: null,
      month: null,
      periods: [],
      archiveOriginal: true,
      autoRefresh: false,
      refreshSeconds: 5,
      autoSync: false,
      googleWebClientId: '',
    );
  }

  final String targetName;
  final int? year;
  final int? month;
  final List<RosterPeriod> periods;
  final bool archiveOriginal;
  final bool autoRefresh;
  final int refreshSeconds;
  final bool autoSync;
  final String googleWebClientId;
  final String organizationName, officerName, defaultShiftName, defaultShiftColor, defaultShiftStart, defaultShiftEnd, defaultShiftReceiver, shiftExchangeNote, shiftCancellationNote;
  final bool setupComplete;

  List<RosterPeriod> get effectivePeriods {
    if (periods.isNotEmpty) {
      final unique = periods.toSet().toList()
        ..sort((left, right) => left.key.compareTo(right.key));
      return List.unmodifiable(unique);
    }
    if (year == null || month == null) return const [];
    return [RosterPeriod(year: year!, month: month!)];
  }

  bool includesPeriod(int year, int month) =>
      effectivePeriods.contains(RosterPeriod(year: year, month: month));

  AppSettings copyWith({
    String? targetName,
    int? year,
    int? month,
    List<RosterPeriod>? periods,
    bool? archiveOriginal,
    bool? autoRefresh,
    int? refreshSeconds,
    bool? autoSync,
    String? googleWebClientId,
    String? organizationName, String? officerName, String? defaultShiftName, String? defaultShiftColor,
    String? defaultShiftStart, String? defaultShiftEnd, String? defaultShiftReceiver,
    String? shiftExchangeNote, String? shiftCancellationNote, bool? setupComplete,
  }) => AppSettings(
    targetName: targetName ?? this.targetName,
    year: year ?? this.year,
    month: month ?? this.month,
    periods: periods ?? this.periods,
    archiveOriginal: archiveOriginal ?? this.archiveOriginal,
    autoRefresh: autoRefresh ?? this.autoRefresh,
    refreshSeconds: refreshSeconds ?? this.refreshSeconds,
    autoSync: autoSync ?? this.autoSync,
    googleWebClientId: googleWebClientId ?? this.googleWebClientId,
    organizationName: organizationName ?? this.organizationName, officerName: officerName ?? this.officerName,
    defaultShiftName: defaultShiftName ?? this.defaultShiftName, defaultShiftColor: defaultShiftColor ?? this.defaultShiftColor,
    defaultShiftStart: defaultShiftStart ?? this.defaultShiftStart, defaultShiftEnd: defaultShiftEnd ?? this.defaultShiftEnd,
    defaultShiftReceiver: defaultShiftReceiver ?? this.defaultShiftReceiver, shiftExchangeNote: shiftExchangeNote ?? this.shiftExchangeNote,
    shiftCancellationNote: shiftCancellationNote ?? this.shiftCancellationNote, setupComplete: setupComplete ?? this.setupComplete,
  );

  AppSettings clearRosterSelection() => AppSettings(
    targetName: '',
    year: null,
    month: null,
    periods: const [],
    archiveOriginal: archiveOriginal,
    autoRefresh: autoRefresh,
    refreshSeconds: refreshSeconds,
    autoSync: autoSync,
    googleWebClientId: googleWebClientId,
    organizationName: organizationName, officerName: officerName, defaultShiftName: defaultShiftName,
    defaultShiftColor: defaultShiftColor, defaultShiftStart: defaultShiftStart, defaultShiftEnd: defaultShiftEnd,
    defaultShiftReceiver: defaultShiftReceiver, shiftExchangeNote: shiftExchangeNote,
    shiftCancellationNote: shiftCancellationNote, setupComplete: setupComplete,
  );
}
