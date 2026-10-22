import 'dart:async';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../controller/app_controller.dart';
import '../features/google_drive/application/multi_sheet_picker_selection.dart';
import '../domain/entities/schedule.dart';
import '../features/reports/presentation/controllers/monthly_schedule_report_controller.dart';
import '../features/reports/presentation/pages/monthly_schedule_report_page.dart';
import '../features/admin/presentation/admin_access_page.dart';
import '../features/edition/domain/app_edition.dart';
import '../features/roster_names/presentation/roster_name_list_page.dart';
import '../features/employees/presentation/pages/employee_directory_page.dart';
import '../features/employees/presentation/controllers/employee_directory_controller.dart';
import '../features/dashboard/application/dashboard_summary_service.dart';
import '../features/dashboard/presentation/widgets/dashboard_summary_grid.dart';
import '../features/shift_exchange/presentation/pages/shift_exchange_page.dart';
import '../features/shift_exchange/presentation/controllers/shift_exchange_controller.dart';
import '../features/shift_parser/domain/monthly_roster_section.dart';
import '../features/shift_parser/domain/monthly_roster_template.dart';
import '../features/shift_templates/application/shift_template_controller.dart';
import '../features/shift_templates/presentation/shift_templates_page.dart';
import '../features/schedule/presentation/controllers/schedule_controller.dart';
import '../features/schedule/presentation/pages/schedule_workspace_page.dart';
import '../l10n/l10n.dart';
import '../models/saved_sheet.dart';
import '../models/roster_period.dart';
import '../models/shift.dart';
import '../models/shift_alert.dart';
import '../models/tool_definition.dart';
import '../services/calendar_service.dart';
import '../services/calendar_color_service.dart';
import '../services/drive_ownership_service.dart';
import '../services/google_auth_service.dart';
import '../services/shift_color_service.dart';
import 'first_login_setup_dialog.dart';
import 'google_sign_in_button.dart';

enum _UtilityPage {
  notifications,
  history,
  tools;

  String label(BuildContext context) => switch (this) {
    notifications => context.l10n.notifications,
    history => context.l10n.history,
    tools => context.l10n.tools,
  };
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.controller,
    required this.reportControllerFactory,
    required this.locale,
    required this.onLocaleChanged,
    required this.employeeDirectoryControllerFactory,
    required this.shiftExchangeControllerFactory,
    required this.dashboardSummaryService,
    required this.shiftTemplateControllerFactory,
    required this.scheduleControllerFactory,
  });

  final AppController controller;
  final MonthlyScheduleReportController Function(Schedule)
  reportControllerFactory;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final EmployeeDirectoryController Function(Schedule)
  employeeDirectoryControllerFactory;
  final ShiftExchangeController Function() shiftExchangeControllerFactory;
  final DashboardSummaryService dashboardSummaryService;
  final ShiftTemplateController Function() shiftTemplateControllerFactory;
  final Future<ScheduleController> Function(Schedule) scheduleControllerFactory;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  final editionRepository = AppEditionRepository();
  AppEdition? edition;
  bool editionLoading = true;
  bool _permissionDialogOpen = false;
  String? _permissionDialogShownForEmail;
  bool _setupDialogOpen = false;
  String? _setupDialogShownForEmail;

  List<NavigationDestination> _destinations(
    BuildContext context,
    AppController controller,
    AppEdition currentEdition,
  ) => [
    NavigationDestination(
      icon: const Icon(Icons.dashboard_outlined),
      label: context.l10n.dashboard,
    ),
    NavigationDestination(
      icon: const Icon(Icons.event_note_outlined),
      label: context.l10n.schedule,
    ),
    const NavigationDestination(
      icon: Icon(Icons.calendar_view_month_outlined),
      label: 'รายเดือน',
    ),
    if (currentEdition == AppEdition.organization) ...[
      const NavigationDestination(
        icon: Icon(Icons.badge_outlined),
        label: 'รายชื่อ',
      ),
      NavigationDestination(
        icon: const Icon(Icons.groups_outlined),
        label: context.l10n.employees,
      ),
      NavigationDestination(
        icon: const Icon(Icons.swap_horiz_outlined),
        label: context.l10n.shiftExchange,
      ),
    ],
    NavigationDestination(
      icon: const Icon(Icons.print_outlined),
      label: context.l10n.reports,
    ),
    if (currentEdition == AppEdition.organization)
      const NavigationDestination(
        icon: Icon(Icons.admin_panel_settings_outlined),
        label: 'Admin',
      ),
    NavigationDestination(
      icon: const Icon(Icons.settings_outlined),
      label: context.l10n.settings,
    ),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    unawaited(_loadEdition());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    final auth = widget.controller.auth;
    final account = auth.account;
    if (account == null) {
      _permissionDialogShownForEmail = null;
      _setupDialogShownForEmail = null;
      return;
    }
    if (_permissionDialogOpen || auth.checkingReadAccess) return;
    if (auth.readAccessGranted) {
      if (!widget.controller.settings.setupComplete &&
          !_setupDialogOpen &&
          _setupDialogShownForEmail != account.email) {
        _setupDialogShownForEmail = account.email;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_showFirstLoginSetupDialog(account.email));
        });
      }
      return;
    }
    if (_permissionDialogShownForEmail == account.email) return;
    _permissionDialogShownForEmail = account.email;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showReadAccessDialog(account.email));
    });
  }

  Future<void> _showFirstLoginSetupDialog(String email) async {
    if (_setupDialogOpen || !mounted) return;
    _setupDialogOpen = true;
    try { await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => FirstLoginSetupDialog(controller: widget.controller, edition: edition ?? AppEdition.personal)); }
    finally { _setupDialogOpen = false; if (mounted && !widget.controller.settings.setupComplete) _setupDialogShownForEmail = null; }
  }

  Future<void> _openSetupFromSettings() => _showFirstLoginSetupDialog(widget.controller.auth.account?.email ?? '');

  Future<void> _loadEdition() async {
    final loaded = await editionRepository.load();
    widget.controller.shiftTimelineEnabled =
        loaded == AppEdition.organization;
    if (mounted) {
      setState(() {
        edition = loaded;
        editionLoading = false;
      });
    }
  }

  Future<void> _selectEdition(AppEdition value) async {
    await editionRepository.save(value);
    widget.controller.shiftTimelineEnabled =
        value == AppEdition.organization;
    if (mounted) {
      setState(() {
        edition = value;
        selectedIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      if (!controller.initialized) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (editionLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (edition == null) {
        return _EditionSelectionPage(onSelected: _selectEdition);
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final currentEdition = edition!;
          final destinations = _destinations(
            context,
            controller,
            currentEdition,
          );
          final pages = <Widget>[
            _DashboardPage(
              controller: controller,
              perform: _perform,
              compareCalendar: _compareCalendar,
              deleteDuplicateCalendarEvents: _deleteDuplicateCalendarEvents,
              sync: _sync,
              openAlerts: () =>
                  unawaited(_openUtilityPage(_UtilityPage.notifications)),
              configureGoogleOAuth: _configureGoogleOAuth,
              dashboardSummaryService: widget.dashboardSummaryService,
            ),
            _PreviewPage(
              controller: controller,
              perform: _perform,
              openRosterEditor: _openRosterEditor,
            ),
            _MonthlyRosterPage(controller: controller, perform: _perform),
            if (currentEdition == AppEdition.organization) ...[
              RosterNameListPage(controller: controller, perform: _perform),
              EmployeeDirectoryPage(
                schedule: controller.canonicalSchedule,
                controllerFactory: widget.employeeDirectoryControllerFactory,
              ),
              ShiftExchangePage(
                schedule: controller.canonicalSchedule,
                controllerFactory: widget.shiftExchangeControllerFactory,
              ),
            ],
            MonthlyScheduleReportPage(
              schedule: controller.canonicalSchedule,
              controllerFactory: widget.reportControllerFactory,
            ),
            if (currentEdition == AppEdition.organization)
              AdminAccessPage(currentEmail: controller.auth.account?.email),
            _SettingsPage(
              controller: controller,
              createFutureSheet: _createFutureSheet,
              openShiftTemplates: _openShiftTemplates,
              edition: currentEdition,
              changeEdition: _selectEdition,
              openSetup: _openSetupFromSettings,
            ),
          ];
          final content = IndexedStack(index: selectedIndex, children: pages);
          final mainContent = wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) =>
                          setState(() => selectedIndex = index),
                      labelType: NavigationRailLabelType.all,
                      leading: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircleAvatar(child: Icon(Icons.calendar_month)),
                      ),
                      destinations: [
                        for (final destination in destinations)
                          NavigationRailDestination(
                            icon: destination.icon,
                            label: Text(destination.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content;
          return Scaffold(
            appBar: AppBar(
              titleSpacing: 16,
              title: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    child: Icon(Icons.calendar_month_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.appTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          context.l10n.appSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(tooltip: 'Timeline ย้อนหลัง', icon: const Icon(Icons.history_toggle_off_outlined), onPressed: () => unawaited(_openUtilityPage(_UtilityPage.history))),
                IconButton(
                  key: const Key('locale-switch'),
                  tooltip: context.l10n.switchLanguage,
                  onPressed: () => widget.onLocaleChanged(
                    widget.locale.languageCode == 'th'
                        ? const Locale('en')
                        : const Locale('th'),
                  ),
                  icon: const Icon(Icons.language),
                ),
                PopupMenuButton<_UtilityPage>(
                  tooltip: context.l10n.more,
                  onSelected: (page) => unawaited(_openUtilityPage(page)),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _UtilityPage.notifications,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Badge(
                          isLabelVisible: controller.pendingAlertCount > 0,
                          label: Text('${controller.pendingAlertCount}'),
                          child: const Icon(Icons.notifications_outlined),
                        ),
                        title: Text(context.l10n.notifications),
                      ),
                    ),
                    PopupMenuItem(
                      value: _UtilityPage.history,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history_outlined),
                        title: Text(context.l10n.history),
                      ),
                    ),
                    PopupMenuItem(
                      value: _UtilityPage.tools,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.apps_outlined),
                        title: Text(context.l10n.tools),
                      ),
                    ),
                  ],
                ),
                if (controller.auth.account != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text(
                        controller.auth.account!.email,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
            body: Column(
              children: [
                _PinnedToolsBar(
                  tools: controller.pinnedTools.toList(),
                  openTool: _openTool,
                  manageTools: () =>
                      unawaited(_openUtilityPage(_UtilityPage.tools)),
                ),
                const Divider(height: 1),
                Expanded(child: mainContent),
              ],
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: selectedIndex,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.onlyShowSelected,
                    onDestinationSelected: (index) =>
                        setState(() => selectedIndex = index),
                    destinations: destinations,
                  ),
          );
        },
      );
    },
  );

  Future<void> _openUtilityPage(_UtilityPage page) {
    final child = switch (page) {
      _UtilityPage.notifications => _NotificationsPage(
        controller: widget.controller,
        perform: _perform,
      ),
      _UtilityPage.history => _AuditPage(
        controller: widget.controller,
        saveCurrentSheet: _saveCurrentSheet,
        activateSavedSheet: _activateSavedSheet,
        openSavedSheet: _openSavedSheet,
        deleteSavedSheet: _deleteSavedSheet,
      ),
      _UtilityPage.tools => _ToolsPage(
        controller: widget.controller,
        openTool: _openTool,
        togglePinned: _togglePinnedTool,
      ),
    };
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(page.label(context))),
          body: child,
        ),
      ),
    );
  }

  Future<void> _openShiftTemplates() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ShiftTemplatesPage(
          controllerFactory: widget.shiftTemplateControllerFactory,
        ),
      ),
    );
  }

  Future<void> _openRosterEditor() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => _OwnedScheduleEditorRoute(
          schedule: widget.controller.canonicalSchedule,
          controllerFactory: widget.scheduleControllerFactory,
          onCommitted: (schedule) => widget.controller.adoptCanonicalSchedule(
            schedule,
            persist: false,
          ),
        ),
      ),
    );
  }

  Future<void> _perform(Future<void> Function() action) async {
    await _performWithResult(action);
  }

  Future<bool> _performWithResult(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return false;
      final status = widget.controller.status;
      if (status != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(status)));
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    }
  }

  Future<void> _showReadAccessDialog(String email) async {
    if (_permissionDialogOpen || !mounted) return;
    _permissionDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.googleAccessTitle),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('บัญชี $email'),
              const SizedBox(height: 12),
              const Text(
                'แอปจะเปิดหน้าต่าง Google เพื่อขอสิทธิ์อ่านข้อมูลที่จำเป็น:',
              ),
              const SizedBox(height: 12),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.table_chart_outlined),
                title: Text('Google Sheets แบบอ่านอย่างเดียว'),
                subtitle: Text('ใช้ค้นหาเวร โดยไม่แก้ไขชีตต้นฉบับ'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.calendar_month_outlined),
                title: Text('Google Calendar แบบอ่านอย่างเดียว'),
                subtitle: Text('ใช้ตรวจรายการซ้ำก่อนบันทึก'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.badge_outlined),
                title: Text(
                  'ข้อมูลเจ้าของไฟล์ใน Google Drive แบบอ่านอย่างเดียว',
                ),
                subtitle: Text('ใช้ยืนยันว่าชีตหลักเป็นของบัญชีที่ล็อกอิน'),
              ),
              const Text(
                'สิทธิ์เขียน Calendar, Drive และ Sheets จะยังไม่ถูกขอในขั้นตอนนี้',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.googleAccessLater),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_perform(widget.controller.authorizeReadAccess));
            },
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(context.l10n.googleAccessAllow),
          ),
        ],
      ),
    );
    _permissionDialogOpen = false;
  }

  Future<void> _openTool(ToolDefinition tool) =>
      _perform(() => widget.controller.openTool(tool));

  Future<void> _togglePinnedTool(ToolDefinition tool) =>
      _perform(() => widget.controller.toggleToolPinned(tool));

  Future<void> _saveCurrentSheet() =>
      _perform(widget.controller.saveCurrentSheet);

  Future<void> _activateSavedSheet(SavedSheet sheet) => _perform(() async {
    await widget.controller.activateSavedSheet(sheet);
    await widget.controller.loadRoster();
  });

  Future<void> _openSavedSheet(SavedSheet sheet) =>
      _perform(() => widget.controller.openSavedSheet(sheet));

  Future<void> _deleteSavedSheet(SavedSheet sheet) async {
    final confirmed = await _showConfirmationDialog(
      title: 'ลบออกจากรายการบันทึก',
      message:
          'จะลบ “${sheet.displayTitle}” ออกจากรายการในเครื่องนี้เท่านั้น '
          'ไฟล์และแท็บจริงใน Google Sheets จะไม่ถูกลบ',
    );
    if (confirmed != true) return;
    await _perform(() => widget.controller.deleteSavedSheet(sheet));
  }

  Future<void> _sync() async {
    final compared = await _performWithResult(
      widget.controller.compareCalendar,
    );
    if (!compared) return;
    if (widget.controller.pendingAlertCount > 0) {
      await _showConflictWarningDialog();
      return;
    }
    final prepared = await _performWithResult(
      widget.controller.prepareCalendarSync,
    );
    if (!prepared) return;
    final confirmed = await _showSyncConfirmationDialog();
    if (confirmed != true) {
      widget.controller.cancelCalendarSyncPreparation();
      return;
    }
    final synced = await _performWithResult(widget.controller.syncCalendar);
    if (!synced && widget.controller.pendingAlertCount > 0) {
      await _showConflictWarningDialog();
    }
  }

  Future<void> _compareCalendar() async {
    final compared = await _performWithResult(
      widget.controller.compareCalendar,
    );
    if (compared && widget.controller.pendingAlertCount > 0) {
      await _showConflictWarningDialog();
    }
  }

  Future<void> _deleteDuplicateCalendarEvents() async {
    final scanned = await _performWithResult(
      widget.controller.findDuplicateCalendarEvents,
    );
    if (!scanned || !mounted) return;
    final count = widget.controller.duplicateCalendarEventCount;
    if (count == 0) return;
    final confirmed = await _showConfirmationDialog(
      title: 'ลบเวรซ้ำ $count รายการ?',
      message:
          'ระบบจะเก็บหนึ่งรายการต่อเวร และลบเฉพาะรายการซ้ำที่มี metadata '
          'ของ Shift Tools กิจกรรมส่วนตัวจะไม่ถูกลบ',
    );
    if (confirmed == true) {
      await _perform(widget.controller.deleteDuplicateCalendarEvents);
    }
  }

  Future<void> _showConflictWarningDialog() async {
    final pending = widget.controller.alerts
        .where((alert) => alert.isPending)
        .toList();
    if (!mounted || pending.isEmpty) return;
    final inspect = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(dialogContext).colorScheme.error,
          size: 34,
        ),
        title: Text('พบรายการชนกัน ${pending.length} รายการ'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ยังไม่มีข้อมูลใดถูกเขียนลง Google Calendar '
                  'กรุณาตรวจและตัดสินใจรายการต่อไปนี้ก่อน',
                ),
                const SizedBox(height: 12),
                for (final alert in pending.take(5)) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_busy_outlined),
                    title: Text(alert.title),
                    subtitle: Text(alert.message),
                  ),
                  const Divider(height: 1),
                ],
                if (pending.length > 5) ...[
                  const SizedBox(height: 10),
                  Text('และอีก ${pending.length - 5} รายการ'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ปิด'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('ตรวจและตัดสินใจ'),
          ),
        ],
      ),
    );
    if (inspect == true && mounted) {
      await _openUtilityPage(_UtilityPage.notifications);
    }
  }

  Future<void> _configureGoogleOAuth() async {
    final value = TextEditingController(
      text: widget.controller.auth.webClientId,
    );
    String? validationError;
    final clientId = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ตั้งค่า Google OAuth สำหรับ Web'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'วาง Web OAuth Client ID จาก Google Cloud เพื่อเปิดปุ่มล็อกอิน '
                  'Client ID เปิดเผยได้และไม่ใช่ Client Secret',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: value,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Web OAuth Client ID',
                    hintText: '123456789-abc.apps.googleusercontent.com',
                    errorText: validationError,
                    prefixIcon: const Icon(Icons.key_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Authorized JavaScript origin สำหรับหน้านี้ต้องมี '
                  '${Uri.base.origin}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () {
                final text = value.text.trim();
                if (!GoogleAuthService.isValidWebClientId(text)) {
                  setDialogState(
                    () => validationError = 'รูปแบบ Client ID ไม่ถูกต้อง',
                  );
                  return;
                }
                Navigator.pop(context, text);
              },
              child: const Text('บันทึกและเปิด Google Login'),
            ),
          ],
        ),
      ),
    );
    value.dispose();
    if (clientId == null) return;
    await _perform(
      () => widget.controller.configureGoogleWebClientId(clientId),
    );
  }

  Future<void> _createFutureSheet(String template, String newTitle) async {
    final confirmed = await _showConfirmationDialog(
      title: 'ยืนยันสร้างแท็บใหม่',
      message:
          'จะทำสำเนาแท็บ “$template” เป็น “$newTitle” '
          'โดยไม่แก้แท็บต้นแบบ',
    );
    if (confirmed != true) return;
    await _perform(
      () => widget.controller.createFutureSheet(
        templateTitle: template,
        newTitle: newTitle,
      ),
    );
  }

  Future<bool?> _showSyncConfirmationDialog() {
    final controller = widget.controller;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.googleSyncConfirmTitle),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('จะเพิ่มใหม่ ${controller.newCount} กิจกรรม'),
              Text('ข้ามรายการที่มีแล้ว ${controller.existingCount} กิจกรรม'),
              Text(
                controller.settings.archiveOriginal
                    ? 'จะสร้าง/ตรวจสำเนาต้นฉบับใน Drive ของบัญชีที่ล็อกอินก่อน'
                    : 'ไม่ได้เปิดสร้างสำเนาต้นฉบับ',
              ),
              const SizedBox(height: 12),
              const Text('ไฟล์ต้นฉบับ Google Sheets จะไม่ถูกแก้ไข'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.googleSyncConfirm),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 420, child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }
}

