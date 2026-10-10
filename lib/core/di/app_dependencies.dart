import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:googleapis/calendar/v3.dart' as calendar;

import '../../controller/app_controller.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../domain/repositories/import_repository.dart';
import '../../domain/repositories/schedule_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/shift_template_repository.dart';
import '../../domain/entities/schedule.dart';
import '../../domain/services/calendar_sync_service.dart';
import '../../domain/services/export_service.dart';
import '../../domain/services/google_sheets_service.dart';
import '../../domain/services/import_service.dart';
import '../../domain/services/notification_service.dart';
import '../../features/excel_import/application/import_engine.dart';
import '../../features/dashboard/application/dashboard_summary_service.dart';
import '../../features/excel_import/data/excel_reader_service.dart';
import '../../features/excel_import/data/google_sheets_import_data_source.dart';
import '../../features/excel_import/data/spreadsheet_ownership_verifier.dart';
import '../../features/excel_import/presentation/controllers/column_mapping_controller.dart';
import '../../features/excel_import/presentation/controllers/excel_import_controller.dart';
import '../../features/excel_import/domain/shift_record.dart';
import '../../features/google_sheets/infrastructure/google_sheets_gateway.dart';
import '../../features/employees/presentation/controllers/employee_directory_controller.dart';
import '../../features/employees/infrastructure/shared_preferences_employee_repository.dart';
import '../../features/calendar_engine/application/calendar_sync_plan_builder.dart';
import '../../features/calendar_engine/application/resilient_calendar_sync_executor.dart';
import '../../features/calendar_engine/application/resume_sync_service.dart';
import '../../features/calendar_engine/domain/calendar_sync_gateway.dart';
import '../../features/calendar_engine/domain/failed_sync_repository.dart';
import '../../features/calendar_engine/infrastructure/google_calendar_sync_gateway.dart';
import '../../features/calendar_engine/infrastructure/shared_preferences_failed_sync_repository.dart';
import '../../features/history/domain/sync_history_repository.dart';
import '../../features/history/infrastructure/shared_preferences_sync_history_repository.dart';
import '../../features/rule_engine/application/rule_engine.dart'
    as legacy_rules;
import '../../features/rule_engine/domain/default_schedule_rules.dart'
    as legacy_rules;
import '../../features/rule_engine/domain/schedule_rule.dart' as legacy_rules;
import '../../features/rules/application/rule_engine.dart';
import '../../features/rules/application/schedule_validation_service.dart';
import '../../features/rules/domain/rule.dart';
import '../../features/rules/domain/schedule_rules.dart';
import '../../features/reports/domain/monthly_report_options.dart';
import '../../features/reports/domain/report_service.dart';
import '../../features/reports/infrastructure/monthly_schedule_pdf_service.dart';
import '../../features/reports/infrastructure/printing_report_output_gateway.dart';
import '../../features/reports/presentation/controllers/monthly_schedule_report_controller.dart';
import '../../features/schedule/data/imported_schedule_adapter.dart';
import '../../features/schedule/data/legacy_schedule_adapter.dart';
import '../../features/schedule/data/schedule_service.dart';
import '../../features/schedule/data/shared_preferences_schedule_repository.dart';
import '../../features/schedule/presentation/controllers/schedule_controller.dart';
import '../../features/shift_exchange/presentation/controllers/shift_exchange_controller.dart';
import '../../features/shift_templates/application/shift_template_controller.dart';
import '../../features/shift_templates/infrastructure/shared_preferences_shift_template_repository.dart';
import '../../features/workflow/application/calendar_sync_coordinator.dart';
import '../../features/workflow/application/shift_calendar_workflow_controller.dart';
import '../../features/workflow/application/workflow_preview_builder.dart';
import '../../services/calendar_service.dart';
import '../../services/drive_archive_service.dart';
import '../../services/drive_ownership_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/google_api_client.dart';
import '../../services/local_roster_file_service.dart';
import '../../services/settings_service.dart';
import '../../services/sheets_service.dart';
import '../../services/shift_alert_service.dart';
import '../../services/shift_parser.dart';
import '../google/authorized_google_client_factory.dart';
import '../../l10n/l10n.dart';
import '../../l10n/app_localizations_th.dart';
import '../result/result.dart';
import '../validation/rule_evaluator.dart';

