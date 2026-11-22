import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/schedule/data/schedule_service.dart';
import 'package:phakphum_calendar/features/schedule/domain/department.dart';
import 'package:phakphum_calendar/features/schedule/domain/employee.dart';
import 'package:phakphum_calendar/features/schedule/domain/shift.dart';
import 'package:phakphum_calendar/features/schedule/domain/shift_assignment.dart';
import 'package:phakphum_calendar/features/schedule/presentation/controllers/schedule_controller.dart';
import 'package:phakphum_calendar/features/schedule/presentation/pages/schedule_workspace_page.dart';
import 'package:phakphum_calendar/features/schedule/presentation/widgets/schedule_year_overview.dart';

void main() {
  testWidgets('year view shows all months and summarizes saved shifts', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller
      ..updateAssignment(
        DateTime(2026, 8, 10),
        const ShiftAssignment(employee: _employee, shift: _shift),
      )
      ..loadMonth(DateTime(2026, 7));

    await tester.pumpWidget(
      MaterialApp(home: ScheduleWorkspacePage(controller: controller)),
    );
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleYearOverview), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('January'), findsOneWidget);
    expect(find.text('December'), findsOneWidget);
    expect(find.text('1 shift'), findsOneWidget);
  });


  testWidgets('year overview remains usable at mobile and desktop widths', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: ScheduleWorkspacePage(controller: controller)),
    );
    await tester.ensureVisible(find.text('Year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleYearOverview), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1440, 1000);
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleYearOverview), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('year view navigates years and opens a selected month', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ScheduleWorkspacePage(controller: controller)),
    );
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Next year'));
    await tester.pumpAndSettle();
    expect(find.text('2027'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous year'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('August'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('August'));
    await tester.pumpAndSettle();

    expect(controller.currentMonth, DateTime(2026, 8));
    expect(find.byType(ScheduleYearOverview), findsNothing);
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
