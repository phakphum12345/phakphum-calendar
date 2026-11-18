import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/schedule/data/schedule_service.dart';
import 'package:phakphum_calendar/features/schedule/domain/department.dart';
import 'package:phakphum_calendar/features/schedule/domain/employee.dart';
import 'package:phakphum_calendar/features/schedule/domain/schedule_drag_payload.dart';
import 'package:phakphum_calendar/features/schedule/domain/shift.dart';
import 'package:phakphum_calendar/features/schedule/domain/shift_assignment.dart';
import 'package:phakphum_calendar/features/schedule/presentation/controllers/schedule_controller.dart';
import 'package:phakphum_calendar/features/schedule/presentation/pages/daily_schedule_page.dart';
import 'package:phakphum_calendar/features/schedule/presentation/pages/monthly_schedule_page.dart';
import 'package:phakphum_calendar/features/schedule/presentation/pages/schedule_workspace_page.dart';
import 'package:phakphum_calendar/features/schedule/presentation/pages/weekly_schedule_page.dart';
import 'package:phakphum_calendar/features/schedule/presentation/widgets/schedule_grid.dart';
import 'package:phakphum_calendar/features/schedule/presentation/widgets/schedule_view_selector.dart';

void main() {
  testWidgets('renders reusable monthly, weekly, and daily schedule views', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: MonthlySchedulePage(controller: controller)),
    );
    expect(find.text('Monthly Schedule'), findsOneWidget);
    expect(find.byType(ScheduleGrid), findsOneWidget);
    expect(find.text('Total shifts'), findsNothing);
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();
    expect(find.text('Total shifts'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: WeeklySchedulePage(controller: controller)),
    );
    expect(find.text('Weekly Schedule'), findsOneWidget);

    controller.filterDate(DateTime(2026, 7, 6));
    await tester.pumpWidget(
      MaterialApp(home: DailySchedulePage(controller: controller)),
    );
    expect(find.text('Daily Schedule'), findsOneWidget);
    expect(find.textContaining('Mali Dee'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('switches views and exposes zoom and prepared drag targets', (
    tester,
  ) async {
    final controller = _controller()..selectDay(DateTime(2026, 7, 6));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ScheduleWorkspacePage(controller: controller)),
    );

    expect(find.byType(ScheduleViewSelector), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(Slider),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(ScheduleViewSelector),
      -300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('Week'), findsOneWidget);

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('prepares assignment dragging without changing data', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    final day = controller.schedule.day(DateTime(2026, 7, 6))!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScheduleGrid(
              days: [day],
              assignmentsFor: controller.assignmentsFor,
              showMonthPadding: false,
              dragEnabled: true,
              onAssignmentDrop: (_, _) {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is LongPressDraggable<ScheduleDragPayload>,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DragTarget<ScheduleDragPayload>,
      ),
      findsOneWidget,
    );
    expect(day.assignments, hasLength(1));
  });

  testWidgets('shows a filter-aware empty state for the selected day', (
    tester,
  ) async {
    final controller = _controller()
      ..selectDay(DateTime(2026, 7, 6))
      ..filterStaffName('Unknown staff');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: DailySchedulePage(controller: controller)),
    );
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    expect(
      find.text('No assignments match the active filters for this date.'),
      findsOneWidget,
    );
    expect(find.text('Staff: Unknown staff'), findsOneWidget);

    await tester.tap(find.text('Clear all filters'));
    await tester.pump();

    expect(find.textContaining('Mali Dee'), findsOneWidget);
    expect(
      find.text('No assignments match the active filters for this date.'),
      findsNothing,
    );
  });
}

ScheduleController _controller() {
  const department = Department(id: 'icu', code: 'ICU', name: 'ICU');
  const employee = Employee(
    id: 'e1',
    employeeCode: 'E01',
    firstName: 'Mali',
    lastName: 'Dee',
    nickname: 'Mai',
    department: department,
    position: 'Nurse',
  );
  const shift = Shift(
    id: 'm',
    code: 'M',
    name: 'Morning',
    color: 0xFF00897B,
    startTime: Duration(hours: 8),
    endTime: Duration(hours: 16),
    workingHours: 8,
  );
  final controller = ScheduleController(
    initialMonth: DateTime(2026, 7),
    service: ScheduleService(
      departments: const [department],
      employees: const [employee],
      shifts: const [shift],
    ),
  );
  controller.updateAssignment(
    DateTime(2026, 7, 6),
    const ShiftAssignment(employee: employee, shift: shift),
  );
  return controller;
}