class _PinnedToolsBar extends StatelessWidget {
  const _PinnedToolsBar({
    required this.tools,
    required this.openTool,
    required this.manageTools,
  });

  final List<ToolDefinition> tools;
  final Future<void> Function(ToolDefinition tool) openTool;
  final VoidCallback manageTools;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SizedBox(
      height: 66,
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 8),
            child: Icon(Icons.apps_outlined),
          ),
          Expanded(
            child: tools.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: manageTools,
                      icon: const Icon(Icons.add),
                      label: const Text('ติดตั้งเครื่องมือในแถบ'),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: tools.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final tool = tools[index];
                      return ActionChip(
                        tooltip: 'เปิด ${tool.name}',
                        avatar: CircleAvatar(
                          backgroundColor: tool.color.withValues(alpha: 0.14),
                          child: Icon(tool.icon, size: 18, color: tool.color),
                        ),
                        label: Text(tool.name),
                        onPressed: () => unawaited(openTool(tool)),
                      );
                    },
                  ),
          ),
          IconButton(
            onPressed: manageTools,
            tooltip: 'จัดการเครื่องมือ',
            icon: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
    ),
  );
}

class _ToolsPage extends StatefulWidget {
  const _ToolsPage({
    required this.controller,
    required this.openTool,
    required this.togglePinned,
  });

  final AppController controller;
  final Future<void> Function(ToolDefinition tool) openTool;
  final Future<void> Function(ToolDefinition tool) togglePinned;

