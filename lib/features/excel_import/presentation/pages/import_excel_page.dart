import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;

import '../../../../core/google/authorized_google_client_factory.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/excel_column_name.dart';
import '../../../../domain/entities/schedule.dart';
import '../../../../l10n/l10n.dart';
import '../../../../services/google_auth_service.dart';
import '../../../../services/drive_ownership_service.dart';
import '../../../../services/sheets_service.dart';
import '../../../google_sheets/infrastructure/google_sheets_gateway.dart';
import '../../../schedule/data/imported_schedule_adapter.dart';
import '../../../schedule/presentation/controllers/schedule_controller.dart';
import '../../data/excel_reader_service.dart';
import '../../data/google_sheets_import_data_source.dart';
import '../../data/spreadsheet_ownership_verifier.dart';
import '../../domain/column_mapping.dart';
import '../../domain/google_sheets_import_info.dart';
import '../../domain/shift_record.dart';
import '../../domain/worksheet_info.dart';
import '../controllers/column_mapping_controller.dart';
import '../controllers/excel_import_controller.dart';
import 'column_mapping_page.dart';
import 'import_summary_page.dart';
import '../widgets/empty_import_view.dart';
import '../widgets/excel_import_button.dart';
import '../widgets/excel_preview_table.dart';
import '../widgets/import_error_card.dart';
import '../widgets/import_status_card.dart';
import '../widgets/google_sheets_import_widgets.dart';
import '../widgets/worksheet_list.dart';

class ImportExcelPage extends StatefulWidget {
  const ImportExcelPage({
    this.controller,
    this.controllerFactory,
    this.mappingController,
    this.mappingControllerFactory,
    this.googleAuthService,
    this.authorizedGoogleClientFactory = const AuthorizedGoogleClientFactory(),
    this.driveOwnershipGateway = const DriveOwnershipService(),
    this.googleSheetsImportDataSourceFactory,
    this.importedScheduleFactory,
    this.scheduleControllerFactory,
    this.scheduleSaver,
    super.key,
  });

  static const routeName = '/import-excel';

  final ExcelImportController? controller;
  final ExcelImportController Function()? controllerFactory;
  final ColumnMappingController? mappingController;
  final ColumnMappingController Function()? mappingControllerFactory;
  final GoogleAuthGateway? googleAuthService;
  final AuthorizedGoogleClientFactory authorizedGoogleClientFactory;
  final DriveOwnershipGateway driveOwnershipGateway;
  final GoogleSheetsImportDataSource Function(auth.AuthClient)?
  googleSheetsImportDataSourceFactory;
  final Schedule Function(Iterable<ShiftRecord>)? importedScheduleFactory;
  final ScheduleController Function(Schedule)? scheduleControllerFactory;
  final Future<Result<Schedule>> Function(Schedule)? scheduleSaver;

  @override
  State<ImportExcelPage> createState() => _ImportExcelPageState();
}

class _ImportExcelPageState extends State<ImportExcelPage> {
  late final ExcelImportController controller =
      widget.controller ??
      widget.controllerFactory?.call() ??
      ExcelImportController();
  late final bool ownsController = widget.controller == null;
  late final ColumnMappingController mappingController =
      widget.mappingController ??
      widget.mappingControllerFactory?.call() ??
      ColumnMappingController();
  late final bool ownsMappingController = widget.mappingController == null;
  final googleSheetsInputController = TextEditingController();
  GoogleSheetsImportDataSource? googleSheetsSource;
  GoogleSheetsImportInfo? googleSheetsInfo;
  auth.AuthClient? googleSheetsClient;
  bool loadingGoogleSheets = false;
  String? googleSheetsError;

