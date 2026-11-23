import 'package:flutter/material.dart';

import '../../domain/schedule_day.dart';
import '../../domain/schedule_drag_payload.dart';
import '../../domain/shift_assignment.dart';
import 'schedule_cell.dart';

class ScheduleGrid extends StatefulWidget {
  const ScheduleGrid({
    required this.days,
    required this.assignmentsFor,
    super.key,
    this.showMonthPadding = true,
    this.onDaySelected,
    this.selectedDate,
    this.today,
    this.dragEnabled = false,
    this.onAssignmentDrop,
    this.initialZoom = 1,
  }) : assert(initialZoom >= 0.75 && initialZoom <= 1.75);

  final List<ScheduleDay> days;
  final List<ShiftAssignment> Function(ScheduleDay day) assignmentsFor;
  final bool showMonthPadding;
  final ValueChanged<ScheduleDay>? onDaySelected;
  final DateTime? selectedDate;
  final DateTime? today;

  /// Enables drag gestures only. The grid never mutates schedule data itself.
  final bool dragEnabled;
  final void Function(ScheduleDragPayload payload, ScheduleDay targetDay)?
  onAssignmentDrop;
  final double initialZoom;

  @override
  State<ScheduleGrid> createState() => _ScheduleGridState();
}

class _ScheduleGridState extends State<ScheduleGrid> {
  late double zoom = widget.initialZoom;

  @override
  Widget build(BuildContext context) {
    if (widget.days.isEmpty) {
      return const Center(child: Text('No schedule days available.'));
    }

    final leading = widget.showMonthPadding
        ? widget.days.first.date.weekday - 1
        : 0;
    final itemCount = leading + widget.days.length;
    final columns = widget.showMonthPadding
        ? 7
        : widget.days.length.clamp(1, 7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Icon(
                Icons.zoom_out_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(
                width: 132,
                child: Slider(
                  value: zoom,
                  min: 0.75,
                  max: 1.75,
                  divisions: 4,
                  label: '${(zoom * 100).round()}%',
                  onChanged: (value) => setState(() => zoom = value),
                ),
              ),
              Icon(
                Icons.zoom_in_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              Text(
                '${(zoom * 100).round()}%',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final minimumWidth = widget.showMonthPadding ? 700.0 : 480.0;
            final contentWidth =
                (constraints.maxWidth < minimumWidth
                    ? minimumWidth
                    : constraints.maxWidth) *
                zoom;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: RepaintBoundary(
                  child: Column(
                    children: [
                      if (widget.showMonthPadding) const _WeekdayHeader(),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          childAspectRatio: widget.showMonthPadding
                              ? 0.9
                              : 0.75,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index < leading) {
                            return const SizedBox.shrink();
                          }
                          final day = widget.days[index - leading];
                          return ScheduleCell(
                            key: ValueKey(day.date),
                            day: day,
                            assignments: widget.assignmentsFor(day),
                            isToday: _sameDay(
                              day.date,
                              widget.today ?? DateTime.now(),
                            ),
                            isSelected: _sameDay(day.date, widget.selectedDate),
                            dragEnabled: widget.dragEnabled,
                            onAssignmentDrop: widget.onAssignmentDrop == null
                                ? null
                                : (payload) =>
                                      widget.onAssignmentDrop!(payload, day),
                            onTap: widget.onDaySelected == null
                                ? null
                                : () => widget.onDaySelected!(day),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  bool _sameDay(DateTime left, DateTime? right) =>
      right != null &&
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final label in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
