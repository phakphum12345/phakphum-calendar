import 'package:flutter/material.dart';

import 'navigation_layout_preferences.dart';

class AppShellNavigationItem {
  const AppShellNavigationItem({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final Widget icon;
}

/// Reorderable, resizable navigation for both Excel-like horizontal tabs and
/// a vertical workspace rail. Persistence is owned by the parent shell.
class AppShellNavigationView extends StatelessWidget {
  const AppShellNavigationView({
    super.key,
    required this.items,
    required this.selectedId,
    required this.preferences,
    required this.onSelected,
    required this.onReorder,
    required this.onResizeTab,
    required this.onResizeSidebar,
    required this.onToggleCollapsed,
    required this.onOrientationChanged,
    required this.onReset,
  });

  final List<AppShellNavigationItem> items;
  final String selectedId;
  final NavigationLayoutPreferences preferences;
  final ValueChanged<String> onSelected;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(String id, double width) onResizeTab;
  final ValueChanged<double> onResizeSidebar;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<NavigationLayoutOrientation> onOrientationChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: preferences.orientation == NavigationLayoutOrientation.horizontal
          ? _buildHorizontal(context)
          : _buildVertical(context),
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    final widths = preferences.tabWidths;
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              buildDefaultDragHandles: false,
              onReorderItem: onReorder,
              children: [
                for (var index = 0; index < items.length; index++)
                  SizedBox(
                    key: ValueKey(items[index].id),
                    width: widths[items[index].id] ?? 148,
                    child: _tab(context, items[index], index),
                  ),
              ],
            ),
          ),
          _layoutMenu(context),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, AppShellNavigationItem item, int index) {
    final selected = item.id == selectedId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: Icon(Icons.drag_indicator, size: 17),
              ),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelected(item.id),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    item.icon,
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              key: ValueKey('resize-tab-${item.id}'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) => onResizeTab(
                item.id,
                (preferences.tabWidths[item.id] ?? 148) + details.delta.dx,
              ),
              child: const SizedBox(
                width: 10,
                child: Center(
                  child: VerticalDivider(width: 1, thickness: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVertical(BuildContext context) {
    final collapsed = preferences.sidebarCollapsed;
    return SizedBox(
      width: collapsed ? 68 : preferences.sidebarWidth,
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: collapsed ? 'ขยายเมนู' : 'พับเมนู',
                      onPressed: onToggleCollapsed,
                      icon: Icon(
                        collapsed
                            ? Icons.keyboard_double_arrow_right
                            : Icons.keyboard_double_arrow_left,
                      ),
                    ),
                    if (!collapsed)
                      Expanded(
                        child: Text(
                          'เมนูหลัก',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    _layoutMenu(context),
                  ],
                ),
                Expanded(
                  child: ReorderableListView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    buildDefaultDragHandles: false,
                    onReorderItem: onReorder,
                    children: [
                      for (var index = 0; index < items.length; index++)
                        ListTile(
                          key: ValueKey(items[index].id),
                          dense: true,
                          selected: items[index].id == selectedId,
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.drag_indicator, size: 16),
                                const SizedBox(width: 6),
                                items[index].icon,
                              ],
                            ),
                          ),
                          title: collapsed
                              ? null
                              : Text(
                                  items[index].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => onSelected(items[index].id),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!collapsed)
            GestureDetector(
              key: const ValueKey('resize-navigation-sidebar'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) => onResizeSidebar(
                preferences.sidebarWidth + details.delta.dx,
              ),
              child: const SizedBox(
                width: 10,
                child: Center(
                  child: VerticalDivider(width: 1, thickness: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _layoutMenu(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'ปรับแต่งแท็บและแถบเมนู',
    icon: const Icon(Icons.tune, size: 20),
    onSelected: (value) {
      switch (value) {
        case 'horizontal':
          onOrientationChanged(NavigationLayoutOrientation.horizontal);
          break;
        case 'vertical':
          onOrientationChanged(NavigationLayoutOrientation.vertical);
          break;
        case 'collapse':
          onToggleCollapsed();
          break;
        case 'reset':
          onReset();
          break;
      }
    },
    itemBuilder: (context) => [
      const PopupMenuItem(
        value: 'horizontal',
        child: ListTile(
          dense: true,
          leading: Icon(Icons.view_week_outlined),
          title: Text('แท็บแนวนอนแบบ Excel'),
        ),
      ),
      const PopupMenuItem(
        value: 'vertical',
        child: ListTile(
          dense: true,
          leading: Icon(Icons.view_sidebar_outlined),
          title: Text('แถบเมนูแนวตั้ง'),
        ),
      ),
      if (preferences.orientation == NavigationLayoutOrientation.vertical)
        PopupMenuItem(
          value: 'collapse',
          child: ListTile(
            dense: true,
            leading: Icon(
              preferences.sidebarCollapsed
                  ? Icons.unfold_more
                  : Icons.unfold_less,
            ),
            title: Text(
              preferences.sidebarCollapsed ? 'ขยายแถบเมนู' : 'พับแถบเมนู',
            ),
          ),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'reset',
        child: ListTile(
          dense: true,
          leading: Icon(Icons.restart_alt),
          title: Text('คืนค่าการจัดวางเริ่มต้น'),
        ),
      ),
    ],
  );
}