/// Immutable dependency container passed explicitly at composition boundaries.
///
/// Consumers receive only the dependency they need through constructors; they
/// should not reach back into this object as a global service locator.
class AppDependencies {
  AppDependencies({
    GoogleAuthGateway? googleAuthService,
    AppSettingsStore? legacySettingsService,
    RosterSheetsGateway? legacySheetsService,
    RosterShiftParser? shiftParser,
    ShiftAlertPolicy? shiftAlertService,
    LegacyCalendarGateway? legacyCalendarService,
    DriveArchiveGateway? driveArchiveService,
    DriveOwnershipGateway? driveOwnershipService,
    LocalRosterSource? localRosterFileService,
    ExcelReaderService? excelReaderService,
    ImportEngine? importEngine,
    ImportedScheduleAdapter? importedScheduleAdapter,
    DashboardSummaryService? dashboardSummaryService,
    LegacyScheduleAdapter? legacyScheduleAdapter,
    AuthorizedGoogleClientFactory? authorizedGoogleClientFactory,
    GoogleSheetsImportDataSource Function(auth.AuthClient)?
    googleSheetsImportDataSourceFactory,
    Iterable<Rule>? scheduleRules,
    Iterable<legacy_rules.ScheduleRule>? legacyScheduleRules,
    SyncHistoryRepository? syncHistoryRepository,
    FailedSyncRepository? failedSyncRepository,
    CalendarSyncGateway Function(GoogleApiClient)? calendarSyncGatewayFactory,
    MonthlyScheduleReportService? monthlyScheduleReportService,
    ReportOutputGateway? reportOutputGateway,
    DateTime Function()? reportClock,
    EmployeeRepository? employeeRepository,
    ShiftTemplateRepository? shiftTemplateRepository,
    ScheduleRepository? scheduleRepository,
    this.importRepository,
    this.settingsRepository,
    this.importService,
    this.exportService,
    this.calendarSyncService,
    this.googleSheetsService,
    this.notificationService,
    String? Function(String key)? workflowMessageProviderOverride,
  }) : googleAuthService = googleAuthService ?? GoogleAuthService(),
       legacySettingsService = legacySettingsService ?? SettingsService(),
       legacySheetsService = legacySheetsService ?? SheetsService(),
       shiftParser = shiftParser ?? const ShiftParser(),
       shiftAlertService = shiftAlertService ?? const ShiftAlertService(),
       legacyCalendarService = legacyCalendarService ?? const CalendarService(),
       driveArchiveService = driveArchiveService ?? const DriveArchiveService(),
       driveOwnershipService =
           driveOwnershipService ?? const DriveOwnershipService(),
       localRosterFileService =
           localRosterFileService ?? const LocalRosterFileService(),
       excelReaderService = excelReaderService ?? ExcelReaderService(),
       importEngine = importEngine ?? const ImportEngine(),
       importedScheduleAdapter =
           importedScheduleAdapter ?? const ImportedScheduleAdapter(),
       dashboardSummaryService =
           dashboardSummaryService ?? const DashboardSummaryService(),
       legacyScheduleAdapter =
           legacyScheduleAdapter ?? const LegacyScheduleAdapter(),
       authorizedGoogleClientFactory =
           authorizedGoogleClientFactory ??
           const AuthorizedGoogleClientFactory(),
       googleSheetsImportDataSourceFactory =
           googleSheetsImportDataSourceFactory ??
           ((client) => GoogleSheetsImportDataSource(
             GoogleSheetsGateway(client),
             ownershipVerifier: GoogleDriveSpreadsheetOwnershipVerifier(
               client: client,
               gateway: driveOwnershipService ?? const DriveOwnershipService(),
             ),
           )),
       scheduleRules = List.unmodifiable(
         scheduleRules ?? _productionScheduleRules,
       ),
       legacyScheduleRules = List.unmodifiable(
         legacyScheduleRules ?? _productionLegacyScheduleRules,
       ),
       _syncHistoryRepositoryFactory = _dependencyFactory(
         syncHistoryRepository,
         SharedPreferencesSyncHistoryRepository.new,
       ),
       _failedSyncRepositoryFactory = _dependencyFactory(
         failedSyncRepository,
         SharedPreferencesFailedSyncRepository.new,
       ),
       calendarSyncGatewayFactory =
           calendarSyncGatewayFactory ??
           ((client) => GoogleCalendarSyncGateway(client)),
       monthlyScheduleReportService =
           monthlyScheduleReportService ?? MonthlySchedulePdfService(),
       reportOutputGateway =
           reportOutputGateway ?? const PrintingReportOutputGateway(),
       reportClock = reportClock ?? DateTime.now,
       employeeRepository =
           employeeRepository ?? SharedPreferencesEmployeeRepository(),
       shiftTemplateRepository =
           shiftTemplateRepository ??
           SharedPreferencesShiftTemplateRepository(),
       scheduleRepository =
           scheduleRepository ?? SharedPreferencesScheduleRepository(),
       workflowMessageProvider =
           workflowMessageProviderOverride ??
           ((key) => workflowMessageFor(AppLocalizationsTh(), key));

