import '../features/edition/domain/app_edition.dart';

enum AppShellDestination {
  dashboard,
  schedule,
  monthlyRoster,
  rosterNames,
  employees,
  shiftExchange,
  reports,
  admin,
  settings,
}

/// Keeps destination identity and responsive navigation mapping independent
/// from the widget layout used to render the shell.
class AppShellNavigation {
  AppShellNavigation._(this.destinations);

  factory AppShellNavigation.forEdition(AppEdition edition) {
    final destinations = <AppShellDestination>[
      AppShellDestination.dashboard,
      AppShellDestination.schedule,
      AppShellDestination.monthlyRoster,
      if (edition == AppEdition.organization) ...[
        AppShellDestination.rosterNames,
        AppShellDestination.employees,
        AppShellDestination.shiftExchange,
      ],
      AppShellDestination.reports,
      if (edition == AppEdition.organization) AppShellDestination.admin,
      AppShellDestination.settings,
    ];
    return AppShellNavigation._(List.unmodifiable(destinations));
  }

  final List<AppShellDestination> destinations;

  static const primaryDestinations = <AppShellDestination>[
    AppShellDestination.dashboard,
    AppShellDestination.schedule,
    AppShellDestination.reports,
  ];

  List<int> get primaryIndexes => [
    for (final destination in primaryDestinations)
      destinations.indexOf(destination),
  ].where((index) => index >= 0).toList(growable: false);

  List<int> get secondaryIndexes => [
    for (var index = 0; index < destinations.length; index++)
      if (!primaryIndexes.contains(index)) index,
  ];

  int indexOf(AppShellDestination destination) =>
      destinations.indexOf(destination);

  int primaryTabIndexFor(int destinationIndex) =>
      primaryIndexes.indexOf(destinationIndex);

  int? destinationIndexForPrimaryTab(int tabIndex) {
    if (tabIndex < 0 || tabIndex >= primaryIndexes.length) return null;
    return primaryIndexes[tabIndex];
  }
}