  @override
  void dispose() {
    if (ownsController) controller.dispose();
    if (ownsMappingController) mappingController.dispose();
    googleSheetsInputController.dispose();
    googleSheetsClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.importExcel)),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.l10n.importSchedule,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.importDescription,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      if (controller.selectedFile == null &&
                          googleSheetsInfo == null)
                        const EmptyImportView()
                      else if (controller.selectedFile != null)
                        ImportStatusCard(
                          file: controller.selectedFile!,
                          worksheetCount:
                              controller.workbook?.worksheetCount ?? 0,
                          selectedWorksheet: controller.selectedWorksheet,
                          loadedRowCount: controller.rows.length,
                        ),
                      if (googleSheetsInfo != null)
                        GoogleSheetsStatusCard(
                          info: googleSheetsInfo!,
                          selectedWorksheet: controller.selectedWorksheet,
                          loadedRowCount: controller.rows.length,
                        ),
                      if (controller.workbook != null ||
                          googleSheetsInfo != null) ...[
                        const SizedBox(height: 16),
                        WorksheetList(
                          worksheets:
                              controller.workbook?.worksheets ??
                              googleSheetsInfo!.worksheets,
                          selectedWorksheet: controller.selectedWorksheet,
                          enabled:
                              !controller.isLoading && !loadingGoogleSheets,
                          onSelected: _selectWorksheet,
                        ),
                      ],
                      if (controller.selectedWorksheet != null) ...[
                        const SizedBox(height: 16),
                        ExcelPreviewTable(
                          worksheet: controller.selectedWorksheet!,
                          rows: controller.rows,
                        ),
                        const SizedBox(height: 12),
                        if (controller.completed &&
                            controller.importSummary != null)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.auto_awesome),
                              title: const Text('วิเคราะห์และสร้างข้อมูลอัตโนมัติแล้ว'),
                              subtitle: Text(
                                'สร้างได้ ${controller.importSummary!.importedRows} รายการ'
                                ' • ข้าม ${controller.importSummary!.skippedRows}'
                                ' • ข้อผิดพลาด ${controller.importSummary!.errorCount}'
                                ' • คำเตือน ${controller.importSummary!.warningCount}',
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _openColumnMapping,
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(
                            mappingController.isValid
                                ? context.l10n.editColumnMapping
                                : context.l10n.nextColumnMapping,
                          ),
                        ),
                      ],
                      if (controller.error != null) ...[
                        const SizedBox(height: 16),
                        ImportErrorCard(error: controller.error!),
                      ],
                      if (googleSheetsError != null) ...[
                        const SizedBox(height: 16),
                        GoogleSheetsErrorCard(message: googleSheetsError!),
                      ],
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ExcelImportButton(
                            label: context.l10n.selectExcelFile,
                            icon: Icons.upload_file,
                            loading: controller.isLoading,
                            onPressed: controller.isLoading
                                ? null
                                : _pickExcelFile,
                          ),
                          ExcelImportButton(
                            label: context.l10n.cancel,
                            icon: Icons.close,
                            outlined: true,
                            onPressed:
                                controller.isLoading || loadingGoogleSheets
                                ? null
                                : _cancel,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Google Sheets',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: googleSheetsInputController,
                        enabled: !loadingGoogleSheets,
                        decoration: InputDecoration(
                          labelText: context.l10n.googleSheetsInputLabel,
                          hintText:
                              'https://docs.google.com/spreadsheets/d/...',
                          prefixIcon: const Icon(Icons.table_chart),
                        ),
                        onSubmitted: (_) => _loadGoogleSheets(),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: loadingGoogleSheets
                                  ? null
                                  : _pickGoogleSheetFromDrive,
                              icon: const Icon(Icons.add_to_drive),
                              label: Text(context.l10n.chooseFromGoogleDrive),
                            ),
                            OutlinedButton.icon(
                              onPressed: loadingGoogleSheets
                                  ? null
                                  : _loadGoogleSheets,
                              icon: loadingGoogleSheets
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.cloud_download),
                              label: Text(context.l10n.loadGoogleSheets),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _selectWorksheet(WorksheetInfo worksheet) async {
    final googleSource = googleSheetsSource;
    if (googleSheetsInfo != null && googleSource != null) {
      final importRows = googleSource.selectWorksheet(worksheet);
      controller.loadConvertedWorksheet(
        worksheet: worksheet,
        previewRows: importRows
            .take(ExcelReaderService.maxPreviewRows)
            .toList(growable: false),
        importRows: importRows,
      );
    } else {
      await controller.selectWorksheet(worksheet);
    }
    if (!mounted || controller.state != ExcelImportState.worksheetLoaded) {
      return;
    }
    mappingController.resetMapping();
    mappingController.loadAvailableColumns(
      List.generate(
        worksheet.columnCount,
        ExcelColumnName.fromIndex,
        growable: false,
      ),
    );
    mappingController.applySuggestedMapping(controller.suggestMapping());
    if (mappingController.isValid) {
      await controller.importRows(mappingController.mapping);
    }
  }

  Future<void> _openColumnMapping() async {
    await Navigator.of(context).push<ColumnMapping>(
      MaterialPageRoute(
        builder: (context) => ColumnMappingPage(
          controller: mappingController,
          onNext: _runImport,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _runImport(ColumnMapping mapping) async {
    await controller.importRows(mapping);
    if (!mounted || controller.importSummary == null) return;
    final records = controller.shiftRecords;
    final schedule =
        widget.importedScheduleFactory?.call(records) ??
        const ImportedScheduleAdapter().createSchedule(records);
    final persistenceResult = await widget.scheduleSaver?.call(schedule);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ImportSummaryPage(
          summary: controller.importSummary!,
          records: records,
          schedule: schedule,
          scheduleControllerFactory: widget.scheduleControllerFactory,
          persistenceResult: persistenceResult,
        ),
      ),
    );
  }

  Future<void> _pickExcelFile() async {
    setState(() {
      googleSheetsInfo = null;
      googleSheetsSource = null;
      googleSheetsError = null;
    });
    await controller.pickFile();
  }

  void _cancel() {
    controller.cancel();
    setState(() {
      googleSheetsInfo = null;
      googleSheetsSource = null;
      googleSheetsError = null;
    });
  }

  Future<void> _loadGoogleSheets() async {
    final input = googleSheetsInputController.text.trim();
    if (input.isEmpty || loadingGoogleSheets) return;

    auth.AuthClient? pendingClient;
    setState(() {
      loadingGoogleSheets = true;
      googleSheetsError = null;
    });
    try {
      final authService = widget.googleAuthService;
      if (authService == null) {
        throw StateError('Google authentication is unavailable.');
      }
      if (authService.account == null) {
        await authService.signIn();
      }
      final account = authService.account;
      if (account == null) {
        throw StateError('Sign in to Google before loading a spreadsheet.');
      }
      final spreadsheetId = SheetsService.spreadsheetIdFromUrl(input);
      pendingClient = await widget.authorizedGoogleClientFactory.create(
        account: account,
        scopes: const [
          GoogleAuthService.spreadsheetsReadOnlyScope,
          drive.DriveApi.driveMetadataReadonlyScope,
        ],
      );
      final source =
          widget.googleSheetsImportDataSourceFactory?.call(pendingClient) ??
          GoogleSheetsImportDataSource(
            GoogleSheetsGateway(pendingClient),
            ownershipVerifier: GoogleDriveSpreadsheetOwnershipVerifier(
              client: pendingClient,
              gateway: const DriveOwnershipService(),
            ),
          );
      final info = await source.readMetadata(spreadsheetId);
      if (!mounted) {
        pendingClient.close();
        return;
      }
      googleSheetsClient?.close();
      googleSheetsClient = pendingClient;
      pendingClient = null;
      controller.cancel();
      mappingController.resetMapping();
      setState(() {
        googleSheetsSource = source;
        googleSheetsInfo = info;
      });
    } catch (error) {
      pendingClient?.close();
      if (!mounted) return;
      setState(() {
        googleSheetsError = error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('FormatException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          loadingGoogleSheets = false;
        });
      }
    }
  }

  Future<void> _pickGoogleSheetFromDrive() async {
    if (loadingGoogleSheets) return;
    auth.AuthClient? client;
    setState(() {
      loadingGoogleSheets = true;
      googleSheetsError = null;
    });
    try {
      final authService = widget.googleAuthService;
      if (authService == null) {
        throw StateError('Google authentication is unavailable.');
      }
      if (authService.account == null) {
        await authService.signIn();
      }
      final account = authService.account;
      if (account == null) {
        throw StateError('Sign in to Google before choosing a spreadsheet.');
      }
      client = await widget.authorizedGoogleClientFactory.create(
        account: account,
        scopes: const [drive.DriveApi.driveMetadataReadonlyScope],
      );
      final sheets = await widget.driveOwnershipGateway.listOwnedSpreadsheets(
        client,
        limit: 50,
      );
      if (!mounted) return;
      final selected = await showDialog<RecentOwnedSheet>(
        context: context,
        builder: (context) => OwnedGoogleSheetPickerDialog(sheets: sheets),
      );
      if (selected == null || !mounted) return;
      googleSheetsInputController.text = selected.url;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        googleSheetsError = error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('FormatException: ', '');
      });
      return;
    } finally {
      client?.close();
      if (mounted) {
        setState(() {
          loadingGoogleSheets = false;
        });
      }
    }
    await _loadGoogleSheets();
  }
}
