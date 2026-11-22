import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/schedule/data/schedule_service.dart';
import 'package:phakphum_calendar/features/schedule/domain/department.dart';
import 'package:phakphum_calendar/features/schedule/domain/employee.dart';
import 'package:phakphum_calendar/features/schedule/domain/shift.dart';
import 'package:phakphum_calendar/features/schedule/domain/shift_assignment.dart';
import 'package:phakphum_calendar/features/schedule/presentation/controllers/schedule_controller.dart';
import 'package:phakphum_calendar/features/schedule/presentation/pages/schedule_workspace_page.dart';
import 'package:phakphum_calendar/features/schedule/presentation/pages/weekly_schedule_page.dart';
import 'package:phakphum_calendar/features/schedule/presentation/widgets/schedule_grid.dart';

void main() {
  testWidgets('weekly page includes all seven days across month boundaries', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller
      ..updateAssignment(
        DateTime(2026, 6, 30),
        const ShiftAssignment(employee: _employee, shift: _shift),
      )
      ..updateAssignment(
        DateTime(2026, 8, 1),
        const ShiftAssignment(employee: _employee, shift: _shift),
      )
      ..loadMonth(DateTime(2026, 7))
      ..selectDay(DateTime(2026, 7, 1));

    await tester.pumpWidget(
      MaterialApp(home: WeeklySchedulePage(controller: controller)),
    );

    final days = tester.widget<ScheduleGrid>(find.byType(ScheduleGrid)).days;
    expect(
      days.map((day) => day.date),
      [
        DateTime(2026, 6, 29),
        DateTime(2026, 6, 30),
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 2),
        DateTime(2026, 7, 3),
        DateTime(2026, 7, 4),
        DateTime(2026, 7, 5),
      ],
    );
    expect(days[1].assignments, hasLength(1));
  });


  testWidgets('selecting an adjacent-month day updates the workspace month', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller
      ..loadMonth(DateTime(2026, 7))
      ..selectDay(DateTime(2026, 7, 31));

    await tester.pumpWidget(
      MaterialApp(home: ScheduleWorkspacePage(controller: controller)),
    );
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    final days = tester.widget<ScheduleGrid>(find.byType(ScheduleGrid)).days;
    expect(controller.currentMonth, DateTime(2026, 8));
    expect(controller.selectedDay, DateTime(2026, 8, 1));
    expect(days, hasLength(1));
    expect(days.single.date, DateTime(2026, 8, 1));
  });

  testWidgets('selecting an adjacent-month day in weekly page changes month', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller
      ..loadMonth(DateTime(2026, 7))
      ..selectDay(DateTime(2026, 7, 31));

    await tester.pumpWidget(
      MaterialApp(home: WeeklySchedulePage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(controller.currentMonth, DateTime(2026, 8));
    expect(controller.selectedDay, DateTime(2026, 8, 1));
  });

  testWidgets('workspace week mode includes next-month assignments', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller
      ..updateAssignment(
        DateTime(2026, 8, 1),
        const ShiftAssignment(employee: _employee, shift: _shift),
      )
      ..loadMonth(DateTime(2026, 7))
      ..selectDay(DateTime(2026, 7, 31));

    await tester.pumpWidget(
      MaterialApp(home: ScheduleWorkspacePage(controller: controller)),
    );
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    final days = tester.widget<ScheduleGrid>(find.byType(ScheduleGrid)).days;
    expect(
      days.map((day) => day.date),
      [
        DateTime(2026, 7, 27),
        DateTime(2026, 7, 28),
        DateTime(2026, 7, 29),
        DateTime(2026, 7, 30),
        DateTime(2026, 7, 31),
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 2),
      ],
    );
    expect(days[5].assignments, hasLength(1));
  });
}

const _department = Department(id: 'icu', code: 'ICU', name: 'ICU');
const _employee = Employee(
  id: 'employee',
  employeeCode: 'E01',
  firstName: 'Mali',
  lastName: 'Dee',
  nickname: 'Mai',
  department: _department,
  position: 'Nurse',
);
const _shift = Shift(
  id: 'morning',
  code: 'M',
  name: 'Morning',
  color: 0xFF00897B,
  startTime: Duration(hours: 8),
  endTime: Duration(hours: 16),
  workingHours: 8,
);

ScheduleController _controller() => ScheduleController(
  initialMonth: DateTime(2026, 7),
  service: ScheduleService(
    departments: const [_department],
    employees: const [_employee],
    shifts: const [_shift],
  ),
);
