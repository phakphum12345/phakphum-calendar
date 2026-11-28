import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:googleapis/calendar/v3.dart' as calendar;

import '../../controller/app_controller.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../domain/repositories/import_repository.dart';
import '../../domain/repositories/schedule_repository.dart';
import '../../domain/repositories/conditional_schedule_writer.dart';
import '../../domain/repositories/schedule_revision_source.dart';
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
import '../../core/google/authorized_google_gateway_session.dart';
import '../../core/google/google_scopes.dart';
import '../../features/calendar_engine/infrastructure/google_calendar_gateway.dart';
import '../../features/employees/infrastructure/google_employee_sync_service.dart';
import '../../features/google_drive/infrastructure/google_drive_gateway.dart';
import '../../features/employees/presentation/controllers/employee_directory_controller.dart';
import '../../features/employees/infrastructure/shared_preferences_employee_repository.dart';
import '../../features/calendar_engine/application/calendar_sync_plan_builder.dart';
import '../../features/calendar_engine/application/resilient_calendar_sync_executor.dart';
import '../../features/calendar_engine/application/resume_sync_service.dart';
import '../../features/calendar_engine/domain/calendar_sync_coordination_gateway.dart';
import '../../features/calendar_engine/infrastructure/backend_calendar_sync_coordination_gateway.dart';
import '../../features/calendar_engine/domain/calendar_sync_gateway.dart';
import '../../features/calendar_engine/domain/failed_sync_repository.dart';
import '../../features/calendar_engine/infrastructure/google_calendar_sync_gateway.dart';
import '../../features/calendar_engine/infrastructure/shared_preferences_failed_sync_repository.dart';
import '../../features/history/domain/sync_history_repository.dart';
import '../../features/history/application/sync_history_controller.dart';
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
import '../../features/schedule/data/backend_schedule_repository.dart';
import '../../features/schedule/data/legacy_schedule_adapter.dart';
import '../../features/schedule/data/schedule_service.dart';
import '../../features/schedule/data/shared_preferences_schedule_repository.dart';
import '../../features/schedule/presentation/controllers/schedule_controller.dart';
import '../../features/shift_exchange/presentation/controllers/shift_exchange_controller.dart';
import '../../features/shift_templates/application/shift_template_controller.dart';
import '../../features/shift_parser/application/grid_roster_import_workflow.dart';
import '../../features/shift_parser/data/backend_grid_roster_import_journal_gateway.dart';
import '../../features/shift_parser/data/grid_roster_bundle_journal.dart';
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
       _providedScheduleRepository = scheduleRepository,
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
  final ScheduleRepository? _providedScheduleRepository;

  /// Server-side coordination is enabled only when an authenticated backend is configured.
  late final CalendarSyncCoordinationGateway? calendarSyncCoordinationGateway = () {
    const baseUrl = String.fromEnvironment('ORGANIZATION_API_BASE_URL');
    if (baseUrl.trim().isEmpty) return null;
    return BackendCalendarSyncCoordinationGateway(
      baseUrl: baseUrl,
      idTokenProvider: () async => googleAuthService.account?.authentication.idToken,
    );
  }();

  /// Uses the same configured backend for every production Schedule writer.
  /// If the backend is not configured, local storage uses process-scoped
  /// revision-aware CAS. Shared multi-device writes require the backend CAS.
  late final ScheduleRepository scheduleRepository =
      _providedScheduleRepository ?? _createDefaultScheduleRepository();

  ScheduleRepository _createDefaultScheduleRepository() {
    const baseUrl = String.fromEnvironment('ORGANIZATION_API_BASE_URL');
    if (baseUrl.trim().isEmpty) return SharedPreferencesScheduleRepository();
    return BackendScheduleRepository(
      baseUrl: baseUrl,
      idTokenProvider: () async => googleAuthService.account?.authentication.idToken,
    );
  }

  /// Grid imports share the same repository instance and snapshot revision cache.
  late final ScheduleRepository gridScheduleRepository = scheduleRepository;
  /// Uses the same configured backend origin as Schedule persistence.
  /// When no backend origin is configured, the existing local journal remains
  /// the only journal and all legacy local workflows continue unchanged.
  late final GridRosterImportJournalGateway? gridRosterImportJournalGateway = () {
    const baseUrl = String.fromEnvironment('ORGANIZATION_API_BASE_URL');
    if (baseUrl.trim().isEmpty) return null;
    return BackendGridRosterImportJournalGateway(
      baseUrl: baseUrl,
      idTokenProvider: () async =>
          googleAuthService.account?.authentication.idToken,
    );
  }();

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
      shiftTemplateRepository: shiftTemplateRepository,
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
      scheduleRepository:
          _providedScheduleRepository ?? SharedPreferencesScheduleRepository(),
      shiftTemplateRepository: shiftTemplateRepository,
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

  /// Creates the repository-backed Grid workbook import workflow.
  GridRosterImportWorkflow createGridRosterImportWorkflow() {
    return GridRosterImportWorkflow(
      scheduleRepository: gridScheduleRepository,
      journal: GridRosterBundleJournal(
        store: SharedPreferencesScheduleKeyValueStore(),
      ),
      remoteJournalGateway: gridRosterImportJournalGateway,
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
      repository: gridScheduleRepository,
      initialMonth: schedule.months.firstOrNull?.month,
    );
  }

  /// Loads the current canonical imported schedule without mutating it.
  Future<Result<Schedule?>> loadImportedSchedule() {
    return gridScheduleRepository.findById('imported');
  }

  /// Creates a new imported Schedule. Replacing an existing backend
  /// Schedule must go through the reviewed Grid import workflow and its
  /// caller-owned revision token.
  Future<Result<Schedule>> saveImportedSchedule(Schedule schedule) async {
    final repository = gridScheduleRepository;
    if (repository is ConditionalScheduleWriter &&
        repository is ScheduleRevisionSource) {
      final conditionalWriter = repository as ConditionalScheduleWriter;
      final revisionSource = repository as ScheduleRevisionSource;
      final current = await repository.findById(schedule.id);
      if (current case Failure<Schedule?>()) {
        return PersistenceFailure<Schedule>(
          current.message,
          cause: current,
        );
      }
      if ((current as Success<Schedule?>).value != null) {
        return const PersistenceFailure(
          'An existing Schedule can only be replaced through the reviewed Grid import workflow.',
        );
      }
      final revision = revisionSource.revisionForAbsentSchedule(schedule.id);
      if (revision == null || revision.trim().isEmpty) {
        return const PersistenceFailure(
          'The Schedule repository did not provide an absent-Schedule revision.',
        );
      }
      return conditionalWriter.saveIfRevision(schedule, revision);
    }
    return const PersistenceFailure(
      'The configured Schedule repository does not support atomic conditional writes.',
    );
  }

  /// Creates one short-lived authorized client for a single Google account.
  ///
  /// The account is checked again after authorization so a concurrent account
  /// switch cannot attach a client created for the previous account to a new
  /// feature session.
  Future<AuthorizedGoogleGatewaySession<T>> _createGoogleGatewaySession<T>({
    required List<String> scopes,
    required T Function(auth.AuthClient client) createGateway,
  }) async {
    final account = googleAuthService.account;
    if (account == null) {
      throw StateError('กรุณาเชื่อมต่อบัญชี Google ก่อนใช้งาน');
    }

    final client = await authorizedGoogleClientFactory.create(
      account: account,
      scopes: scopes,
    );
    if (googleAuthService.account?.id != account.id) {
      client.close();
      throw StateError(
        'บัญชี Google เปลี่ยนระหว่างกำลังขอสิทธิ์ กรุณาลองใหม่อีกครั้ง',
      );
    }

    return AuthorizedGoogleGatewaySession<T>(
      gateway: createGateway(client),
      client: client,
      accountId: account.id,
    );
  }

  /// Calendar metadata verification uses calendar.readonly, not write access.
  Future<AuthorizedGoogleGatewaySession<GoogleCalendarGateway>>
  createGoogleCalendarGateway() {
    return _createGoogleGatewaySession(
      scopes: GoogleScopes.calendarMetadataRead,
      createGateway: GoogleCalendarGateway.new,
    );
  }

  /// Lists spreadsheets visible to this account using metadata-only access.
  Future<AuthorizedGoogleGatewaySession<GoogleDriveGateway>>
  createGoogleDriveGateway() {
    return _createGoogleGatewaySession(
      scopes: GoogleScopes.driveFileDiscovery,
      createGateway: GoogleDriveGateway.new,
    );
  }

  /// Reads spreadsheet cells with the least-privilege Sheets scope.
  Future<AuthorizedGoogleGatewaySession<GoogleSheetsGateway>>
  createGoogleSheetsGateway() {
    return _createGoogleGatewaySession(
      scopes: GoogleScopes.spreadsheetRead,
      createGateway: GoogleSheetsGateway.new,
    );
  }

  /// Employee directory sync is isolated to the account's Drive appDataFolder.
  Future<AuthorizedGoogleGatewaySession<GoogleEmployeeSyncService>>
  createGoogleEmployeeSyncService() {
    return _createGoogleGatewaySession(
      scopes: GoogleScopes.employeeDirectory,
      createGateway: GoogleEmployeeSyncService.new,
    );
  }

  /// Contacts transfer is optional and requests permission only when invoked.
  Future<AuthorizedGoogleGatewaySession<GoogleContactsService>>
  createGoogleContactsService() {
    return _createGoogleGatewaySession(
      scopes: GoogleScopes.contactTransfer,
      createGateway: GoogleContactsService.new,
    );
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

  /// Creates the explicit durable-history recovery controller.
  SyncHistoryController createSyncHistoryController() {
    return SyncHistoryController(
      syncHistoryRepository,
      recoverHistory: (historyId) async {
        final coordination = calendarSyncCoordinationGateway;
        if (coordination == null) {
          throw StateError('History recovery requires a configured shared backend.');
        }
        final client = await googleAuthService.clientFor([
          GoogleScopes.calendarEvents,
        ]);
        try {
          final service = ResumeSyncService(
            gateway: calendarSyncGatewayFactory(client),
            historyRepository: syncHistoryRepository,
            failedRepository: failedSyncRepository,
            coordinationGateway: coordination,
          );
          await service.recoverHistory(historyId);
        } finally {
          client.close();
        }
      },
    );
  }

  /// Creates the resilient executor used for one authorized sync session.
  ResilientCalendarSyncExecutor createResilientCalendarSyncExecutor(
    CalendarSyncGateway gateway,
  ) {
    return ResilientCalendarSyncExecutor(
      gateway: gateway,
      historyRepository: syncHistoryRepository,
      failedRepository: failedSyncRepository,
      coordinationGateway: calendarSyncCoordinationGateway,
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
        coordinationGateway: calendarSyncCoordinationGateway,
      ),
      onDispose: onDispose,
      messageProvider: messageProvider ?? workflowMessageProvider,
    );
  }

  /// Requests Calendar authorization and owns the client for the controller.
  Future<ShiftCalendarWorkflowController>
  createAuthorizedCalendarWorkflowController() async {
    final client = await googleAuthService.clientFor([
      GoogleScopes.calendarEvents,
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
