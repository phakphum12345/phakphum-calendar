import 'package:flutter/material.dart';

enum ScheduleViewMode { month, week, day, year }

class ScheduleViewSelector extends StatelessWidget {
  const ScheduleViewSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ScheduleViewMode value;
  final ValueChanged<ScheduleViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<ScheduleViewMode>(
        segments: const [
          ButtonSegment(
            value: ScheduleViewMode.month,
            icon: Icon(Icons.calendar_view_month),
            label: Text('Month'),
          ),
          ButtonSegment(
            value: ScheduleViewMode.week,
            icon: Icon(Icons.view_week_outlined),
            label: Text('Week'),
          ),
          ButtonSegment(
            value: ScheduleViewMode.day,
            icon: Icon(Icons.view_day_outlined),
            label: Text('Day'),
          ),
          ButtonSegment(
            value: ScheduleViewMode.year,
            icon: Icon(Icons.calendar_month_outlined),
            label: Text('Year'),
          ),
        ],
        selected: {value},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}
