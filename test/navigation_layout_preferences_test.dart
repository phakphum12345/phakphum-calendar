import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/ui/navigation_layout_preferences.dart';

void main() {
  group('NavigationLayoutPreferences', () {
    test('keeps destination identity while applying a saved order', () {
      const preferences = NavigationLayoutPreferences(
        order: ['reports', 'dashboard'],
      );

      expect(
        preferences.orderedIds(['dashboard', 'schedule', 'reports']),
        ['reports', 'dashboard', 'schedule'],
      );
    });

    test('reorders destinations without losing unlisted destinations', () {
      const preferences = NavigationLayoutPreferences(
        order: ['dashboard', 'schedule', 'reports'],
      );

      final reordered = preferences.reorder(
        ['dashboard', 'schedule', 'reports', 'settings'],
        0,
        2,
      );

      expect(
        reordered.orderedIds(['dashboard', 'schedule', 'reports', 'settings']),
        ['schedule', 'reports', 'dashboard', 'settings'],
      );
    });

    test('clamps tab and sidebar widths to safe bounds', () {
      const preferences = NavigationLayoutPreferences();

      expect(
        preferences.resizeTab('schedule', 20).tabWidths['schedule'],
        NavigationLayoutPreferences.minTabWidth,
      );
      expect(
        preferences.resizeTab('schedule', 900).tabWidths['schedule'],
        NavigationLayoutPreferences.maxTabWidth,
      );
      expect(
        preferences.resizeSidebar(20).sidebarWidth,
        NavigationLayoutPreferences.minSidebarWidth,
      );
      expect(
        preferences.resizeSidebar(900).sidebarWidth,
        NavigationLayoutPreferences.maxSidebarWidth,
      );
    });

    test('round trips persisted preferences', () {
      const preferences = NavigationLayoutPreferences(
        orientation: NavigationLayoutOrientation.vertical,
        order: ['schedule', 'dashboard'],
        tabWidths: {'schedule': 190},
        sidebarWidth: 280,
        sidebarCollapsed: true,
      );

      final restored = NavigationLayoutPreferences.decode(
        preferences.encode(),
      );

      expect(restored.orientation, NavigationLayoutOrientation.vertical);
      expect(restored.order, preferences.order);
      expect(restored.tabWidths, preferences.tabWidths);
      expect(restored.sidebarWidth, 280);
      expect(restored.sidebarCollapsed, isTrue);
    });

    test('invalid or future versions fall back to defaults', () {
      expect(
        NavigationLayoutPreferences.decode('not-json').orientation,
        NavigationLayoutOrientation.horizontal,
      );
      expect(
        NavigationLayoutPreferences.decode('{"version":2}').order,
        isEmpty,
      );
    });
  });
}
