import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/edition/domain/app_edition.dart';
import 'package:phakphum_calendar/ui/app_shell_navigation.dart';

void main() {
  group('AppShellNavigation', () {
    test('personal edition keeps core destinations and primary tabs stable', () {
      final navigation = AppShellNavigation.forEdition(AppEdition.personal);

      expect(navigation.destinations, [
        AppShellDestination.dashboard,
        AppShellDestination.schedule,
        AppShellDestination.monthlyRoster,
        AppShellDestination.shiftExchange,
        AppShellDestination.reports,
        AppShellDestination.settings,
      ]);
      expect(navigation.primaryIndexes, [0, 1, 4]);
      expect(navigation.secondaryIndexes, [2, 3, 5]);
      expect(navigation.destinationIndexForPrimaryTab(2), 4);
    });

    test('organization edition adds organization destinations to workspace', () {
      final navigation = AppShellNavigation.forEdition(
        AppEdition.organization,
      );

      expect(navigation.destinations, [
        AppShellDestination.dashboard,
        AppShellDestination.schedule,
        AppShellDestination.monthlyRoster,
        AppShellDestination.rosterNames,
        AppShellDestination.employees,
        AppShellDestination.shiftExchange,
        AppShellDestination.reports,
        AppShellDestination.admin,
        AppShellDestination.settings,
      ]);
      expect(navigation.primaryIndexes, [0, 1, 6]);
      expect(navigation.secondaryIndexes, [2, 3, 4, 5, 7, 8]);
      expect(navigation.destinationIndexForPrimaryTab(2), 6);
    });

    test('invalid primary tab does not resolve to a destination', () {
      final navigation = AppShellNavigation.forEdition(AppEdition.personal);

      expect(navigation.destinationIndexForPrimaryTab(-1), isNull);
      expect(navigation.destinationIndexForPrimaryTab(3), isNull);
      expect(navigation.primaryTabIndexFor(5), isNegative);
    });
  });
}
