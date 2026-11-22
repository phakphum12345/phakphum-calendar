import 'package:flutter/material.dart';

import '../../domain/schedule_day.dart';
import '../controllers/schedule_controller.dart';
import '../widgets/schedule_controller_host.dart';
import '../widgets/schedule_grid.dart';
import '../widgets/schedule_view_scaffold.dart';

class WeeklySchedulePage extends StatelessWidget {
  const WeeklySchedulePage({super.key, this.controller});

  final ScheduleController? controller;

  @override
  Widget build(BuildContext context) {
    return ScheduleControllerHost(
      controller: controller,
      builder: (context, controller) {
        final days = _weekDays(controller);
        return ScheduleViewScaffold(
          title: 'Weekly Schedule',
          controller: controller,
          child: ScheduleGrid(
            days: days,
            assignmentsFor: controller.assignmentsFor,
            showMonthPadding: false,
            selectedDate: controller.selectedDay,
            onDaySelected: (day) => controller.selectDay(day.date),
          ),
        );
      },
    );
  }

  ScheduleDay _dayForDate(ScheduleController controller, DateTime date) =>
      controller.canonicalSchedule.month(date)?.day(date) ??
      ScheduleDay(date: date);

  List<ScheduleDay> _weekDays(ScheduleController controller) {
    final anchor =
        controller.selectedDay ??
        controller.selectedDate ??
        controller.schedule.days.first.date;
    final start = anchor.subtract(Duration(days: anchor.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return [
      for (var offset = 0; offset < 7; offset++)
        _dayForDate(controller, start.add(Duration(days: offset))),
    ];
  }
}