  /// Creates the dependency graph used by the production application.
  factory AppDependencies.production({
    String? Function(String key)? workflowMessageProvider,
  }) =>
      AppDependencies(workflowMessageProviderOverride: workflowMessageProvider);

  final GoogleAuthGateway googleAuthService;
  final AppSettingsStore legacySettingsService;
  final RosterSheetsGateway legacySheetsService;
  final RosterShiftParser shiftParser;
  final ShiftAlertPolicy shiftAlertService;
  final LegacyCalendarGateway legacyCalendarService;
  final DriveArchiveGateway driveArchiveService;
  final DriveOwnershipGateway driveOwnershipService;
  final LocalRosterSource localRosterFileService;
  final ExcelReaderService excelReaderService;
  final ImportEngine importEngine;
  final ImportedScheduleAdapter importedScheduleAdapter;
  final DashboardSummaryService dashboardSummaryService;
  final LegacyScheduleAdapter legacyScheduleAdapter;
  final AuthorizedGoogleClientFactory authorizedGoogleClientFactory;
  final GoogleSheetsImportDataSource Function(auth.AuthClient)
  googleSheetsImportDataSourceFactory;
  final List<Rule> scheduleRules;
  final List<legacy_rules.ScheduleRule> legacyScheduleRules;
  final SyncHistoryRepository Function() _syncHistoryRepositoryFactory;
  final FailedSyncRepository Function() _failedSyncRepositoryFactory;
  late final SyncHistoryRepository syncHistoryRepository =
      _syncHistoryRepositoryFactory();
  late final FailedSyncRepository failedSyncRepository =
      _failedSyncRepositoryFactory();
  final CalendarSyncGateway Function(GoogleApiClient)
  calendarSyncGatewayFactory;
  final MonthlyScheduleReportService monthlyScheduleReportService;
  final ReportOutputGateway reportOutputGateway;
  final DateTime Function() reportClock;
  final String? Function(String key) workflowMessageProvider;

  final EmployeeRepository employeeRepository;
  final ShiftTemplateRepository shiftTemplateRepository;
  final ScheduleRepository scheduleRepository;
  final ImportRepository? importRepository;
  final SettingsRepository? settingsRepository;
  final ImportService? importService;
  final ExportService? exportService;
  final CalendarSyncService? calendarSyncService;
  final GoogleSheetsService? googleSheetsService;
  final NotificationService? notificationService;

  /// Creates the legacy application controller from the canonical graph.
  AppController createAppController() {
    return AppController(
      auth: googleAuthService,
      settingsService: legacySettingsService,
      sheetsService: legacySheetsService,
      parser: shiftParser,
      alertService: shiftAlertService,
      calendarService: legacyCalendarService,
      archiveService: driveArchiveService,
      ownershipService: driveOwnershipService,
      localFileService: localRosterFileService,
      scheduleRepository: scheduleRepository,
      legacyScheduleAdapter: legacyScheduleAdapter,
      calendarWorkflowControllerFactory:
          createAuthorizedCalendarWorkflowController,
    );
  }

