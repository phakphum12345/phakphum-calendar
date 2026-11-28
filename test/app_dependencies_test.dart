import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/app.dart';
import 'package:phakphum_calendar/core/di/app_dependencies.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/features/excel_import/application/import_engine.dart';
import 'support/in_memory_conditional_schedule_repository.dart';
import 'package:phakphum_calendar/features/excel_import/data/excel_reader_service.dart';
import 'package:phakphum_calendar/features/rule_engine/domain/default_schedule_rules.dart'
    as legacy;
import 'package:phakphum_calendar/features/rule_engine/domain/schedule_rule.dart'
    as legacy;
import 'package:phakphum_calendar/features/rules/application/schedule_validation_service.dart';
import 'package:phakphum_calendar/features/rules/domain/schedule_rules.dart';
import 'package:phakphum_calendar/features/schedule/data/shared_preferences_schedule_repository.dart';
import 'package:phakphum_calendar/models/app_settings.dart';
import 'package:phakphum_calendar/models/shift.dart';
import 'package:phakphum_calendar/services/google_auth_service.dart';
import 'package:phakphum_calendar/services/settings_service.dart';
import 'package:phakphum_calendar/services/shift_parser.dart';
import 'package:phakphum_calendar/ui/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Google integration gateways require the active Google account', () async {
    final dependencies = AppDependencies.production();

    await expectLater(
      dependencies.createGoogleCalendarGateway(),
      throwsStateError,
    );
    await expectLater(
      dependencies.createGoogleDriveGateway(),
      throwsStateError,
    );
    await expectLater(
      dependencies.createGoogleSheetsGateway(),
      throwsStateError,
    );
    await expectLater(
      dependencies.createGoogleEmployeeSyncService(),
      throwsStateError,
    );
    await expectLater(
      dependencies.createGoogleContactsService(),
      throwsStateError,
    );
  });

  test('composition root injects services into AppController', () async {
    final auth = _FakeGoogleAuthService();
    final settings = _FakeSettingsService();
    final dependencies = AppDependencies(
      googleAuthService: auth,
      legacySettingsService: settings,
    );
    final controller = dependencies.createAppController();
    addTearDown(controller.dispose);

    expect(controller.auth, same(auth));

    await controller.initialize();

    expect(settings.loadCalls, 1);
    expect(auth.initializeCalls, 1);
    expect(controller.settings.refreshSeconds, 17);
  });

  testWidgets('app startup resolves through AppDependencies', (tester) async {
    final auth = _FakeGoogleAuthService();
    final settings = _FakeSettingsService();
    final dependencies = AppDependencies(
      googleAuthService: auth,
      legacySettingsService: settings,
    );

    await tester.pumpWidget(ShiftToolsApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
    expect(settings.loadCalls, 1);
    expect(auth.initializeCalls, 1);
  });

  test('composition root accepts feature dependency replacements', () {
    final reader = _FakeExcelReaderService();
    const importEngine = ImportEngine();
    final dependencies = AppDependencies(
      excelReaderService: reader,
      importEngine: importEngine,
    );

    final first = dependencies.createExcelImportController();
    final second = dependencies.createExcelImportController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    expect(first, isNot(same(second)));
    expect(dependencies.excelReaderService, same(reader));
    expect(dependencies.importEngine, same(importEngine));
  });

  test('composition root owns SCE top-level controller construction', () {
    final dependencies = AppDependencies.production();
    final schedule = Schedule(id: 'schedule', name: 'Schedule');

    final employees = dependencies.createEmployeeDirectoryController(schedule);
    final exchanges = dependencies.createShiftExchangeController();
    final otherEmployees = dependencies.createEmployeeDirectoryController(
      schedule,
    );
    final otherExchanges = dependencies.createShiftExchangeController();
    addTearDown(employees.dispose);
    addTearDown(exchanges.dispose);
    addTearDown(otherEmployees.dispose);
    addTearDown(otherExchanges.dispose);

    expect(employees.employees, isEmpty);
    expect(exchanges.requests, isEmpty);
    expect(otherEmployees, isNot(same(employees)));
    expect(otherExchanges, isNot(same(exchanges)));
  });

  test('composition root accepts an interface-only legacy service fake', () {
    final parser = _FakeRosterShiftParser();
    final dependencies = AppDependencies(shiftParser: parser);
    final controller = dependencies.createAppController();
    addTearDown(controller.dispose);

    expect(dependencies.shiftParser, same(parser));
    expect(dependencies.shiftParser, isA<RosterShiftParser>());
    expect(dependencies.shiftParser, isNot(isA<ShiftParser>()));
  });

  test('production rule registration comes from AppDependencies', () {
    final dependencies = AppDependencies.production();

    final service = dependencies.createScheduleValidationService();

    expect(service, isA<ScheduleValidationService>());
    expect(service.engine.rules.map((rule) => rule.id), [
      'duplicate-shifts',
      'missing-required-staff',
      'invalid-shift-duration',
      'empty-assignment',
    ]);
  });

  test('test environments can replace the production rule set', () {
    const customRule = WeekendRule(id: 'test-weekend');
    final dependencies = AppDependencies(scheduleRules: const [customRule]);

    final first = dependencies.createRuleEngine();
    final second = dependencies.createRuleEngine();

    expect(first, isNot(same(second)));
    expect(first.rules, [same(customRule)]);
    expect(second.rules, [same(customRule)]);
  });

  test('legacy production registration comes from AppDependencies', () {
    final dependencies = AppDependencies.production();

    final engine = dependencies.createLegacyRuleEngine();

    expect(engine.rules.map((rule) => rule.id), [
      'overlapping-shifts',
      'minimum-rest',
      'maximum-weekly-hours',
    ]);
  });

  test('test environments can replace legacy production rules', () {
    const customRule = legacy.MinimumRestRule(minimumRest: Duration(hours: 12));
    final dependencies = AppDependencies(
      legacyScheduleRules: const [customRule],
    );

    final engine = dependencies.createLegacyRuleEngine();

    expect(engine.rules, [same(customRule)]);
  });

  test('composition-root engines preserve registration order', () {
    const canonicalRules = [
      WeekendRule(id: 'first'),
      WeekendRule(id: 'second'),
    ];
    const legacyRules = [
      legacy.MinimumRestRule(),
      legacy.OverlappingShiftRule(),
    ];
    final dependencies = AppDependencies(
      scheduleRules: canonicalRules,
      legacyScheduleRules: legacyRules,
    );

    expect(dependencies.createRuleEngine().rules.map((rule) => rule.id), [
      'first',
      'second',
    ]);
    expect(dependencies.createLegacyRuleEngine().rules.map((rule) => rule.id), [
      'minimum-rest',
      'overlapping-shifts',
    ]);
  });

  test('legacy composition-root engine executes duplicate IDs once', () {
    final rule = _CountingLegacyRule();
    final dependencies = AppDependencies(legacyScheduleRules: [rule, rule]);

    final result = dependencies.createLegacyRuleEngine().evaluate(const []);

    expect(rule.executionCount, 1);
    expect(result.violations, isEmpty);
  });

  test(
    'direct validation service construction remains backward compatible',
    () {
      final service = ScheduleValidationService();

      expect(service.engine.rules, isEmpty);
    },
  );

  test('composition root constructs the production ScheduleRepository', () {
    final dependencies = AppDependencies.production();

    expect(
      dependencies.scheduleRepository,
      isA<SharedPreferencesScheduleRepository>(),
    );
  });

  test('injected ScheduleRepository reaches imported controllers', () {
    final repository = _FakeScheduleRepository();
    final dependencies = AppDependencies(scheduleRepository: repository);
    final controller = dependencies.createImportedScheduleController(
      Schedule(id: 'imported', name: 'Imported'),
    );
    addTearDown(controller.dispose);

    expect(dependencies.scheduleRepository, same(repository));
    expect(controller.repository, same(repository));
  });

  test(
    'legacy AppController exposes an adapted view of its canonical schedule',
    () async {
      final repository = _FakeScheduleRepository();
      final dependencies = AppDependencies(scheduleRepository: repository);
      final controller = dependencies.createDemoAppController();
      repository.seed(controller.canonicalSchedule);
      addTearDown(controller.dispose);

      expect(controller.canonicalSchedule.id, 'legacy-runtime');
      expect(controller.canonicalSchedule.months, isNotEmpty);
      expect(controller.shifts, isNotEmpty);
      expect(
        () => controller.shifts.add(controller.shifts.first),
        throwsUnsupportedError,
      );

      final index = controller.shifts.indexWhere((shift) => !shift.generated);
      controller.updateShift(
        index,
        category: ShiftCategory.specialClinic,
        excluded: true,
      );
      await controller.flushSchedulePersistence();

      expect(controller.shifts[index].category, ShiftCategory.specialClinic);
      expect(controller.shifts[index].excluded, isTrue);
      expect(repository.saved, hasLength(1));
      expect(repository.saved.single, same(controller.canonicalSchedule));
      expect(
        controller.canonicalSchedule.months
            .expand((month) => month.days)
            .expand((day) => day.assignments)
            .any(
              (assignment) =>
                  assignment.shift.color ==
                  ShiftCategory.specialClinic.colorValue,
            ),
        isTrue,
      );
    },
  );

  test('legacy runtime repository is supplied by AppDependencies', () async {
    final repository = _FakeScheduleRepository();
    final dependencies = AppDependencies(scheduleRepository: repository);
    final controller = dependencies.createDemoAppController();
    repository.seed(controller.canonicalSchedule);
    addTearDown(controller.dispose);

    controller.updateShift(0, excluded: true);
    await controller.flushSchedulePersistence();

    expect(repository.saved, isNotEmpty);
    expect(repository.saved.last.id, 'legacy-runtime');
  });
}

class _FakeGoogleAuthService extends GoogleAuthService {
  int initializeCalls = 0;

  @override
  Future<void> initialize({String? webClientId}) async {
    initializeCalls++;
  }
}

class _FakeSettingsService extends SettingsService {
  int loadCalls = 0;

  @override
  Future<AppSettings> load() async {
    loadCalls++;
    return AppSettings.defaults().copyWith(refreshSeconds: 17);
  }
}

class _FakeExcelReaderService extends ExcelReaderService {}

class _FakeRosterShiftParser implements RosterShiftParser {
  @override
  List<Shift> parse({
    required List<SheetSnapshot> snapshots,
    required String targetName,
    Iterable<String> targetAliases = const [],
    required int year,
    required int month,
  }) {
    return const [];
  }
}

class _CountingLegacyRule implements legacy.ScheduleRule {
  int executionCount = 0;

  @override
  String get id => 'counting-rule';

  @override
  List<legacy.RuleViolation> evaluate(List<legacy.ScheduledShift> shifts) {
    executionCount += 1;
    return const [];
  }
}

class _FakeScheduleRepository extends InMemoryConditionalScheduleRepository {}