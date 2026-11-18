import 'package:flutter/material.dart';

import '../controllers/schedule_controller.dart';
import 'legend.dart';
import 'month_header.dart';
import 'schedule_filters.dart';
import 'schedule_statistics_panel.dart';

class ScheduleViewScaffold extends StatelessWidget {
  const ScheduleViewScaffold({
    required this.title,
    required this.controller,
    required this.child,
    super.key,
    this.viewSelector,
    this.appBarActions = const [],
  });

  final String title;
  final ScheduleController controller;
  final Widget child;
  final Widget? viewSelector;
  final List<Widget> appBarActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: theme.textTheme.titleLarge),
        centerTitle: false,
        scrolledUnderElevation: 1,
        actions: appBarActions,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Keep the schedule close to the screen edges. The roster is the
          // primary workspace, so it must not be constrained to a desktop
          // content width.
          final horizontalPadding = constraints.maxWidth < 600 ? 4.0 : 12.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              16,
            ),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth < 600 ? 8 : 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      MonthHeader(
                        month: controller.currentMonth,
                        onPrevious: controller.previousMonth,
                        onNext: controller.nextMonth,
                      ),
                      if (viewSelector != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.center,
                          child: viewSelector!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _CollapsibleSection(
                title: 'Filters',
                icon: Icons.filter_list_rounded,
                child: ScheduleFilters(controller: controller),
              ),
              _CollapsibleSection(
                title: 'Statistics',
                icon: Icons.analytics_outlined,
                child: ScheduleStatisticsPanel(
                  statistics: controller.statistics,
                ),
              ),
              const SizedBox(height: 6),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.all(
                    constraints.maxWidth < 600 ? 4 : 10,
                  ),
                  child: child,
                ),
              ),
              const SizedBox(height: 6),
              _CollapsibleSection(
                title: 'Shift legend',
                icon: Icons.palette_outlined,
                child: Legend(shifts: controller.shifts),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(icon, size: 20, color: theme.colorScheme.primary),
        title: Text(title, style: theme.textTheme.titleSmall),
        children: [child],
      ),
    );
  }
}
