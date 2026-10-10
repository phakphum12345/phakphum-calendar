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
import '../models/roster_reference_comparison.dart';
import '../models/roster_assignment_timeline.dart';
import '../models/saved_sheet.dart';
import '../models/shift.dart';
import '../models/shift_alert.dart';
import '../models/tool_definition.dart';
import '../domain/entities/schedule.dart';
import '../domain/entities/schedule_month.dart';
import '../domain/repositories/schedule_repository.dart';
import '../features/schedule/data/legacy_schedule_adapter.dart';
import '../features/google_sheets/domain/sheet_color.dart';
import '../features/shift_parser/application/monthly_roster_section_parser.dart';
import '../features/shift_parser/domain/monthly_roster_section.dart';
import '../features/shift_parser/domain/normalized_cell.dart';
import '../features/shift_parser/domain/shift_parser_input.dart';
import '../features/workflow/application/shift_calendar_workflow_controller.dart';
import '../features/diff_engine/domain/calendar_event_candidate.dart';
import '../services/calendar_service.dart';
import '../services/calendar_color_service.dart';
import '../services/drive_archive_service.dart';
import '../services/drive_ownership_service.dart';
import '../services/google_auth_service.dart';
import '../services/google_api_client.dart';
import '../services/local_roster_file_service.dart';
import '../services/roster_revision_service.dart';
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
        assignedName: '',
        start: DateTime(2026, 8, 3, 8),
        end: DateTime(2026, 8, 3, 16),
        sheetTitle: 'ตัวอย่าง',
        cell: 'D5',
        category: ShiftCategory.own,
      ),
      Shift(
        code: 'UG',
        rowLabel: 'GEN',
        assignedName: '',
        start: DateTime(2026, 8, 8, 7, 30),
        end: DateTime(2026, 8, 8, 12),
        sheetTitle: 'ตัวอย่าง',
        cell: 'I40',
        category: ShiftCategory.clinic,
      ),
      Shift(
        code: 'NP2',
        rowLabel: 'P2 ดึก',
        assignedName: '',
        start: DateTime(2026, 8, 10),
        end: DateTime(2026, 8, 10, 8),
        sheetTitle: 'ตัวอย่าง',
        cell: 'K7',
        category: ShiftCategory.own,
      ),
      Shift(
        code: 'UP3',
        rowLabel: 'P3 เช้า',
        assignedName: '',
        start: DateTime(2026, 8, 11, 8),
        end: DateTime(2026, 8, 11, 16),
        sheetTitle: 'ตัวอย่าง',
        cell: 'K9',
        category: ShiftCategory.own,
      ),
    ];
    _loadedRosterShifts = sourceShifts;
    _replaceLegacyShifts(
      _alertService.addOffDutyPeriods(sourceShifts),
      persist: false,
    );
    _rebuildAlerts();
  }

  final GoogleAuthGateway auth;
  final AppSettingsStore _settingsService;
  final RosterSheetsGateway _sheetsService;
  final RosterShiftParser _parser;
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

  /// Read-only compatibility projection consumed by the legacy shell.
  List<Shift> get shifts => _legacySchedule.toLegacyShifts();
  List<ShiftAlert> alerts = [];
  List<CalendarBusyPeriod> calendarPeriods = [];
  Set<String> _duplicateCalendarEventIds = {};
  Map<String, ShiftAlertDecision> alertDecisions = {};
  List<AuditEntry> auditEntries = [];
  List<SavedSheet> savedSheets = [];
  List<RecentOwnedSheet> recentOwnedSheets = [];
  Set<String> existingKeys = {};
  Map<String, RosterAssignmentTimeline> _revisionTimelines = const {};
  int _loadedRevisionCount = 0;
  String? timelineWarning;
  List<String> sheetTitles = [];
  Set<String> pinnedToolIds = {...defaultPinnedToolIds};
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
  String? localReferenceLabel;
  List<Shift> localReferenceShifts = [];
  List<Shift> _currentAllRosterShifts = [];
  List<Shift> _referenceAllRosterShifts = [];
  List<Shift> _loadedRosterShifts = [];
  bool _syncRangeCustomized = false;
  MonthlyRosterParseReport monthlyRoster = const MonthlyRosterParseReport(
    sections: [],
    warnings: [],
  );
  DateTime? syncRangeStart;
  DateTime? syncRangeEnd;
  final Map<String, _ShiftOverride> _shiftOverrides = {};
  final Map<String, String> _shiftOverrideSourceKeys = {};
  ShiftCalendarWorkflowController? _pendingCalendarWorkflow;

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
  int get duplicateCalendarEventCount => _duplicateCalendarEventIds.length;
  int get newCount => shifts
      .where((shift) => !shift.excluded && !_matchesCurrentCalendar(shift))
      .length;
  int get pendingAlertCount => alerts.where((alert) => alert.isPending).length;
  int get conflictAlertCount =>
      alerts.where((alert) => alert.isConflict).length;
  RosterReferenceComparison? get localReferenceComparison =>
      localReferenceLabel == null
      ? null
      : RosterReferenceComparison.compare(
          syncShifts: shifts,
          referenceShifts: localReferenceShifts,
        );
  int get localReceivedShiftCount => _relationshipCount(received: true);
  int get localGivenShiftCount => _relationshipCount(received: false);

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
    await Future.wait<void>([
      () async {
        try {
          settings = await _settingsService.load();
        } catch (caught) {
          error = 'โหลดการตั้งค่าไม่สำเร็จ: $caught';
        }
      }(),
      () async {
        try {
          auditEntries = await _settingsService.loadAudit();
        } catch (caught) {
          error ??= 'โหลดบันทึกไม่สำเร็จ: $caught';
        }
      }(),
      () async {
        try {
          savedSheets = await _settingsService.loadSavedSheets();
        } catch (caught) {
          error ??= 'โหลดรายการชีตที่บันทึกไม่สำเร็จ: $caught';
        }
      }(),
      () async {
        try {
          pinnedToolIds = await _settingsService.loadPinnedToolIds();
        } catch (caught) {
          error ??= 'โหลดแถบเครื่องมือไม่สำเร็จ: $caught';
        }
      }(),
      () async {
        try {
          alertDecisions = await _settingsService.loadAlertDecisions();
        } catch (caught) {
          error ??= 'โหลดการตัดสินใจแจ้งเตือนไม่สำเร็จ: $caught';
        }
      }(),
    ]);
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
    await auth.signOut();
    _autoRefreshTimer?.cancel();
    _replaceLegacyShifts(const []);
    alerts = [];
    calendarPeriods = [];
    existingKeys = {};
    sheetTitles = [];
    monthlyRoster = const MonthlyRosterParseReport(sections: [], warnings: []);
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
      _pendingCalendarWorkflow?.dispose();
      _pendingCalendarWorkflow = null;
      calendarPeriods = [];
      existingKeys = {};
    }
    settings = next;
    await _settingsService.save(next);
    if (periodChanged) _rebuildAlerts();
    _scheduleAutoRefresh();
    notifyListeners();
  }

  Future<void> updateSyncDateRange(DateTime start, DateTime end) async {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    if (normalizedEnd.isBefore(normalizedStart)) {
      throw const FormatException('วันสิ้นสุดต้องไม่อยู่ก่อนวันเริ่มต้น');
    }
    syncRangeStart = normalizedStart;
    syncRangeEnd = normalizedEnd;
    _syncRangeCustomized = true;
    _pendingCalendarWorkflow?.dispose();
    _pendingCalendarWorkflow = null;
    calendarPeriods = [];
    existingKeys = {};
    _replaceLegacyShifts(
      _filterToSyncDateRange(
        _alertService.addOffDutyPeriods(
          _applyReferenceRelationships(
            _filterToSyncDateRange(_loadedRosterShifts),
          ),
        ),
      ),
    );
    _rebuildAlerts();
    status =
        'กำหนดช่วงซิงก์ ${_dateLabel(normalizedStart)}–'
        '${_dateLabel(normalizedEnd)} แล้ว';
    notifyListeners();
  }

  Iterable<ToolDefinition> get pinnedTools =>
      toolCatalog.where((tool) => pinnedToolIds.contains(tool.id));

  List<SavedSheet> get savedSheetsForCurrentAccount {
    final accountId = auth.account?.id;
    if (accountId == null) return const [];
    return savedSheets
        .where((sheet) => sheet.ownerAccountId == accountId)
        .toList()
      ..sort((left, right) => right.savedAt.compareTo(left.savedAt));
  }

  SavedSheet? get currentSourceSheet =>
      savedSheetsForCurrentAccount.firstOrNull;

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
        recentOwnedSheets = await _ownershipService.listOwnedSpreadsheets(
          client,
          limit: 1000,
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

        // บันทึกย้อนลำดับ เพื่อให้ไฟล์แรกที่ผู้ใช้เลือกเป็นไฟล์หลักล่าสุด
        // และยังเก็บไฟล์อื่นทั้งหมดไว้ในรายการชีตที่บันทึก
        for (final selected in uniqueSheets.reversed) {
          await _ownershipService.requireOwnedSpreadsheet(client, selected.id);
          final reference = await _sheetsService.describeSpreadsheet(
            client,
            selected.url,
          );
          await _saveSheetReference(account.id, reference);
          addedCount++;
        }
        _resetSyncRange();

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
        _resetSyncRange();
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
    await _run('ลบชีตออกจากรายการบันทึก', () async {
      final wasCurrent = currentSourceSheet?.key == sheet.key;
      savedSheets.removeWhere((item) => item.key == sheet.key);
      await _settingsService.saveSavedSheets(savedSheets);
      if (wasCurrent) {
        _replaceLegacyShifts(const []);
        alerts = [];
        calendarPeriods = [];
        existingKeys = {};
        sheetTitles = [];
        monthlyRoster = const MonthlyRosterParseReport(
          sections: [],
          warnings: [],
        );
        _loadedRosterShifts = [];
        _resetSyncRange();
        _autoRefreshTimer?.cancel();
      }
      status = 'ลบ “${sheet.displayTitle}” ออกจากรายการแล้ว';
      await _addAudit(
        'sheet.reference.delete',
        'ลบ “${sheet.displayTitle}” ออกจากรายการในเครื่อง; ไม่ได้ลบไฟล์ Google Sheets',
        true,
      );
    });
  }

  Future<void> loadRoster({bool background = false}) async {
    await _run('อ่านตารางเวร', () async {
      final sourceUrl = localSourceLabel == null ? currentSourceUrl : '';
      if (sourceUrl.isEmpty) {
        throw StateError(
          'กรุณาวางลิงก์และเลือกไฟล์ Google Sheets หลักของบัญชีนี้ก่อน',
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
        drive.DriveApi.driveReadonlyScope,
      ], promptIfNecessary: !background);
      try {
        final spreadsheetId = _sheetsService.parseSpreadsheetId(sourceUrl);
        await _ownershipService.requireOwnedSpreadsheet(client, spreadsheetId);
        final snapshots = await _sheetsService.readAll(client, sourceUrl);
        final parsed = _parseRosterSnapshots(
          snapshots,
          searchNames: searchNames,
        );
        final parsedMonthly = _parseMonthlyRosterSnapshots(
          snapshots,
          spreadsheetId: spreadsheetId,
        );
        monthlyRoster = parsedMonthly.sections.isEmpty
            ? MonthlyRosterParseReport.fromShifts(parsed)
            : parsedMonthly;
        _loadedRosterShifts = parsed;
        _setDefaultSyncDateRange(parsed);
        final rangedParsed = _filterToSyncDateRange(parsed);
        _currentAllRosterShifts = _parseAllRosterSnapshots(
          snapshots,
          fallback: rangedParsed,
        );
        _currentAllRosterShifts = _filterToSyncDateRange(
          _currentAllRosterShifts,
        );
        final currentRevision = RosterRevisionDocument(
          revisionId: 'current',
          modifiedAt: DateTime.now(),
          snapshots: snapshots,
        );
        final timelineGenerator = const RosterTimelineGenerator();
        if (background && _loadedRevisionCount > 0) {
          timelineWarning =
              'ใช้ประวัติ Timeline จากการอ่านล่าสุด; '
              'กดอ่านใหม่เพื่อโหลด revision ล่าสุดจาก Drive';
        } else {
          timelineWarning = null;
          try {
            final historicalRevisions = await const RosterRevisionService()
                .readHistoryTransient(client, spreadsheetId);
            _loadedRevisionCount = historicalRevisions.length + 1;
            _revisionTimelines = timelineGenerator.generateFromDocuments([
              ...historicalRevisions,
              currentRevision,
            ]);
            if (historicalRevisions.isEmpty) {
              timelineWarning =
                  'Google Drive ไม่พบประวัติ revision ที่อ่านได้ '
                  'จึงแสดงเฉพาะรายชื่อเวรปัจจุบัน';
            }
          } on Object catch (caught, stackTrace) {
            _loadedRevisionCount = 1;
            _revisionTimelines = timelineGenerator.generateFromDocuments([
              currentRevision,
            ]);
            timelineWarning =
                'อ่านประวัติ Timeline จาก Google Drive ไม่สำเร็จ: $caught';
            await _addAudit('sheet.timeline.failed', timelineWarning!, false);
            debugPrintStack(
              label: 'Could not load Google Sheets revision timeline',
              stackTrace: stackTrace,
            );
          }
        }
        final periods = _periodsForShifts(rangedParsed);
        _replaceLegacyShifts(
          _alertService.addOffDutyPeriods(
            _applyReferenceRelationships(rangedParsed),
          ),
        );
        localSourceLabel = null;
        sheetTitles = snapshots.map((sheet) => sheet.title).toList();
        existingKeys = {};
        calendarPeriods = [];
        _rebuildAlerts(applyDecisions: true);
        lastRefresh = DateTime.now();
        final offCount = shifts.where((shift) => shift.isOffDuty).length;
        final colorCount = rangedParsed
            .where((shift) => shift.sourceColorValue != null)
            .length;
        status =
            'พบเวรของ ${searchNames.first} ${rangedParsed.length} รายการ '
            'จาก ${periods.length} เดือน • '
            '${syncRangeStart == null || syncRangeEnd == null ? '' : 'ช่วง ${_dateLabel(syncRangeStart!)}–${_dateLabel(syncRangeEnd!)} • '}'
            'อ่านสีจากไฟล์หลัก $colorCount รายการ • '
            'Timeline $_loadedRevisionCount revision'
            '${timelineWarning == null ? '' : ' • $timelineWarning'} • '
            'สร้าง OFF $offCount รายการ • รอตัดสินใจ $pendingAlertCount รายการ';
        await _addAudit(
          'sheet.read',
          'อ่าน ${snapshots.length} แท็บ ${periods.length} เดือน '
              'พบ ${rangedParsed.length} เวรในช่วงที่กำหนด '
              'อ่าน Timeline $_loadedRevisionCount revision '
              'อ่านสีจากไฟล์หลัก $colorCount รายการ และสร้าง OFF '
              '$offCount รายการ; ไม่มีการแก้ไขชีต',
          true,
        );
      } finally {
        client.close();
      }
    });
    _scheduleAutoRefresh();
    // Optionally perform automatic prepare+sync when enabled.
    if (settings.autoSync && auth.isSignedIn) {
      try {
        if (pendingAlertCount == 0) {
          await prepareCalendarSync();
          await syncCalendar();
        } else {
          await _addAudit(
            'auto.sync.skipped',
            'ข้ามการซิงก์อัตโนมัติเนื่องจากมีแจ้งเตือนค้าง $pendingAlertCount รายการ',
            true,
          );
        }
      } catch (e) {
        // Log and continue — do not fail the load flow if sync fails.
        await _addAudit('auto.sync.failed', 'Auto sync failed: $e', false);
      }
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
      final parsed = _parseRosterSnapshots(
        document.snapshots,
        searchNames: searchNames,
      );
      final parsedMonthly = _parseMonthlyRosterSnapshots(
        document.snapshots,
        spreadsheetId: 'local-${document.extension}',
      );
      monthlyRoster = parsedMonthly.sections.isEmpty
          ? MonthlyRosterParseReport.fromShifts(parsed)
          : parsedMonthly;
      _loadedRosterShifts = parsed;
      _syncRangeCustomized = false;
      _setDefaultSyncDateRange(parsed);
      final rangedParsed = _filterToSyncDateRange(parsed);
      _currentAllRosterShifts = _parseAllRosterSnapshots(
        document.snapshots,
        fallback: rangedParsed,
      );
      _currentAllRosterShifts = _filterToSyncDateRange(_currentAllRosterShifts);
      _revisionTimelines = const {};
      _loadedRevisionCount = 0;
      timelineWarning = null;
      _replaceLegacyShifts(
        _alertService.addOffDutyPeriods(
          _applyReferenceRelationships(rangedParsed),
        ),
      );
      sheetTitles = document.snapshots.map((sheet) => sheet.title).toList();
      localSourceLabel = 'ไฟล์ .${document.extension} ในเครื่อง';
      existingKeys = {};
      calendarPeriods = [];
      _autoRefreshTimer?.cancel();
      _rebuildAlerts(applyDecisions: true);
      lastRefresh = DateTime.now();
      status =
          'อ่านไฟล์ .${document.extension} ${document.snapshots.length} แท็บ '
          'พบ ${rangedParsed.length} เวรในช่วงที่กำหนด; ไฟล์ไม่ถูกอัปโหลด';
      await _addAudit(
        'local_file.read',
        'อ่านไฟล์ .${document.extension} ในหน่วยความจำ '
            '${document.snapshots.length} แท็บ พบ ${rangedParsed.length} เวร; '
            'ไม่บันทึกชื่อไฟล์หรือเนื้อหาใน Audit log',
        true,
      );
    });
  }

  Future<void> loadMonthlyRoster() async {
    final sourceUrl = currentSourceUrl;
    if (sourceUrl.isEmpty) {
      throw StateError('กรุณาเลือก Google Sheets ก่อนอ่านตารางรายเดือน');
    }
    await _run('อ่านตารางเวรรายเดือน', () async {
      final client = await auth.clientFor([
        sheets.SheetsApi.spreadsheetsReadonlyScope,
        drive.DriveApi.driveMetadataReadonlyScope,
      ]);
      try {
        final spreadsheetId = _sheetsService.parseSpreadsheetId(sourceUrl);
        await _ownershipService.requireOwnedSpreadsheet(client, spreadsheetId);
        final snapshots = await _sheetsService.readAll(client, sourceUrl);
        final parsedMonthly = _parseMonthlyRosterSnapshots(
          snapshots,
          spreadsheetId: spreadsheetId,
        );
        monthlyRoster = parsedMonthly.sections.isEmpty
            ? MonthlyRosterParseReport.fromShifts(
                _parseAllRosterSnapshots(snapshots, fallback: const []),
              )
            : parsedMonthly;
        sheetTitles = snapshots.map((sheet) => sheet.title).toList();
        localSourceLabel = null;
        lastRefresh = DateTime.now();
        status =
            'อ่านตารางรายเดือน ${monthlyRoster.sections.length} บล็อก '
            '${monthlyRoster.assignments.length} ช่อง';
        await _addAudit(
          'monthly_roster.sheet.read',
          'อ่านตารางรายเดือนจาก Google Sheets แบบ read-only '
              '${monthlyRoster.sections.length} บล็อก',
          true,
        );
      } finally {
        client.close();
      }
    });
  }

  Future<void> importLocalMonthlyRosterFile() async {
    await _run('นำเข้าไฟล์ตารางเวรรายเดือน', () async {
      final document = await _localFileService.pickAndRead();
      if (document == null) {
        status = 'ยกเลิกการเลือกไฟล์';
        return;
      }
      final parsedMonthly = _parseMonthlyRosterSnapshots(
        document.snapshots,
        spreadsheetId: 'local-monthly-${document.extension}',
      );
      monthlyRoster = parsedMonthly.sections.isEmpty
          ? MonthlyRosterParseReport.fromShifts(
              _parseAllRosterSnapshots(document.snapshots, fallback: const []),
            )
          : parsedMonthly;
      sheetTitles = document.snapshots.map((sheet) => sheet.title).toList();
      localSourceLabel = 'ไฟล์ .${document.extension} ในเครื่อง';
      lastRefresh = DateTime.now();
      status =
          'นำเข้าตารางรายเดือน ${monthlyRoster.sections.length} บล็อก '
          '${monthlyRoster.assignments.length} ช่อง; ไฟล์ไม่ถูกอัปโหลด';
      await _addAudit(
        'monthly_roster.local.read',
        'อ่านไฟล์ตารางรายเดือนในหน่วยความจำ; '
            'ไม่บันทึกชื่อไฟล์หรือเนื้อหาใน Audit log',
        true,
      );
    });
  }

  MonthlyRosterParseReport _parseMonthlyRosterSnapshots(
    List<SheetSnapshot> snapshots, {
    required String spreadsheetId,
  }) {
    final sections = <MonthlyRosterSection>[];
    final warnings = <String>[];
    const parser = MonthlyRosterSectionParser();

    for (var sheetIndex = 0; sheetIndex < snapshots.length; sheetIndex++) {
      final snapshot = snapshots[sheetIndex];
      final cells = <NormalizedCell>[];
      for (var rowIndex = 0; rowIndex < snapshot.rows.length; rowIndex++) {
        final row = snapshot.rows[rowIndex];
        for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
          final value = row[columnIndex];
          final text = value?.toString().trim();
          if ((text == null || text.isEmpty) &&
              snapshot.backgroundColorAt(rowIndex, columnIndex) == null) {
            continue;
          }
          cells.add(
            NormalizedCell(
              sheetId: sheetIndex,
              sheetTitle: snapshot.title,
              a1: '',
              rowIndex: rowIndex,
              columnIndex: columnIndex,
              text: text == null || text.isEmpty ? null : text,
              rawValue: value,
              backgroundColor: _sheetColor(
                snapshot.backgroundColorAt(rowIndex, columnIndex),
              ),
            ),
          );
        }
      }
      final report = parser.parse(
        ShiftParserInput(
          spreadsheetId: spreadsheetId,
          spreadsheetTitle: selectedSourceSheetTitle,
          sheetId: sheetIndex,
          sheetTitle: snapshot.title,
          timeZone: 'Asia/Bangkok',
          cells: cells,
        ),
      );
      sections.addAll(report.sections);
      warnings.addAll(report.warnings);
    }

    final report = MonthlyRosterParseReport(
      sections: List.unmodifiable(sections),
      warnings: List.unmodifiable(warnings),
    );
    return settings.effectivePeriods.isEmpty
        ? report
        : report.filtered(
            includesDate: (date) =>
                settings.includesPeriod(date.year, date.month),
          );
  }

  SheetColor? _sheetColor(int? value) {
    if (value == null) return null;
    return SheetColor(
      red: ((value >> 16) & 0xFF) / 255,
      green: ((value >> 8) & 0xFF) / 255,
      blue: (value & 0xFF) / 255,
      alpha: ((value >> 24) & 0xFF) / 255,
    );
  }

  Future<void> attachLocalReferenceFile() async {
    final searchNames = rosterSearchNames;
    if (searchNames.isEmpty) {
      throw const FormatException(
        'กรุณากรอกชื่อที่ต้องค้นหา หรือล็อกอินเพื่อใช้ชื่อโปรไฟล์ Google',
      );
    }
    if (shifts.isEmpty) {
      throw StateError('กรุณาอ่านไฟล์หลักที่จะซิงก์ก่อนแนบไฟล์ต้นฉบับ');
    }
    await _run('แนบไฟล์ต้นฉบับเพื่อเปรียบเทียบ', () async {
      final document = await _localFileService.pickAndRead();
      if (document == null) {
        status = 'ยกเลิกการแนบไฟล์ต้นฉบับ';
        return;
      }
      localReferenceShifts = _parseRosterSnapshots(
        document.snapshots,
        searchNames: searchNames,
      );
      _referenceAllRosterShifts = _parseAllRosterSnapshots(
        document.snapshots,
        fallback: localReferenceShifts,
      );
      localReferenceLabel =
          'ไฟล์ต้นฉบับ .${document.extension} • '
          '${document.snapshots.length} แท็บ';
      final primary = shifts
          .where((shift) => !shift.generated)
          .map((shift) => shift.copyWith(clearRelationshipComment: true))
          .toList(growable: false);
      _replaceLegacyShifts(
        _alertService.addOffDutyPeriods(_applyReferenceRelationships(primary)),
      );
      final comparison = localReferenceComparison!;
      status =
          'แนบไฟล์ต้นฉบับแล้ว • ตรงกัน ${comparison.matched} • '
          'เปลี่ยน ${comparison.changed} • '
          'ขาดจากไฟล์ซิงก์ ${comparison.missingFromSync} • '
          'มีเฉพาะไฟล์ซิงก์ ${comparison.onlyInSync} • '
          'รับ/แทนเวร $localReceivedShiftCount • '
          'ยกเวร $localGivenShiftCount';
      await _addAudit(
        'local_reference.read',
        'อ่านไฟล์ต้นฉบับในหน่วยความจำ '
            '${document.snapshots.length} แท็บ '
            'พบ ${localReferenceShifts.length} เวร; '
            'ไม่อัปโหลดและไม่บันทึกชื่อไฟล์',
        true,
      );
    });
  }

  Future<void> clearLocalReferenceFile() async {
    localReferenceLabel = null;
    localReferenceShifts = [];
    _referenceAllRosterShifts = [];
    final primary = shifts
        .where((shift) => !shift.generated)
        .map((shift) => shift.copyWith(clearRelationshipComment: true))
        .toList(growable: false);
    _replaceLegacyShifts(_alertService.addOffDutyPeriods(primary));
    status = 'ถอดไฟล์ต้นฉบับที่ใช้เปรียบเทียบแล้ว';
    notifyListeners();
    await _addAudit(
      'local_reference.clear',
      'ถอดไฟล์ต้นฉบับออกจากหน่วยความจำ',
      true,
    );
  }

  void refreshNow() {
    if (!busy && auth.isSignedIn) {
      unawaited(loadRoster());
    }
  }

  Future<void> compareCalendar() async {
    if (shifts.isEmpty) throw StateError('กรุณาอ่านตารางเวรก่อน');
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
        final reference = localReferenceComparison;
        status =
            'มีแล้ว $existingCount รายการ • เตรียมเพิ่ม $newCount รายการ • '
            'แจ้งเตือนรอตัดสินใจ $pendingAlertCount รายการ'
            '${reference == null ? '' : ' • ไฟล์ต้นฉบับต่าง ${reference.issueCount} รายการ'}';
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

  Future<int> findDuplicateCalendarEvents() async {
    if (!auth.isSignedIn) {
      throw StateError('กรุณาเชื่อมต่อบัญชี Google ก่อนตรวจเวรซ้ำ');
    }
    await _run('ตรวจหาเวรซ้ำใน Google Calendar', () async {
      final client = await auth.clientFor([
        calendar.CalendarApi.calendarEventsReadonlyScope,
      ]);
      try {
        final duplicateIds = <String>{};
        for (final period in _activeRosterPeriods()) {
          duplicateIds.addAll(
            await _calendarService.findManagedDuplicateEventIds(
              client,
              year: period.year,
              month: period.month,
              desiredShifts: shifts
                  .where(
                    (shift) =>
                        !shift.excluded &&
                        shift.start.year == period.year &&
                        shift.start.month == period.month,
                  )
                  .toList(growable: false),
            ),
          );
        }
        _duplicateCalendarEventIds = duplicateIds;
        status = duplicateIds.isEmpty
            ? 'ไม่พบเวรซ้ำที่สร้างโดย Shift Tools'
            : 'พบเวรซ้ำที่ลบได้ ${duplicateIds.length} รายการ';
        await _addAudit(
          'calendar.duplicate.scan',
          'ตรวจแบบอ่านอย่างเดียว พบเวรซ้ำที่มี metadata ของระบบ '
              '${duplicateIds.length} รายการ',
          true,
        );
      } finally {
        client.close();
      }
    });
    return duplicateCalendarEventCount;
  }

  Future<void> deleteDuplicateCalendarEvents() async {
    final ids = _duplicateCalendarEventIds.toList(growable: false);
    if (ids.isEmpty) {
      throw StateError('กรุณากดตรวจหาเวรซ้ำก่อนลบ');
    }
    await _run('ลบเวรซ้ำจาก Google Calendar', () async {
      final client = await auth.clientFor([
        calendar.CalendarApi.calendarEventsScope,
      ]);
      var deleted = 0;
      try {
        for (final eventId in ids) {
          await _calendarService.deleteEvent(client, eventId: eventId);
          deleted++;
        }
        _duplicateCalendarEventIds = {};
        existingKeys = {};
        calendarPeriods = [];
        _rebuildAlerts();
        status = 'ลบเวรซ้ำจาก Google Calendar แล้ว $deleted รายการ';
        await _addAudit(
          'calendar.duplicate.delete',
          'ผู้ใช้ยืนยันลบเวรซ้ำที่มี metadata ของระบบ $deleted รายการ',
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
      final workflow =
          _pendingCalendarWorkflow ?? await _createPreparedCalendarWorkflow();
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
  Future<CalendarDiff> previewCalendarDiff() async {
    // Dispose any previous prepared workflow and create a new one.
    _pendingCalendarWorkflow?.dispose();
    _pendingCalendarWorkflow = null;
    final workflow = await _createPreparedCalendarWorkflow();
    _pendingCalendarWorkflow = workflow;
    final prep = workflow.schedulePreparation;
    if (prep == null) {
      throw StateError('ไม่พบแผนการซิงก์ที่เตรียมไว้');
    }
    return prep.diff;
  }

  /// Prepares a preview for a pre-mapped list of desired calendar event
  /// candidates (used for swap/one-off previews) and returns the computed diff.
  Future<CalendarDiff> previewCandidates(
    List<CalendarEventCandidate> desired,
  ) async {
    final workflow = await _calendarWorkflowControllerFactory();
    try {
      await workflow.prepareCandidatePreview(desired: desired);
      final preview = workflow.preview;
      if (preview == null) throw StateError('ไม่พบ preview หลังจากเตรียม');
      return preview.diff;
    } finally {
      workflow.dispose();
    }
  }

  /// Executes synchronization for a pre-mapped set of desired candidates.
  Future<void> syncCandidates(List<CalendarEventCandidate> desired) async {
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
  }

  /// Releases an authorized prepared workflow when confirmation is cancelled.
  void cancelCalendarSyncPreparation() {
    _pendingCalendarWorkflow?.dispose();
    _pendingCalendarWorkflow = null;
  }

  Future<ShiftCalendarWorkflowController>
  _createPreparedCalendarWorkflow() async {
    final workflow = await _calendarWorkflowControllerFactory();
    try {
      await workflow.prepareSchedule(_scheduleForActivePeriods());
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
    if (!end.isAfter(start)) {
      throw const FormatException('เวลาสิ้นสุดต้องอยู่หลังเวลาเริ่ม');
    }
    final color = CalendarColorService.parseCommand(colorCommand);
    final sourceKey =
        _shiftOverrideSourceKeys[shift.sourceKey] ?? shift.sourceKey;
    final updated = shift.copyWith(
      customTitle: title.trim().isEmpty ? shift.displayName : title.trim(),
      start: start,
      end: end,
      category: category,
      generated: false,
      calendarColorId: color?.id,
      clearCalendarColor: color == null,
    );
    updatedShifts[index] = updated;
    _rememberShiftOverride(updated, sourceKey: sourceKey);
    _replaceLegacyShifts(
      _alertService.addOffDutyPeriods(
        updatedShifts.where((item) => !item.generated).toList(),
      ),
    );
    calendarPeriods = [];
    existingKeys = {};
    _rebuildAlerts();
    status = 'ปรับชื่อ เวลา ประเภท และสีของรายการแล้ว';
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
    final color = CalendarColorService.parseCommand(colorCommand);
    final code =
        'MANUAL-${start.year}${start.month.toString().padLeft(2, '0')}'
        '${start.day.toString().padLeft(2, '0')}-'
        '${start.hour.toString().padLeft(2, '0')}'
        '${start.minute.toString().padLeft(2, '0')}-${shifts.length + 1}';
    final shift = Shift(
      code: code,
      rowLabel: normalizedTitle,
      assignedName: searchNames.firstOrNull ?? '',
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
    monthlyRoster = monthlyRoster.appendShift(shift);
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

  Future<SavedSheet> _saveSheetReference(
    String accountId,
    SheetReference reference,
  ) async {
    final saved = SavedSheet(
      ownerAccountId: accountId,
      spreadsheetId: reference.spreadsheetId,
      spreadsheetTitle: reference.spreadsheetTitle,
      sheetId: reference.sheetId,
      sheetTitle: reference.sheetTitle,
      url: reference.url,
      savedAt: DateTime.now(),
    );
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

  Future<void> _run(String action, Future<void> Function() body) async {
    if (busy) return;
    busy = true;
    status = action;
    error = null;
    notifyListeners();
    try {
      await body();
    } catch (caught) {
      error = caught.toString().replaceFirst('Bad state: ', '');
      await _addAudit('error', '$action: $error', false);
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _addAudit(String action, String message, bool success) async {
    final entry = AuditEntry(
      timestamp: DateTime.now(),
      action: action,
      message: message,
      success: success,
    );
    auditEntries.insert(0, entry);
    await _settingsService.appendAudit(entry);
  }

  void _onAuthChanged() {
    final accountId = auth.account?.id;
    if (_observedAccountId != accountId) {
      _observedAccountId = accountId;
      settings = settings.clearRosterSelection();
      _autoRefreshTimer?.cancel();
      _replaceLegacyShifts(const []);
      alerts = [];
      calendarPeriods = [];
      existingKeys = {};
      sheetTitles = [];
      recentOwnedSheets = [];
      localSourceLabel = null;
      localReferenceLabel = null;
      localReferenceShifts = [];
      _currentAllRosterShifts = [];
      _referenceAllRosterShifts = [];
      _revisionTimelines = const {};
      _loadedRevisionCount = 0;
      timelineWarning = null;
      _loadedRosterShifts = [];
      syncRangeStart = null;
      syncRangeEnd = null;
      _syncRangeCustomized = false;
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
      final selectedPeriods = settings.effectivePeriods;
      final selectedShifts = selectedPeriods.isEmpty
          ? allPeriods
          : allPeriods
                .where(
                  (shift) => settings.includesPeriod(
                    shift.start.year,
                    shift.start.month,
                  ),
                )
                .toList(growable: false);
      if (allPeriods.isNotEmpty || selectedPeriods.isEmpty) {
        return selectedShifts.map(_applyShiftOverride).toList(growable: false)
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
      for (final shift in periodShifts) {
        parsedByKey[shift.sourceKey] = _applyShiftOverride(shift);
      }
    }
    return parsedByKey.values.toList()
      ..sort((left, right) => left.start.compareTo(right.start));
  }

  List<Shift> _parseAllRosterSnapshots(
    List<SheetSnapshot> snapshots, {
    required List<Shift> fallback,
  }) {
    final parser = _parser;
    return parser is FullRosterShiftParser
        ? (parser as FullRosterShiftParser).parseAllWorkersAllPeriods(
            snapshots: snapshots,
          )
        : fallback;
  }

  List<Shift> _applyReferenceRelationships(List<Shift> primary) {
    if (_revisionTimelines.isEmpty &&
        (localReferenceLabel == null ||
            _referenceAllRosterShifts.isEmpty ||
            _currentAllRosterShifts.isEmpty)) {
      return primary;
    }
    final originalByPosition = {
      for (final shift in _referenceAllRosterShifts)
        _rosterPositionKey(shift): shift,
    };
    final currentByPosition = {
      for (final shift in _currentAllRosterShifts)
        _rosterPositionKey(shift): shift,
    };
    return [
      for (final shift in primary)
        _annotateKnownRelationship(
          shift,
          originalByPosition,
          currentByPosition,
        ),
    ];
  }

  Shift _annotateKnownRelationship(
    Shift shift,
    Map<String, Shift> originalByPosition,
    Map<String, Shift> currentByPosition,
  ) {
    final position = _rosterPositionKey(shift);
    final timeline = _revisionTimelines[position];
    if (timeline != null && timeline.versions.length > 1) {
      return _annotateTimelineRelationship(shift, timeline);
    }
    if (localReferenceLabel == null) {
      return shift.copyWith(clearRelationshipComment: true);
    }
    return _annotateRelationship(
      shift,
      originalByPosition[position],
      currentByPosition[position] ?? shift,
    );
  }

  Shift _annotateTimelineRelationship(
    Shift shift,
    RosterAssignmentTimeline timeline,
  ) {
    final versions = timeline.versions;
    final workers = timeline.workerChain;
    final first = _normalizeWorker(workers.first);
    final last = _normalizeWorker(workers.last);
    final changedBack = versions.length >= 3 && first == last;
    final receivedOnward =
        versions.length >= 3 &&
        !changedBack &&
        _matchesRosterUser(workers.last);
    final status = changedBack
        ? 'สถานะ: เปลี่ยนเวรแล้วเปลี่ยนกลับ'
        : receivedOnward
        ? 'สถานะ: รับต่อ/แลกมา'
        : 'สถานะ: รับเวร/แลกมา';
    return shift.copyWith(
      relationshipComment: <String>[
        status,
        'Timeline: ${workers.join(' → ')}',
        'ประวัติจาก Google Sheets (อ่านอย่างเดียว):',
        for (final version in versions)
          '- ${_revisionTimeLabel(version.modifiedAt)}: ${version.assignedName}',
      ].join('\n'),
    );
  }

  String _revisionTimeLabel(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year + 543;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Shift _annotateRelationship(Shift shift, Shift? original, Shift current) {
    if (shift.category == ShiftCategory.given) {
      return shift.copyWith(
        relationshipComment: <String>[
          'สถานะ: ยกเวร',
          if (original != null) 'เจ้าของเวรเดิม: ${original.assignedName}',
          'ผู้ปฏิบัติงานตามไฟล์ล่าสุด: ${current.assignedName}',
        ].join('\n'),
      );
    }
    if (original == null ||
        _normalizeWorker(original.assignedName) ==
            _normalizeWorker(current.assignedName)) {
      return shift.copyWith(clearRelationshipComment: true);
    }
    return shift.copyWith(
      relationshipComment: <String>[
        'สถานะ: รับเวร/คนแทนเวร',
        'เจ้าของเวรเดิม: ${original.assignedName}',
        'ผู้ปฏิบัติงานปัจจุบัน: ${current.assignedName}',
      ].join('\n'),
    );
  }

  int _relationshipCount({required bool received}) {
    if (localReferenceLabel == null) return 0;
    final originalByPosition = {
      for (final shift in _referenceAllRosterShifts)
        _rosterPositionKey(shift): shift,
    };
    final currentByPosition = {
      for (final shift in _currentAllRosterShifts)
        _rosterPositionKey(shift): shift,
    };
    final positions = <String>{
      ...originalByPosition.keys,
      ...currentByPosition.keys,
    };
    return positions.where((position) {
      final before = originalByPosition[position]?.assignedName ?? '';
      final after = currentByPosition[position]?.assignedName ?? '';
      final wasUser = _matchesRosterUser(before);
      final isUser = _matchesRosterUser(after);
      return received ? !wasUser && isUser : wasUser && !isUser;
    }).length;
  }

  bool _matchesRosterUser(String value) {
    final normalized = _normalizeWorker(value);
    return normalized.isNotEmpty &&
        rosterSearchNames.map(_normalizeWorker).any(normalized.contains);
  }

  String _rosterPositionKey(Shift shift) => rosterPositionKey(shift);

  String _normalizeWorker(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  List<RosterPeriod> _periodsForShifts(Iterable<Shift> source) {
    final periods = <RosterPeriod>{
      for (final shift in source)
        if (!shift.generated)
          RosterPeriod(year: shift.start.year, month: shift.start.month),
    }.toList()..sort((left, right) => left.key.compareTo(right.key));
    return List.unmodifiable(periods);
  }

  List<RosterPeriod> _activeRosterPeriods() {
    final selectedPeriods = settings.effectivePeriods;
    if (selectedPeriods.isNotEmpty) return selectedPeriods;
    final periods = _periodsForShifts(shifts);
    return periods.isEmpty ? _requirePeriods() : periods;
  }

  Schedule _scheduleForActivePeriods() {
    final activePeriods = _activeRosterPeriods().toSet();
    return canonicalSchedule.copyWith(
      months: canonicalSchedule.months
          .where(
            (month) => activePeriods.contains(
              RosterPeriod(year: month.month.year, month: month.month.month),
            ),
          )
          .map(
            (month) => ScheduleMonth(
              month: month.month,
              days: month.days
                  .where((day) => _includesSyncDate(day.date))
                  .toList(growable: false),
            ),
          )
          .where((month) => month.days.isNotEmpty)
          .toList(growable: false),
    );
  }

  void _setDefaultSyncDateRange(List<Shift> parsed) {
    if (_syncRangeCustomized &&
        syncRangeStart != null &&
        syncRangeEnd != null) {
      return;
    }
    final ranges = monthlyRoster.dateRanges;
    if (ranges.isEmpty) {
      if (parsed.isEmpty) return;
      syncRangeStart = parsed.first.start;
      syncRangeEnd = parsed.last.start;
      return;
    }
    final anchor = parsed.firstOrNull?.start;
    final selected = anchor == null
        ? ranges.first
        : ranges.firstWhere(
            (range) =>
                !anchor.isBefore(range.start) && !anchor.isAfter(range.end),
            orElse: () => ranges.first,
          );
    syncRangeStart = selected.start;
    syncRangeEnd = selected.end;
  }

  void _resetSyncRange() {
    syncRangeStart = null;
    syncRangeEnd = null;
    _syncRangeCustomized = false;
    _loadedRosterShifts = [];
  }

  List<Shift> _filterToSyncDateRange(Iterable<Shift> source) => source
      .where((shift) => _includesSyncDate(shift.start))
      .toList(growable: false);

  bool _includesSyncDate(DateTime date) {
    final start = syncRangeStart;
    final end = syncRangeEnd;
    if (start == null || end == null) return true;
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  String _dateLabel(DateTime date) =>
      '${date.day}/${date.month}/${date.year + 543}';

  void _rememberShiftOverride(Shift shift, {String? sourceKey}) {
    final stableSourceKey =
        sourceKey ??
        _shiftOverrideSourceKeys[shift.sourceKey] ??
        shift.sourceKey;
    _shiftOverrides[stableSourceKey] = _ShiftOverride(
      category: shift.category,
      excluded: shift.excluded,
      start: shift.start,
      end: shift.end,
      customTitle: shift.customTitle,
      calendarColorId: shift.calendarColorId,
    );
    _shiftOverrideSourceKeys[shift.sourceKey] = stableSourceKey;
  }

  Shift _applyShiftOverride(Shift shift) {
    final override = _shiftOverrides[shift.sourceKey];
    if (override == null) return shift;
    final updated = shift.copyWith(
      category: override.category,
      excluded: override.excluded,
      start: override.start,
      end: override.end,
      customTitle: override.customTitle,
      calendarColorId: override.calendarColorId,
      clearCalendarColor: override.calendarColorId == null,
    );
    _shiftOverrideSourceKeys[updated.sourceKey] = shift.sourceKey;
    return updated;
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
    auth.removeListener(_onAuthChanged);
    auth.dispose();
    super.dispose();
  }
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