  /// Creates a controller containing the existing deterministic demo data.
  AppController createDemoAppController() {
    return AppController.demo(
      auth: googleAuthService,
      settingsService: legacySettingsService,
      sheetsService: legacySheetsService,
      parser: shiftParser,
      alertService: shiftAlertService,
      calendarService: legacyCalendarService,
      archiveService: driveArchiveService,
      ownershipService: driveOwnershipService,
      localFileService: localRosterFileService,
      scheduleRepository: scheduleRepository,
      legacyScheduleAdapter: legacyScheduleAdapter,
      calendarWorkflowControllerFactory:
          createAuthorizedCalendarWorkflowController,
    );
  }

  /// Creates an independently owned controller for a canonical schedule route.
  ScheduleController createScheduleController(Schedule schedule) {
    return ScheduleController(
      service: ScheduleService(schedule: schedule),
      repository: scheduleRepository,
      validationService: createScheduleValidationService(),
    );
  }

  /// Loads roster catalogs before creating the independently owned editor.
  Future<ScheduleController> createRosterEditorController(
    Schedule schedule,
  ) async {
    final employeeResult = await employeeRepository.findAll();
    final templateResult = await shiftTemplateRepository.findAll();
    return ScheduleController(
      service: ScheduleService(
        schedule: schedule,
        employees: switch (employeeResult) {
          Success(value: final employees) => employees,
          Failure() => const [],
        },
        shifts: switch (templateResult) {
          Success(value: final templates) => [
            for (final template in templates) template.toShiftType(),
          ],
          Failure() => const [],
        },
      ),
      repository: scheduleRepository,
      validationService: createScheduleValidationService(),
    );
  }

  /// Creates the controller used by the Excel import route.
  ExcelImportController createExcelImportController() {
    return ExcelImportController(
      reader: excelReaderService,
      importEngine: importEngine,
    );
  }

  /// Creates the in-memory column-mapping controller.
  ColumnMappingController createColumnMappingController() {
    return ColumnMappingController();
  }

  /// Creates one independently owned employee-directory controller.
  EmployeeDirectoryController createEmployeeDirectoryController(
    Schedule schedule,
  ) {
    return EmployeeDirectoryController(
      schedule: schedule,
      repository: employeeRepository,
      googleAuth: googleAuthService,
    );
  }

  /// Creates one independently owned exchange workspace controller.
  ShiftExchangeController createShiftExchangeController() {
    return ShiftExchangeController();
  }

  /// Creates one independently owned shift-template controller.
  ShiftTemplateController createShiftTemplateController() {
    return ShiftTemplateController(repository: shiftTemplateRepository);
  }

  /// Converts imported rows into the canonical in-memory schedule aggregate.
  Schedule createImportedSchedule(Iterable<ShiftRecord> records) {
    return importedScheduleAdapter.createSchedule(records);
  }

  /// Creates one independently owned controller for an imported schedule.
  ScheduleController createImportedScheduleController(Schedule schedule) {
    return ScheduleController(
      service: ScheduleService(schedule: schedule),
      validationService: createScheduleValidationService(),
      repository: scheduleRepository,
      initialMonth: schedule.months.firstOrNull?.month,
    );
  }

  /// Persists a successfully converted canonical import aggregate.
  Future<Result<Schedule>> saveImportedSchedule(Schedule schedule) {
    return scheduleRepository.save(schedule);
  }

  /// Creates a rule engine from the rules registered at the composition root.
  RuleEngine createRuleEngine() {
    return RuleEngine(rules: scheduleRules, evaluator: const RuleEvaluator());
  }

  /// Creates the compatibility engine for legacy flat schedule records.
  legacy_rules.RuleEngine createLegacyRuleEngine() {
    return legacy_rules.RuleEngine(
      legacyScheduleRules,
      evaluator: const RuleEvaluator(),
    );
  }

  /// Creates the production-facing canonical schedule validation service.
  ScheduleValidationService createScheduleValidationService() {
    return ScheduleValidationService(engine: createRuleEngine());
  }

