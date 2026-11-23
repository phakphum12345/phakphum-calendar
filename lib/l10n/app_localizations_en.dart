// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Shift Tools';

  @override
  String get appSubtitle => 'Schedule workspace';

  @override
  String get switchLanguage => 'Switch language';

  @override
  String get home => 'Home';

  @override
  String get preview => 'Preview';

  @override
  String get notifications => 'Notifications';

  @override
  String get history => 'History';

  @override
  String get reports => 'Reports';

  @override
  String get settings => 'Settings';

  @override
  String get tools => 'Tools';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get schedule => 'Schedule';

  @override
  String get employees => 'Employees';

  @override
  String get shiftExchange => 'Shift exchange';

  @override
  String get more => 'More';

  @override
  String get clear => 'Clear';

  @override
  String get all => 'All';

  @override
  String get pending => 'Pending';

  @override
  String get approved => 'Approved';

  @override
  String get rejected => 'Rejected';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get employeeDirectoryDescription =>
      'People referenced by the active canonical schedule.';

  @override
  String get searchEmployees => 'Search by name, code or position';

  @override
  String get activeEmployeesOnly => 'Active only';

  @override
  String get noEmployeesMatch => 'No employees match the active filters.';

  @override
  String get noEmployeesInSchedule =>
      'No employees are referenced by the current schedule.';

  @override
  String get shiftExchangeDescription =>
      'Review shift-exchange requests and their approval status.';

  @override
  String get noExchangeRequests => 'No shift-exchange requests are available.';

  @override
  String get exchangeApprovalBoundary =>
      'New requests and approvals use the protected exchange workflow.';

  @override
  String get myNextShift => 'My next shift';

  @override
  String get todaySummary => 'Today';

  @override
  String get tomorrowSummary => 'Tomorrow';

  @override
  String get monthlyAssignments => 'This month';

  @override
  String get calendarSyncStatus => 'Calendar sync';

  @override
  String get conflictWarning => 'Conflict warning';

  @override
  String get assignmentCount => 'assignments';

  @override
  String get noUpcomingShift => 'No upcoming shift';

  @override
  String get noScheduleData => 'No schedule data';

  @override
  String get connected => 'Connected';

  @override
  String get notConnected => 'Not connected';

  @override
  String get neverSynced => 'Never synced';

  @override
  String get noPendingConflicts => 'No pending conflicts';

  @override
  String get requiresReview => 'Requires review';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get next => 'Next';

  @override
  String get reset => 'Reset';

  @override
  String get retry => 'Retry';

  @override
  String get errors => 'Errors';

  @override
  String get warnings => 'Warnings';

  @override
  String get rules => 'Rules';

  @override
  String get validationTitle => 'Rule Validation';

  @override
  String get importExcel => 'Import Excel';

  @override
  String get importSchedule => 'Import schedule';

  @override
  String get importDescription =>
      'Select an .xlsx file or Google Sheets document, then review it before choosing a worksheet.';

  @override
  String get selectExcelFile => 'Select Excel File';

  @override
  String get loadGoogleSheets => 'Load Google Sheets';

  @override
  String get googleSheetsInputLabel => 'Google Sheets URL or spreadsheet ID';

  @override
  String get chooseFromGoogleDrive => 'Choose from Google Drive';

  @override
  String get chooseGoogleSheet => 'Choose a Google Sheet';

  @override
  String get ownedGoogleSheetsOnly =>
      'Only spreadsheets owned by the signed-in Google account are shown.';

  @override
  String get noOwnedGoogleSheets =>
      'No Google Sheets owned by this account were found.';

  @override
  String get columnMapping => 'Column Mapping';

  @override
  String get mapExcelColumns => 'Map Excel columns';

  @override
  String get requiredMappingHelp =>
      'Required fields must be mapped before continuing.';

  @override
  String get editColumnMapping => 'Edit Column Mapping';

  @override
  String get nextColumnMapping => 'Next: Column Mapping';

  @override
  String get importSummary => 'Import Summary';

  @override
  String get importCompleted => 'Import completed';

  @override
  String importCreatedRecords(int recordCount, int rowCount) {
    return '$recordCount Shift Records created from $rowCount data rows.';
  }

  @override
  String scheduleSaveFailed(String message) {
    return 'Schedule could not be saved: $message';
  }

  @override
  String get viewMonthCalendar => 'View Month Calendar';

  @override
  String get issues => 'Issues';

  @override
  String get monthCalendar => 'Month Calendar';

  @override
  String get monthlySchedule => 'Monthly Schedule';

  @override
  String get noShiftsThisMonth => 'No shifts scheduled for this month.';

  @override
  String get noMatchingAssignments =>
      'No assignments match the active filters.';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get reportEmptySchedule =>
      'No schedule data is available. You can still create an empty report.';

  @override
  String get reportPreviewPrompt =>
      'Select filters, then choose “Generate preview”.';

  @override
  String get month => 'Month';

  @override
  String get department => 'Department';

  @override
  String get allDepartments => 'All departments';

  @override
  String get generatePreview => 'Generate preview';

  @override
  String get print => 'Print';

  @override
  String get saveSharePdf => 'Save / share PDF';

  @override
  String get reportDefaultTitle => 'Monthly Staff Schedule Report';

  @override
  String get reportGeneratedAt => 'Generated at';

  @override
  String get reportEmployee => 'Employee';

  @override
  String get reportPosition => 'Position';

  @override
  String get reportNoData => 'No schedule data for the selected month';

  @override
  String get reportSummary => 'Summary';

  @override
  String get reportLegend => 'Shift legend';

  @override
  String get reportNotes => 'Notes';

  @override
  String get reportEmployeeCount => 'Employees';

  @override
  String get reportAssignmentCount => 'Assignments';

  @override
  String get reportPreparedBy => 'Prepared by';

  @override
  String get reportCheckedBy => 'Checked by';

  @override
  String get reportApprovedBy => 'Approved by';

  @override
  String get reportDate => 'Date';

  @override
  String get weekdayMondayShort => 'Mon';

  @override
  String get weekdayTuesdayShort => 'Tue';

  @override
  String get weekdayWednesdayShort => 'Wed';

  @override
  String get weekdayThursdayShort => 'Thu';

  @override
  String get weekdayFridayShort => 'Fri';

  @override
  String get weekdaySaturdayShort => 'Sat';

  @override
  String get weekdaySundayShort => 'Sun';

  @override
  String get googleAccessTitle => 'Allow Google access';

  @override
  String get googleAccessLater => 'Later';

  @override
  String get googleAccessAllow => 'Allow access';

  @override
  String get googleSyncConfirmTitle => 'Confirm calendar changes';

  @override
  String get googleSyncConfirm => 'Confirm and continue';

  @override
  String get googleSyncNoWriteBeforeConfirm =>
      'Nothing is written to Google Calendar before confirmation.';

  @override
  String get unexpectedError => 'Something went wrong. Please try again.';

  @override
  String get edit => 'Edit';

  @override
  String get deactivate => 'Deactivate';

  @override
  String get requiredField => 'This field is required.';

  @override
  String get invalidNumber => 'Enter a valid non-negative number.';

  @override
  String get addEmployee => 'Add employee';

  @override
  String get editEmployee => 'Edit employee';

  @override
  String get deactivateEmployee => 'Deactivate employee';

  @override
  String deactivateEmployeeConfirmation(String name) {
    return 'Deactivate $name? Existing schedule assignments will be retained.';
  }

  @override
  String get employeeCode => 'Employee code';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get nickname => 'Nickname';

  @override
  String get position => 'Position';

  @override
  String get departmentCode => 'Department code';

  @override
  String get departmentName => 'Department name';

  @override
  String get shiftTemplates => 'Shift templates';

  @override
  String get shiftTemplatesDescription =>
      'Configure reusable shift codes, times, colors, and rates.';

  @override
  String get addShiftTemplate => 'Add shift template';

  @override
  String get editShiftTemplate => 'Edit shift template';

  @override
  String get shiftCode => 'Shift code';

  @override
  String get shiftName => 'Shift name';

  @override
  String get shortName => 'Short name';

  @override
  String get startTime => 'Start time';

  @override
  String get endTime => 'End time';

  @override
  String get workingHours => 'Working hours';

  @override
  String get shiftRate => 'Shift rate';

  @override
  String get overnight => 'Overnight';

  @override
  String get manualRosterEditor => 'Manual roster editor';

  @override
  String get addAssignment => 'Add assignment';

  @override
  String get selectDayToEdit => 'Select a day to edit its assignments.';

  @override
  String get rosterCatalogRequired =>
      'Add employees and shift templates before creating assignments.';

  @override
  String get previewChanges => 'Preview changes';

  @override
  String get deleteAssignment => 'Delete assignment';

  @override
  String deleteAssignmentConfirmation(String employee, String shift) {
    return 'Delete $employee from shift $shift?';
  }

  @override
  String get scheduleSaved => 'Schedule saved.';

  @override
  String get location => 'Location';

  @override
  String get notes => 'Notes';

    @override
    String workflowAddedCount(int count) => 'Added $count';

    @override
    String workflowUpdatedCount(int count) => 'Updated $count';

    @override
    String workflowDeletedCount(int count) => 'Deleted $count';

    @override
    String workflowUnchangedCount(int count) => 'Unchanged $count';

    @override
    String workflowWarningCount(int count) => 'Warnings $count';

    @override
    String workflowBlockedCount(int count) => 'Blocked $count';

      @override
      String get workflowScheduleFailedValidation =>
          'Schedule failed validation, cannot sync';

      @override
      String get workflowReadyToConfirm => 'Ready to confirm sync';

      @override
      String get workflowWarningsBeforeConfirm =>
          'Warnings found, please review before confirming sync';

      @override
      String get workflowCalendarCheckFailed => 'Google Calendar check failed';

      @override
      String get workflowNoValidatedPlan => 'No validated plan available for sync';

      @override
      String get workflowNoValidationResult =>
          'No validation result available for sync';

      @override
      String get workflowItemsStillBlocked =>
          'Items still blocked, please review before sync';

      @override
      String get workflowSyncPartialSuccess =>
          'Partial sync success, please check history';

      @override
      String get workflowSyncSuccessful => 'Google Calendar sync successful';

      @override
      String get workflowSyncFailed =>
          'Sync failed, check internet and Google permissions';

    @override
    String get startupTimeout =>
            'Startup took too long. Check Google OAuth settings or reload the page.';

    @override
    String startupFailed(String error) => 'Startup failed: $error';
}
