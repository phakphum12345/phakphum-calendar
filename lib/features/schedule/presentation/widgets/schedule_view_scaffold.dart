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
  });

  final String title;
  final ScheduleController controller;
  final Widget child;
  final Widget? viewSelector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: theme.textTheme.titleLarge),
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 600 ? 12.0 : 24.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              20,
              horizontalPadding,
              28,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: constraints.maxWidth < 600 ? 8 : 20,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              MonthHeader(
                                month: controller.currentMonth,
                                onPrevious: controller.previousMonth,
                                onNext: controller.nextMonth,
                              ),
                              if (viewSelector != null) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.center,
                                  child: viewSelector!,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Filters',
                        icon: Icons.filter_list_rounded,
                        child: ScheduleFilters(controller: controller),
                      ),
                      const SizedBox(height: 16),
                      ScheduleStatisticsPanel(
                        statistics: controller.statistics,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: EdgeInsets.all(
                            constraints.maxWidth < 600 ? 8 : 16,
                          ),
                          child: child,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Shift legend',
                        icon: Icons.palette_outlined,
                        child: Legend(shifts: controller.shifts),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
