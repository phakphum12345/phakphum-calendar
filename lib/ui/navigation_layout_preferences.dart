import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum NavigationLayoutOrientation { horizontal, vertical }

/// User-owned navigation layout. Destination IDs are stable enum names rather
/// than list indexes, so reordering never changes which page is selected.
class NavigationLayoutPreferences {
  const NavigationLayoutPreferences({
    this.orientation = NavigationLayoutOrientation.horizontal,
    this.order = const <String>[],
    this.tabWidths = const <String, double>{},
    this.sidebarWidth = 248,
    this.sidebarCollapsed = false,
  });

  static const storageKey = 'app.navigation_layout.v1';
  static const minTabWidth = 104.0;
  static const maxTabWidth = 280.0;
  static const minSidebarWidth = 176.0;
  static const maxSidebarWidth = 420.0;

  final NavigationLayoutOrientation orientation;
  final List<String> order;
  final Map<String, double> tabWidths;
  final double sidebarWidth;
  final bool sidebarCollapsed;

  List<String> orderedIds(Iterable<String> availableIds) {
    final available = availableIds.toSet();
    final result = <String>[];
    for (final id in order) {
      if (available.contains(id) && !result.contains(id)) {
        result.add(id);
      }
    }
    for (final id in availableIds) {
      if (!result.contains(id)) result.add(id);
    }
    return List.unmodifiable(result);
  }

  NavigationLayoutPreferences reorder(
    List<String> availableIds,
    int oldIndex,
    int newIndex,
  ) {
    final next = orderedIds(availableIds).toList();
    if (oldIndex < 0 || oldIndex >= next.length) return this;
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= next.length) newIndex = next.length - 1;
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    return copyWith(order: next);
  }

  NavigationLayoutPreferences resizeTab(String id, double width) {
    final next = Map<String, double>.of(tabWidths)
      ..[id] = width.clamp(minTabWidth, maxTabWidth).toDouble();
    return copyWith(tabWidths: next);
  }

  NavigationLayoutPreferences resizeSidebar(double width) => copyWith(
    sidebarWidth: width.clamp(minSidebarWidth, maxSidebarWidth).toDouble(),
  );

  NavigationLayoutPreferences copyWith({
    NavigationLayoutOrientation? orientation,
    List<String>? order,
    Map<String, double>? tabWidths,
    double? sidebarWidth,
    bool? sidebarCollapsed,
  }) => NavigationLayoutPreferences(
    orientation: orientation ?? this.orientation,
    order: order ?? this.order,
    tabWidths: tabWidths ?? this.tabWidths,
    sidebarWidth: sidebarWidth ?? this.sidebarWidth,
    sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'orientation': orientation.name,
    'order': order,
    'tabWidths': tabWidths,
    'sidebarWidth': sidebarWidth,
    'sidebarCollapsed': sidebarCollapsed,
  };

  String encode() => jsonEncode(toJson());

  factory NavigationLayoutPreferences.decode(String source) {
    try {
      final value = jsonDecode(source);
      if (value is! Map<String, dynamic> || value['version'] != 1) {
        return const NavigationLayoutPreferences();
      }
      final rawOrientation = value['orientation'];
      final orientation = NavigationLayoutOrientation.values.firstWhere(
        (item) => item.name == rawOrientation,
        orElse: () => NavigationLayoutOrientation.horizontal,
      );
      final rawOrder = value['order'];
      final rawWidths = value['tabWidths'];
      final widths = <String, double>{};
      if (rawWidths is Map) {
        for (final entry in rawWidths.entries) {
          final width = entry.value;
          if (entry.key is String && width is num) {
            widths[entry.key as String] = width
                .toDouble()
                .clamp(minTabWidth, maxTabWidth)
                .toDouble();
          }
        }
      }
      final sidebarWidth = value['sidebarWidth'];
      return NavigationLayoutPreferences(
        orientation: orientation,
        order: rawOrder is List
            ? rawOrder.whereType<String>().toList(growable: false)
            : const [],
        tabWidths: widths,
        sidebarWidth: sidebarWidth is num
            ? sidebarWidth.toDouble()
                .clamp(minSidebarWidth, maxSidebarWidth)
                .toDouble()
            : 248,
        sidebarCollapsed: value['sidebarCollapsed'] == true,
      );
    } on Object {
      return const NavigationLayoutPreferences();
    }
  }
}

class NavigationLayoutPreferencesStore {
  Future<NavigationLayoutPreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(
      NavigationLayoutPreferences.storageKey,
    );
    return encoded == null
        ? const NavigationLayoutPreferences()
        : NavigationLayoutPreferences.decode(encoded);
  }

  Future<void> save(NavigationLayoutPreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      NavigationLayoutPreferences.storageKey,
      value.encode(),
    );
  }
}
