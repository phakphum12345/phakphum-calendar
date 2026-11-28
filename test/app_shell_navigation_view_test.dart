import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/ui/app_shell_navigation_view.dart';
import 'package:phakphum_calendar/ui/navigation_layout_preferences.dart';

void main() {
  const items = [
    AppShellNavigationItem(
      id: 'dashboard',
      label: 'Dashboard',
      icon: Icon(Icons.dashboard_outlined),
    ),
    AppShellNavigationItem(
      id: 'schedule',
      label: 'Schedule',
      icon: Icon(Icons.event_note_outlined),
    ),
  ];

  testWidgets('horizontal layout renders selectable Excel-like tabs', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppShellNavigationView(
            items: items,
            selectedId: 'dashboard',
            preferences: const NavigationLayoutPreferences(),
            onSelected: (id) => selected = id,
            onReorder: (_, _) {},
            onResizeTab: (_, _) {},
            onResizeSidebar: (_) {},
            onToggleCollapsed: () {},
            onOrientationChanged: (_) {},
            onReset: () {},
          ),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    await tester.tap(find.text('Schedule'));
    expect(selected, 'schedule');
  });

  testWidgets('vertical layout renders a collapsible workspace rail', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppShellNavigationView(
            items: items,
            selectedId: 'schedule',
            preferences: const NavigationLayoutPreferences(
              orientation: NavigationLayoutOrientation.vertical,
            ),
            onSelected: (_) {},
            onReorder: (_, _) {},
            onResizeTab: (_, _) {},
            onResizeSidebar: (_) {},
            onToggleCollapsed: () {},
            onOrientationChanged: (_) {},
            onReset: () {},
          ),
        ),
      ),
    );

    expect(find.text('เมนูหลัก'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
  });
}
