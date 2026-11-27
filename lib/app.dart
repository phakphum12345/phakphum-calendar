import 'dart:async';

import 'package:flutter/material.dart';

import 'controller/app_controller.dart';
import 'core/di/app_dependencies.dart';
import 'features/excel_import/presentation/pages/import_excel_page.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'ui/app_shell.dart';

class ShiftToolsApp extends StatefulWidget {
  const ShiftToolsApp({
    super.key,
    this.controller,
    this.dependencies,
    this.locale,
  });

  final AppController? controller;
  final AppDependencies? dependencies;
  final Locale? locale;

  @override
  State<ShiftToolsApp> createState() => _ShiftToolsAppState();
}

class _ShiftToolsAppState extends State<ShiftToolsApp> {
  static const _startupTimeout = Duration(seconds: 12);

  late final AppDependencies dependencies =
      widget.dependencies ??
      AppDependencies.production(
        workflowMessageProvider: (key) =>
            workflowMessageFor(localizationsForLocale(_locale), key),
      );
  late final AppController controller =
      widget.controller ?? dependencies.createAppController();
  late final bool ownsController = widget.controller == null;
  late Locale _locale = widget.locale ?? const Locale('th');

  @override
  void initState() {
    super.initState();
    unawaited(_initializeControllerSafely());
  }

  Future<void> _initializeControllerSafely() async {
    try {
      await controller.initialize().timeout(_startupTimeout);
    } on TimeoutException {
      if (!mounted || controller.initialized) return;
      controller.error ??= localizationsForLocale(_locale).startupTimeout;
      controller.initialized = true;
      controller.notifyListeners();
    } catch (caught) {
      if (!mounted || controller.initialized) return;
      controller.error ??= localizationsForLocale(_locale).startupFailed(
        caught.toString(),
      );
      controller.initialized = true;
      controller.notifyListeners();
    }
  }

  @override
  void dispose() {
    if (ownsController) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ShiftToolsApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locale != null && widget.locale != oldWidget.locale) {
      _locale = widget.locale!;
    }
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF0F5F5C);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF4F7F7),
        appBarTheme: AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          surfaceTintColor: Colors.transparent,
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primaryContainer,
          selectedIconTheme: IconThemeData(
            color: colorScheme.onPrimaryContainer,
          ),
          selectedLabelTextStyle: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          elevation: 0,
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primaryContainer,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        dividerTheme: DividerThemeData(
          color: colorScheme.outlineVariant,
          thickness: 1,
        ),
      ),
      routes: {
        ImportExcelPage.routeName: (context) => ImportExcelPage(
          controllerFactory: dependencies.createExcelImportController,
          mappingControllerFactory: dependencies.createColumnMappingController,
          googleAuthService: controller.auth,
          authorizedGoogleClientFactory:
              dependencies.authorizedGoogleClientFactory,
          driveOwnershipGateway: dependencies.driveOwnershipService,
          googleSheetsImportDataSourceFactory:
              dependencies.googleSheetsImportDataSourceFactory,
          importedScheduleFactory: dependencies.createImportedSchedule,
          scheduleControllerFactory:
              dependencies.createImportedScheduleController,
          workflowControllerFactory:
              dependencies.createAuthorizedCalendarWorkflowController,
          scheduleSaver: dependencies.saveImportedSchedule,
          existingScheduleLoader: dependencies.loadImportedSchedule,
          employeeRepository: dependencies.employeeRepository,
          shiftTemplateControllerFactory:
              dependencies.createShiftTemplateController,
          gridRosterWorkflow: dependencies.createGridRosterImportWorkflow(),
        ),
      },
      home: AppShell(
        controller: controller,
        locale: _locale,
        onLocaleChanged: (locale) => setState(() => _locale = locale),
        reportControllerFactory:
            dependencies.createMonthlyScheduleReportController,
        employeeDirectoryControllerFactory:
            dependencies.createEmployeeDirectoryController,
        shiftExchangeControllerFactory:
            dependencies.createShiftExchangeController,
        dashboardSummaryService: dependencies.dashboardSummaryService,
        shiftTemplateControllerFactory:
            dependencies.createShiftTemplateController,
        scheduleControllerFactory: dependencies.createRosterEditorController,
        gridRosterImportWorkflowFactory:
            dependencies.createGridRosterImportWorkflow,
      ),
    );
  }
}
