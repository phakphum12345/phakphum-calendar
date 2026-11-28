import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/app.dart';
import 'package:phakphum_calendar/core/di/app_dependencies.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/features/edition/domain/app_edition.dart';
import 'package:phakphum_calendar/features/reports/domain/monthly_report_options.dart';
import 'package:phakphum_calendar/features/reports/domain/report_service.dart';
import 'package:phakphum_calendar/features/reports/infrastructure/monthly_schedule_pdf_service.dart';
import 'package:phakphum_calendar/features/reports/infrastructure/printing_report_output_gateway.dart';
import 'package:phakphum_calendar/features/reports/presentation/controllers/monthly_schedule_report_controller.dart';
import 'package:phakphum_calendar/features/reports/presentation/pages/monthly_schedule_report_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/canonical_schedule_fixture.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      AppEditionRepository.storageKey: AppEdition.organization.name,
    }),
  );

  test('AppDependencies constructs and injects report dependencies', () {
    final service = _FakeReportService();
    final gateway = _FakeOutputGateway();
    final dependencies = AppDependencies(
      monthlyScheduleReportService: service,
      reportOutputGateway: gateway,
      reportClock: () => DateTime(2026, 7, 1, 9),
    );
    final controller = dependencies.createMonthlyScheduleReportController(
      canonicalScheduleFixture(),
    );
    addTearDown(controller.dispose);

    expect(dependencies.monthlyScheduleReportService, same(service));
    expect(dependencies.reportOutputGateway, same(gateway));
    expect(controller.options.month, DateTime(2026, 7));
    expect(controller.options.generatedAt, DateTime(2026, 7, 1, 9));
    expect(
      AppDependencies.production().monthlyScheduleReportService,
      isA<MonthlySchedulePdfService>(),
    );
    expect(
      AppDependencies.production().reportOutputGateway,
      isA<PrintingReportOutputGateway>(),
    );
  });

  test(
    'generation, printing, sharing, and cancellation states are explicit',
    () async {
      final service = _FakeReportService();
      final gateway = _FakeOutputGateway();
      final controller = _controller(service, gateway);
      addTearDown(controller.dispose);

      final generated = await controller.generate();
      expect(generated, isA<Success<Uint8List>>());
      expect(controller.status, MonthlyReportStatus.ready);

      await controller.printReport();
      expect(controller.status, MonthlyReportStatus.success);
      expect(gateway.printCalls, 1);

      gateway.shareOutcome = ReportOutputOutcome.cancelled;
      await controller.shareReport();
      expect(controller.status, MonthlyReportStatus.ready);
      expect(controller.success, isFalse);
      expect(controller.message, 'ยกเลิกการดำเนินการ');
    },
  );

  test('generation and output failures remain controlled', () async {
    final service = _FakeReportService()..fail = true;
    final gateway = _FakeOutputGateway();
    final controller = _controller(service, gateway);
    addTearDown(controller.dispose);

    final generated = await controller.generate();

    expect(generated, isA<Failure<Uint8List>>());
    expect(controller.status, MonthlyReportStatus.failure);
    expect(controller.error, 'generation failed');

    service.fail = false;
    await controller.generate();
    gateway.failPrint = true;
    final printed = await controller.printReport();
    expect(printed, isA<Failure<ReportOutputOutcome>>());
    expect(controller.status, MonthlyReportStatus.failure);
  });

  testWidgets('report options update without mutating the Schedule', (
    tester,
  ) async {
    final schedule = canonicalScheduleFixture();
    final originalMonths = schedule.months;
    final service = _FakeReportService();
    final gateway = _FakeOutputGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthlyScheduleReportPage(
            schedule: schedule,
            controllerFactory: (_) => _controller(service, gateway),
          ),
        ),
      ),
    );

    expect(find.text('เลือกตัวกรองแล้วกด “สร้างตัวอย่าง”'), findsOneWidget);
    expect(find.byKey(const Key('report-month')), findsOneWidget);
    expect(find.byKey(const Key('report-department')), findsOneWidget);
    expect(schedule.months, same(originalMonths));
  });

  testWidgets('production AppShell exposes the Reports destination', (
    tester,
  ) async {
    final service = _FakeReportService();
    final gateway = _FakeOutputGateway();
    final dependencies = AppDependencies(
      monthlyScheduleReportService: service,
      reportOutputGateway: gateway,
    );
    final appController = dependencies.createDemoAppController();
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      ShiftToolsApp(controller: appController, dependencies: dependencies),
    );
    await tester.pumpAndSettle();
    // Reports may be outside the visible horizontal tab viewport.
    await tester.tap(find.byTooltip('รายการหน้า'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('รายงาน').last);
    await tester.pumpAndSettle();

    expect(find.byType(MonthlyScheduleReportPage), findsOneWidget);
    expect(find.byKey(const Key('generate-report')), findsOneWidget);
  });
}

MonthlyScheduleReportController _controller(
  MonthlyScheduleReportService service,
  ReportOutputGateway gateway,
) {
  return MonthlyScheduleReportController(
    schedule: canonicalScheduleFixture(),
    reportService: service,
    outputGateway: gateway,
    initialOptions: MonthlyReportOptions(
      month: DateTime(2026, 7),
      generatedAt: DateTime(2026, 7, 1),
    ),
  );
}

class _FakeReportService implements MonthlyScheduleReportService {
  bool fail = false;

  @override
  Future<Result<Uint8List>> generate(
    Schedule schedule,
    MonthlyReportOptions options,
  ) async {
    return fail
        ? const ValidationFailure('generation failed')
        : Success(Uint8List.fromList([0x25, 0x50, 0x44, 0x46]));
  }
}

class _FakeOutputGateway implements ReportOutputGateway {
  int printCalls = 0;
  bool failPrint = false;
  ReportOutputOutcome shareOutcome = ReportOutputOutcome.completed;

  @override
  Future<Result<ReportOutputOutcome>> printPdf(
    Uint8List bytes, {
    required String documentName,
  }) async {
    printCalls++;
    return failPrint
        ? const PersistenceFailure('print failed')
        : const Success(ReportOutputOutcome.completed);
  }

  @override
  Future<Result<ReportOutputOutcome>> sharePdf(
    Uint8List bytes, {
    required String fileName,
  }) async => Success(shareOutcome);
}
