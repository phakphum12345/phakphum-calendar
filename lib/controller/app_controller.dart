import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:url_launcher/url_launcher.dart';

import '../models/app_settings.dart';
import '../models/audit_entry.dart';
import '../models/calendar_busy_period.dart';
import '../models/roster_period.dart';
import '../models/saved_sheet.dart';
import '../models/shift.dart';
import '../models/shift_alert.dart';
import '../models/tool_definition.dart';
import '../domain/entities/schedule.dart';
import '../domain/repositories/schedule_repository.dart';
import '../domain/repositories/shift_template_repository.dart';
import '../core/result/result.dart';
import '../features/schedule/data/legacy_schedule_adapter.dart';
import '../features/workflow/application/shift_calendar_workflow_controller.dart';
import '../features/diff_engine/domain/calendar_event_candidate.dart';
import '../services/calendar_service.dart';
import '../services/calendar_color_service.dart';
import '../services/drive_archive_service.dart';
import '../services/drive_ownership_service.dart';
import '../services/google_auth_service.dart';
import '../services/google_api_client.dart';
import '../services/local_roster_file_service.dart';
import '../services/settings_service.dart';
import '../services/sheets_service.dart';
import '../services/shift_alert_service.dart';
import '../services/shift_parser.dart';
import '../core/state/controller_state.dart';
import '../features/diff_engine/domain/calendar_diff.dart';
import '../services/roster_timeline_generator.dart';

class AppController extends ChangeNotifier implements ControllerState {
  factory AppController({
    required GoogleAuthGateway auth,
    required AppSettingsStore settingsService,
    required RosterSheetsGateway sheetsService,
    required RosterShiftParser parser,
    required ShiftAlertPolicy alertService,
    required LegacyCalendarGateway calendarService,
    required DriveArchiveGateway archiveService,
    required DriveOwnershipGateway ownershipService,
    required LocalRosterSource localFileService,
    required ScheduleRepository scheduleRepository,
    ShiftTemplateRepository? shiftTemplateRepository,
    required LegacyScheduleAdapter legacyScheduleAdapter,
    required Future<ShiftCalendarWorkflowController> Function()
    calendarWorkflowControllerFactory,
  }) {
    return AppController._(
      auth: auth,
      settingsService: settingsService,
      sheetsService: sheetsService,
      parser: parser,
      alertService: alertService,
      calendarService: calendarService,
      archiveService: archiveService,
      ownershipService: ownershipService,
      localFileService: localFileService,
      scheduleRepository: scheduleRepository,
      shiftTemplateRepository: shiftTemplateRepository,
      legacyScheduleAdapter: legacyScheduleAdapter,
      calendarWorkflowControllerFactory: calendarWorkflowControllerFactory,
    );
  }

  factory AppController.demo({
    required GoogleAuthGateway auth,
    required AppSettingsStore settingsService,
    required RosterSheetsGateway sheetsService,
    required RosterShiftParser parser,
    required ShiftAlertPolicy alertService,
    required LegacyCalendarGateway calendarService,
    required DriveArchiveGateway archiveService,
    required DriveOwnershipGateway ownershipService,
    required LocalRosterSource localFileService,
    required ScheduleRepository scheduleRepository,
    ShiftTemplateRepository? shiftTemplateRepository,
    required LegacyScheduleAdapter legacyScheduleAdapter,
    required Future<ShiftCalendarWorkflowController> Function()
    calendarWorkflowControllerFactory,
  }) {
    final controller = AppController(
      auth: auth,
      settingsService: settingsService,
      sheetsService: sheetsService,
      parser: parser,
      alertService: alertService,
      calendarService: calendarService,
      archiveService: archiveService,
      ownershipService: ownershipService,
      localFileService: localFileService,
      scheduleRepository: scheduleRepository,
      shiftTemplateRepository: shiftTemplateRepository,
      legacyScheduleAdapter: legacyScheduleAdapter,
      calendarWorkflowControllerFactory: calendarWorkflowControllerFactory,
    );
    controller._initializeDemo();
    return controller;
  }

  AppController._({
    required this.auth,
    required this._settingsService,
    required this._sheetsService,
    required this._parser,
    required this._alertService,
    required this._calendarService,
    required this._archiveService,
    required this._ownershipService,
    required this._localFileService,
    required this._scheduleRepository,
    this._shiftTemplateRepository,
    required this._legacyScheduleAdapter,
    required this._calendarWorkflowControllerFactory,
  });

  void _initializeDemo() {
    initialized = true;
    settings = AppSettings.defaults();
    final sourceShifts = [
      Shift(
        code: 'UP1',
        rowLabel: 'P1 เช้า',
        assignedName: 'ผู้ใช้งานตัวอย่าง',
        start: DateTime(2026, 8, 3, 8),
        end: DateTime(2026, 8, 3, 16),
        sheetTitle: 'ตัวอย่าง',
        cell: 'D5',
        category: ShiftCategory.own,
      ),
      Shift(
        code: 'UG',
        rowLabel: 'GEN',
        assignedName: 'ผู้ใช้งานตัวอย่าง',
        start: DateTime(2026, 8, 8, 7, 30),
        end: DateTime(2026, 8, 8, 12),
        sheetTitle: 'ตัวอย่าง',
        cell: 'I40',
        category: ShiftCategory.clinic,
      ),
      Shift(
        code: 'NP2',
        rowLabel: 'P2 ดึก',
        assignedName: 'ผู้ใช้งานตัวอย่าง',
        start: DateTime(2026, 8, 10),
        end: DateTime(2026, 8, 10, 8),
        sheetTitle: 'ตัวอย่าง',
        cell: 'K7',
        category: ShiftCategory.own,
      ),
      Shift(
        code: 'UP3',
        rowLabel: 'P3 เช้า',
        assignedName: 'ผู้ใช้งานตัวอย่าง',
        start: DateTime(2026, 8, 10, 8),
        end: DateTime(2026, 8, 10, 16),
        sheetTitle: 'ตัวอย่าง',
        cell: 'K9',
        category: ShiftCategory.own,
      ),
    ];
    _replaceLegacyShifts(
      _alertService.addOffDutyPeriods(sourceShifts),
      persist: false,
    );
    _rebuildAlerts();
  }

  final GoogleAuthGateway auth;
  final AppSettingsStore _settingsService;
  final RosterSheetsGateway _sheetsService;
  RosterShiftParser _parser;
  final ShiftTemplateRepository? _shiftTemplateRepository;
  List<ShiftTemplate> _shiftTemplates = const [];
  final ShiftAlertPolicy _alertService;
  final LegacyCalendarGateway _calendarService;
  final DriveArchiveGateway _archiveService;
  final DriveOwnershipGateway _ownershipService;
  final LocalRosterSource _localFileService;
  final ScheduleRepository _scheduleRepository;
  final LegacyScheduleAdapter _legacyScheduleAdapter;
  final Future<ShiftCalendarWorkflowController> Function()
  _calendarWorkflowControllerFactory;

  AppSettings settings = AppSettings.defaults();
  late LegacyScheduleConversion _legacySchedule = _legacyScheduleAdapter
      .toCanonical(
        const [],
        id: _runtimeScheduleId,
        name: _runtimeScheduleName,
      );
  Future<void> _pendingScheduleWrite = Future.value();

  /// Canonical runtime schedule used by all legacy schedule orchestration.
  Schedule get canonicalSchedule => _legacySchedule.schedule;

  /// Read-only compatibility projection for source editing and import workflows.
  /// This remains the original canonical schedule, not a transaction overlay.
  List<Shift> get shifts => _legacySchedule.toLegacyShifts();

  int get loadedRosterShiftCount => _loadedRosterShifts.length;
  int get filteredRosterShiftCount =>
      _filterToSyncDateRange(_loadedRosterShifts).length;

  final ShiftTransactionScheduleProjector _shiftTransactionProjector =
      const ShiftTransactionScheduleProjector();
  List<ShiftTransactionSnapshot> _shiftTransactions = const [];

  ShiftTransactionScheduleProjection get _shiftTransactionProjection =>
      _shiftTransactionProjector.project(
        source: canonicalSchedule,
        transactions: _shiftTransactions,
      );

  /// Effective view with approved transfers applied; canonical source is untouched.
  Schedule get effectiveSchedule => _shiftTransactionProjection.schedule;

  /// Legacy read-only view of the effective schedule, retaining imported metadata.
  List<Shift> get effectiveShifts =>
      _legacySchedule.toLegacyShifts(schedule: effectiveSchedule);

  List<String> get shiftTransactionProjectionWarnings =>
      _shiftTransactionProjection.warnings;

  void updateShiftTransactions(List<ShiftTransactionSnapshot> transactions) {
    final pending = _pendingShiftTransactionCalendarSync;
    if (pending != null) {
      final latest = transactions.where((item) => item.id == pending.transactionId);
      if (latest.length != 1 ||
          latest.single.version != pending.transactionVersion) {
        cancelShiftTransactionCalendarSyncPreview();
      }
    }
    _shiftTransactions = List.unmodifiable(transactions);
    notifyListeners();
  }

  void clearShiftTransactions() {
    cancelShiftTransactionCalendarSyncPreview();
    if (_shiftTransactions.isEmpty) return;
    _shiftTransactions = const [];
    notifyListeners();
  }
  List<ShiftAlert> alerts = [];
  List<CalendarBusyPeriod> calendarPeriods = [];
  Map<String, ShiftAlertDecision> alertDecisions = {};
  List<AuditEntry> auditEntries = [];
  List<SavedSheet> savedSheets = [];
  List<RecentOwnedSheet> recentOwnedSheets = [];
  Set<String> existingKeys = {};
  List<String> sheetTitles = [];
  Set<String> pinnedToolIds = {...defaultPinnedToolIds};
  // Keep Google Calendar audit history enabled by default; callers can still
  // disable it explicitly for a session when the user requests that.
  bool shiftTimelineEnabled = true;
  bool initialized = false;
  bool busy = false;
  bool recentSheetHistoryLoaded = false;
  String? status;
  @override
  String? error;
  DateTime? lastRefresh;
  Timer? _autoRefreshTimer;
  String? _observedAccountId;
  String? localSourceLabel;
  final Map<String, _ShiftOverride> _shiftOverrides = {};
  ShiftCalendarWorkflowController? _pendingCalendarWorkflow;
  _PendingShiftTransactionCalendarSync? _pendingShiftTransactionCalendarSync;

  static const _runtimeScheduleId = 'legacy-runtime';
  static const _runtimeScheduleName = 'Legacy runtime schedule';

  @override
  bool get loading => busy;

  @override
  bool get success => initialized && !busy && error == null;

  @override
  String? get message => error ?? status;

  int get includedCount => shifts.where((shift) => !shift.excluded).length;
  int get existingCount => shifts.where(_matchesCurrentCalendar).length;
  int get newCount => shifts
      .where((shift) => !shift.excluded && !_matchesCurrentCalendar(shift))
      .length;
  int get pendingAlertCount => alerts.where((alert) => alert.isPending).length;
  int get conflictAlertCount =>
      alerts.where((alert) => alert.isConflict).length;

