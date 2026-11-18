import 'package:flutter/material.dart';

import '../../domain/schedule_day.dart';
import '../../../../l10n/l10n.dart';
import '../controllers/schedule_controller.dart';
import '../widgets/schedule_controller_host.dart';
import '../widgets/schedule_grid.dart';
import '../widgets/schedule_view_scaffold.dart';
import 'daily_schedule_page.dart';

class MonthlySchedulePage extends StatelessWidget {
  const MonthlySchedulePage({
    super.key,
    this.controller,
    this.title = 'Monthly Schedule',
    this.appBarActions = const [],
  });

  final ScheduleController? controller;
  final String title;
  final List<Widget> appBarActions;

  @override
  Widget build(BuildContext context) {
    return ScheduleControllerHost(
      controller: controller,
      builder: (context, controller) => ScheduleViewScaffold(
        title: title,
        controller: controller,
        appBarActions: appBarActions,
        child: Column(
          children: [
            if (!controller.hasAssignments) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text(context.l10n.noShiftsThisMonth)),
                ),
              ),
              const SizedBox(height: 12),
            ] else if (controller.hasActiveFilters &&
                !controller.hasMatchingAssignments) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(context.l10n.noMatchingAssignments),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ScheduleGrid(
              days: controller.schedule.days,
              assignmentsFor: controller.assignmentsFor,
              selectedDate: controller.selectedDay,
              onDaySelected: (day) => _openDay(context, controller, day),
            ),
          ],
        ),
      ),
    );
  }

  void _openDay(
    BuildContext context,
    ScheduleController controller,
    ScheduleDay day,
  ) {
    controller.selectDay(day.date);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DailySchedulePage(controller: controller),
      ),
    );
  }
}
