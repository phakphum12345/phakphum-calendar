import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/schedule_month.dart';
import '../controllers/schedule_controller.dart';

class ScheduleYearOverview extends StatelessWidget {
  const ScheduleYearOverview({
    required this.year,
    required this.controller,
    required this.onMonthSelected,
    super.key,
  });

  final int year;
  final ScheduleController controller;
  final ValueChanged<DateTime> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 600
                ? 2
                : 1;
        const spacing = 8.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List<Widget>.generate(12, (index) {
            final monthDate = DateTime(year, index + 1);
            final month =
                controller.canonicalSchedule.month(monthDate) ??
                ScheduleMonth.empty(monthDate);
            return SizedBox(
              width: cardWidth,
              height: 390,
              child: _YearMonthCard(
                month: month,
                controller: controller,
                onTap: () => onMonthSelected(monthDate),
              ),
            );
          }),
        );
      },
    );
  }
}

class _YearMonthCard extends StatelessWidget {
  const _YearMonthCard({
    required this.month,
    required this.controller,
    required this.onTap,
  });

  final ScheduleMonth month;
  final ScheduleController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final title = DateFormat.MMMM(locale).format(month.month);
    final shiftCount = month.days.fold<int>(
      0,
      (total, day) => total + controller.assignmentsFor(day).length,
    );
    final leading = month.days.first.date.weekday - 1;
    final itemCount = leading + month.days.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$shiftCount ${shiftCount == 1 ? 'shift' : 'shifts'}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1.3,
                      ),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index < leading) return const SizedBox.shrink();
                    final day = month.days[index - leading];
                    final count = controller.assignmentsFor(day).length;
                    return Tooltip(
                      message:
                          DateFormat.yMMMd(locale).format(day.date) +
                          (count == 0 ? '' : ' · $count shifts'),
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: count == 0
                              ? null
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.date.day}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: count == 0
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