  bool _matchesCurrentCalendar(Shift shift) =>
      _calendarService.matchesExistingShift(shift, existingKeys) ||
      calendarPeriods.any(
        (period) => CalendarService.matchesEquivalentPeriod(shift, period),
      );

  List<String> get rosterSearchNames {
    final names = <String>{};
    final enteredName = settings.targetName.trim();
    if (enteredName.isNotEmpty) names.add(enteredName);
    final displayName = auth.account?.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      names.add(displayName);
      names.addAll(
        displayName
            .split(RegExp(r'\s+'))
            .map((part) => part.trim())
            .where((part) => part.length >= 2),
      );
    }
    return names.toList(growable: false);
  }

  Future<void> initialize() async {
    if (initialized) return;
    try {
      settings = await _settingsService.load();
    } catch (caught) {
      error = 'โหลดการตั้งค่าไม่สำเร็จ: $caught';
    }
    try {
      auditEntries = await _settingsService.loadAudit();
    } catch (caught) {
      error ??= 'โหลดบันทึกไม่สำเร็จ: $caught';
    }
    try {
      savedSheets = await _settingsService.loadSavedSheets();
      await _ensureActiveSavedSheetPerAccount();
    } catch (caught) {
      error ??= 'โหลดรายการชีตที่บันทึกไม่สำเร็จ: $caught';
    }
    try {
      pinnedToolIds = await _settingsService.loadPinnedToolIds();
    } catch (caught) {
      error ??= 'โหลดแถบเครื่องมือไม่สำเร็จ: $caught';
    }
    try {
      await _ensureActiveSavedSheetPerAccount();
    } catch (caught) {
      error ??= 'ปรับข้อมูลแหล่งชีตเดิมไม่สำเร็จ: $caught';
    }
    auth.addListener(_onAuthChanged);
    await auth.initialize(webClientId: settings.googleWebClientId);
    initialized = true;
    notifyListeners();
  }

  Future<void> signIn() => auth.signIn();

  Future<void> authorizeReadAccess() async {
    await _run('ขอสิทธิ์อ่าน Google Sheets, Drive และ Calendar', () async {
      await auth.requestReadAccess();
      status = 'อนุญาตสิทธิ์อ่าน Google Sheets, Drive และ Calendar สำเร็จ';
      await _addAudit('auth.read', status!, true);
    });
  }

  Future<void> signOut() async {
    _timelineLoadGeneration++;
    timelineLoading = false;
    await auth.signOut();
    _autoRefreshTimer?.cancel();
    _replaceLegacyShifts(const []);
    _shiftTransactions = const [];
    alerts = [];
    calendarPeriods = [];
    existingKeys = {};
    sheetTitles = [];
    recentOwnedSheets = [];
    localSourceLabel = null;
    _shiftOverrides.clear();
    recentSheetHistoryLoaded = false;
    lastRefresh = null;
    status = 'ออกจากระบบ Google แล้ว';
    notifyListeners();
  }

  Future<void> configureGoogleWebClientId(String value) async {
    final clientId = value.trim();
    if (!auth.validateWebClientId(clientId)) {
      throw const FormatException(
        'รูปแบบ Google Web OAuth Client ID ไม่ถูกต้อง',
      );
    }
    settings = settings.copyWith(googleWebClientId: clientId);
    await _settingsService.save(settings);
    await auth.configureWebClientId(clientId);
    status = 'ตั้งค่า Google OAuth สำหรับ Web สำเร็จ';
    await _addAudit('auth.configure', status!, true);
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings next) async {
    final periodChanged = !listEquals(
      next.effectivePeriods,
      settings.effectivePeriods,
    );
    if (periodChanged) {
      calendarPeriods = [];
      existingKeys = {};
      // A month change invalidates any previously customized date range.
      // Recompute it from the selected periods instead of retaining a stale
      // range that could silently point at a different month.
      syncRangeStart = null;
      syncRangeEnd = null;
      _syncRangeCustomized = false;
    }
    settings = next;
    await _settingsService.save(next);
    if (periodChanged) {
      monthlyRoster = _filterMonthlyReportToSelectedPeriods(_allMonthlyRoster);
      _setDefaultSyncDateRange(_loadedRosterShifts);
      if (_loadedRosterShifts.isNotEmpty) {
        final selectedShifts = _filterToSyncDateRange(_loadedRosterShifts);
        _replaceLegacyShifts(
          _alertService.addOffDutyPeriods(
            _applyReferenceRelationships(selectedShifts),
          ),
        );
      }
      _rebuildAlerts();
    }
    _scheduleAutoRefresh();
    notifyListeners();
  }

  Future<void> _ensureActiveSavedSheetPerAccount() async {
    final accountIds = savedSheets
        .map((sheet) => sheet.ownerAccountId)
        .where((id) => id.isNotEmpty)
        .toSet();
    var changed = false;
    for (final accountId in accountIds) {
      final accountSheets = savedSheets
          .where((sheet) => sheet.ownerAccountId == accountId)
          .toList()
        ..sort((left, right) => right.savedAt.compareTo(left.savedAt));
      if (accountSheets.any((sheet) => sheet.isActive) ||
          accountSheets.isEmpty) {
        continue;
      }
      final activeKey = accountSheets.first.key;
      savedSheets = [
        for (final item in savedSheets)
          if (item.key == activeKey) item.copyWith(isActive: true) else item,
      ];
      changed = true;
    }
    if (changed) await _settingsService.saveSavedSheets(savedSheets);
  }

  Iterable<ToolDefinition> get pinnedTools =>
      toolCatalog.where((tool) => pinnedToolIds.contains(tool.id));

  List<SavedSheet> get savedSheetsForCurrentAccount {
    final accountId = auth.account?.id;
    if (accountId == null) return const [];
    return savedSheets
        .where((sheet) => sheet.ownerAccountId == accountId)
        .toList()
      ..sort((left, right) {
        if (left.isActive != right.isActive) return left.isActive ? -1 : 1;
        return right.savedAt.compareTo(left.savedAt);
      });
  }

  /// Only an explicitly selected source is used for roster import/sync.
  /// Saved sources are not automatically substituted when selection is empty.
  SavedSheet? get currentSourceSheet =>
      savedSheetsForCurrentAccount.where((sheet) => sheet.isActive).firstOrNull;

  String get currentSourceUrl => currentSourceSheet?.url ?? '';

  bool get hasSelectedSourceSheet => currentSourceSheet != null;
  bool get hasRosterSource =>
      currentSourceSheet != null || localSourceLabel != null;

  String get selectedSourceSheetTitle =>
      localSourceLabel ??
      currentSourceSheet?.displayTitle ??
      'ยังไม่ได้เลือกแหล่งข้อมูลเวร';

  bool isToolPinned(String id) => pinnedToolIds.contains(id);

  Future<void> toggleToolPinned(ToolDefinition tool) async {
    if (pinnedToolIds.contains(tool.id)) {
      pinnedToolIds = {...pinnedToolIds}..remove(tool.id);
      status = 'นำ ${tool.name} ออกจากแถบแล้ว';
    } else {
      pinnedToolIds = {...pinnedToolIds, tool.id};
      status = 'ติดตั้ง ${tool.name} ในแถบแล้ว';
    }
    await _settingsService.savePinnedToolIds(pinnedToolIds);
    notifyListeners();
  }

  Future<void> openTool(ToolDefinition tool) async {
    final opened = await launchUrl(
      tool.uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened) throw StateError('ไม่สามารถเปิด ${tool.name} ได้');
    status = 'เปิด ${tool.name} แล้ว';
    notifyListeners();
  }

  Future<void> saveCurrentSheet() async {
    final sourceUrl = currentSourceUrl;
    if (sourceUrl.isEmpty) {
      throw StateError('กรุณาเลือกไฟล์ Google Sheets หลักในหน้าแรกก่อน');
    }
    await selectSourceForCurrentAccount(sourceUrl);
  }

  Future<void> clearRosterSourceSelection() async {
    _timelineLoadGeneration++;
    timelineLoading = false;
    await _run('ยกเลิกการเลือกตารางเวร', () async {
      final accountId = auth.account?.id;
      if (accountId != null) {
        savedSheets = [
          for (final sheet in savedSheets)
            if (sheet.ownerAccountId != accountId)
              sheet
            else
              sheet.copyWith(isActive: false),
        ];
        await _settingsService.saveSavedSheets(savedSheets);
      }

      localSourceLabel = null;
      _autoRefreshTimer?.cancel();
      _replaceLegacyShifts(const []);
      alerts = [];
      calendarPeriods = [];
      existingKeys = {};
      sheetTitles = [];
      monthlyRoster = const MonthlyRosterParseReport(
        sections: [],
        warnings: [],
      );
      monthlyRosterConversion = const MonthlyRosterConversionReport(
        shifts: [],
        unconvertedAssignments: [],
      );
      _loadedRosterShifts = [];
      _currentAllRosterShifts = [];
      _referenceAllRosterShifts = [];
      _revisionTimelines = const {};
      _loadedRevisionCount = 0;
      timelineWarning = null;
      _resetSyncRange();
      status = 'ยกเลิกการเลือกตารางแล้ว; ไฟล์ต้นฉบับยังอยู่ใน Google Sheets';
      await _addAudit(
        'sheet.source.clear',
        'ยกเลิกการเลือกแหล่งข้อมูลเวรสำหรับบัญชีปัจจุบัน; ไม่ได้ลบไฟล์ต้นฉบับ',
        true,
      );
    });
  }

  Future<void> findAvailableSourceSheets({
    OwnedSheetOrder order = OwnedSheetOrder.recentlyModified,
  }) async {
    if (!auth.isSignedIn) {
      throw StateError('กรุณาเข้าสู่ระบบ Google ก่อนเลือกไฟล์');
    }

    await _run('กำลังค้นหา Google Sheets จาก Google Drive', () async {
      final client = await auth.clientFor([
        drive.DriveApi.driveMetadataReadonlyScope,
      ]);
      try {
        recentOwnedSheets = order == OwnedSheetOrder.firstCreated
            ? await _ownershipService.listFirstSpreadsheetOfEachMonth(
                client,
                limit: 1000,
              )
            : await _ownershipService.listOwnedSpreadsheets(
                client,
                limit: 100,
                order: order,
              );
        recentSheetHistoryLoaded = true;
        status = recentOwnedSheets.isEmpty
            ? 'ไม่พบ Google Sheets ที่บัญชีนี้เข้าถึงได้'
            : 'พบ Google Sheets ${recentOwnedSheets.length} ไฟล์';
        await _addAudit(
          'drive.sheet_picker.read',
          'อ่านรายการ Google Sheets แบบอ่านอย่างเดียว พบ '
              '${recentOwnedSheets.length} ไฟล์; ไม่บันทึกชื่อไฟล์ใน Audit log',
          true,
        );
      } finally {
        client.close();
      }
    });
  }

  Future<void> findRecentSourceSheets() => findAvailableSourceSheets();

  Future<void> selectRecentSourceSheet(RecentOwnedSheet sheet) async {
    await selectRecentSourceSheets([sheet]);
  }

  Future<void> selectRecentSourceSheets(
    List<RecentOwnedSheet> selectedSheets,
  ) async {
    final account = auth.account;
    if (account == null) throw StateError('กรุณาล็อกอิน Google ก่อน');

    final uniqueSheets = <String, RecentOwnedSheet>{
      for (final sheet in selectedSheets) sheet.id: sheet,
    }.values.toList(growable: false);

    if (uniqueSheets.isEmpty) return;

    await _run('ตรวจและเพิ่ม Google Sheets ที่เลือก', () async {
      final client = await auth.clientFor([
        sheets.SheetsApi.spreadsheetsReadonlyScope,
        drive.DriveApi.driveMetadataReadonlyScope,
      ]);

      try {
        var addedCount = 0;
        final shouldActivateFirst = currentSourceSheet == null;
        final firstSelectedId = uniqueSheets.first.id;

        // Keep an existing explicit selection when adding more files.
        // If no source is active yet, use the first file the user selected.
        for (final selected in uniqueSheets.reversed) {
          await _ownershipService.requireOwnedSpreadsheet(client, selected.id);
          final reference = await _sheetsService.describeSpreadsheet(
            client,
            selected.url,
          );
          await _saveSheetReference(
            account.id,
            reference,
            setActive:
                shouldActivateFirst && selected.id == firstSelectedId,
          );
          addedCount++;
        }

        status = addedCount == 1
            ? 'เพิ่ม Google Sheets 1 ไฟล์แล้ว'
            : 'เพิ่ม Google Sheets $addedCount ไฟล์แล้ว';
        await _addAudit(
          'sheet.source.add_many',
          'ตรวจสิทธิ์และบันทึก Google Sheets $addedCount ไฟล์ไว้เฉพาะในเครื่อง',
          true,
        );
      } finally {
        client.close();
      }
    });
  }

  Future<void> selectSourceForCurrentAccount(String sourceUrl) async {
    _timelineLoadGeneration++;
    timelineLoading = false;
    final account = auth.account;
    if (account == null) throw StateError('กรุณาล็อกอิน Google ก่อน');
    final normalizedUrl = sourceUrl.trim();
    final spreadsheetId = _sheetsService.parseSpreadsheetId(normalizedUrl);
    await _run('ตรวจและเลือกไฟล์ชีตหลักของบัญชีนี้', () async {
      final client = await auth.clientFor([
        sheets.SheetsApi.spreadsheetsReadonlyScope,
        drive.DriveApi.driveMetadataReadonlyScope,
      ]);
      try {
        await _ownershipService.requireOwnedSpreadsheet(client, spreadsheetId);
        final reference = await _sheetsService.describeSpreadsheet(
          client,
          normalizedUrl,
        );
        final saved = await _saveSheetReference(account.id, reference);
        localSourceLabel = null;
        status = 'เลือก “${saved.displayTitle}” เป็นไฟล์หลักของบัญชีนี้แล้ว';
        await _addAudit(
          'sheet.source.select',
          'ตรวจสิทธิ์เข้าถึงและบันทึก “${saved.displayTitle}” '
              'ไว้เฉพาะในเครื่อง',
          true,
        );
      } finally {
        client.close();
      }
    });
  }

  Future<void> activateSavedSheet(SavedSheet sheet) async {
    _requireSheetOwner(sheet);
    await selectSourceForCurrentAccount(sheet.url);
  }

  Future<void> openSavedSheet(SavedSheet sheet) async {
    _requireSheetOwner(sheet);
    await _run('เปิดชีตที่บันทึก', () async {
      final opened = await launchUrl(
        Uri.parse(sheet.url),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened) throw StateError('ไม่สามารถเปิดลิงก์ Google Sheets ได้');
      status = 'เปิด “${sheet.displayTitle}” แล้ว';
      await _addAudit(
        'sheet.reference.open',
        'เปิดชีตที่บันทึก “${sheet.displayTitle}”',
        true,
      );
    });
  }

  Future<void> deleteSavedSheet(SavedSheet sheet) async {
    _requireSheetOwner(sheet);
    if (currentSourceSheet?.key == sheet.key) {
      _timelineLoadGeneration++;
      timelineLoading = false;
    }
    await _run('ลบชีตออกจากรายการบันทึก', () async {
      final wasCurrent = currentSourceSheet?.key == sheet.key;
      savedSheets = [
        for (final item in savedSheets)
          if (item.key == sheet.key) item.copyWith(isActive: false) else item,
      ];
      await _settingsService.saveSavedSheets(savedSheets);
      if (wasCurrent) {
        _replaceLegacyShifts(const []);
        alerts = [];
        calendarPeriods = [];
        existingKeys = {};
        sheetTitles = [];
        _autoRefreshTimer?.cancel();
      }
      status = 'นำ “${sheet.displayTitle}” ออกจากไฟล์หลักแล้ว; ยังเก็บไว้ในประวัติ';
      await _addAudit(
        'sheet.reference.delete',
        'นำ “${sheet.displayTitle}” ออกจากไฟล์หลัก; ยังเก็บประวัติไว้และไม่ได้ลบไฟล์ Google Sheets',
        true,
      );
    });
  }

  /// Explicitly reloads the selected Google Sheet and its historical Drive
  /// revisions for Timeline. This operation is read-only and must never trigger
  /// automatic writes to Google Calendar.
  Future<void> syncHistoricalTimeline() async {
    if (busy) throw StateError('กำลังทำงานอื่นอยู่ กรุณารอสักครู่');
    if (!auth.isSignedIn) throw StateError('กรุณาเข้าสู่ระบบ Google ก่อน');
    if (!hasSelectedSourceSheet) {
      throw StateError('กรุณาเลือก Google Sheets ที่ต้องการซิงค์ Timeline ก่อน');
    }

    await loadRoster(
      allowAutomaticCalendarSync: false,
      refreshHistoricalTimeline: true,
    );
    if (error != null) return;

    final warning = timelineWarning;
    status = warning == null
        ? 'อ่านตารางเวรแล้ว; กำลังซิงค์ Timeline ย้อนหลังเบื้องหลัง'
        : 'อ่านตารางเวรแล้ว; Timeline ย้อนหลังมีข้อจำกัด: $warning';
    await _addAudit('sheet.timeline.sync.started', status!, true);
    notifyListeners();
  }

  Future<void> loadRoster({
    bool background = false,
    bool allowAutomaticCalendarSync = true,
    bool refreshHistoricalTimeline = false,
  }) async {
    final timelineGeneration = ++_timelineLoadGeneration;
    timelineLoading = false;
    dynamic pendingTimelineSnapshots;
    String? pendingTimelineSpreadsheetId;
    String? pendingTimelineAccountId;
    String? pendingTimelineScope;
    await _run('อ่านตารางเวร', () async {
      final sourceUrl = localSourceLabel == null ? currentSourceUrl : '';
      if (sourceUrl.isEmpty) {
        throw StateError(
          'ยังไม่ได้เลือกไฟล์หลักของบัญชีนี้',
        );
      }
      final searchNames = rosterSearchNames;
      if (searchNames.isEmpty) {
        throw const FormatException(
          'กรุณากรอกชื่อที่ต้องค้นหา หรือตรวจชื่อโปรไฟล์ Google',
        );
      }
      final client = await auth.clientFor([
        sheets.SheetsApi.spreadsheetsReadonlyScope,
        drive.DriveApi.driveMetadataReadonlyScope,
      ], promptIfNecessary: !background);
      try {
        final spreadsheetId = _sheetsService.parseSpreadsheetId(sourceUrl);
        await _ownershipService.requireOwnedSpreadsheet(client, spreadsheetId);
        final snapshots = await _sheetsService.readAll(client, sourceUrl);
        final legacyParsed = _parseRosterSnapshots(
          snapshots,
          searchNames: searchNames,
        );
        final periods = _periodsForShifts(parsed);
        _replaceLegacyShifts(_alertService.addOffDutyPeriods(parsed));
        localSourceLabel = null;
        sheetTitles = snapshots.map((sheet) => sheet.title).toList();
        existingKeys = {};
        calendarPeriods = [];
        _rebuildAlerts(applyDecisions: true);
        lastRefresh = DateTime.now();
        final offCount = shifts.where((shift) => shift.isOffDuty).length;
        final colorCount = parsed
            .where((shift) => shift.sourceColorValue != null)
            .length;
        status =
            'พบเวรของ ${searchNames.first} ${parsed.length} รายการ '
            'จาก ${periods.length} เดือน • '
            'อ่านสีจากไฟล์หลัก $colorCount รายการ • '
            'สร้าง OFF $offCount รายการ • รอตัดสินใจ $pendingAlertCount รายการ';
        await _addAudit(
          'sheet.read',
          'อ่าน ${snapshots.length} แท็บ ${periods.length} เดือน '
              'พบ ${parsed.length} เวร '
              'อ่านสีจากไฟล์หลัก $colorCount รายการ และสร้าง OFF '
              '$offCount รายการ; ไม่มีการแก้ไขชีต',
          true,
        );
      } finally {
        client.close();
      }
    });
    if (pendingTimelineSnapshots != null &&
        pendingTimelineSpreadsheetId != null &&
        pendingTimelineScope != null) {
      timelineLoading = true;
      timelineWarning = 'กำลังโหลด Timeline ย้อนหลังเบื้องหลัง';
      notifyListeners();
      unawaited(
        _loadTimelineInBackground(
          snapshots: pendingTimelineSnapshots,
          spreadsheetId: pendingTimelineSpreadsheetId!,
          accountId: pendingTimelineAccountId,
          timelineScope: pendingTimelineScope!,
          background: background,
          refreshHistoricalTimeline: refreshHistoricalTimeline,
          generation: timelineGeneration,
        ),
      );
    }
    _scheduleAutoRefresh();
    // A roster read must never write to Google Calendar. Keep compatibility
    // with legacy autoSync settings, but require the normal preview and the
    // explicit confirmation dialog for every Calendar mutation.
    if (allowAutomaticCalendarSync && settings.autoSync && auth.isSignedIn) {
      final message = pendingAlertCount > 0
          ? 'ข้ามการซิงก์อัตโนมัติเนื่องจากมีแจ้งเตือนค้าง $pendingAlertCount รายการ'
          : 'ยังไม่เขียน Google Calendar อัตโนมัติ; กรุณาตรวจตัวอย่างและยืนยันการซิงก์ด้วยตนเอง';
      await _addAudit('auto.sync.requires_confirmation', message, true);
    }
  }

  Future<void> _loadTimelineInBackground({
    required dynamic snapshots,
    required String spreadsheetId,
    required String? accountId,
    required String timelineScope,
    required bool background,
    required bool refreshHistoricalTimeline,
    required int generation,
  }) async {
    if (generation != _timelineLoadGeneration || !auth.isSignedIn) return;
    GoogleApiClient? client;
    try {
      client = await auth.clientFor([
        sheets.SheetsApi.spreadsheetsReadonlyScope,
        drive.DriveApi.driveMetadataReadonlyScope,
        drive.DriveApi.driveReadonlyScope,
      ], promptIfNecessary: false);
      if (generation != _timelineLoadGeneration) return;
    final currentRevision = RosterRevisionDocument(
      revisionId: 'current',
      modifiedAt: DateTime.now(),
      snapshots: snapshots,
    );
    final timelineGenerator = RosterTimelineGenerator(
      shiftTemplates: _shiftTemplates,
    );
    void appendTimelineGenerationWarnings(Iterable<String> source) {
      final messages = source.toList(growable: false);
      if (messages.isEmpty) return;
      final shown = messages.take(4).join('；');
      final more = messages.length > 4
          ? ' และอีก ${messages.length - 4} รายการ'
          : '';
      final warning = 'Timeline มีข้อมูลบางส่วนที่ถูกข้าม: $shown$more';
      timelineWarning = timelineWarning == null
          ? warning
          : '$timelineWarning; $warning';
    }
    if (background &&
        _loadedRevisionCount > 0 &&
        _loadedTimelineScope == timelineScope) {
      timelineWarning =
          'ใช้ประวัติ Timeline จากการอ่านล่าสุด; '
          'กดอ่านใหม่เพื่อโหลด revision ล่าสุดจาก Drive';
    } else {
      if (generation == _timelineLoadGeneration) timelineWarning = null;
      try {
        final skippedArchiveRevisionIds = <String>{};
        final skippedDriveRevisionIds = <String>{};
        final legacyAccountId = auth.account?.email.trim();
        const archive = TimelineArchiveService();
        var archivedRevisions = <RosterRevisionDocument>[];

        // Render the durable local archive first. A temporary Drive or
        // network failure must not hide history already saved on this device.
        if (accountId != null && accountId.isNotEmpty) {
          try {
            archivedRevisions = await archive.readRevisionsWithLegacyAccountScope(
              accountId: accountId,
              legacyAccountId: legacyAccountId,
              fileId: spreadsheetId,
              onRevisionSkipped: (revisionId, error) {
                skippedArchiveRevisionIds.add(revisionId);
              },
              onMigrationError: (migrationError) {
                final message =
                    'ย้ายคลัง Timeline จากอีเมลไปยังรหัสบัญชี Google ไม่สำเร็จ: '
                    '$migrationError';
                if (generation == _timelineLoadGeneration) timelineWarning = message;
                unawaited(_addAudit(
                  'sheet.timeline.archive.migration.failed',
                  message,
                  false,
                ));
              },
            );
          } on Object catch (archiveReadError) {
            final archiveWarning =
                'อ่านคลัง Timeline ในเครื่องไม่สำเร็จ: $archiveReadError';
            if (generation == _timelineLoadGeneration) timelineWarning = archiveWarning;
            await _addAudit(
              'sheet.timeline.archive.read.failed',
              archiveWarning,
              false,
            );
          }
        } else {
          if (generation == _timelineLoadGeneration) {
            timelineWarning =
                'ไม่พบอีเมลบัญชี Google จึงไม่สามารถแยกคลัง Timeline ตามบัญชีได้';
          }
        }
        skippedArchiveRevisionIds.removeAll(
          archivedRevisions.map((revision) => revision.revisionId),
        );

        try {
          if (generation != _timelineLoadGeneration) return;
          final knownRevisionIds = archivedRevisions
              .map((revision) => revision.revisionId)
              .toSet();
          // Bootstrap an empty local archive once so historical Timeline
          // remains available on first use. Routine reads with an existing
          // archive avoid Drive revision exports; explicit refresh still
          // checks Drive for revisions added since the last archive.
          final shouldRefreshDriveHistory =
              refreshHistoricalTimeline ||
              archivedRevisions.isEmpty ||
              skippedArchiveRevisionIds.isNotEmpty;
          final missingRevisions = shouldRefreshDriveHistory
              ? await const RosterRevisionService().readHistoryTransient(
                  client,
                  spreadsheetId,
                  knownRevisionIds: knownRevisionIds,
                  onRevisionSkipped: (revisionId, error) {
                    skippedDriveRevisionIds.add(revisionId);
                  },
                )
              : <RosterRevisionDocument>[];

          if (generation != _timelineLoadGeneration) return;
          final recoveredRevisionIds = missingRevisions
              .map((revision) => revision.revisionId)
              .toSet();
          final unresolvedRevisionIds = <String>{
            ...skippedArchiveRevisionIds.difference(recoveredRevisionIds),
            ...skippedDriveRevisionIds,
          };

          // Persist each downloaded revision before adding it to the
          // in-memory timeline. If a write fails, the local archive remains
          // valid and the warning makes the incomplete refresh visible.
          if (accountId != null && accountId.isNotEmpty) {
            for (final revision in missingRevisions) {
              await archive.putRevision(
                accountId: accountId,
                fileId: spreadsheetId,
                document: revision,
              );
            }
          }

          final mergedRevisions = <String, RosterRevisionDocument>{
            for (final revision in archivedRevisions)
              revision.revisionId: revision,
            for (final revision in missingRevisions)
              revision.revisionId: revision,
          }.values.toList()
            ..sort((left, right) =>
                left.modifiedAt.compareTo(right.modifiedAt));

          if (generation != _timelineLoadGeneration) return;
          _loadedRevisionCount = mergedRevisions.length + 1;
          final generatedTimeline = await timelineGenerator
              .generateFromDocumentsWithDiagnosticsAsync([
                ...mergedRevisions,
                currentRevision,
              ]);
          _revisionTimelines = generatedTimeline.timelines;
          _loadedTimelineScope = timelineScope;
          if (mergedRevisions.isEmpty) {
            timelineWarning = shouldRefreshDriveHistory
                ? 'ไม่พบประวัติ revision ที่อ่านได้ จึงแสดงเฉพาะรายชื่อเวรปัจจุบัน'
                : 'ใช้คลัง Timeline ในเครื่อง; กด “ซิงค์ Timeline ย้อนหลัง” เพื่อตรวจ revision ใหม่จาก Drive';
          }
          appendTimelineGenerationWarnings(generatedTimeline.warnings);
          if (unresolvedRevisionIds.isNotEmpty) {
            final skippedIds = unresolvedRevisionIds.toList()..sort();
            final shownIds = skippedIds.take(5).join(', ');
            final more = skippedIds.length > 5
                ? ' และอีก ${skippedIds.length - 5} รายการ'
                : '';
            final skippedWarning =
                'อ่าน revision ไม่สำเร็จ ${skippedIds.length} รายการ '
                '($shownIds$more); Timeline อาจไม่ครบ';
            timelineWarning = timelineWarning == null
                ? skippedWarning
                : '$timelineWarning; $skippedWarning';
          }
        } on Object catch (historyError) {
          if (generation != _timelineLoadGeneration) return;
          _loadedRevisionCount = archivedRevisions.length + 1;
          final fallbackTimeline = await timelineGenerator
              .generateFromDocumentsWithDiagnosticsAsync([
                ...archivedRevisions,
                currentRevision,
              ]);
          _revisionTimelines = fallbackTimeline.timelines;
          appendTimelineGenerationWarnings(fallbackTimeline.warnings);
          _loadedTimelineScope = timelineScope;
          final fallbackWarning = archivedRevisions.isEmpty
              ? 'อ่านประวัติ Timeline จาก Drive ไม่สำเร็จและไม่มีคลังในเครื่อง: $historyError'
              : 'Drive ยังอ่านประวัติใหม่ไม่ได้ จึงใช้ Timeline ที่บันทึกในเครื่อง '
                    '(${archivedRevisions.length} revision): $historyError';
          timelineWarning = timelineWarning == null
              ? fallbackWarning
              : '$timelineWarning; $fallbackWarning';
          await _addAudit(
            'sheet.timeline.drive.failed',
            fallbackWarning,
            false,
          );
        }
      } on Object catch (caught, stackTrace) {
        if (generation != _timelineLoadGeneration) return;
        _loadedRevisionCount = 1;
        final currentTimeline = await timelineGenerator
            .generateFromDocumentsWithDiagnosticsAsync([currentRevision]);
        _revisionTimelines = currentTimeline.timelines;
        _loadedTimelineScope = timelineScope;
        timelineWarning =
            'อ่านประวัติ Timeline จาก Google Drive ไม่สำเร็จ: $caught';
        appendTimelineGenerationWarnings(currentTimeline.warnings);
        await _addAudit('sheet.timeline.failed', timelineWarning!, false);
        debugPrintStack(
          label: 'Could not load Google Sheets revision timeline',
          stackTrace: stackTrace,
        );
      }
    }

      if (generation == _timelineLoadGeneration) {
        if (_loadedRosterShifts.isNotEmpty) {
          final visibleShifts = _filterToSyncDateRange(_loadedRosterShifts);
          _replaceLegacyShifts(
            _alertService.addOffDutyPeriods(
              _applyReferenceRelationships(visibleShifts),
            ),
            persist: false,
          );
        }
        timelineLoading = false;
        notifyListeners();
      }
    } catch (caught, stackTrace) {
      if (generation == _timelineLoadGeneration) {
        timelineWarning = 'อ่านประวัติ Timeline เบื้องหลังไม่สำเร็จ: $caught';
        timelineLoading = false;
        _loadedRevisionCount = 1;
        _revisionTimelines = const {};
        await _addAudit('sheet.timeline.background.failed', timelineWarning!, false);
        notifyListeners();
      }
      debugPrintStack(label: 'Background roster Timeline load failed', stackTrace: stackTrace);
    } finally {
      client?.close();
    }
  }

  Future<void> importLocalRosterFile() async {
    final searchNames = rosterSearchNames;
    if (searchNames.isEmpty) {
      throw const FormatException(
        'กรุณากรอกชื่อที่ต้องค้นหา หรือล็อกอินเพื่อใช้ชื่อโปรไฟล์ Google',
      );
    }
    await _run('เลือกและอ่านไฟล์ตารางเวรในเครื่อง', () async {
      final document = await _localFileService.pickAndRead();
      if (document == null) {
        status = 'ยกเลิกการเลือกไฟล์';
        return;
      }
      final legacyParsed = _parseRosterSnapshots(
        document.snapshots,
        searchNames: searchNames,
      );
      _replaceLegacyShifts(_alertService.addOffDutyPeriods(parsed));
      sheetTitles = document.snapshots.map((sheet) => sheet.title).toList();
      localSourceLabel = 'ไฟล์ .${document.extension} ในเครื่อง';
      existingKeys = {};
      calendarPeriods = [];
      _autoRefreshTimer?.cancel();
      _rebuildAlerts(applyDecisions: true);
      lastRefresh = DateTime.now();
      status =
          'อ่านไฟล์ .${document.extension} ${document.snapshots.length} แท็บ '
          'พบ ${parsed.length} เวร; ไฟล์ไม่ถูกอัปโหลด';
      await _addAudit(
        'local_file.read',
        'อ่านไฟล์ .${document.extension} ในหน่วยความจำ '
            '${document.snapshots.length} แท็บ พบ ${parsed.length} เวร; '
            'ไม่บันทึกชื่อไฟล์หรือเนื้อหาใน Audit log',
        true,
      );
    });
  }

  void refreshNow() {
    if (!busy && auth.isSignedIn) {
      unawaited(loadRoster());
    }
  }

  Future<void> compareCalendar() async {
    if (effectiveShifts.isEmpty) throw StateError('กรุณาอ่านตารางเวรก่อน');
    await _run('เปรียบเทียบ Google Calendar', () async {
      final periods = _activeRosterPeriods();
      final client = await auth.clientFor([
        calendar.CalendarApi.calendarEventsReadonlyScope,
      ]);
      try {
        final snapshot = await _readCalendarPeriods(client, periods);
        existingKeys = snapshot.sourceKeys;
        calendarPeriods = snapshot.busyPeriods;
        _rebuildAlerts();
        status =
            'มีแล้ว $existingCount รายการ • เตรียมเพิ่ม $newCount รายการ • '
            'แจ้งเตือนรอตัดสินใจ $pendingAlertCount รายการ';
        await _addAudit(
          'calendar.compare',
          'ตรวจแบบอ่านอย่างเดียว: มีแล้ว $existingCount, ใหม่ $newCount, '
              'กิจกรรมที่นำมาตรวจชน ${calendarPeriods.length}',
          true,
        );
      } finally {
        client.close();
      }
    });
  }

  Future<void> syncCalendar() async {
    if (shifts.isEmpty) throw StateError('กรุณาอ่านตารางเวรก่อน');
    if (pendingAlertCount > 0) {
      throw StateError(
        'มีแจ้งเตือน $pendingAlertCount รายการที่ยังไม่ได้ตัดสินใจ '
        'กรุณาตรวจแจ้งเตือนก่อนบันทึก Calendar',
      );
    }
    await _run('สร้างสำเนาและบันทึกปฏิทิน', () async {
      final sourceUrl = localSourceLabel == null ? currentSourceUrl : '';
      if (sourceUrl.isEmpty && localSourceLabel == null) {
        throw StateError('ไม่พบแหล่งข้อมูลเวรของรอบนี้');
      }
      final periods = _activeRosterPeriods();
      final workflow = preparedWorkflow;
      _pendingCalendarWorkflow = null;
      try {
        if (settings.archiveOriginal && sourceUrl.isNotEmpty) {
          final driveClient = await auth.clientFor([drive.DriveApi.driveScope]);
          try {
            for (final period in periods) {
              final archive = await _archiveService.copyMonthlyOriginal(
                driveClient,
                sourceFileId: _sheetsService.parseSpreadsheetId(sourceUrl),
                year: period.year,
                month: period.month,
              );
              await _addAudit(
                'drive.copy',
                archive.alreadyExisted
                    ? 'ใช้สำเนาเดิม ${archive.name}; ไม่สร้างซ้ำ'
                    : 'สร้างสำเนาต้นฉบับ ${archive.name}',
                true,
              );
            }
          } finally {
            driveClient.close();
          }
        } else if (settings.archiveOriginal && localSourceLabel != null) {
          await _addAudit(
            'local_file.archive.skip',
            'ไม่อัปโหลดไฟล์ในเครื่องไป Drive อัตโนมัติเพื่อคุ้มครองข้อมูล',
            true,
          );
        }

        await workflow.synchronize();
        final result = workflow.lastResult;
        if (result == null) {
          throw StateError(
            workflow.message ?? 'ซิงก์ Google Calendar ไม่สำเร็จ',
          );
        }
        final inserted = result.historyEntry.inserted;
        final updated = result.historyEntry.updated;
        final deleted = result.historyEntry.deleted;
        status = result.hasFailures
            ? 'ซิงก์ Google Calendar สำเร็จบางส่วน กรุณาตรวจสอบประวัติ'
            : 'ซิงก์ Google Calendar สำเร็จ';
        await _addAudit(
          'calendar.write',
          'เพิ่ม $inserted แก้ไข $updated ลบ $deleted '
              'ล้มเหลว ${result.historyEntry.failed}',
          !result.hasFailures,
        );
      } finally {
        workflow.dispose();
      }
    });
  }

  /// Validates and prepares the canonical diff before the existing UI asks
  /// the user to confirm execution.
  Future<void> prepareCalendarSync() async {
    await _run('ตรวจสอบตารางเวรและเตรียมแผนซิงก์', () async {
      _pendingCalendarWorkflow?.dispose();
      _pendingCalendarWorkflow = null;
      _pendingCalendarWorkflow = await _createPreparedCalendarWorkflow();
      final warnings =
          _pendingCalendarWorkflow!.validationResult?.warnings.length ?? 0;
      status = warnings == 0
          ? 'ตรวจสอบแล้ว พร้อมยืนยันการซิงก์'
          : 'ตรวจสอบแล้ว พบคำเตือน $warnings รายการ พร้อมให้ผู้ใช้ยืนยัน';
    });
  }

  /// Builds and returns a prepared calendar diff for preview purposes.
  Future<CalendarDiff> previewCalendarDiff() {
    return _run('เตรียมตัวอย่างการซิงก์ปฏิทิน', () async {
      _pendingCalendarWorkflow?.dispose();
      _pendingCalendarWorkflow = null;
      final workflow = await _createPreparedCalendarWorkflow();
      _pendingCalendarWorkflow = workflow;
      final prep = workflow.schedulePreparation;
      if (prep == null) {
        throw StateError('ไม่พบแผนการซิงก์ที่เตรียมไว้');
      }
      return prep.diff;
    });
  }

  Future<ShiftTransactionCalendarSyncPreview>
  previewShiftTransactionCalendarSync(ShiftTransactionSnapshot transaction) {
    return _run('ตรวจสอบตัวอย่าง Calendar สำหรับธุรกรรมเวร', () async {
      if (transaction.status != 'approved') {
        throw StateError('ต้องอนุมัติธุรกรรมก่อนเตรียม Calendar');
      }
      if (transaction.syncStatus == 'pending' ||
          transaction.syncStatus == 'synced') {
        throw StateError('ธุรกรรมนี้กำลังซิงก์หรือซิงก์สำเร็จแล้ว');
      }
      if (shiftTransactionProjectionWarnings.isNotEmpty) {
        throw StateError('มีธุรกรรมที่นำไปใช้กับตารางไม่ได้ กรุณาแก้ไขก่อนซิงก์ Calendar');
      }
      _pendingShiftTransactionCalendarSync?.workflow.dispose();
      _pendingShiftTransactionCalendarSync = null;
      final schedule = _scheduleForActivePeriods();
      final syncIds = const ShiftTransactionCalendarSyncMapper().map(
        schedule: schedule,
        transaction: transaction,
      );
      final workflow = await _calendarWorkflowControllerFactory();
      try {
        await workflow.prepareSchedule(schedule);
        if (workflow.hasBlockingFailures) {
          throw StateError(workflow.validationResult?.errors
              .map((item) => item.message).join('\n') ?? 'ตารางเวรไม่ผ่านการตรวจสอบ');
        }
        final preparation = workflow.schedulePreparation;
        if (preparation == null) throw StateError('ไม่พบแผน Calendar ที่ผ่านการตรวจสอบ');
        final plannedIds = {
          ...preparation.existingEventIdsBySyncId.keys,
          ...preparation.plan.inserts.map((item) => item.syncId),
          ...preparation.plan.updates.map((item) => item.command.syncId),
        };
        if (syncIds.any((id) => !plannedIds.contains(id))) {
          throw StateError('ไม่พบรายการเวรของธุรกรรมในแผน Calendar ที่เตรียมไว้');
        }
        _pendingShiftTransactionCalendarSync = _PendingShiftTransactionCalendarSync(
          transactionId: transaction.id,
          transactionVersion: transaction.version,
          sourceSchedule: canonicalSchedule,
          schedule: schedule,
          workflow: workflow,
          syncIds: syncIds,
        );
        return ShiftTransactionCalendarSyncPreview(
          transactionId: transaction.id,
          transactionVersion: transaction.version,
          insertCount: preparation.diff.toAdd.length,
          updateCount: preparation.diff.toUpdate.length,
          deleteCount: preparation.diff.toDelete.length,
          transferLines: [
            for (final transfer in transaction.transfers)
              '${transfer['shift_code'] ?? 'Shift'} · ${transfer['from_employee_id'] ?? '?'} → ${transfer['to_employee_id'] ?? '?'} · ${transfer['starts_at'] ?? ''} – ${transfer['ends_at'] ?? ''}',
          ],
          insertTitles: [for (final item in preparation.diff.toAdd) item.title],
          updateTitles: [for (final item in preparation.diff.toUpdate) item.title],
          deleteTitles: [for (final item in preparation.diff.toDelete) item.title],
          warnings: workflow.validationResult?.warnings
                  .map((item) => item.message).toList(growable: false) ??
              const <String>[],
        );
      } catch (_) {
        workflow.dispose();
        rethrow;
      }
    });
  }

  Future<ShiftTransactionSnapshot> confirmShiftTransactionCalendarSync({
    required ShiftTransactionSnapshot transaction,
    required ShiftTransactionApiClient apiClient,
    required bool userConfirmed,
  }) {
    return _run('ยืนยันและซิงก์ Calendar สำหรับธุรกรรมเวร', () async {
      if (!userConfirmed) throw StateError('ต้องยืนยันจากหน้าตัวอย่างก่อนบันทึก Calendar');
      final pending = _pendingShiftTransactionCalendarSync;
      final currentTransactions = _shiftTransactions.where(
        (item) => item.id == transaction.id,
      );
      if (pending == null ||
          currentTransactions.length != 1 ||
          currentTransactions.single.version != transaction.version ||
          pending.transactionId != transaction.id ||
          pending.transactionVersion != transaction.version ||
          !identical(pending.sourceSchedule, canonicalSchedule)) {
        throw StateError('ตัวอย่างหมดอายุแล้ว กรุณาเตรียม Preview ใหม่');
      }
      final currentIds = const ShiftTransactionCalendarSyncMapper().map(
        schedule: _scheduleForActivePeriods(),
        transaction: transaction,
      );
      if (currentIds.length != pending.syncIds.length ||
          !currentIds.toSet().containsAll(pending.syncIds)) {
        throw StateError('ตารางเวรเปลี่ยนหลัง Preview กรุณาตรวจสอบใหม่');
      }
      var syncStartAttempted = false;
      var syncCompleted = false;
      ShiftCalendarWorkflowController? verification;
      try {
        syncStartAttempted = true;
        await apiClient.startCalendarSync(transaction.id, previewConfirmed: true);
        await pending.workflow.synchronize();
        final result = pending.workflow.lastResult;
        if (result == null || result.hasFailures) {
          throw StateError('Calendar ซิงก์ไม่ครบ กรุณาตรวจประวัติและลองใหม่');
        }
        verification = await _calendarWorkflowControllerFactory();
        await verification.prepareSchedule(pending.schedule);
        if (verification.hasBlockingFailures ||
            verification.schedulePreparation == null) {
          throw StateError('อ่านยืนยันรายการ Calendar หลังซิงก์ไม่สำเร็จ');
        }
        final providerIds = verification.schedulePreparation!.existingEventIdsBySyncId;
        final writtenIds = {
          for (final operation in result.operations)
            if (operation.success &&
                operation.providerEventId != null &&
                operation.providerEventId!.isNotEmpty)
              operation.referenceId: operation.providerEventId!,
        };
        final eventIds = <String>[];
        for (final syncId in pending.syncIds) {
          final readBackId = providerIds[syncId];
          final writtenId = writtenIds[syncId];
          if (readBackId == null ||
              readBackId.isEmpty ||
              (writtenId != null && writtenId != readBackId)) {
            throw StateError(
              'Calendar read-back ไม่ตรงกับ Event ID ที่ได้จากการเขียน',
            );
          }
          eventIds.add(readBackId);
        }
        if (eventIds.toSet().length != pending.syncIds.length) {
          throw StateError('Calendar read-back ไม่พบ Event ID ที่ไม่ซ้ำกันครบทุกเวร');
        }
        final updated = await apiClient.completeCalendarSync(
          transaction.id,
          calendarEventIds: eventIds,
        );
        syncCompleted = true;
        _shiftTransactions = List.unmodifiable([
          for (final item in _shiftTransactions)
            if (item.id == updated.id) updated else item,
        ]);
        status = 'ซิงก์ Calendar และยืนยัน Event ID ของธุรกรรมแล้ว';
        await _addAudit(
          'shift_transaction.calendar_sync',
          'ยืนยัน Calendar Event ${eventIds.length} รายการสำหรับธุรกรรม ${transaction.id}',
          true,
        );
        notifyListeners();
        return updated;
      } catch (error) {
        if (syncStartAttempted && !syncCompleted) {
          try {
            await apiClient.failCalendarSync(transaction.id, reason: error.toString());
          } catch (_) {}
        }
        rethrow;
      } finally {
        verification?.dispose();
        pending.workflow.dispose();
        if (identical(_pendingShiftTransactionCalendarSync, pending)) {
          _pendingShiftTransactionCalendarSync = null;
        }
      }
    });
  }

  void cancelShiftTransactionCalendarSyncPreview() {
    _pendingShiftTransactionCalendarSync?.workflow.dispose();
    _pendingShiftTransactionCalendarSync = null;
  }


  /// Prepares a preview for a pre-mapped list of desired calendar event
  /// candidates (used for swap/one-off previews) and returns the computed diff.
  Future<CalendarDiff> previewCandidates(
    List<CalendarEventCandidate> desired,
  ) {
    return _run('เตรียมตัวอย่างรายการปฏิทิน', () async {
      final workflow = await _calendarWorkflowControllerFactory();
      try {
        await workflow.prepareCandidatePreview(desired: desired);
        final preview = workflow.preview;
        if (preview == null) throw StateError('ไม่พบ preview หลังจากเตรียม');
        return preview.diff;
      } finally {
        workflow.dispose();
      }
    });
  }

  /// Executes synchronization for a pre-mapped set of desired candidates.
  Future<void> syncCandidates(List<CalendarEventCandidate> desired) {
    return _run('ซิงก์รายการปฏิทิน', () async {
      final workflow = await _calendarWorkflowControllerFactory();
      try {
        await workflow.prepareCandidatePreview(desired: desired);
        if (workflow.preview == null) {
          throw StateError('ไม่พบแผนการซิงก์สำหรับรายการนี้');
        }
        await workflow.synchronize();
        final result = workflow.lastResult;
        if (result != null) {
          await _addAudit(
            'calendar.sync.candidates',
            'ซิงก์ candidates: เพิ่ม ${result.historyEntry.inserted} แก้ไข ${result.historyEntry.updated} ลบ ${result.historyEntry.deleted}',
            !result.hasFailures,
          );
        }
      } finally {
        workflow.dispose();
      }
    });
  }

  /// Releases an authorized prepared workflow when confirmation is cancelled.
  void cancelCalendarSyncPreparation() {
    _pendingCalendarWorkflow?.dispose();
    _pendingCalendarWorkflow = null;
  }

  Future<ShiftCalendarWorkflowController>
  _createPreparedCalendarWorkflow() async {
    final dateAnomalies = monthlyRoster.blockingDateAnomalies;
    if (dateAnomalies.isNotEmpty) {
      final details = monthlyRoster.sections
          .where((section) => section.hasBlockingDateAnomalies)
          .expand(
            (section) => section.dateAnomalies.map(
              (anomaly) => '${section.title}: ${anomaly.message}',
            ),
          )
          .take(8)
          .join('；');
      throw StateError(
        'พบข้อผิดปกติของแถววันที่ในตารางเวร จึงหยุดก่อนสร้าง Preview และก่อนเชื่อมต่อ Google Calendar '
        'กรุณาตรวจสอบวันที่ซ้ำ วันที่ขาด หรือวันที่เรียงผิดลำดับ: $details',
      );
    }
    final schedule = _scheduleForActivePeriods();
    final assignmentCount = schedule.months.fold<int>(
      0,
      (total, month) => total + month.days.fold<int>(
        0,
        (dayTotal, day) => dayTotal + day.assignments.length,
      ),
    );
    if (assignmentCount == 0) {
      final selectedPeriods = _activeRosterPeriods();
      final selectedLabel = selectedPeriods
          .map((period) => '${period.month}/${period.year + 543}')
          .join(', ');
      final parsedCount = _loadedRosterShifts.length;
      final filteredCount = _filterToSyncDateRange(_loadedRosterShifts).length;
      throw StateError(
        'ไม่พบรายการเวรในตารางสำหรับเดือนที่เลือก ($selectedLabel) '
        'จึงยังสร้าง Preview ไม่ได้ '
        '(อ่านเวรต้นทางได้ $parsedCount รายการ; หลังกรองเดือน/ช่วงวันที่เหลือ $filteredCount รายการ; '
        'ช่องตารางรายเดือนที่อ่านได้ ${monthlyRoster.assignments.length}; '
        'ช่องที่ยังแปลงเป็นเวรไม่ได้ ${monthlyRosterConversion.unconvertedAssignments.length}). '
        'ระบบหยุดก่อนอ่านหรือเขียน Google Calendar เพื่อป้องกันการสร้างแผนจากตารางว่าง '
        'กรุณาตรวจปี/เดือนและผลการแปลงตารางเวร',
      );
    }

    final workflow = await _calendarWorkflowControllerFactory();
    try {
      await workflow.prepareSchedule(canonicalSchedule);
      if (workflow.hasBlockingFailures) {
        throw StateError(
          workflow.validationResult?.errors
                  .map((violation) => violation.message)
                  .join('\n') ??
              'ตารางเวรไม่ผ่านการตรวจสอบ',
        );
      }
      return workflow;
    } catch (_) {
      workflow.dispose();
      rethrow;
    }
  }

  Future<void> createFutureSheet({
    required String templateTitle,
    required String newTitle,
  }) async {
    if (templateTitle.trim().isEmpty || newTitle.trim().isEmpty) {
      throw StateError('กรุณาระบุแท็บต้นแบบและชื่อแท็บใหม่');
    }
    final sourceUrl = currentSourceUrl;
    if (sourceUrl.isEmpty) {
      throw StateError('กรุณาเลือกไฟล์ Google Sheets หลักของบัญชีนี้ก่อน');
    }
    await _run('สร้างชีตเดือนล่วงหน้า', () async {
      final client = await auth.clientFor([
        sheets.SheetsApi.spreadsheetsScope,
        drive.DriveApi.driveMetadataReadonlyScope,
      ]);
      try {
        final spreadsheetId = _sheetsService.parseSpreadsheetId(sourceUrl);
        await _ownershipService.requireOwnedSpreadsheet(client, spreadsheetId);
        final created = await _sheetsService.duplicateSheet(
          client,
          sourceUrl: sourceUrl,
          templateTitle: templateTitle.trim(),
          newTitle: newTitle.trim(),
        );
        final createdTitle = created.sheetTitle ?? newTitle.trim();
        if (!sheetTitles.contains(createdTitle)) {
          sheetTitles.add(createdTitle);
        }
        final accountId = auth.account?.id;
        if (accountId != null) {
          await _saveSheetReference(accountId, created);
        }
        status = 'สร้างและบันทึกแท็บ “$createdTitle” สำเร็จ';
        await _addAudit(
          'sheet.create',
          'ทำสำเนาแท็บ “$templateTitle” เป็น “$createdTitle”; ไม่แก้แท็บต้นแบบ',
          true,
        );
      } finally {
        client.close();
      }
    });
  }

  void updateShift(int index, {ShiftCategory? category, bool? excluded}) {
    final updatedShifts = shifts.toList();
    final shift = updatedShifts[index];
    updatedShifts[index] = shift.copyWith(
      category: category,
      excluded: excluded,
    );
    if (!shift.generated) {
      _rememberShiftOverride(updatedShifts[index]);
      _replaceLegacyShifts(
        _alertService.addOffDutyPeriods(
          updatedShifts.where((item) => !item.generated).toList(),
        ),
      );
    } else {
      _replaceLegacyShifts(updatedShifts);
    }
    _rebuildAlerts();
    unawaited(recordShiftTimelineEvent(action: excluded == true || category == ShiftCategory.given ? 'SHIFT_CANCELLED' : (category == ShiftCategory.majorSwap || category == ShiftCategory.borrowedPaid || category == ShiftCategory.borrowedUnpaid) ? 'SHIFT_EXCHANGED' : 'SHIFT_UPDATED', summary: excluded == true || category == ShiftCategory.given ? 'ยกเวร' : (category == ShiftCategory.majorSwap || category == ShiftCategory.borrowedPaid || category == ShiftCategory.borrowedUnpaid) ? 'แลกเวร' : 'ปรับสถานะเวร', details: 'เวร: ${shift.displayName}\nผู้ปฏิบัติงาน: ${shift.assignedName}\nเวลาเดิม: ${shift.start}–${shift.end}\nประเภทเดิม: ${shift.category.label}\nประเภทใหม่: ${updatedShifts[index].category.label}\nยกเวร: ${excluded == true}', shift: shift).catchError((Object error) { status = 'บันทึก Timeline ไม่สำเร็จ: $error'; notifyListeners(); }));
    notifyListeners();
  }

  void customizeShift(
    int index, {
    required String title,
    required DateTime start,
    required DateTime end,
    required ShiftCategory category,
    required String colorCommand,
  }) {
    final updatedShifts = shifts.toList();
    final shift = updatedShifts[index];
    if (shift.generated) {
      throw StateError('รายการ OFF อัตโนมัติปรับจากเวรดึกต้นทางเท่านั้น');
    }
    if (!end.isAfter(start)) {
      throw const FormatException('เวลาสิ้นสุดต้องอยู่หลังเวลาเริ่ม');
    }
    final color = CalendarColorService.parseCommand(colorCommand);
    final updated = shift.copyWith(
      customTitle: title.trim().isEmpty ? shift.displayName : title.trim(),
      start: start,
      end: end,
      category: category,
      calendarColorId: color?.id,
      clearCalendarColor: color == null,
    );
    updatedShifts[index] = updated;
    _rememberShiftOverride(updated);
    _replaceLegacyShifts(
      _alertService.addOffDutyPeriods(
        updatedShifts.where((item) => !item.generated).toList(),
      ),
    );
    calendarPeriods = [];
    existingKeys = {};
    _rebuildAlerts();
    status = 'ปรับชื่อ เวลา ประเภท และสีของรายการแล้ว';
    unawaited(recordShiftTimelineEvent(action: 'SHIFT_UPDATED', summary: 'แก้ไขรายละเอียดเวร', details: 'เวรเดิม: ${shift.displayName}\nเวรใหม่: ${updated.displayName}\nผู้ปฏิบัติงาน: ${shift.assignedName}\nเวลาเดิม: ${shift.start}–${shift.end}\nเวลาใหม่: ${updated.start}–${updated.end}\nสีใหม่: ${updated.effectiveCalendarColorId}\nประเภทใหม่: ${updated.category.label}', shift: shift).catchError((Object error) { status = 'บันทึก Timeline ไม่สำเร็จ: $error'; notifyListeners(); }));
    notifyListeners();
  }

  Future<void> addManualShift({
    required String sourceKind,
    required String title,
    required DateTime start,
    required DateTime end,
    required ShiftCategory category,
    required String colorCommand,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const FormatException('กรุณากรอกชื่อกิจกรรมที่อ่านจากต้นฉบับ');
    }
    if (!end.isAfter(start)) {
      throw const FormatException('เวลาสิ้นสุดต้องอยู่หลังเวลาเริ่ม');
    }
    final searchNames = rosterSearchNames;
    if (searchNames.isEmpty) {
      throw const FormatException(
        'กรุณากรอกชื่อที่ต้องค้นหา หรือล็อกอินเพื่อใช้ชื่อโปรไฟล์ Google',
      );
    }
    final color = CalendarColorService.parseCommand(colorCommand);
    final code =
        'MANUAL-${start.year}${start.month.toString().padLeft(2, '0')}'
        '${start.day.toString().padLeft(2, '0')}-'
        '${start.hour.toString().padLeft(2, '0')}'
        '${start.minute.toString().padLeft(2, '0')}-${shifts.length + 1}';
    final shift = Shift(
      code: code,
      rowLabel: normalizedTitle,
      assignedName: searchNames.first,
      start: start,
      end: end,
      sheetTitle: 'ต้นฉบับ: $sourceKind',
      cell: 'ผู้ใช้กำหนด',
      category: category,
      customTitle: normalizedTitle,
      calendarColorId: color?.id,
    );
    _replaceLegacyShifts(
      _alertService.addOffDutyPeriods([
        ...shifts.where((item) => !item.generated),
        shift,
      ]),
    );
    localSourceLabel = 'รายการจาก $sourceKind (ผู้ใช้ตรวจแล้ว)';
    existingKeys = {};
    calendarPeriods = [];
    _rebuildAlerts();
    status = 'เพิ่มรายการจาก $sourceKind แล้ว กรุณาตรวจในแท็บตัวอย่าง';
    await _addAudit(
      'manual_source.add',
      'เพิ่มรายการจาก $sourceKind 1 รายการ; '
          'ไม่บันทึกชื่อกิจกรรมหรือข้อมูลต้นฉบับใน Audit log',
      true,
    );
    unawaited(recordShiftTimelineEvent(action: 'SHIFT_CREATED', summary: 'เพิ่มเวรใหม่', details: 'เวร: ${shift.displayName}\nผู้รับเวร: ${shift.assignedName}\nเวลา: ${shift.start}–${shift.end}\nประเภท: ${shift.category.label}\nสี Calendar: ${shift.effectiveCalendarColorId}', shift: shift).catchError((Object error) { status = 'บันทึก Timeline ไม่สำเร็จ: $error'; notifyListeners(); }));
    notifyListeners();
  }

  Future<void> openCalendarConflict(ShiftAlert alert) async {
    final rawUrl = alert.calendarEventUrl;
    if (rawUrl == null || rawUrl.isEmpty) {
      throw StateError('กิจกรรมนี้ไม่มีลิงก์สำหรับเปิดจาก Google Calendar');
    }
    final opened = await launchUrl(
      Uri.parse(rawUrl),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened) throw StateError('ไม่สามารถเปิดกิจกรรม Google Calendar ได้');
  }

  Future<void> deleteCalendarConflict(ShiftAlert alert) async {
    final eventId = alert.calendarEventId;
    if (eventId == null || eventId.isEmpty) {
      throw StateError('ไม่พบรหัสกิจกรรม Google Calendar ที่ต้องการลบ');
    }
    await _run('ลบกิจกรรมที่เลือกจาก Google Calendar', () async {
      final client = await auth.clientFor([
        calendar.CalendarApi.calendarEventsScope,
      ]);
      try {
        await _calendarService.deleteEvent(client, eventId: eventId);
        calendarPeriods.removeWhere((period) => period.id == eventId);
        alertDecisions.remove(alert.id);
        _rebuildAlerts();
        status = 'ลบกิจกรรมที่เลือกจาก Google Calendar แล้ว';
        await _addAudit(
          'calendar.delete_conflict',
          'ผู้ใช้ยืนยันลบกิจกรรมที่ชน 1 รายการ',
          true,
        );
      } finally {
        client.close();
      }
    });
  }

  Future<void> resolveAlert(String alertId, ShiftAlertDecision decision) async {
    ShiftAlert? alert;
    for (final item in alerts) {
      if (item.id == alertId) {
        alert = item;
        break;
      }
    }
    if (alert == null || !alert.requiresDecision) return;
    alertDecisions[alertId] = decision;
    await _settingsService.saveAlertDecision(alertId, decision);
    _applyAlertDecision(alert, decision);
    _rebuildAlerts();
    status = switch (decision) {
      ShiftAlertDecision.acknowledged => 'รับทราบคำเตือนและคงรายการไว้',
      ShiftAlertDecision.accepted => 'ยืนยันรายการที่ชนแล้ว',
      ShiftAlertDecision.cancelled => 'ไม่นำรายการที่ชนเข้าปฏิทิน',
      ShiftAlertDecision.pending => 'ตั้งเป็นรอตัดสินใจ',
    };
    await _addAudit('alert.${decision.name}', '${alert.title}: $status', true);
    notifyListeners();
  }

  void _rebuildAlerts({bool applyDecisions = false}) {
    alerts = _alertService.build(
      shifts: shifts,
      calendarPeriods: calendarPeriods,
      decisions: alertDecisions,
      existingKeys: existingKeys,
    );
    if (!applyDecisions) return;
    for (final alert in alerts) {
      _applyAlertDecision(alert, alert.decision);
    }
    alerts = _alertService.build(
      shifts: shifts,
      calendarPeriods: calendarPeriods,
      decisions: alertDecisions,
      existingKeys: existingKeys,
    );
  }

  void _applyAlertDecision(ShiftAlert alert, ShiftAlertDecision decision) {
    if (!alert.requiresDecision) return;
    switch (decision) {
      case ShiftAlertDecision.pending:
      case ShiftAlertDecision.acknowledged:
        return;
      case ShiftAlertDecision.accepted:
        _setExcluded(alert.targetShiftKey, false);
        if (alert.type == ShiftAlertType.offConflict) {
          _setExcluded(alert.offShiftKey, true);
        }
        return;
      case ShiftAlertDecision.cancelled:
        _setExcluded(alert.targetShiftKey, true);
        return;
    }
  }

  void _setExcluded(String? sourceKey, bool excluded) {
    if (sourceKey == null) return;
    final updatedShifts = shifts.toList();
    final index = updatedShifts.indexWhere(
      (shift) => shift.sourceKey == sourceKey,
    );
    if (index >= 0) {
      updatedShifts[index] = updatedShifts[index].copyWith(excluded: excluded);
      _replaceLegacyShifts(updatedShifts);
    }
  }

  Future<void> _ensureActiveSavedSheetPerAccount() async {
    final accountIds = savedSheets
        .map((sheet) => sheet.ownerAccountId)
        .where((id) => id.isNotEmpty)
        .toSet();
    var changed = false;

    for (final accountId in accountIds) {
      final accountSheets = savedSheets
          .where((sheet) => sheet.ownerAccountId == accountId)
          .toList()
        ..sort((left, right) => right.savedAt.compareTo(left.savedAt));

      if (accountSheets.any((sheet) => sheet.isActive)) continue;
      // Migrate only accounts whose records all predate explicit selection.
      // If the user already has explicit inactive records, preserve that choice.
      if (accountSheets.any((sheet) => sheet.hasExplicitActiveState)) continue;
      if (accountSheets.isEmpty) continue;

      final activeKey = accountSheets.first.key;
      savedSheets = [
        for (final item in savedSheets)
          if (item.ownerAccountId == accountId)
            item.copyWith(isActive: item.key == activeKey)
          else
            item,
      ];
      changed = true;
    }

    if (changed) await _settingsService.saveSavedSheets(savedSheets);
  }

  Future<SavedSheet> _saveSheetReference(
    String accountId,
    SheetReference reference, {
    bool setActive = true,
  }) async {
    final saved = SavedSheet(
      ownerAccountId: accountId,
      spreadsheetId: reference.spreadsheetId,
      spreadsheetTitle: reference.spreadsheetTitle,
      sheetId: reference.sheetId,
      sheetTitle: reference.sheetTitle,
      url: reference.url,
      savedAt: DateTime.now(),
      isActive: setActive,
    );
    if (setActive) {
      savedSheets = [
        for (final item in savedSheets)
          if (item.ownerAccountId == accountId)
            item.copyWith(isActive: false)
          else
            item,
      ];
    }
    savedSheets.removeWhere((item) => item.key == saved.key);
    savedSheets.insert(0, saved);
    await _settingsService.saveSavedSheets(savedSheets);
    return saved;
  }

  void _requireSheetOwner(SavedSheet sheet) {
    final accountId = auth.account?.id;
    if (accountId == null) throw StateError('กรุณาล็อกอิน Google ก่อน');
    if (accountId != sheet.ownerAccountId) {
      throw StateError('รายการนี้เป็นของ Google อีกบัญชีหนึ่ง');
    }
  }

  Future<T> _run<T>(String action, Future<T> Function() body) async {
    if (busy) {
      throw StateError(
        'กำลังทำงาน “${status ?? 'รายการก่อนหน้า'}” อยู่ กรุณารอให้เสร็จก่อนเริ่ม “$action”',
      );
    }
    busy = true;
    status = action;
    error = null;
    notifyListeners();
    try {
      return await body();
    } catch (caught) {
      error = caught.toString().replaceFirst('Bad state: ', '');
      await _addAudit('error', '$action: $error', false);
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Writes a structured audit record to the shift event description and a separate Calendar event.
  Future<void> recordShiftTimelineEvent({
    required String action,
    required String summary,
    required String details,
    Shift? shift,
  }) async {
    if (!shiftTimelineEnabled) return;

    final account = auth.account;
    if (account == null) {
      throw StateError('กรุณาล็อกอิน Google ก่อนบันทึก Timeline');
    }
    final timestamp = DateTime.now();
    final actor = account.displayName?.trim().isNotEmpty == true
        ? account.displayName!.trim()
        : account.email;
    final record =
        '[$action] ${timestamp.toIso8601String()} | ผู้แก้ไข: $actor\n$details';
    var sourceEventStatus = '';
    final client = await auth.clientFor([
      calendar.CalendarApi.calendarEventsScope,
    ]);
    try {
      final api = calendar.CalendarApi(client);
      if (shift != null) {
        // Interpret the month in the device's local timezone, then query using
        // absolute UTC instants. Never subtract a fixed Bangkok offset.
        final rangeStart = DateTime(
          shift.start.year,
          shift.start.month,
          1,
        ).toUtc();
        final rangeEnd = DateTime(
          shift.start.year,
          shift.start.month + 1,
          1,
        ).toUtc();
        String? token;
        calendar.Event? matched;
        do {
          final page = await api.events.list(
            'primary',
            timeMin: rangeStart,
            timeMax: rangeEnd,
            singleEvents: true,
            showDeleted: false,
            maxResults: 2500,
            pageToken: token,
          );
          for (final event in page.items ?? const <calendar.Event>[]) {
            final eventStart = event.start?.dateTime;
            if ((event.summary ?? '').trim() ==
                    CalendarService.summaryFor(shift) &&
                eventStart != null &&
                eventStart
                        .toUtc()
                        .difference(shift.start.toUtc())
                        .inMinutes
                        .abs() <=
                    1) {
              matched = event;
              break;
            }
          }
          token = matched == null ? page.nextPageToken : null;
        } while (token != null && token.isNotEmpty);

        final matchedEvent = matched;
        if (matchedEvent != null && matchedEvent.id != null) {
          matchedEvent.description = CalendarService.withTimelineRecord(
            matchedEvent.description?.trim() ?? '',
            record,
          );
          await api.events.update(
            matchedEvent,
            'primary',
            matchedEvent.id!,
          );
          sourceEventStatus =
              'พบรายการเวรต้นฉบับและเพิ่มรายละเอียด Timeline แล้ว';
        } else if (action != 'SHIFT_CREATED') {
          // Keep the separate Timeline entry, but be explicit that the source
          // event could not be matched and was not modified.
          sourceEventStatus =
              'ไม่พบรายการเวรต้นฉบับที่ตรงกัน จึงไม่ได้แก้ไขคำอธิบายรายการเดิม';
        }
      }

      final recordedDetails = sourceEventStatus.isEmpty
          ? details
          : '$details\n\nสถานะรายการเวรต้นฉบับ: $sourceEventStatus';
      final endTime = timestamp.add(const Duration(minutes: 10));
      await api.events.insert(
        calendar.Event(
          summary: 'Timeline: $summary',
          description:
              'ประเภทเหตุการณ์: $action\nผู้แก้ไข: $actor (${account.email})'
              '\nเวลา: ${timestamp.toIso8601String()}\n\n$recordedDetails',
          colorId: '8',
          // Use absolute instants. The timeZone controls calendar display;
          // shifting the hour manually would record the wrong instant.
          start: calendar.EventDateTime(
            dateTime: timestamp.toUtc(),
            timeZone: CalendarService.timeZone,
          ),
          end: calendar.EventDateTime(
            dateTime: endTime.toUtc(),
            timeZone: CalendarService.timeZone,
          ),
          extendedProperties: calendar.EventExtendedProperties(
            private: {
              'sourceApp': CalendarService.sourceApp,
              'auditType': 'shift_timeline',
              'action': action,
              'actorEmail': account.email,
            },
          ),
        ),
        'primary',
        sendUpdates: 'none',
      );
      await _addAudit(
        action,
        '$summary — ผู้แก้ไข: $actor; $recordedDetails',
        true,
      );
    } finally {
      client.close();
    }
  }

  Future<void> _addAudit(String action, String message, bool success) async {
    // Use the stable authenticated account ID, never a display name, for actor
    // attribution. A null ID deliberately remains "unknown" in the audit UI.
    final actorId = auth.account?.id.trim();
    final entry = AuditEntry(
      timestamp: DateTime.now(),
      action: action,
      message: message,
      success: success,
      actorId: actorId == null || actorId.isEmpty ? null : actorId,
    );
    auditEntries.insert(0, entry);
    await _settingsService.appendAudit(entry);
  }

  void _onAuthChanged() {
    final accountId = auth.account?.id;
    if (_observedAccountId != accountId) {
      _timelineLoadGeneration++;
      timelineLoading = false;
      _observedAccountId = accountId;
      _shiftTransactions = const [];
      settings = settings.clearRosterSelection();
      _autoRefreshTimer?.cancel();
      _replaceLegacyShifts(const []);
      alerts = [];
      calendarPeriods = [];
      existingKeys = {};
      sheetTitles = [];
      recentOwnedSheets = [];
      localSourceLabel = null;
      _shiftOverrides.clear();
      recentSheetHistoryLoaded = false;
      lastRefresh = null;
    }
    notifyListeners();
  }

  List<RosterPeriod> _requirePeriods() {
    final periods = settings.effectivePeriods;
    if (periods.isEmpty) {
      throw StateError('กรุณาเลือกและเพิ่มเดือน/ปี ค.ศ. ก่อนอ่านตารางเวร');
    }
    return periods;
  }

  List<Shift> _parseRosterSnapshots(
    List<SheetSnapshot> snapshots, {
    required List<String> searchNames,
  }) {
    final parser = _parser;
    if (parser is AllPeriodRosterShiftParser) {
      final allPeriodParser = parser as AllPeriodRosterShiftParser;
      final allPeriods = allPeriodParser.parseAllPeriods(
        snapshots: snapshots,
        targetName: searchNames.first,
        targetAliases: searchNames.skip(1),
      );
      if (allPeriods.isNotEmpty || settings.effectivePeriods.isEmpty) {
        return allPeriods.map(_applyShiftOverride).toList(growable: false)
          ..sort((left, right) => left.start.compareTo(right.start));
      }
    }

    final parsedByKey = <String, Shift>{};
    for (final period in _requirePeriods()) {
      final periodShifts = parser.parse(
        snapshots: snapshots,
        targetName: searchNames.first,
        targetAliases: searchNames.skip(1),
        year: period.year,
        month: period.month,
      );
      for (final rawShift in periodShifts) {
        final shift = _attachRosterSourceIdentity(rawShift, snapshots);
        parsedByKey[shift.sourceIdentityKey] = _applyShiftOverride(shift);
      }
    }
    return parsedByKey.values.toList()
      ..sort((left, right) => left.start.compareTo(right.start));
  }

  List<RosterPeriod> _periodsForShifts(Iterable<Shift> source) {
    final periods = <RosterPeriod>{
      for (final shift in source)
        if (!shift.generated)
          RosterPeriod(year: shift.start.year, month: shift.start.month),
    }.toList()..sort((left, right) => left.key.compareTo(right.key));
    return List.unmodifiable(periods);
  }

  List<RosterPeriod> _activeRosterPeriods() {
    final periods = _periodsForShifts(shifts);
    return periods.isEmpty ? _requirePeriods() : periods;
  }

  void _rememberShiftOverride(Shift shift) {
    _shiftOverrides[shift.sourceKey] = _ShiftOverride(
      category: shift.category,
      excluded: shift.excluded,
      start: shift.start,
      end: shift.end,
      customTitle: shift.customTitle,
      calendarColorId: shift.calendarColorId,
    );
  }

  Shift _applyShiftOverride(Shift shift) {
    final override = _shiftOverrides[shift.sourceKey];
    if (override == null) return shift;
    return shift.copyWith(
      category: override.category,
      excluded: override.excluded,
      start: override.start,
      end: override.end,
      customTitle: override.customTitle,
      calendarColorId: override.calendarColorId,
      clearCalendarColor: override.calendarColorId == null,
    );
  }

  Future<CalendarReadResult> _readCalendarPeriods(
    GoogleApiClient client,
    List<RosterPeriod> periods,
  ) async {
    final sourceKeys = <String>{};
    final busyByKey = <String, CalendarBusyPeriod>{};
    for (final period in periods) {
      final snapshot = await _calendarService.readCalendar(
        client,
        year: period.year,
        month: period.month,
      );
      sourceKeys.addAll(snapshot.sourceKeys);
      for (final busyPeriod in snapshot.busyPeriods) {
        busyByKey['${busyPeriod.id}|${busyPeriod.start.toIso8601String()}'] =
            busyPeriod;
      }
    }
    return CalendarReadResult(
      sourceKeys: sourceKeys,
      busyPeriods: busyByKey.values.toList()
        ..sort((left, right) => left.start.compareTo(right.start)),
    );
  }

  void _scheduleAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (!settings.autoRefresh ||
        shifts.isEmpty ||
        !auth.isSignedIn ||
        currentSourceSheet == null ||
        localSourceLabel != null) {
      return;
    }
    _autoRefreshTimer = Timer.periodic(
      Duration(seconds: settings.refreshSeconds.clamp(1, 60)),
      (_) {
        if (busy || !auth.isSignedIn) return;
        unawaited(loadRoster(background: true).catchError((_) {}));
      },
    );
  }

  void _replaceLegacyShifts(List<Shift> next, {bool persist = true}) {
    cancelShiftTransactionCalendarSyncPreview();
    final conversion = _legacyScheduleAdapter.toCanonical(
      next,
      id: _runtimeScheduleId,
      name: _runtimeScheduleName,
    );
    _legacySchedule = conversion;
    if (persist) {
      _pendingScheduleWrite = _pendingScheduleWrite.then((_) async {
        await _scheduleRepository.save(conversion.schedule);
      });
    }
  }

  /// Waits until canonical schedule mutations queued by synchronous legacy
  /// compatibility APIs have reached the repository.
  Future<void> flushSchedulePersistence() => _pendingScheduleWrite;

  /// Adopts a manually edited canonical schedule at the legacy UI boundary.
  ///
  /// The canonical aggregate remains authoritative; legacy shifts are generated
  /// only when compatibility widgets read [shifts].
  Future<void> adoptCanonicalSchedule(
    Schedule schedule, {
    bool persist = true,
  }) async {
    cancelShiftTransactionCalendarSyncPreview();
    _legacySchedule = _legacyScheduleAdapter.wrapCanonical(schedule);
    _rebuildAlerts();
    if (persist) {
      await _scheduleRepository.save(schedule);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _pendingCalendarWorkflow?.dispose();
    cancelShiftTransactionCalendarSyncPreview();
    auth.removeListener(_onAuthChanged);
    auth.dispose();
    super.dispose();
  }
}

class _PendingShiftTransactionCalendarSync {
  const _PendingShiftTransactionCalendarSync({
    required this.transactionId,
    required this.transactionVersion,
    required this.sourceSchedule,
    required this.schedule,
    required this.workflow,
    required this.syncIds,
  });

  final String transactionId;
  final int transactionVersion;
  final Schedule sourceSchedule;
  final Schedule schedule;
  final ShiftCalendarWorkflowController workflow;
  final List<String> syncIds;
}

class _ShiftOverride {
  const _ShiftOverride({
    required this.category,
    required this.excluded,
    required this.start,
    required this.end,
    required this.customTitle,
    required this.calendarColorId,
  });

  final ShiftCategory category;
  final bool excluded;
  final DateTime start;
  final DateTime end;
  final String? customTitle;
  final String? calendarColorId;
}
