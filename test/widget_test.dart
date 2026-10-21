import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/app.dart';
import 'package:phakphum_calendar/controller/app_controller.dart';
import 'package:phakphum_calendar/core/di/app_dependencies.dart';
import 'package:phakphum_calendar/features/excel_import/presentation/pages/import_excel_page.dart';
import 'package:phakphum_calendar/features/edition/domain/app_edition.dart';
import 'package:phakphum_calendar/models/shift.dart';
import 'package:phakphum_calendar/models/shift_alert.dart';
import 'package:phakphum_calendar/ui/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      AppEditionRepository.storageKey: AppEdition.organization.name,
    }),
  );

  AppController demoController() =>
      AppDependencies.production().createDemoAppController();

  testWidgets('first launch asks for personal or organization edition', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = demoController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(ShiftToolsApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('เลือกเวอร์ชัน Shift Tools'), findsOneWidget);
    expect(find.text('บุคคลทั่วไป'), findsOneWidget);
    expect(find.text('องค์กร'), findsOneWidget);
  });

  test('default monthly roster contains no personal names', () {
    final controller = demoController();
    addTearDown(controller.dispose);

    expect(
      controller.shifts.every((shift) => shift.assignedName.isEmpty),
      isTrue,
    );
  });

  test(
    'accepting an OFF conflict keeps duty and excludes generated OFF',
    () async {
      final controller = demoController();
      final conflict = controller.alerts.singleWhere(
        (alert) => alert.type == ShiftAlertType.offConflict,
      );

      await controller.resolveAlert(conflict.id, ShiftAlertDecision.accepted);

      expect(
        controller.shifts.singleWhere((shift) => shift.code == 'OFF').excluded,
        isTrue,
      );
      expect(
        controller.shifts.singleWhere((shift) => shift.code == 'UP3').excluded,
        isFalse,
      );
      controller.dispose();
    },
  );

  test('customizing a shift accepts a new date and an overnight end', () {
    final controller = demoController();
    addTearDown(controller.dispose);
    final index = controller.shifts.indexWhere((shift) => !shift.generated);
    final original = controller.shifts[index];
    final newDate = DateTime(
      original.start.year,
      original.start.month,
      original.start.day + 3,
      20,
    );

    controller.customizeShift(
      index,
      title: original.displayName,
      start: newDate,
      end: newDate.add(const Duration(hours: 12)),
      category: original.category,
      colorCommand: '',
    );

    expect(controller.shifts[index].start, newDate);
    expect(
      controller.shifts[index].end,
      DateTime(newDate.year, newDate.month, newDate.day + 1, 8),
    );
  });

  test('customizing a default OFF accepts any user-defined date and time', () {
    final controller = demoController();
    addTearDown(controller.dispose);
    final index = controller.shifts.indexWhere((shift) => shift.generated);
    final customStart = DateTime(2026, 8, 7, 9);
    final customEnd = customStart.add(const Duration(hours: 4));

    controller.customizeShift(
      index,
      title: 'OFF กำหนดเอง',
      start: customStart,
      end: customEnd,
      category: ShiftCategory.off,
      colorCommand: '',
    );

    final offShifts = controller.shifts.where((shift) => shift.isOffDuty);
    expect(offShifts, hasLength(1));
    expect(offShifts.single.start, customStart);
    expect(offShifts.single.end, customEnd);
    expect(offShifts.single.generated, isFalse);
  });

  test(
    'a custom sync range filters shifts and can be expanded again',
    () async {
      final controller = demoController();
      addTearDown(controller.dispose);

      await controller.updateSyncDateRange(
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 8),
      );

      expect(
        controller.shifts
            .where((shift) => !shift.generated)
            .map((shift) => shift.start.day),
        [3, 8],
      );

      await controller.updateSyncDateRange(
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 11),
      );

      expect(
        controller.shifts
            .where((shift) => !shift.generated)
            .map((shift) => shift.start.day),
        [3, 8, 10, 11],
      );
    },
  );

  testWidgets('shift settings allow selecting a different date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ShiftToolsApp(controller: demoController()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตารางเวร'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตั้งวันที่ เวลา ชื่อ ประเภท และสี').first);
    await tester.pumpAndSettle();

    expect(find.text('ตั้งค่ารายการก่อนใช้'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
  });

  testWidgets('desktop layout shows the full navigation and dashboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ShiftToolsApp(controller: demoController()));
    await tester.pumpAndSettle();

    expect(find.text('Shift Tools'), findsOneWidget);
    expect(find.text('แหล่งข้อมูลเวร'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
    expect(find.text('รีเฟรช/อ่านใหม่ตอนนี้'), findsOneWidget);
    expect(find.text('ชื่อที่ต้องค้นหา'), findsOneWidget);
    expect(find.text('กรอกชื่อให้ตรงกับชื่อในตารางเวร'), findsOneWidget);
    expect(find.text('เลือกไฟล์จาก Google Sheets'), findsOneWidget);
    expect(find.text('เปิดกล้อง'), findsOneWidget);
    expect(find.text('วาง URL จากเบราว์เซอร์'), findsNothing);
    expect(find.text('แนบไฟล์ต้นฉบับเพื่อเปรียบเทียบ'), findsOneWidget);
    expect(find.textContaining('คอมเมนต์คนแทนเวรและยกเวร'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(2));
    expect(find.text('${DateTime.now().year}'), findsNothing);

    expect(find.text('แดชบอร์ด'), findsOneWidget);
    expect(find.text('ตารางเวร'), findsOneWidget);
    expect(find.text('รายเดือน'), findsOneWidget);
    expect(find.text('บุคลากร'), findsOneWidget);
    expect(find.text('แลกเวร'), findsOneWidget);
    expect(find.text('รายงาน'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('ตั้งค่า'), findsOneWidget);
    expect(find.text('ลบเวรซ้ำ'), findsOneWidget);

    await tester.tap(find.text('รายเดือน'));
    await tester.pumpAndSettle();
    expect(find.text('ตารางเวรรายเดือน'), findsOneWidget);
    expect(find.text('Excel / CSV / ไฟล์'), findsOneWidget);
    expect(find.text('เปิดกล้อง'), findsOneWidget);
    expect(find.text('เลือกรูป'), findsOneWidget);
    expect(find.byTooltip('สร้างเทมเพลตรายเดือน'), findsOneWidget);

    await tester.tap(find.byTooltip('สร้างเทมเพลตรายเดือน'));
    await tester.pumpAndSettle();
    expect(find.text('สร้างเทมเพลตรายเดือน'), findsOneWidget);
    expect(find.text('ชื่อเทมเพลต'), findsOneWidget);
    expect(find.text('แถวเวรหรือสถานที่'), findsOneWidget);
    expect(find.byTooltip('เพิ่มกลุ่มเวร'), findsOneWidget);
    await tester.tap(find.byTooltip('เพิ่มกลุ่มเวร'));
    await tester.pumpAndSettle();
    expect(find.text('ชื่อกลุ่มเวร 2'), findsOneWidget);
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('รายชื่อ'));
    await tester.pumpAndSettle();
    expect(find.text('ค้นหาชื่อหรือสถานะ'), findsOneWidget);
    expect(find.text('Import ไฟล์'), findsOneWidget);
    expect(find.byTooltip('เพิ่มลิสต์รายชื่อ'), findsOneWidget);
    await tester.tap(find.byTooltip('เพิ่มลิสต์รายชื่อ'));
    await tester.pumpAndSettle();
    expect(find.text('เพิ่มลิสต์รายชื่อ'), findsOneWidget);
    expect(find.text('รายชื่อเจ้าหน้าที่'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'รายชื่อเจ้าหน้าที่'),
      'เจ้าหน้าที่ A\nเจ้าหน้าที่ B',
    );
    await tester.tap(find.text('เพิ่มรายชื่อ'));
    await tester.pumpAndSettle();
    expect(find.text('เจ้าหน้าที่ A'), findsOneWidget);
    expect(find.text('เจ้าหน้าที่ B'), findsOneWidget);
    expect(find.text('ล็อก'), findsNWidgets(2));
    expect(find.text('สถานะ'), findsNWidgets(2));
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('ล็อกบุคคลไว้ที่จุดเวร'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'ชื่อจุดเวร'), 'CT');
    await tester.tap(find.widgetWithText(FilledButton, 'ล็อก'));
    await tester.pumpAndSettle();
    expect(find.text('ล็อก: CT'), findsOneWidget);
    await tester.tap(find.text('แดชบอร์ด'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('แจ้งเตือน').last);
    await tester.pumpAndSettle();
    expect(find.text('ศูนย์แจ้งเตือนเวร'), findsOneWidget);
    expect(find.text('รับทราบและคงไว้'), findsWidgets);
    expect(find.text('ไม่นำเข้าปฏิทิน'), findsWidgets);

    Navigator.of(tester.element(find.text('ศูนย์แจ้งเตือนเวร'))).pop();
    await tester.pumpAndSettle();

    final yearDropdown = find.byType(DropdownButtonFormField<int>).last;
    await tester.ensureVisible(yearDropdown);
    await tester.pumpAndSettle();
    await tester.tap(yearDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('${DateTime.now().year + 1}').last);
    await tester.pumpAndSettle();
    expect(find.text('${DateTime.now().year + 1}'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เครื่องมือ').last);
    await tester.pumpAndSettle();
    expect(find.text('คลังเครื่องมือ'), findsOneWidget);
    expect(find.text('Gmail'), findsWidgets);
    expect(find.text('VS Code Web'), findsWidgets);
    expect(find.text('ติดตั้งในแถบ'), findsWidgets);

    Navigator.of(tester.element(find.text('คลังเครื่องมือ'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตั้งค่า'));
    await tester.pumpAndSettle();
    expect(find.text('สร้างชีตเดือนล่วงหน้า'), findsOneWidget);
    expect(find.textContaining('Passkey'), findsNothing);
    expect(find.textContaining('passkey'), findsNothing);
  });

  testWidgets('phone layout remains usable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ShiftToolsApp(controller: demoController()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Auto refresh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Import Excel named route remains available', (tester) async {
    await tester.pumpWidget(ShiftToolsApp(controller: demoController()));
    await tester.pumpAndSettle();

    final shellContext = tester.element(find.byType(AppShell));
    Navigator.of(shellContext).pushNamed(ImportExcelPage.routeName);
    await tester.pumpAndSettle();

    expect(find.byType(ImportExcelPage), findsOneWidget);
    expect(find.text('เลือกไฟล์ Excel'), findsOneWidget);
  });

  testWidgets('Google Sheets link picker stays gated while signed out on a phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = demoController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(ShiftToolsApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่ได้เลือกแหล่งข้อมูลเวร'), findsOneWidget);
    expect(find.text('เลือกไฟล์จาก Google Sheets'), findsOneWidget);
    expect(find.text('เลือกแท็บด้วยลิงก์'), findsOneWidget);
    expect(find.text('วาง URL จากเบราว์เซอร์'), findsNothing);

    // The demo controller is intentionally signed out. Verify the picker is
    // present but gated until Google authentication, rather than tapping a
    // disabled button and expecting its dialog to open.
    final linkPickerButton = find.ancestor(
      of: find.text('เลือกแท็บด้วยลิงก์'),
      matching: find.byType(OutlinedButton),
    );
    expect(linkPickerButton, findsOneWidget);
    final button = tester.widget<OutlinedButton>(linkPickerButton);
    expect(button.onPressed, isNull);
    expect(find.text('เลือกไฟล์หรือแท็บด้วยลิงก์'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved Sheets controls are visible in the audit tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ShiftToolsApp(controller: demoController()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึก').last);
    await tester.pumpAndSettle();

    expect(find.text('ชีตที่บันทึก'), findsOneWidget);
    expect(find.text('บันทึกชีตปัจจุบัน'), findsOneWidget);
    expect(find.textContaining('ล็อกอิน Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tools library remains usable in phone landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ShiftToolsApp(controller: demoController()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เครื่องมือ').last);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Notion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows explains that Google actions use the web app', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(ShiftToolsApp(controller: demoController()));
      await tester.pumpAndSettle();

      expect(find.text('Google Login ใช้ผ่าน Web'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Timeline shortcut opens the audit history', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = demoController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(ShiftToolsApp(controller: controller));
    await tester.pumpAndSettle();

    final timelineShortcut = find.byTooltip('Timeline ย้อนหลัง');
    expect(timelineShortcut, findsOneWidget);
    await tester.tap(timelineShortcut);
    await tester.pumpAndSettle();

    expect(find.text('ประวัติการทำงาน'), findsOneWidget);
    expect(find.text('ยังไม่มี Audit log'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