  /// Creates the resilient executor used for one authorized sync session.
  ResilientCalendarSyncExecutor createResilientCalendarSyncExecutor(
    CalendarSyncGateway gateway,
  ) {
    return ResilientCalendarSyncExecutor(
      gateway: gateway,
      historyRepository: syncHistoryRepository,
      failedRepository: failedSyncRepository,
    );
  }

  /// Creates the canonical coordinator for one authorized sync session.
  CalendarSyncCoordinator createCalendarSyncCoordinator(
    CalendarSyncGateway gateway,
  ) {
    return CalendarSyncCoordinator(
      gateway: gateway,
      planBuilder: const CalendarSyncPlanBuilder(),
      executor: createResilientCalendarSyncExecutor(gateway),
    );
  }

  /// Creates the canonical workflow controller and its resume support.
  ShiftCalendarWorkflowController createShiftCalendarWorkflowController(
    CalendarSyncGateway gateway, {
    void Function()? onDispose,
    String? Function(String key)? messageProvider,
  }) {
    return ShiftCalendarWorkflowController(
      previewBuilder: const WorkflowPreviewBuilder(),
      syncCoordinator: createCalendarSyncCoordinator(gateway),
      validationService: createScheduleValidationService(),
      resumeSyncService: ResumeSyncService(
        gateway: gateway,
        historyRepository: syncHistoryRepository,
        failedRepository: failedSyncRepository,
      ),
      onDispose: onDispose,
      messageProvider: messageProvider ?? workflowMessageProvider,
    );
  }

  /// Requests Calendar authorization and owns the client for the controller.
  Future<ShiftCalendarWorkflowController>
  createAuthorizedCalendarWorkflowController() async {
    final client = await googleAuthService.clientFor([
      calendar.CalendarApi.calendarEventsScope,
    ]);
    return createShiftCalendarWorkflowController(
      calendarSyncGatewayFactory(client),
      onDispose: client.close,
    );
  }

  /// Creates an independently owned controller for one canonical schedule.
  MonthlyScheduleReportController createMonthlyScheduleReportController(
    Schedule schedule,
  ) {
    final now = reportClock();
    final initialMonth =
        schedule.months.firstOrNull?.month ?? DateTime(now.year, now.month);
    return MonthlyScheduleReportController(
      schedule: schedule,
      reportService: monthlyScheduleReportService,
      outputGateway: reportOutputGateway,
      initialOptions: MonthlyReportOptions(
        month: initialMonth,
        generatedAt: now,
      ),
    );
  }
}

const List<Rule> _productionScheduleRules = [
  DuplicateShiftRule(),
  MissingRequiredStaffRule(),
  InvalidShiftDurationRule(),
  EmptyAssignmentRule(),
];

const List<legacy_rules.ScheduleRule> _productionLegacyScheduleRules = [
  legacy_rules.OverlappingShiftRule(),
  legacy_rules.MinimumRestRule(),
  legacy_rules.MaximumWeeklyHoursRule(),
];

T Function() _dependencyFactory<T>(T? value, T Function() fallback) {
  return value == null ? fallback : () => value;
}

/// Typed composition-root registration. It performs no global registration and
/// no runtime type lookup.
class DependencyRegistration {
  const DependencyRegistration({
    required this.employeeRepository,
    required this.scheduleRepository,
    required this.importRepository,
    required this.settingsRepository,
    required this.importService,
    required this.exportService,
    required this.calendarSyncService,
    required this.googleSheetsService,
    required this.notificationService,
  });

  final EmployeeRepository Function() employeeRepository;
  final ScheduleRepository Function() scheduleRepository;
  final ImportRepository Function() importRepository;
  final SettingsRepository Function() settingsRepository;
  final ImportService Function() importService;
  final ExportService Function() exportService;
  final CalendarSyncService Function() calendarSyncService;
  final GoogleSheetsService Function() googleSheetsService;
  final NotificationService Function() notificationService;

  AppDependencies build() {
    return AppDependencies(
      employeeRepository: employeeRepository(),
      scheduleRepository: scheduleRepository(),
      importRepository: importRepository(),
      settingsRepository: settingsRepository(),
      importService: importService(),
      exportService: exportService(),
      calendarSyncService: calendarSyncService(),
      googleSheetsService: googleSheetsService(),
      notificationService: notificationService(),
    );
  }
}