  @override
  State<_ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<_ToolsPage> {
  final search = TextEditingController();
  ToolGroup? selectedGroup;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final tools = toolCatalog.where((tool) {
      final matchesGroup = selectedGroup == null || tool.group == selectedGroup;
      final matchesQuery =
          query.isEmpty ||
          tool.name.toLowerCase().contains(query) ||
          tool.description.toLowerCase().contains(query);
      return matchesGroup && matchesQuery;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'คลังเครื่องมือ',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'ติดตั้งทางลัดลงแถบ แล้วเปิดด้วยบัญชีที่เลือกในแต่ละบริการได้ทุกระบบ',
              ),
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.privacy_tip_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'แอปเก็บเฉพาะรายการทางลัดที่ติดตั้งในเครื่องนี้ '
                          'ไม่เก็บอีเมล รหัสผ่าน หรือ token ของ Google, GitHub, AI และบริการอื่น',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'ค้นหาเครื่องมือ',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('ทั้งหมด'),
                      selected: selectedGroup == null,
                      onSelected: (_) => setState(() => selectedGroup = null),
                    ),
                    const SizedBox(width: 8),
                    for (final group in ToolGroup.values) ...[
                      FilterChip(
                        label: Text(_toolGroupLabel(group)),
                        selected: selectedGroup == group,
                        onSelected: (_) =>
                            setState(() => selectedGroup = group),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 980
                      ? 3
                      : constraints.maxWidth >= 620
                      ? 2
                      : 1;
                  const spacing = 16.0;
                  final width =
                      (constraints.maxWidth - (columns - 1) * spacing) /
                      columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final tool in tools)
                        SizedBox(
                          width: width,
                          child: _ToolCard(
                            tool: tool,
                            pinned: widget.controller.isToolPinned(tool.id),
                            openTool: widget.openTool,
                            togglePinned: widget.togglePinned,
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (tools.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('ไม่พบเครื่องมือที่ค้นหา')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.tool,
    required this.pinned,
    required this.openTool,
    required this.togglePinned,
  });

  final ToolDefinition tool;
  final bool pinned;
  final Future<void> Function(ToolDefinition tool) openTool;
  final Future<void> Function(ToolDefinition tool) togglePinned;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: tool.color.withValues(alpha: 0.14),
                child: Icon(tool.icon, color: tool.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tool.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (pinned)
                const Tooltip(
                  message: 'ติดตั้งในแถบแล้ว',
                  child: Icon(Icons.push_pin, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(tool.description),
          const SizedBox(height: 10),
          Text(
            tool.usesGoogleAccountChooser
                ? 'เลือกบัญชี Google ก่อนเปิดบริการ'
                : 'ใช้ระบบบัญชีของบริการนั้นโดยตรง',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => unawaited(openTool(tool)),
                icon: const Icon(Icons.open_in_new),
                label: const Text('เปิด'),
              ),
              OutlinedButton.icon(
                onPressed: () => unawaited(togglePinned(tool)),
                icon: Icon(pinned ? Icons.remove : Icons.add),
                label: Text(pinned ? 'นำออกจากแถบ' : 'ติดตั้งในแถบ'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

String _toolGroupLabel(ToolGroup group) => switch (group) {
  ToolGroup.google => 'Google',
  ToolGroup.ai => 'AI',
  ToolGroup.developer => 'นักพัฒนา',
  ToolGroup.productivity => 'งานและเอกสาร',
};

class _DashboardPage extends StatefulWidget {
  const _DashboardPage({
    required this.controller,
    required this.perform,
    required this.compareCalendar,
    required this.deleteDuplicateCalendarEvents,
    required this.sync,
    required this.openAlerts,
    required this.configureGoogleOAuth,
    required this.dashboardSummaryService,
  });

  final AppController controller;
  final Future<void> Function(Future<void> Function()) perform;
  final Future<void> Function() compareCalendar;
  final Future<void> Function() deleteDuplicateCalendarEvents;
  final Future<void> Function() sync;
  final VoidCallback openAlerts;
  final Future<void> Function() configureGoogleOAuth;
  final DashboardSummaryService dashboardSummaryService;

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  late final searchName = TextEditingController(
    text: widget.controller.settings.targetName,
  );
  late String? sourceAccountId = widget.controller.auth.account?.id;
  late int? month = widget.controller.settings.month;
  late int? year = widget.controller.settings.year;

  List<int> get selectableYears {
    final currentYear = DateTime.now().year;
    final values = <int>{
      for (var value = currentYear - 5; value <= currentYear + 10; value++)
        value,
      ?year,
    }.toList()..sort();
    return values;
  }

  @override
  void didUpdateWidget(covariant _DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextAccountId = widget.controller.auth.account?.id;
    final accountChanged = nextAccountId != sourceAccountId;
    if (accountChanged) {
      sourceAccountId = nextAccountId;
    }
    if (accountChanged) {
      searchName.text = widget.controller.settings.targetName;
      month = widget.controller.settings.month;
      year = widget.controller.settings.year;
    }
  }

  @override
  void dispose() {
    searchName.dispose();
    super.dispose();
  }

  Future<void> _saveSettings({bool? autoRefresh, int? refreshSeconds}) =>
      widget.controller.updateSettings(
        widget.controller.settings.copyWith(
          targetName: searchName.text.trim(),
          year: year,
          month: month,
          autoRefresh: autoRefresh,
          refreshSeconds: refreshSeconds,
        ),
      );

  Future<void> _pickGoogleSheet({
    OwnedSheetOrder order = OwnedSheetOrder.recentlyModified,
  }) async {
    final controller = widget.controller;

    if (!controller.auth.isSignedIn) {
      throw StateError('กรุณาเข้าสู่ระบบ Google ก่อนเลือกไฟล์');
    }

    await controller.findAvailableSourceSheets(order: order);
    if (!mounted) return;

    if (controller.recentOwnedSheets.isEmpty) {
      throw StateError('ไม่พบ Google Sheets ที่บัญชีนี้เข้าถึงได้');
    }

    final selection = await showDialog<_GoogleSheetPickerResult>(
      context: context,
      builder: (context) => _GoogleSheetPickerDialog(
        files: controller.recentOwnedSheets,
        order: order,
        alreadyAddedSpreadsheetIds: controller.savedSheetsForCurrentAccount
            .map((sheet) => sheet.spreadsheetId)
            .toSet(),
      ),
    );

    if (selection == null || !mounted) return;

    if (selection.removedSpreadsheetIds.isNotEmpty) {
      final savedToRemove = controller.savedSheetsForCurrentAccount
          .where(
            (sheet) =>
                selection.removedSpreadsheetIds.contains(sheet.spreadsheetId),
          )
          .toList(growable: false);
      for (final sheet in savedToRemove) {
        await controller.deleteSavedSheet(sheet);
      }
    }

    if (selection.addedFiles.isNotEmpty) {
      await controller.selectRecentSourceSheets(selection.addedFiles);
    }
  }

  Future<void> _selectSourceByUrl() async {
    final urlController = TextEditingController();
    try {
      final sourceUrl = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('เลือกไฟล์หรือแท็บด้วยลิงก์'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'คัดลอกลิงก์ Google Sheets จากแท็บที่ต้องการใช้ '
                  'ลิงก์ที่มี #gid= จะอ่านเฉพาะแท็บนั้น '
                  'หากไม่มี gid จะอ่านทุกแท็บที่มองเห็น',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL Google Sheets',
                    hintText:
                        'https://docs.google.com/spreadsheets/d/.../edit#gid=123',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(urlController.text.trim()),
              child: const Text('เลือกแหล่งข้อมูล'),
            ),
          ],
        ),
      );
      if (!mounted || sourceUrl == null || sourceUrl.isEmpty) return;
      await widget.controller.selectSourceForCurrentAccount(sourceUrl);
    } finally {
      urlController.dispose();
    }
  }

  Future<void> _addPeriod() async {
    if (month == null || year == null) {
      throw StateError('กรุณาเลือกเดือนและปี ค.ศ. ก่อนกดเพิ่ม');
    }
    final periods = <RosterPeriod>{
      ...widget.controller.settings.periods,
      RosterPeriod(year: year!, month: month!),
    }.toList()..sort((left, right) => left.key.compareTo(right.key));
    await widget.controller.updateSettings(
      widget.controller.settings.copyWith(
        targetName: searchName.text.trim(),
        year: year,
        month: month,
        periods: periods,
      ),
    );
  }

  Future<void> _removePeriod(RosterPeriod period) =>
      widget.controller.updateSettings(
        widget.controller.settings.copyWith(
          periods: widget.controller.settings.periods
              .where((item) => item != period)
              .toList(),
        ),
      );

  Future<void> _pickSyncRangeDate({required bool start}) async {
    final controller = widget.controller;
    final currentStart =
        controller.syncRangeStart ??
        DateTime(year ?? DateTime.now().year, month ?? DateTime.now().month);
    final currentEnd =
        controller.syncRangeEnd ??
        DateTime(currentStart.year, currentStart.month + 1, 0);
    final initialDate = start ? currentStart : currentEnd;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(initialDate.year - 5),
      lastDate: DateTime(initialDate.year + 10, 12, 31),
    );
    if (selected == null) return;
    final nextStart = start ? selected : currentStart;
    final nextEnd = start && currentEnd.isBefore(selected)
        ? selected
        : start
        ? currentEnd
        : selected;
    await controller.updateSyncDateRange(nextStart, nextEnd);
  }

  Future<void> _addManualSourceItem({
    Uint8List? capturedImageBytes,
    String initialSourceKind = 'รูป/ภาพถ่าย',
  }) async {
    await _saveSettings();
    if (!mounted) return;
    final result = await showDialog<_ManualSourceResult>(
      context: context,
      builder: (context) => _ManualSourceDialog(
        capturedImageBytes: capturedImageBytes,
        initialSourceKind: initialSourceKind,
      ),
    );
    if (result == null) return;
    await widget.controller.addManualShift(
      sourceKind: result.sourceKind,
      title: result.title,
      start: result.start,
      end: result.end,
      category: result.category,
      colorCommand: result.colorCommand,
    );
  }

  Future<void> _captureAndImportPhoto() async {
    while (mounted) {
      final photo = await _takePhoto();
      if (photo == null || !mounted) return;
      final bytes = await photo.readAsBytes();
      if (bytes.length > 15 * 1024 * 1024) {
        throw const FormatException(
          'รูปมีขนาดเกิน 15 MB กรุณาลดความละเอียดแล้วถ่ายใหม่',
        );
      }
      if (!mounted) return;
      final action = await showDialog<_CapturedPhotoAction>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _CapturedPhotoPreview(bytes: bytes),
      );
      switch (action) {
        case _CapturedPhotoAction.saveAndImport:
          await _saveCapturedPhoto(bytes);
          if (!mounted) return;
          await _addManualSourceItem(
            capturedImageBytes: bytes,
            initialSourceKind: 'กล้อง',
          );
          return;
        case _CapturedPhotoAction.retake:
          continue;
        case _CapturedPhotoAction.cancel:
        case null:
          return;
      }
    }
  }

  Future<XFile?> _takePhoto() async {
    try {
      return await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 2400,
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      final denied = code.contains('denied') || code.contains('restricted');
      throw StateError(
        denied
            ? 'ไม่ได้รับสิทธิ์ใช้กล้อง กรุณาอนุญาตกล้องในการตั้งค่าอุปกรณ์หรือเบราว์เซอร์'
            : 'ไม่สามารถเปิดกล้องบนอุปกรณ์นี้ได้: ${error.message ?? error.code}',
      );
    }
  }

  Future<void> _saveCapturedPhoto(Uint8List bytes) async {
    final now = DateTime.now();
    final name =
        'shift-roster-${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    await FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      fileExtension: 'jpg',
      mimeType: MimeType.jpeg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SceDashboardHero(
                controller: controller,
                openAlerts: widget.openAlerts,
              ),
              const SizedBox(height: 16),
              DashboardSummaryGrid(
                summary: widget.dashboardSummaryService.build(
                  schedule: controller.canonicalSchedule,
                  now: DateTime.now(),
                  conflictCount: controller.pendingAlertCount,
                ),
                googleConnected: controller.auth.isSignedIn,
                lastSync: controller.lastRefresh,
              ),
              const SizedBox(height: 16),
              _GoogleAccountCard(
                controller: controller,
                perform: widget.perform,
                configureGoogleOAuth: widget.configureGoogleOAuth,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'แหล่งข้อมูลเวร',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'ไฟล์หลักต้องเป็น Google Sheets ของบัญชีที่ล็อกอิน '
                        'แอปอ่านเซลล์และสีแบบ read-only',
                      ),
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                child: Icon(Icons.table_chart_outlined),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      controller.selectedSourceSheetTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      controller.localSourceLabel != null
                                          ? 'อ่านในหน่วยความจำ • ไม่อัปโหลดไฟล์หรือชื่อไฟล์'
                                          : controller.hasRosterSource
                                          ? 'ไฟล์หลักสำหรับอ่านตารางเวร • บันทึกไว้ ${controller.savedSheetsForCurrentAccount.length} ไฟล์'
                                          : 'เลือกไฟล์จาก Google Sheets ของบัญชีที่ล็อกอิน',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (controller.hasRosterSource)
                                const Icon(Icons.check_circle_outline),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const SizedBox(height: 6),
                      const Text(
                        'นำเข้าไฟล์ในเครื่องเพื่ออ่านตารางเวรเท่านั้น '
                        'ไฟล์จะไม่ถูกอัปโหลดไป Google Drive หรือ Google Sheets',
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                controller.auth.isSignedIn && !controller.busy
                                ? () => widget.perform(_pickGoogleSheet)
                                : null,
                            icon: const Icon(Icons.table_chart_outlined),
                            label: const Text('เลือกไฟล์จาก Google Sheets'),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                controller.auth.isSignedIn && !controller.busy
                                ? () => widget.perform(_selectSourceByUrl)
                                : null,
                            icon: const Icon(Icons.link_outlined),
                            label: const Text('เลือกแท็บด้วยลิงก์'),
                          ),
                          OutlinedButton.icon(
                            key: const Key('clearRosterSourceSelectionButton'),
                            onPressed: controller.hasRosterSource && !controller.busy
                                ? () => widget.perform(
                                    controller.clearRosterSourceSelection,
                                  )
                                : null,
                            icon: const Icon(Icons.clear),
                            label: const Text('ยกเลิกการเลือกตาราง'),
                          ),
                          OutlinedButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => widget.perform(() async {
                                    await _saveSettings();
                                    await controller.importLocalRosterFile();
                                  }),
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('นำเข้าตารางเวรจากไฟล์'),
                          ),
                          OutlinedButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => widget.perform(_captureAndImportPhoto),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('เปิดกล้อง'),
                          ),
                          OutlinedButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => widget.perform(_addManualSourceItem),
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('รูป / เว็บไซต์ (กรอกเอง)'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _LocalReferenceFileCard(
                        controller: controller,
                        attach: () => widget.perform(() async {
                          await _saveSettings();
                          await controller.attachLocalReferenceFile();
                        }),
                        clear: () =>
                            widget.perform(controller.clearLocalReferenceFile),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchName,
                        enabled: controller.auth.isSignedIn && !controller.busy,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อที่ต้องค้นหา',
                          hintText: 'กรอกชื่อให้ตรงกับชื่อในตารางเวร',
                          helperText:
                              'เริ่มต้นว่าง ใช้เฉพาะรอบนี้; ถ้าไม่กรอกจะใช้ชื่อโปรไฟล์ Google',
                          prefixIcon: Icon(Icons.person_search_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.account_circle_outlined, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.auth.account?.displayName
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? 'ชื่อสำรองจากบัญชี Google: ${controller.auth.account!.displayName!.trim()}'
                                  : 'กรอกชื่อด้านบนเพื่อใช้ค้นหาเวรในชีต',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 420;
                          final monthField = DropdownButtonFormField<int>(
                            initialValue: month,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'เดือน',
                            ),
                            items: [
                              for (var i = 1; i <= 12; i++)
                                DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                    _thaiMonths[i - 1],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) => setState(() => month = value),
                          );
                          final yearField = DropdownButtonFormField<int>(
                            initialValue: year,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'ปี ค.ศ.',
                            ),
                            items: [
                              for (final value in selectableYears)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text('$value'),
                                ),
                            ],
                            onChanged: (value) => setState(() => year = value),
                          );
                          if (narrow) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                monthField,
                                const SizedBox(height: 12),
                                yearField,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: monthField),
                              const SizedBox(width: 12),
                              Expanded(child: yearField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => widget.perform(_addPeriod),
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่มเดือน (ไม่จำกัด)'),
                          ),
                          for (final period in controller.settings.periods)
                            InputChip(
                              label: Text(
                                '${_thaiMonths[period.month - 1]} ${period.year}',
                              ),
                              onDeleted: controller.busy
                                  ? null
                                  : () => widget.perform(
                                      () => _removePeriod(period),
                                    ),
                            ),
                          if (controller.settings.periods.isEmpty)
                            const Text(
                              'ถ้าไม่กดเพิ่ม แอปจะอ่านเดือนที่เลือก 1 เดือน',
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => widget.perform(
                                    () => _pickSyncRangeDate(start: true),
                                  ),
                            icon: const Icon(Icons.date_range_outlined),
                            label: Text(
                              controller.syncRangeStart == null
                                  ? 'กำหนดวันเริ่มซิงก์'
                                  : 'เริ่ม ${_thaiDate(controller.syncRangeStart!)}',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => widget.perform(
                                    () => _pickSyncRangeDate(start: false),
                                  ),
                            icon: const Icon(Icons.event_available_outlined),
                            label: Text(
                              controller.syncRangeEnd == null
                                  ? 'กำหนดวันสิ้นสุดซิงก์'
                                  : 'สิ้นสุด ${_thaiDate(controller.syncRangeEnd!)}',
                            ),
                          ),
                          const Text(
                            'หัวตารางเป็นค่าเริ่มต้น แก้ช่วงได้ก่อน Preview และ Sync',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _AutoRefreshControls(
                        controller: controller,
                        onChanged: (enabled, seconds) => widget.perform(
                          () => _saveSettings(
                            autoRefresh: enabled,
                            refreshSeconds: seconds,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                controller.auth.isSignedIn && !controller.busy
                                ? () => widget.perform(() async {
                                    await _saveSettings();
                                    if (!controller.hasSelectedSourceSheet) {
                                      throw StateError(
                                        'กรุณาเลือก Google Sheets ก่อนอ่านตารางเวร',
                                      );
                                    }
                                    await controller.loadRoster();
                                  })
                                : null,
                            icon: const Icon(Icons.refresh),
                            label: const Text('รีเฟรช/อ่านใหม่ตอนนี้'),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                controller.auth.isSignedIn &&
                                    controller.shifts.isNotEmpty &&
                                    !controller.busy
                                ? widget.compareCalendar
                                : null,
                            icon: const Icon(Icons.difference_outlined),
                            label: const Text('เปรียบเทียบ Calendar'),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                controller.auth.isSignedIn &&
                                    controller.shifts.isNotEmpty &&
                                    !controller.busy
                                ? widget.deleteDuplicateCalendarEvents
                                : null,
                            icon: const Icon(Icons.delete_sweep_outlined),
                            label: const Text('ลบเวรซ้ำ'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed:
                                controller.auth.isSignedIn &&
                                    controller.shifts.isNotEmpty &&
                                    !controller.busy
                                ? widget.sync
                                : null,
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('ยืนยันและบันทึก Calendar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (controller.busy) const LinearProgressIndicator(),
              if (controller.error != null) ...[
                const SizedBox(height: 10),
                _MessageBanner(message: controller.error!, error: true),
              ] else if (controller.status != null) ...[
                const SizedBox(height: 10),
                _MessageBanner(message: controller.status!),
              ],
              const SizedBox(height: 16),
              _Stats(controller: controller),
              if (controller.pendingAlertCount > 0) ...[
                const SizedBox(height: 16),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    onTap: widget.openAlerts,
                    leading: const Icon(Icons.notification_important_outlined),
                    title: Text(
                      'มี ${controller.pendingAlertCount} รายการชนกันที่ต้องตัดสินใจ',
                    ),
                    subtitle: const Text(
                      'ระบบจะยังไม่เขียน Google Calendar จนกว่าจะตรวจครบ',
                    ),
                    trailing: const Icon(Icons.arrow_forward),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                child: SwitchListTile(
                  value: controller.settings.archiveOriginal,
                  onChanged: (value) => widget.perform(
                    () => controller.updateSettings(
                      controller.settings.copyWith(archiveOriginal: value),
                    ),
                  ),
                  title: const Text(
                    'เก็บสำเนาต้นฉบับใน Drive ของบัญชีที่ล็อกอิน',
                  ),
                  subtitle: const Text(
                    'สร้างครั้งเดียวต่อเดือนก่อนซิงก์ ไม่แก้หรือลบไฟล์ต้นฉบับ',
                  ),
                  secondary: const Icon(Icons.content_copy_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalReferenceFileCard extends StatelessWidget {
  const _LocalReferenceFileCard({
    required this.controller,
    required this.attach,
    required this.clear,
  });

  final AppController controller;
  final VoidCallback attach;
  final VoidCallback clear;

  @override
  Widget build(BuildContext context) {
    final comparison = controller.localReferenceComparison;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: comparison != null && !comparison.isExactMatch
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_file),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controller.localReferenceLabel ??
                        'ไฟล์ต้นฉบับจากเครื่อง (ไม่บังคับ)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (controller.localReferenceLabel != null)
                  IconButton(
                    tooltip: 'ถอดไฟล์ต้นฉบับ',
                    onPressed: controller.busy ? null : clear,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'ใช้เทียบกับไฟล์ล่าสุดเพื่อสร้างคอมเมนต์คนแทนเวรและยกเวร '
              'ข้อมูลความสัมพันธ์จะรวมในคำอธิบาย Calendar '
              'โดยไม่สร้างรายการซ้ำจากไฟล์แนบ',
            ),
            if (comparison != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('ตรงกัน ${comparison.matched}')),
                  Chip(label: Text('เปลี่ยน ${comparison.changed}')),
                  Chip(
                    label: Text(
                      'ขาดจากไฟล์ซิงก์ ${comparison.missingFromSync}',
                    ),
                  ),
                  Chip(
                    label: Text('มีเฉพาะไฟล์ซิงก์ ${comparison.onlyInSync}'),
                  ),
                  Chip(
                    label: Text(
                      'รับ/แทนเวร ${controller.localReceivedShiftCount}',
                    ),
                  ),
                  Chip(label: Text('ยกเวร ${controller.localGivenShiftCount}')),
                ],
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: controller.busy || controller.shifts.isEmpty
                  ? null
                  : attach,
              icon: const Icon(Icons.attach_file),
              label: Text(
                controller.localReferenceLabel == null
                    ? 'แนบไฟล์ต้นฉบับเพื่อเปรียบเทียบ'
                    : 'เปลี่ยนไฟล์ต้นฉบับ',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleSheetPickerDialog extends StatefulWidget {
  const _GoogleSheetPickerDialog({
    required this.files,
    required this.order,
    required this.alreadyAddedSpreadsheetIds,
  });

  final List<RecentOwnedSheet> files;
  final OwnedSheetOrder order;
  final Set<String> alreadyAddedSpreadsheetIds;

  @override
  State<_GoogleSheetPickerDialog> createState() =>
      _GoogleSheetPickerDialogState();
}

class _GoogleSheetPickerDialogState extends State<_GoogleSheetPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  late final MultiSheetPickerSelection _selection =
      MultiSheetPickerSelection(
        alreadyAddedIds: widget.alreadyAddedSpreadsheetIds,
      );
  String _query = '';

  List<RecentOwnedSheet> get _filteredFiles {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.files.take(10).toList(growable: false);
    return widget.files
        .where((file) => file.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  List<RecentOwnedSheet> get _selectedFiles => widget.files
      .where((file) => _selection.selectedIds.contains(file.id))
      .toList(growable: false);

  void _toggle(RecentOwnedSheet file) {
    setState(() => _selection.toggle(file.id));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final files = _filteredFiles;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.table_chart_outlined),
          SizedBox(width: 10),
          Expanded(child: Text('เลือก Google Sheets หลายไฟล์')),
        ],
      ),
      content: SizedBox(
        width: 660,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'ค้นหาชื่อไฟล์',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.order == OwnedSheetOrder.firstCreated ? 'เรียงจากไฟล์ที่สร้างก่อน' : 'เรียงจากไฟล์ที่แก้ไขล่าสุด'} • '
                'แสดงหน้าแรก ${files.length}/${widget.files.length} ไฟล์ • '
                'เลือกใหม่ ${_selection.addedCount} ไฟล์ • '
                'เพิ่มไว้แล้ว ${widget.alreadyAddedSpreadsheetIds.length} ไฟล์ • '
                'เอาออก ${_selection.removedCount} ไฟล์',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: files.isEmpty
                  ? const Center(child: Text('ไม่พบ Google Sheets'))
                  : ListView.separated(
                      itemCount: files.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final file = files[index];
                        final alreadyAdded = widget.alreadyAddedSpreadsheetIds
                            .contains(file.id);
                        return CheckboxListTile(
                          value: _selection.isChecked(file.id),
                          onChanged: (_) => _toggle(file),
                          secondary: const CircleAvatar(
                            child: Icon(Icons.table_chart_outlined),
                          ),
                          title: Text(
                            file.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            alreadyAdded
                                ? _selection.removedIds.contains(file.id)
                                      ? 'จะเอาออกจากรายการในแอป (ไม่ลบไฟล์จริง)'
                                      : 'เพิ่มไว้แล้ว · ติ๊กเพื่อเอาออกจากรายการในแอป'
                                : widget.order == OwnedSheetOrder.firstCreated
                                ? file.createdAt == null
                                      ? 'ไม่พบเวลาที่สร้างไฟล์'
                                      : 'สร้าง ${_thaiDate(file.createdAt!)} '
                                            '${_clock(file.createdAt!)}'
                                : file.modifiedAt == null
                                ? 'ไม่พบเวลาแก้ไขล่าสุด'
                                : 'แก้ไขล่าสุด ${_thaiDate(file.modifiedAt!)} '
                                      '${_clock(file.modifiedAt!)}',
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: !_selection.hasChanges
              ? null
              : () => Navigator.of(context).pop(
                  _GoogleSheetPickerResult(
                    addedFiles: _selectedFiles,
                    removedSpreadsheetIds: _selection.removedIds,
                  ),
                ),
          icon: const Icon(Icons.save_outlined),
          label: Text(
            _selection.removedCount == 0
                ? 'เพิ่ม ${_selection.addedCount} ไฟล์'
                : 'บันทึกการเลือก',
          ),
        ),
      ],
    );
  }
}


class _GoogleSheetPickerResult {
  const _GoogleSheetPickerResult({
    required this.addedFiles,
    required this.removedSpreadsheetIds,
  });

  final List<RecentOwnedSheet> addedFiles;
  final Set<String> removedSpreadsheetIds;
}

class _SceDashboardHero extends StatelessWidget {
  const _SceDashboardHero({required this.controller, required this.openAlerts});

  final AppController controller;
  final VoidCallback openAlerts;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;

          final information = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    avatar: Icon(Icons.auto_awesome, size: 18),
                    label: Text('SCE 3.0'),
                  ),
                  Chip(
                    avatar: Icon(Icons.verified_outlined, size: 18),
                    label: Text('Hospital Workspace'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'จัดการตารางเวรในที่เดียว',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'อ่านเวรจาก Google Sheets ตรวจรายการซ้ำ '
                'จัดการการแจ้งเตือน และบันทึกลง Google Calendar '
                'ด้วยขั้นตอนที่ตรวจสอบได้',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: controller.pendingAlertCount > 0
                        ? openAlerts
                        : null,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(
                      controller.pendingAlertCount > 0
                          ? 'ตรวจ ${controller.pendingAlertCount} การแจ้งเตือน'
                          : 'ไม่มีการแจ้งเตือนค้าง',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: Icon(
                      controller.auth.isSignedIn
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                    ),
                    label: Text(
                      controller.auth.isSignedIn
                          ? 'เชื่อมต่อ Google แล้ว'
                          : 'ยังไม่ได้เชื่อมต่อ Google',
                    ),
                  ),
                ],
              ),
            ],
          );

          final illustration = Container(
            width: 190,
            height: 170,
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 108,
                  color: colorScheme.primary,
                ),
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: colorScheme.tertiaryContainer,
                    child: Icon(
                      Icons.medical_services_outlined,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                information,
                const SizedBox(height: 20),
                Align(child: illustration),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: information),
              const SizedBox(width: 24),
              illustration,
            ],
          );
        },
      ),
    );
  }
}

class _GoogleAccountCard extends StatelessWidget {
  const _GoogleAccountCard({
    required this.controller,
    required this.perform,
    required this.configureGoogleOAuth,
  });

  final AppController controller;
  final Future<void> Function(Future<void> Function()) perform;
  final Future<void> Function() configureGoogleOAuth;

  @override
  Widget build(BuildContext context) {
    final account = controller.auth.account;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: account == null
            ? Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.account_circle_outlined),
                      ),
                      title: const Text('เชื่อมต่อบัญชี Google'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ล็อกอินก่อน แล้วค่อยอนุญาตสิทธิ์ตามปุ่มที่ใช้งาน',
                          ),
                          if (controller.auth.error != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              controller.auth.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (controller.auth.oauthConfigured)
                    if (controller.auth.initialized &&
                        !controller.auth.signInReady)
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.error_outline),
                        label: const Text('Google Login ไม่พร้อม'),
                      )
                    else
                      GoogleLoginButton(
                        enabled:
                            controller.auth.signInReady && !controller.busy,
                        onPressed: () => perform(controller.signIn),
                      )
                  else if (controller.auth.canConfigureWebOAuth)
                    OutlinedButton.icon(
                      onPressed: controller.busy ? null : configureGoogleOAuth,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('ตั้งค่า Google OAuth'),
                    )
                  else
                    Tooltip(
                      message: controller.auth.oauthUnavailableMessage ?? '',
                      child: OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.key_off_outlined),
                        label: Text(
                          controller.auth.platformSupported
                              ? 'ยังไม่ได้ตั้งค่า Google OAuth'
                              : 'Google Login ใช้ผ่าน Web',
                        ),
                      ),
                    ),
                ],
              )
            : Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  CircleAvatar(
                    backgroundImage: account.photoUrl == null
                        ? null
                        : NetworkImage(account.photoUrl!),
                    child: account.photoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.displayName ?? 'Google Account',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(account.email),
                      ],
                    ),
                  ),
                  if (controller.auth.checkingReadAccess)
                    const Chip(
                      avatar: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: Text('กำลังตรวจสิทธิ์'),
                    )
                  else if (controller.auth.readAccessGranted)
                    const Chip(
                      avatar: Icon(Icons.verified_outlined, size: 18),
                      label: Text('พร้อมอ่าน Sheets และ Calendar'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: controller.busy
                          ? null
                          : () => perform(controller.authorizeReadAccess),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('อนุญาตสิทธิ์อ่าน'),
                    ),
                  TextButton(
                    onPressed: controller.busy
                        ? null
                        : () => perform(controller.signOut),
                    child: const Text('ออกจากระบบ'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AutoRefreshControls extends StatelessWidget {
  const _AutoRefreshControls({
    required this.controller,
    required this.onChanged,
  });

  final AppController controller;
  final void Function(bool enabled, int seconds) onChanged;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Switch(
              value: settings.autoRefresh,
              onChanged: (value) => onChanged(value, settings.refreshSeconds),
            ),
            const Text('Auto refresh'),
            DropdownButton<int>(
              value: settings.refreshSeconds,
              items: [
                for (var seconds = 1; seconds <= 60; seconds++)
                  DropdownMenuItem(
                    value: seconds,
                    child: Text('$seconds วินาที'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onChanged(settings.autoRefresh, value);
              },
            ),
            if (settings.refreshSeconds == 1)
              const Text(
                '1 วินาทีอาจชนโควตา API',
                style: TextStyle(color: Colors.deepOrange),
              ),
            if (controller.lastRefresh != null)
              Text('อ่านล่าสุด ${_clock(controller.lastRefresh!)}'),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _StatCard(
        label: 'อ่านพบ',
        value: controller.shifts.length,
        icon: Icons.fact_check_outlined,
      ),
      _StatCard(
        label: 'เลือกไว้',
        value: controller.includedCount,
        icon: Icons.check_circle_outline,
      ),
      _StatCard(
        label: 'มีใน Calendar',
        value: controller.existingCount,
        icon: Icons.event_available_outlined,
      ),
      _StatCard(
        label: 'รอเพิ่ม',
        value: controller.newCount,
        icon: Icons.event_note_outlined,
      ),
      _StatCard(
        label: 'แจ้งเตือนค้าง',
        value: controller.pendingAlertCount,
        icon: Icons.notification_important_outlined,
      ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(label, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ManualSourceResult {
  const _ManualSourceResult({
    required this.sourceKind,
    required this.title,
    required this.start,
    required this.end,
    required this.category,
    required this.colorCommand,
  });

  final String sourceKind;
  final String title;
  final DateTime start;
  final DateTime end;
  final ShiftCategory category;
  final String colorCommand;
}

class _ManualSourceDialog extends StatefulWidget {
  const _ManualSourceDialog({
    this.capturedImageBytes,
    required this.initialSourceKind,
  });

  final Uint8List? capturedImageBytes;
  final String initialSourceKind;

  @override
  State<_ManualSourceDialog> createState() => _ManualSourceDialogState();
}

class _ManualSourceDialogState extends State<_ManualSourceDialog> {
  static const sourceKinds = [
    'รูป/ภาพถ่าย',
    'กล้อง',
    'เว็บไซต์',
    'Google Workspace อื่น',
    'ไฟล์ชนิดอื่น',
  ];

  final title = TextEditingController();
  final colorCommand = TextEditingController();
  late String sourceKind;
  DateTime date = DateTime.now();
  TimeOfDay start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 16, minute: 0);
  ShiftCategory category = ShiftCategory.own;

  @override
  void initState() {
    super.initState();
    sourceKind = sourceKinds.contains(widget.initialSourceKind)
        ? widget.initialSourceKind
        : sourceKinds.first;
  }

  @override
  void dispose() {
    title.dispose();
    colorCommand.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(date.year - 5),
      lastDate: DateTime(date.year + 10, 12, 31),
      initialDate: date,
    );
    if (selected != null) setState(() => date = selected);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? start : end,
    );
    if (selected == null) return;
    setState(() {
      if (isStart) {
        start = selected;
      } else {
        end = selected;
      }
    });
  }

  void _submit() {
    final startAt = DateTime(
      date.year,
      date.month,
      date.day,
      start.hour,
      start.minute,
    );
    var endAt = DateTime(date.year, date.month, date.day, end.hour, end.minute);
    if (!endAt.isAfter(startAt)) {
      endAt = endAt.add(const Duration(days: 1));
    }
    Navigator.pop(
      context,
      _ManualSourceResult(
        sourceKind: sourceKind,
        title: title.text.trim(),
        start: startAt,
        end: endAt,
        category: category,
        colorCommand: colorCommand.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('เพิ่มรายการจากต้นฉบับอื่น'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.capturedImageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  widget.capturedImageBytes!,
                  height: 220,
                  fit: BoxFit.contain,
                  semanticLabel: 'ภาพตารางเวรที่ถ่ายจากกล้อง',
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'แอปไม่เดาข้อความด้วย OCR กรุณาอ่านต้นฉบับและกรอกข้อมูล '
              'จากนั้นตรวจอีกครั้งในแท็บตัวอย่างก่อนซิงก์',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: sourceKind,
              decoration: const InputDecoration(labelText: 'ชนิดต้นฉบับ'),
              items: [
                for (final value in sourceKinds)
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => sourceKind = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'ชื่อเวร/ชื่อกิจกรรมตามต้นฉบับ',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ShiftCategory>(
              initialValue: category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'ประเภทรายการ'),
              items: [
                for (final value in ShiftCategory.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => category = value);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.today),
                  label: Text(_thaiDate(date)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickTime(isStart: true),
                  icon: const Icon(Icons.schedule),
                  label: Text('เริ่ม ${start.format(context)}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickTime(isStart: false),
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text('สิ้นสุด ${end.format(context)}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: colorCommand,
              decoration: const InputDecoration(
                labelText: 'คำสั่งสี (ไม่กรอก = ค่าเริ่มต้น)',
                hintText: 'เช่น แดง, tomato, สี=11',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มไปตรวจในตัวอย่าง'),
      ),
    ],
  );
}

enum _CapturedPhotoAction { saveAndImport, retake, cancel }

class _CapturedPhotoPreview extends StatelessWidget {
  const _CapturedPhotoPreview({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ตรวจภาพที่ถ่าย'),
    content: SizedBox(
      width: 640,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          height: 420,
          fit: BoxFit.contain,
          semanticLabel: 'ภาพตารางเวรก่อนบันทึกและ Import',
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, _CapturedPhotoAction.cancel),
        child: const Text('ยกเลิก'),
      ),
      OutlinedButton.icon(
        onPressed: () => Navigator.pop(context, _CapturedPhotoAction.retake),
        icon: const Icon(Icons.refresh),
        label: const Text('ถ่ายใหม่'),
      ),
      FilledButton.icon(
        onPressed: () =>
            Navigator.pop(context, _CapturedPhotoAction.saveAndImport),
        icon: const Icon(Icons.save_alt),
        label: const Text('บันทึกและ Import'),
      ),
    ],
  );
}

class _MonthlyRosterPage extends StatefulWidget {
  const _MonthlyRosterPage({required this.controller, required this.perform});

  final AppController controller;
  final Future<void> Function(Future<void> Function()) perform;

  @override
  State<_MonthlyRosterPage> createState() => _MonthlyRosterPageState();
}

class _MonthlyRosterPageState extends State<_MonthlyRosterPage> {
  final search = TextEditingController();
  final templateRepository = MonthlyRosterTemplateRepository();
  List<MonthlyRosterTemplate> templates = const [];
  String? selectedSection;
  DateTime? filterStart;
  DateTime? filterEnd;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTemplates());
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    final loaded = await templateRepository.load();
    if (mounted) setState(() => templates = loaded);
  }

  Future<void> _importGoogleSheet() async {
    final controller = widget.controller;
    if (!controller.auth.isSignedIn) {
      throw StateError('กรุณาเข้าสู่ระบบ Google ก่อนเลือกไฟล์');
    }
    await controller.findAvailableSourceSheets();
    if (!mounted || controller.recentOwnedSheets.isEmpty) {
      if (controller.recentOwnedSheets.isEmpty) {
        throw StateError('ไม่พบ Google Sheets ที่บัญชีนี้เข้าถึงได้');
      }
      return;
    }
    final selected = await showDialog<List<RecentOwnedSheet>>(
      context: context,
      builder: (context) => _GoogleSheetPickerDialog(
        files: controller.recentOwnedSheets,
        order: OwnedSheetOrder.recentlyModified,
        alreadyAddedSpreadsheetIds: controller.savedSheetsForCurrentAccount
            .map((sheet) => sheet.spreadsheetId)
            .toSet(),
      ),
    );
    if (selected == null || selected.isEmpty) return;
    await controller.selectRecentSourceSheets(selected);
    await controller.loadMonthlyRoster();
  }

  Future<void> _importPhoto(ImageSource source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2400,
      requestFullMetadata: false,
    );
    if (photo == null || !mounted) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 15 * 1024 * 1024) {
      throw const FormatException('รูปมีขนาดเกิน 15 MB');
    }
    final action = await showDialog<_CapturedPhotoAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CapturedPhotoPreview(bytes: bytes),
    );
    if (action != _CapturedPhotoAction.saveAndImport || !mounted) return;
    if (source == ImageSource.camera) {
      final now = DateTime.now();
      await FileSaver.instance.saveFile(
        name: 'monthly-roster-${now.millisecondsSinceEpoch}',
        bytes: bytes,
        fileExtension: 'jpg',
        mimeType: MimeType.jpeg,
      );
    }
    if (!mounted) return;
    final result = await showDialog<_ManualSourceResult>(
      context: context,
      builder: (context) => _ManualSourceDialog(
        capturedImageBytes: bytes,
        initialSourceKind: source == ImageSource.camera
            ? 'กล้อง'
            : 'รูป/ภาพถ่าย',
      ),
    );
    if (result == null) return;
    await widget.controller.addManualShift(
      sourceKind: result.sourceKind,
      title: result.title,
      start: result.start,
      end: result.end,
      category: result.category,
      colorCommand: result.colorCommand,
    );
  }

  Future<void> _editTemplate([MonthlyRosterTemplate? current]) async {
    final value = await showDialog<MonthlyRosterTemplate>(
      context: context,
      builder: (context) => _MonthlyRosterTemplateDialog(template: current),
    );
    if (value == null) return;
    final updated = [...templates];
    final index = updated.indexWhere((item) => item.id == value.id);
    if (index < 0) {
      updated.add(value);
    } else {
      updated[index] = value;
    }
    await templateRepository.saveAll(updated);
    if (mounted) setState(() => templates = List.unmodifiable(updated));
  }

  Future<void> _deleteTemplate(MonthlyRosterTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบเทมเพลตรายเดือน?'),
        content: Text('ลบ “${template.title}” จากเครื่องนี้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = templates
        .where((item) => item.id != template.id)
        .toList(growable: false);
    await templateRepository.saveAll(updated);
    if (mounted) setState(() => templates = updated);
  }

  MonthlyRosterSection _templateSection(MonthlyRosterTemplate template) =>
      MonthlyRosterSection(
        title: template.title,
        headerRowIndex: 0,
        assignments: const [],
        rowLabels: template.rowLabels,
        startDate:
            filterStart != null && template.startDate.isBefore(filterStart!)
            ? filterStart
            : template.startDate,
        endDate: filterEnd != null && template.endDate.isAfter(filterEnd!)
            ? filterEnd
            : template.endDate,
      );

  Future<void> _pickFilterDate({required bool startDate}) async {
    final now = DateTime.now();
    final current = startDate ? filterStart : filterEnd;
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (selected == null) return;
    setState(() {
      if (startDate) {
        filterStart = selected;
        if (filterEnd != null && filterEnd!.isBefore(selected)) {
          filterEnd = selected;
        }
      } else {
        filterEnd = selected;
        if (filterStart != null && filterStart!.isAfter(selected)) {
          filterStart = selected;
        }
      }
    });
  }

  bool _includesFilterDate(DateTime date) =>
      (filterStart == null || !date.isBefore(filterStart!)) &&
      (filterEnd == null || !date.isAfter(filterEnd!));

  @override
  Widget build(BuildContext context) {
    final report = widget.controller.monthlyRoster;
    final filteredReport = report.filtered(
      query: search.text,
      sectionTitle: selectedSection,
      includesDate: filterStart == null && filterEnd == null
          ? null
          : _includesFilterDate,
    );
    final query = search.text.trim().toLowerCase();
    final visibleTemplates = templates
        .where((template) {
          if (selectedSection != null && selectedSection != template.title) {
            return false;
          }
          if (filterStart != null && template.endDate.isBefore(filterStart!)) {
            return false;
          }
          if (filterEnd != null && template.startDate.isAfter(filterEnd!)) {
            return false;
          }
          return query.isEmpty ||
              template.title.toLowerCase().contains(query) ||
              template.rowLabels.any(
                (row) => row.toLowerCase().contains(query),
              );
        })
        .toList(growable: false);
    final sections = [
      ...visibleTemplates.map(_templateSection),
      ...filteredReport.sections,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ตารางเวรรายเดือน',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.sections.isEmpty
                              ? 'นำเข้าตารางหรือสร้างเทมเพลตรายเดือนแบบว่าง'
                              : '${report.sections.length} บล็อก • '
                                    '${report.assignments.length} ช่องปฏิบัติงาน',
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: widget.controller.busy
                        ? null
                        : () => _editTemplate(),
                    icon: const Icon(Icons.add),
                    tooltip: 'สร้างเทมเพลตรายเดือน',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed:
                        widget.controller.auth.isSignedIn &&
                            !widget.controller.busy
                        ? () => widget.perform(_importGoogleSheet)
                        : null,
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Google Sheets'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.controller.busy
                        ? null
                        : () => widget.perform(
                            widget.controller.importLocalMonthlyRosterFile,
                          ),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Excel / CSV / ไฟล์'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.controller.busy
                        ? null
                        : () => widget.perform(
                            () => _importPhoto(ImageSource.camera),
                          ),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('เปิดกล้อง'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.controller.busy
                        ? null
                        : () => widget.perform(
                            () => _importPhoto(ImageSource.gallery),
                          ),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('เลือกรูป'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        widget.controller.busy ||
                            !widget.controller.hasRosterSource
                        ? null
                        : () => widget.perform(
                            widget.controller.loadMonthlyRoster,
                          ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('อ่านใหม่'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'ค้นหาบล็อก สถานที่ หรือชื่อผู้ปฏิบัติงาน',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickFilterDate(startDate: true),
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      filterStart == null
                          ? 'วันเริ่ม'
                          : 'เริ่ม ${_thaiDate(filterStart!)}',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickFilterDate(startDate: false),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(
                      filterEnd == null
                          ? 'วันสิ้นสุด'
                          : 'สิ้นสุด ${_thaiDate(filterEnd!)}',
                    ),
                  ),
                  if (filterStart != null || filterEnd != null)
                    IconButton(
                      onPressed: () => setState(() {
                        filterStart = null;
                        filterEnd = null;
                      }),
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      tooltip: 'ล้างช่วงวันที่',
                    ),
                ],
              ),
              if (report.sections.isNotEmpty || templates.isNotEmpty) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('ทั้งหมด'),
                        selected: selectedSection == null,
                        onSelected: (_) =>
                            setState(() => selectedSection = null),
                      ),
                      const SizedBox(width: 8),
                      for (final title in <String>{
                        ...templates.map((template) => template.title),
                        ...report.sections.map((section) => section.title),
                      }) ...[
                        ChoiceChip(
                          label: Text(_compactSectionTitle(title)),
                          selected: selectedSection == title,
                          onSelected: (_) =>
                              setState(() => selectedSection = title),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: report.sections.isEmpty && templates.isEmpty
              ? _MonthlyRosterEmptyState(controller: widget.controller)
              : sections.isEmpty
              ? const _EmptyState(
                  icon: Icons.search_off,
                  title: 'ไม่พบข้อมูลที่ค้นหา',
                  message: 'ลองเปลี่ยนคำค้นหาหรือตัวกรองบล็อก',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: sections.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    final template = index < visibleTemplates.length
                        ? visibleTemplates[index]
                        : null;
                    return _MonthlyRosterSectionCard(
                      section: section,
                      onEdit: template == null
                          ? null
                          : () => _editTemplate(template),
                      onDelete: template == null
                          ? null
                          : () => _deleteTemplate(template),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MonthlyRosterTemplateDialog extends StatefulWidget {
  const _MonthlyRosterTemplateDialog({this.template});

  final MonthlyRosterTemplate? template;

  @override
  State<_MonthlyRosterTemplateDialog> createState() =>
      _MonthlyRosterTemplateDialogState();
}

class _MonthlyRosterTemplateDialogState
    extends State<_MonthlyRosterTemplateDialog> {
  late final title = TextEditingController(text: widget.template?.title ?? '');
  late final List<_ShiftGroupDraft> groups;
  late DateTime start =
      widget.template?.startDate ??
      DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime end =
      widget.template?.endDate ??
      DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  @override
  void initState() {
    super.initState();
    groups = widget.template == null
        ? [_ShiftGroupDraft.empty(1)]
        : widget.template!.groups
              .map(_ShiftGroupDraft.fromGroup)
              .toList(growable: true);
  }

  @override
  void dispose() {
    title.dispose();
    for (final group in groups) {
      group.dispose();
    }
    super.dispose();
  }

  void _addGroup() {
    setState(() => groups.add(_ShiftGroupDraft.empty(groups.length + 1)));
  }

  void _removeGroup(int index) {
    if (groups.length == 1) return;
    final removed = groups.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _pickDate({required bool startDate}) async {
    final current = startDate ? start : end;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 5),
      lastDate: DateTime(current.year + 10, 12, 31),
    );
    if (selected == null) return;
    setState(() {
      if (startDate) {
        start = selected;
        if (end.isBefore(start)) end = start;
      } else {
        end = selected;
      }
    });
  }

  void _submit() {
    final name = title.text.trim();
    final shiftGroups = groups.map((group) => group.value).toList();
    if (name.isEmpty ||
        shiftGroups.any(
          (group) => group.title.isEmpty || group.rowLabels.isEmpty,
        )) {
      return;
    }
    Navigator.pop(
      context,
      MonthlyRosterTemplate(
        id:
            widget.template?.id ??
            'monthly-${DateTime.now().microsecondsSinceEpoch}',
        title: name,
        startDate: start,
        endDate: end,
        groups: shiftGroups,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.template == null ? 'สร้างเทมเพลตรายเดือน' : 'แก้ไขเทมเพลตรายเดือน',
    ),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'ชื่อเทมเพลต'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'กลุ่มเวร',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _addGroup,
                  icon: const Icon(Icons.add),
                  tooltip: 'เพิ่มกลุ่มเวร',
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < groups.length; index++) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: groups[index].title,
                            decoration: InputDecoration(
                              labelText: 'ชื่อกลุ่มเวร ${index + 1}',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: groups.length == 1
                              ? null
                              : () => _removeGroup(index),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'ลบกลุ่มเวร',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: groups[index].rows,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'แถวเวรหรือสถานที่',
                        hintText: 'หนึ่งแถวต่อหนึ่งบรรทัด',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickDate(startDate: true),
                  icon: const Icon(Icons.first_page),
                  label: Text('เริ่ม ${_thaiDate(start)}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(startDate: false),
                  icon: const Icon(Icons.last_page),
                  label: Text('สิ้นสุด ${_thaiDate(end)}'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.save_outlined),
        label: const Text('บันทึก'),
      ),
    ],
  );
}

class _ShiftGroupDraft {
  _ShiftGroupDraft({
    required this.id,
    required String title,
    required List<String> rowLabels,
  }) : title = TextEditingController(text: title),
       rows = TextEditingController(text: rowLabels.join('\n'));

  factory _ShiftGroupDraft.empty(int number) => _ShiftGroupDraft(
    id: 'group-${DateTime.now().microsecondsSinceEpoch}-$number',
    title: 'กลุ่มเวร $number',
    rowLabels: const [],
  );

  factory _ShiftGroupDraft.fromGroup(MonthlyRosterShiftGroup group) =>
      _ShiftGroupDraft(
        id: group.id,
        title: group.title,
        rowLabels: group.rowLabels,
      );

  final String id;
  final TextEditingController title;
  final TextEditingController rows;

  MonthlyRosterShiftGroup get value => MonthlyRosterShiftGroup(
    id: id,
    title: title.text.trim(),
    rowLabels: List.unmodifiable(
      rows.text
          .split(RegExp(r'[\r\n,]+'))
          .map((row) => row.trim())
          .where((row) => row.isNotEmpty)
          .toSet(),
    ),
  );

  void dispose() {
    title.dispose();
    rows.dispose();
  }
}

class _MonthlyRosterEmptyState extends StatelessWidget {
  const _MonthlyRosterEmptyState({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => _EmptyState(
    icon: Icons.calendar_view_month_outlined,
    title: controller.hasRosterSource
        ? 'ยังไม่ได้อ่านตารางรายเดือน'
        : 'ยังไม่ได้เลือกแหล่งข้อมูลเวร',
    message: controller.hasRosterSource
        ? 'กด “อ่านใหม่” เพื่อค้นหาบล็อกที่มีแถววันที่ในชีต'
        : 'นำเข้า Google Sheets, Excel, CSV, รูปภาพ หรือกล้องจากหน้านี้',
  );
}

class _MonthlyRosterSectionCard extends StatelessWidget {
  const _MonthlyRosterSectionCard({
    required this.section,
    this.onEdit,
    this.onDelete,
  });

  final MonthlyRosterSection section;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final dates = section.assignments.map((item) => item.date).toSet().toList();
    if (dates.isEmpty && section.startDate != null && section.endDate != null) {
      for (
        var date = section.startDate!;
        !date.isAfter(section.endDate!);
        date = date.add(const Duration(days: 1))
      ) {
        dates.add(date);
      }
    }
    dates.sort();
    final rowIndexes =
        section.assignments.map((item) => item.rowIndex).toSet().toList()
          ..sort();
    final rowLabels = <int, String>{
      for (var index = 0; index < section.rowLabels.length; index++)
        index: section.rowLabels[index],
      for (final assignment in section.assignments)
        assignment.rowIndex: assignment.rowLabel,
    };
    rowIndexes.addAll(rowLabels.keys);
    rowIndexes.sort();
    final byPosition = <(int, DateTime), MonthlyRosterAssignment>{
      for (final assignment in section.assignments)
        (assignment.rowIndex, assignment.date): assignment,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.view_week_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rowIndexes.length} แถว • '
                        '${section.assignments.length} ช่อง',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    tooltip: 'จัดการเทมเพลต',
                    onSelected: (value) =>
                        value == 'edit' ? onEdit?.call() : onDelete?.call(),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
                      PopupMenuItem(value: 'delete', child: Text('ลบ')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (section.assignments.isEmpty && rowLabels.isEmpty)
              const Text('บล็อกนี้ยังไม่มีรายชื่อผู้ปฏิบัติงาน')
            else
              Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowHeight: 44,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 64,
                    columns: [
                      const DataColumn(label: Text('เวร / สถานที่')),
                      for (final date in dates)
                        DataColumn(
                          numeric: false,
                          label: Text('${date.day}\n${_shortWeekday(date)}'),
                        ),
                    ],
                    rows: [
                      for (final rowIndex in rowIndexes)
                        DataRow(
                          cells: [
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 110,
                                  maxWidth: 180,
                                ),
                                child: Text(
                                  rowLabels[rowIndex]!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            for (final date in dates)
                              DataCell(
                                _MonthlyRosterCell(
                                  assignment: byPosition[(rowIndex, date)],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyRosterCell extends StatelessWidget {
  const _MonthlyRosterCell({this.assignment});

  final MonthlyRosterAssignment? assignment;

  @override
  Widget build(BuildContext context) {
    final item = assignment;
    if (item == null) return const SizedBox(width: 72);
    final color = _colorFromHex(item.backgroundColor);
    return Tooltip(
      message: '${item.sourceCell} • ${item.workerName}',
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color?.withValues(alpha: 0.18),
          border: Border.all(
            color: color ?? Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          item.workerName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _PreviewPage extends StatelessWidget {
  const _PreviewPage({
    required this.controller,
    required this.perform,
    required this.openRosterEditor,
  });
  final AppController controller;
  final Future<void> Function(Future<void> Function()) perform;
  final VoidCallback openRosterEditor;

  Future<void> _editShift(BuildContext context, int index, Shift shift) async {
    final result = await showDialog<_ShiftSettingsResult>(
      context: context,
      builder: (context) => _ShiftSettingsDialog(shift: shift),
    );
    if (result == null) return;
    await perform(() async {
      controller.customizeShift(
        index,
        title: result.title,
        start: result.start,
        end: result.end,
        category: result.category,
        colorCommand: result.colorCommand,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (controller.shifts.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _EmptyState(
            icon: Icons.event_note_outlined,
            title: 'ยังไม่มีรายการตัวอย่าง',
            message: 'ไปหน้าแรกแล้วกด “รีเฟรช/อ่านใหม่ตอนนี้”',
          ),
          FilledButton.icon(
            onPressed: openRosterEditor,
            icon: const Icon(Icons.edit_calendar_outlined),
            label: Text(context.l10n.manualRosterEditor),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: openRosterEditor,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: Text(context.l10n.manualRosterEditor),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: controller.shifts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final shift = controller.shifts[index];
              final exists = CalendarService.matchesExisting(
                shift,
                controller.existingKeys,
              );
              final color = Color(
                CalendarColorService.byId(
                      shift.effectiveCalendarColorId,
                    )?.colorValue ??
                    shift.category.colorValue,
              );
              final sourceColor = ShiftColorService.classify(
                shift.sourceColorValue,
              );
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 620;
                      final selector = OutlinedButton.icon(
                        onPressed: () => _editShift(context, index, shift),
                        icon: const Icon(Icons.palette_outlined),
                        label: const Text('ตั้งวันที่ เวลา ชื่อ ประเภท และสี'),
                      );
                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                shift.displayName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(
                                  exists ? Icons.check : Icons.add,
                                  size: 16,
                                ),
                                label: Text(exists ? 'มีแล้ว' : 'รายการใหม่'),
                              ),
                              if (shift.generated)
                                const Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(
                                    Icons.bedtime_outlined,
                                    size: 16,
                                  ),
                                  label: Text('OFF ค่าเริ่มต้น'),
                                ),
                              if (shift.sourceColorValue != null)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: CircleAvatar(
                                    backgroundColor: Color(
                                      shift.sourceColorValue!,
                                    ),
                                    radius: 8,
                                  ),
                                  label: Text(
                                    'สีไฟล์หลัก: '
                                    '${sourceColor?.sourceName ?? shift.sourceColorHex}',
                                  ),
                                ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: CircleAvatar(
                                  backgroundColor: color,
                                  radius: 8,
                                ),
                                label: Text(
                                  'สี Calendar: '
                                  '${CalendarColorService.byId(shift.effectiveCalendarColorId)?.name ?? shift.category.colorName}',
                                ),
                              ),
                              if (sourceColor?.requiresReview == true)
                                const Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(Icons.info_outline, size: 16),
                                  label: Text(
                                    'ลาเวนเดอร์: ตรวจว่าแลกเวรใหญ่หรือยกเวร',
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            '${_thaiDate(shift.start)} • ${_time(shift.start)}–${_time(shift.end)}',
                          ),
                          Text(
                            '${shift.sheetTitle} • ${shift.cell} • ${shift.assignedName}',
                          ),
                          if (shift.generated)
                            const Text(
                              'ระบบสร้างจากค่าเริ่มต้น กดตั้งค่าเพื่อแก้ไขได้',
                            ),
                        ],
                      );
                      final check = Checkbox(
                        value: !shift.excluded,
                        onChanged: (value) => controller.updateShift(
                          index,
                          excluded: value != true,
                        ),
                      );
                      final bar = Container(
                        width: 5,
                        height: 74,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                      if (narrow) {
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                check,
                                bar,
                                const SizedBox(width: 12),
                                Expanded(child: details),
                              ],
                            ),
                            const SizedBox(height: 10),
                            selector,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          check,
                          bar,
                          const SizedBox(width: 12),
                          Expanded(child: details),
                          const SizedBox(width: 10),
                          SizedBox(width: 190, child: selector),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OwnedScheduleEditorRoute extends StatefulWidget {
  const _OwnedScheduleEditorRoute({
    required this.schedule,
    required this.controllerFactory,
    required this.onCommitted,
  });

  final Schedule schedule;
  final Future<ScheduleController> Function(Schedule) controllerFactory;
  final Future<void> Function(Schedule) onCommitted;

  @override
  State<_OwnedScheduleEditorRoute> createState() =>
      _OwnedScheduleEditorRouteState();
}

class _OwnedScheduleEditorRouteState extends State<_OwnedScheduleEditorRoute> {
  ScheduleController? controller;
  Object? error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final value = await widget.controllerFactory(widget.schedule);
      if (!mounted) {
        value.dispose();
        return;
      }
      setState(() => controller = value);
    } on Object catch (caught) {
      if (mounted) setState(() => error = caught);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loaded = controller;
    if (error case final caught?) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.manualRosterEditor)),
        body: Center(child: Text(caught.toString())),
      );
    }
    if (loaded == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ScheduleWorkspacePage(
      controller: loaded,
      editable: true,
      onCommitted: widget.onCommitted,
    );
  }
}

class _ShiftSettingsResult {
  const _ShiftSettingsResult({
    required this.title,
    required this.start,
    required this.end,
    required this.category,
    required this.colorCommand,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final ShiftCategory category;
  final String colorCommand;
}

class _ShiftSettingsDialog extends StatefulWidget {
  const _ShiftSettingsDialog({required this.shift});

  final Shift shift;

  @override
  State<_ShiftSettingsDialog> createState() => _ShiftSettingsDialogState();
}

class _ShiftSettingsDialogState extends State<_ShiftSettingsDialog> {
  late final TextEditingController title = TextEditingController(
    text: widget.shift.displayName,
  );
  late final TextEditingController colorCommand = TextEditingController(
    text: widget.shift.calendarColorId ?? '',
  );
  late ShiftCategory category = widget.shift.category;
  late DateTime date = DateTime(
    widget.shift.start.year,
    widget.shift.start.month,
    widget.shift.start.day,
  );
  late TimeOfDay start = TimeOfDay.fromDateTime(widget.shift.start);
  late TimeOfDay end = TimeOfDay.fromDateTime(widget.shift.end);

  @override
  void dispose() {
    title.dispose();
    colorCommand.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(date.year - 5),
      lastDate: DateTime(date.year + 10, 12, 31),
      initialDate: date,
    );
    if (selected != null) setState(() => date = selected);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? start : end,
    );
    if (selected == null) return;
    setState(() {
      if (isStart) {
        start = selected;
      } else {
        end = selected;
      }
    });
  }

  void _submit() {
    final startAt = DateTime(
      date.year,
      date.month,
      date.day,
      start.hour,
      start.minute,
    );
    var endAt = DateTime(date.year, date.month, date.day, end.hour, end.minute);
    if (!endAt.isAfter(startAt)) {
      endAt = endAt.add(const Duration(days: 1));
    }
    Navigator.pop(
      context,
      _ShiftSettingsResult(
        title: title.text.trim(),
        start: startAt,
        end: endAt,
        category: category,
        colorCommand: colorCommand.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ตั้งค่ารายการก่อนใช้'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'ชื่อกิจกรรมใน Calendar',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ShiftCategory>(
              initialValue: category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'ประเภทรายการ'),
              items: [
                for (final value in ShiftCategory.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => category = value);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(_thaiDate(date)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickTime(isStart: true),
                  icon: const Icon(Icons.schedule),
                  label: Text('เริ่ม ${start.format(context)}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickTime(isStart: false),
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text('สิ้นสุด ${end.format(context)}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: colorCommand,
              decoration: const InputDecoration(
                labelText: 'คำสั่งสี (ไม่กรอก = ค่าเริ่มต้น)',
                hintText: 'เช่น แดง, tomato, สี=11',
                helperText:
                    'ใช้เลข 1–11 หรือชื่อสี: ลาเวนเดอร์ เซจ องุ่น '
                    'ฟลามิงโก กล้วย ส้ม นกยูง กราไฟต์ บลูเบอร์รี โหระพา มะเขือเทศ',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.check),
        label: const Text('ใช้การตั้งค่านี้'),
      ),
    ],
  );
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage({required this.controller, required this.perform});

  final AppController controller;
  final Future<void> Function(Future<void> Function()) perform;

  Future<void> _deleteCalendarEvent(
    BuildContext context,
    ShiftAlert alert,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_forever_outlined),
        title: const Text('ลบกิจกรรมออกจาก Google Calendar?'),
        content: const Text(
          'รายการนี้จะถูกลบจากปฏิทินจริงของบัญชีที่ล็อกอิน '
          'การลบจะเกิดเมื่อกดยืนยันเท่านั้น',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ยืนยันลบกิจกรรม'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await perform(() => controller.deleteCalendarConflict(alert));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller.alerts.isEmpty) {
      return const _EmptyState(
        icon: Icons.notifications_none,
        title: 'ยังไม่มีการแจ้งเตือน',
        message:
            'เมื่ออ่านเวรและเปรียบเทียบ Calendar แอปจะตรวจเวรซ้อนและช่วง OFF ให้อัตโนมัติ',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          color: controller.pendingAlertCount > 0
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ศูนย์แจ้งเตือนเวร',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'รอตัดสินใจ ${controller.pendingAlertCount} รายการ • '
                  'พบรายการชน ${controller.conflictAlertCount} รายการ',
                ),
                const SizedBox(height: 8),
                const Text(
                  'รับทราบและคงไว้ = เขียนตามรายการเดิม • ยืนยันรายการ = '
                  'ยืนยันรายการที่เลือก • ไม่นำเข้าปฏิทิน = ตัดรายการที่ชนออก',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (final alert in controller.alerts) ...[
          _AlertCard(
            alert: alert,
            onDecision: (decision) =>
                perform(() => controller.resolveAlert(alert.id, decision)),
            onOpen: alert.calendarEventUrl == null
                ? null
                : () => perform(() => controller.openCalendarConflict(alert)),
            onDelete: alert.calendarEventId == null
                ? null
                : () => _deleteCalendarEvent(context, alert),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.onDecision,
    this.onOpen,
    this.onDelete,
  });

  final ShiftAlert alert;
  final Future<void> Function(ShiftAlertDecision decision) onDecision;
  final Future<void> Function()? onOpen;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = switch (alert.type) {
      ShiftAlertType.offAfterNight => Colors.indigo,
      ShiftAlertType.offConflict => Colors.deepOrange,
      ShiftAlertType.shiftOverlap => Colors.red,
      ShiftAlertType.calendarOverlap => Colors.purple,
    };
    final icon = switch (alert.type) {
      ShiftAlertType.offAfterNight => Icons.bedtime_outlined,
      ShiftAlertType.offConflict => Icons.do_not_disturb_on_outlined,
      ShiftAlertType.shiftOverlap => Icons.warning_amber_rounded,
      ShiftAlertType.calendarOverlap => Icons.event_busy_outlined,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        alert.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          alert.isPending
                              ? Icons.schedule
                              : Icons.check_circle_outline,
                          size: 16,
                        ),
                        label: Text(alert.decision.label),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(alert.message),
                  const SizedBox(height: 4),
                  Text(
                    '${_thaiDate(alert.start)} • '
                    '${_time(alert.start)}–${_time(alert.end)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (alert.requiresDecision) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              onDecision(ShiftAlertDecision.acknowledged),
                          icon: const Icon(Icons.done),
                          label: const Text('รับทราบและคงไว้'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              onDecision(ShiftAlertDecision.accepted),
                          icon: const Icon(Icons.add_task),
                          label: const Text('ยืนยันรายการ'),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              onDecision(ShiftAlertDecision.cancelled),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('ไม่นำเข้าปฏิทิน'),
                        ),
                        if (onOpen != null)
                          OutlinedButton.icon(
                            onPressed: () => onOpen!(),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('เปิดกิจกรรม'),
                          ),
                        if (onDelete != null)
                          TextButton.icon(
                            onPressed: () => onDelete!(),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('ลบกิจกรรม'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditPage extends StatelessWidget {
  const _AuditPage({
    required this.controller,
    required this.saveCurrentSheet,
    required this.activateSavedSheet,
    required this.openSavedSheet,
    required this.deleteSavedSheet,
  });

  final AppController controller;
  final Future<void> Function() saveCurrentSheet;
  final Future<void> Function(SavedSheet sheet) activateSavedSheet;
  final Future<void> Function(SavedSheet sheet) openSavedSheet;
  final Future<void> Function(SavedSheet sheet) deleteSavedSheet;

  @override
  Widget build(BuildContext context) {
    final account = controller.auth.account;
    final sheets = controller.savedSheetsForCurrentAccount;
    final canSave =
        account != null &&
        controller.currentSourceUrl.isNotEmpty &&
        !controller.busy;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final heading = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ชีตที่บันทึก',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'เปิดดูชีตที่สร้างหรือบันทึกไว้ แยกตามบัญชี Google ที่ล็อกอิน',
                        ),
                      ],
                    );
                    final button = FilledButton.icon(
                      onPressed: canSave
                          ? () => unawaited(saveCurrentSheet())
                          : null,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('บันทึกชีตปัจจุบัน'),
                    );
                    if (constraints.maxWidth < 720) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          heading,
                          const SizedBox(height: 12),
                          Align(alignment: Alignment.centerLeft, child: button),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: heading),
                        const SizedBox(width: 16),
                        button,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'เก็บเฉพาะลิงก์และชื่อชีตในเครื่องนี้ ไม่เก็บอีเมลหรือ token และไม่ส่งขึ้น GitHub',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (account == null)
                  const _SavedSheetNotice(
                    icon: Icons.account_circle_outlined,
                    text: 'ล็อกอิน Google เพื่อดูรายการของบัญชีนี้',
                  )
                else if (sheets.isEmpty)
                  const _SavedSheetNotice(
                    icon: Icons.link_off_outlined,
                    text:
                        'เลือก Google Sheets จาก Google Drive ในหน้าแรก '
                        'แล้วกดรีเฟรชเพื่ออ่านตารางเวร',
                  )
                else
                  for (final sheet in sheets)
                    _SavedSheetCard(
                      sheet: sheet,
                      active: controller.currentSourceSheet?.key == sheet.key,
                      disabled: controller.busy,
                      activate: activateSavedSheet,
                      open: openSavedSheet,
                      delete: deleteSavedSheet,
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('ประวัติการทำงาน', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (controller.auditEntries.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.history_outlined),
              title: Text('ยังไม่มี Audit log'),
              subtitle: Text(
                'การอ่าน สำเนา และการเขียนจะบันทึกไว้ในเครื่องนี้',
              ),
            ),
          )
        else
          for (final entry in controller.auditEntries)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: entry.success
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  child: Icon(
                    entry.success ? Icons.check : Icons.error_outline,
                    color: entry.success ? Colors.green : Colors.red,
                  ),
                ),
                title: Text(entry.message),
                subtitle: Text(
                  '${entry.action} • ${_thaiDate(entry.timestamp)} ${_clock(entry.timestamp)}',
                ),
              ),
            ),
      ],
    );
  }
}

class _SavedSheetNotice extends StatelessWidget {
  const _SavedSheetNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

class _SavedSheetCard extends StatelessWidget {
  const _SavedSheetCard({
    required this.sheet,
    required this.active,
    required this.disabled,
    required this.activate,
    required this.open,
    required this.delete,
  });

  final SavedSheet sheet;
  final bool active;
  final bool disabled;
  final Future<void> Function(SavedSheet sheet) activate;
  final Future<void> Function(SavedSheet sheet) open;
  final Future<void> Function(SavedSheet sheet) delete;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.table_chart_outlined)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sheet.displayTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (active)
                          Text(
                            'ไฟล์หลักของบัญชีนี้',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          '${sheet.contextLabel} • บันทึก ${_thaiDate(sheet.savedAt)} ${_clock(sheet.savedAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: disabled || active
                        ? null
                        : () => unawaited(activate(sheet)),
                    icon: Icon(active ? Icons.check_circle : Icons.swap_horiz),
                    label: Text(active ? 'กำลังใช้งาน' : 'ใช้ไฟล์นี้'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: disabled ? null : () => unawaited(open(sheet)),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('เปิดดู'),
                  ),
                  TextButton.icon(
                    onPressed: disabled ? null : () => unawaited(delete(sheet)),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('ลบ'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [details, const SizedBox(height: 12), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    ),
  );
}

class _EditionSelectionPage extends StatelessWidget {
  const _EditionSelectionPage({required this.onSelected});

  final Future<void> Function(AppEdition edition) onSelected;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('เลือกเวอร์ชัน Shift Tools')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'รูปแบบการใช้งาน',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'เลือกตามลักษณะการใช้งาน เปลี่ยนภายหลังได้จากหน้าตั้งค่า',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            for (final value in AppEdition.values) ...[
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    child: Icon(
                      value == AppEdition.personal
                          ? Icons.person_outline
                          : Icons.apartment_outlined,
                    ),
                  ),
                  title: Text(
                    value.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(value.description),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelected(value),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    ),
  );
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.controller,
    required this.createFutureSheet,
    required this.openShiftTemplates,
    required this.edition,
    required this.changeEdition,
    required this.openSetup,
  });
  final AppController controller;
  final Future<void> Function(String template, String newTitle)
  createFutureSheet;
  final VoidCallback openShiftTemplates;
  final AppEdition edition;
  final Future<void> Function(AppEdition edition) changeEdition;
  final Future<void> Function() openSetup;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.tune_outlined)), title: const Text('ตั้งค่าหน่วยงานและเวร'), subtitle: Text('${controller.settings.organizationName.isEmpty ? 'ยังไม่ได้ตั้งค่า' : controller.settings.organizationName} • ${controller.settings.officerName}'), trailing: const Icon(Icons.edit_outlined), onTap: openSetup)),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(
              edition == AppEdition.personal
                  ? Icons.person_outline
                  : Icons.apartment_outlined,
            ),
          ),
          title: const Text('เวอร์ชันการใช้งาน'),
          subtitle: Text('${edition.label} • ${edition.description}'),
          trailing: const Icon(Icons.swap_horiz),
          onTap: () => _showEditionDialog(context),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.view_timeline_outlined),
          ),
          title: Text(context.l10n.shiftTemplates),
          subtitle: Text(context.l10n.shiftTemplatesDescription),
          trailing: const Icon(Icons.chevron_right),
          onTap: openShiftTemplates,
        ),
      ),
      const SizedBox(height: 16),
      _FutureSheetCard(controller: controller, onCreate: createFutureSheet),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ขอบเขตความปลอดภัย',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const _SafetyRow(
                icon: Icons.lock_outline,
                text: 'อ่าน Google Sheets ด้วย spreadsheets.readonly',
              ),
              const _SafetyRow(
                icon: Icons.edit_off_outlined,
                text: 'ไม่มีคำสั่งแก้ไขไฟล์ต้นฉบับในขั้นตอนอ่านเวร',
              ),
              const _SafetyRow(
                icon: Icons.verified_user_outlined,
                text: 'สร้างสำเนา/เขียน Calendar ด้วยบัญชี Google ที่ล็อกอิน',
              ),
              const _SafetyRow(
                icon: Icons.people_outline,
                text: 'ไม่ส่งคำเชิญและไม่สร้าง Google Meet',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สี Google Calendar',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final category in ShiftCategory.values)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 9,
                    backgroundColor: Color(category.colorValue),
                  ),
                  title: Text(category.label),
                  trailing: Text(category.colorName),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Future<void> _showEditionDialog(BuildContext context) async {
    final selected = await showDialog<AppEdition>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('เลือกเวอร์ชันการใช้งาน'),
        children: [
          for (final value in AppEdition.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  value == edition ? Icons.check_circle : Icons.circle_outlined,
                ),
                title: Text(value.label),
                subtitle: Text(value.description),
              ),
            ),
        ],
      ),
    );
    if (selected != null && selected != edition) {
      await changeEdition(selected);
    }
  }
}

class _FutureSheetCard extends StatefulWidget {
  const _FutureSheetCard({required this.controller, required this.onCreate});

  final AppController controller;
  final Future<void> Function(String template, String newTitle) onCreate;

  @override
  State<_FutureSheetCard> createState() => _FutureSheetCardState();
}

class _FutureSheetCardState extends State<_FutureSheetCard> {
  late final template = TextEditingController(
    text: widget.controller.sheetTitles.lastOrNull ?? '',
  );
  late final newTitle = TextEditingController(
    text: _suggestedFutureSheetTitle(widget.controller),
  );

  @override
  void didUpdateWidget(covariant _FutureSheetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (template.text.trim().isEmpty &&
        widget.controller.sheetTitles.isNotEmpty) {
      template.text = widget.controller.sheetTitles.last;
    }
    final suggestedTitle = _suggestedFutureSheetTitle(widget.controller);
    if (newTitle.text.trim().isEmpty && suggestedTitle.isNotEmpty) {
      newTitle.text = suggestedTitle;
    }
  }

  @override
  void dispose() {
    template.dispose();
    newTitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'สร้างชีตเดือนล่วงหน้า',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'ทำสำเนาแท็บต้นแบบเป็นแท็บใหม่ โดยอนุญาตสิทธิ์ Sheets '
            'เฉพาะตอนกดสร้าง',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: template,
            decoration: const InputDecoration(
              labelText: 'ชื่อแท็บต้นแบบ',
              prefixIcon: Icon(Icons.copy_all_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: newTitle,
            decoration: const InputDecoration(
              labelText: 'ชื่อแท็บเดือนใหม่',
              prefixIcon: Icon(Icons.add_box_outlined),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'หมายเหตุ: เป็นสำเนาเต็มของต้นแบบ ควรตรวจและปรับวันที่/รายชื่อในแท็บใหม่ก่อนใช้',
            style: TextStyle(color: Colors.deepOrange),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed:
                widget.controller.auth.isSignedIn && !widget.controller.busy
                ? () => widget.onCreate(
                    template.text.trim(),
                    newTitle.text.trim(),
                  )
                : null,
            icon: const Icon(Icons.library_add_outlined),
            label: const Text('สร้างแท็บใหม่'),
          ),
        ],
      ),
    ),
  );
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: error
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.info_outline),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

const _thaiMonths = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

String _thaiDate(DateTime value) =>
    '${value.day} ${_thaiMonths[value.month - 1]} ${value.year + 543}';
String _shortWeekday(DateTime value) =>
    const ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'][value.weekday - 1];
String _compactSectionTitle(String value) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.length <= 28
      ? normalized
      : '${normalized.substring(0, 27)}…';
}

Color? _colorFromHex(String? value) {
  if (value == null) return null;
  final rgb = int.tryParse(value.replaceFirst('#', ''), radix: 16);
  return rgb == null ? null : Color(0xFF000000 | rgb);
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _clock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

String _suggestedFutureSheetTitle(AppController controller) {
  final month = controller.settings.month;
  final year = controller.settings.year;
  if (month == null || year == null) return '';
  return 'เวร ${_thaiMonths[month - 1]} ${year + 543}';
}
