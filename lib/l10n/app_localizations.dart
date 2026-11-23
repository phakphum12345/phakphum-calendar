import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Tools'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule workspace'**
  String get appSubtitle;

  /// No description provided for @switchLanguage.
  ///
  /// In en, this message translates to:
  /// **'Switch language'**
  String get switchLanguage;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @employees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employees;

  /// No description provided for @shiftExchange.
  ///
  /// In en, this message translates to:
  /// **'Shift exchange'**
  String get shiftExchange;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @employeeDirectoryDescription.
  ///
  /// In en, this message translates to:
  /// **'People referenced by the active canonical schedule.'**
  String get employeeDirectoryDescription;

  /// No description provided for @searchEmployees.
  ///
  /// In en, this message translates to:
  /// **'Search by name, code or position'**
  String get searchEmployees;

  /// No description provided for @activeEmployeesOnly.
  ///
  /// In en, this message translates to:
  /// **'Active only'**
  String get activeEmployeesOnly;

  /// No description provided for @noEmployeesMatch.
  ///
  /// In en, this message translates to:
  /// **'No employees match the active filters.'**
  String get noEmployeesMatch;

  /// No description provided for @noEmployeesInSchedule.
  ///
  /// In en, this message translates to:
  /// **'No employees are referenced by the current schedule.'**
  String get noEmployeesInSchedule;

  /// No description provided for @shiftExchangeDescription.
  ///
  /// In en, this message translates to:
  /// **'Review shift-exchange requests and their approval status.'**
  String get shiftExchangeDescription;

  /// No description provided for @noExchangeRequests.
  ///
  /// In en, this message translates to:
  /// **'No shift-exchange requests are available.'**
  String get noExchangeRequests;

  /// No description provided for @exchangeApprovalBoundary.
  ///
  /// In en, this message translates to:
  /// **'New requests and approvals use the protected exchange workflow.'**
  String get exchangeApprovalBoundary;

  /// No description provided for @myNextShift.
  ///
  /// In en, this message translates to:
  /// **'My next shift'**
  String get myNextShift;

  /// No description provided for @todaySummary.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todaySummary;

  /// No description provided for @tomorrowSummary.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrowSummary;

  /// No description provided for @monthlyAssignments.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get monthlyAssignments;

  /// No description provided for @calendarSyncStatus.
  ///
  /// In en, this message translates to:
  /// **'Calendar sync'**
  String get calendarSyncStatus;

  /// No description provided for @conflictWarning.
  ///
  /// In en, this message translates to:
  /// **'Conflict warning'**
  String get conflictWarning;

  /// No description provided for @assignmentCount.
  ///
  /// In en, this message translates to:
  /// **'assignments'**
  String get assignmentCount;

  /// No description provided for @noUpcomingShift.
  ///
  /// In en, this message translates to:
  /// **'No upcoming shift'**
  String get noUpcomingShift;

  /// No description provided for @noScheduleData.
  ///
  /// In en, this message translates to:
  /// **'No schedule data'**
  String get noScheduleData;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @neverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get neverSynced;

  /// No description provided for @noPendingConflicts.
  ///
  /// In en, this message translates to:
  /// **'No pending conflicts'**
  String get noPendingConflicts;

  /// No description provided for @requiresReview.
  ///
  /// In en, this message translates to:
  /// **'Requires review'**
  String get requiresReview;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @errors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get errors;

  /// No description provided for @warnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get warnings;

  /// No description provided for @rules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get rules;

  /// No description provided for @validationTitle.
  ///
  /// In en, this message translates to:
  /// **'Rule Validation'**
  String get validationTitle;

  /// No description provided for @importExcel.
  ///
  /// In en, this message translates to:
  /// **'Import Excel'**
  String get importExcel;

  /// No description provided for @importSchedule.
  ///
  /// In en, this message translates to:
  /// **'Import schedule'**
  String get importSchedule;

  /// No description provided for @importDescription.
  ///
  /// In en, this message translates to:
  /// **'Select an .xlsx file or Google Sheets document, then review it before choosing a worksheet.'**
  String get importDescription;

  /// No description provided for @selectExcelFile.
  ///
  /// In en, this message translates to:
  /// **'Select Excel File'**
  String get selectExcelFile;

  /// No description provided for @loadGoogleSheets.
  ///
  /// In en, this message translates to:
  /// **'Load Google Sheets'**
  String get loadGoogleSheets;

  /// No description provided for @googleSheetsInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Google Sheets URL or spreadsheet ID'**
  String get googleSheetsInputLabel;

  /// No description provided for @chooseFromGoogleDrive.
  ///
  /// In en, this message translates to:
  /// **'Choose from Google Drive'**
  String get chooseFromGoogleDrive;

  /// No description provided for @chooseGoogleSheet.
  ///
  /// In en, this message translates to:
  /// **'Choose a Google Sheet'**
  String get chooseGoogleSheet;

  /// No description provided for @ownedGoogleSheetsOnly.
  ///
  /// In en, this message translates to:
  /// **'Only spreadsheets owned by the signed-in Google account are shown.'**
  String get ownedGoogleSheetsOnly;

  /// No description provided for @noOwnedGoogleSheets.
  ///
  /// In en, this message translates to:
  /// **'No Google Sheets owned by this account were found.'**
  String get noOwnedGoogleSheets;

  /// No description provided for @columnMapping.
  ///
  /// In en, this message translates to:
  /// **'Column Mapping'**
  String get columnMapping;

  /// No description provided for @mapExcelColumns.
  ///
  /// In en, this message translates to:
  /// **'Map Excel columns'**
  String get mapExcelColumns;

  /// No description provided for @requiredMappingHelp.
  ///
  /// In en, this message translates to:
  /// **'Required fields must be mapped before continuing.'**
  String get requiredMappingHelp;

  /// No description provided for @editColumnMapping.
  ///
  /// In en, this message translates to:
  /// **'Edit Column Mapping'**
  String get editColumnMapping;

  /// No description provided for @nextColumnMapping.
  ///
  /// In en, this message translates to:
  /// **'Next: Column Mapping'**
  String get nextColumnMapping;

  /// No description provided for @importSummary.
  ///
  /// In en, this message translates to:
  /// **'Import Summary'**
  String get importSummary;

  /// No description provided for @importCompleted.
  ///
  /// In en, this message translates to:
  /// **'Import completed'**
  String get importCompleted;

  /// No description provided for @importCreatedRecords.
  ///
  /// In en, this message translates to:
  /// **'{recordCount} Shift Records created from {rowCount} data rows.'**
  String importCreatedRecords(int recordCount, int rowCount);

  /// No description provided for @scheduleSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Schedule could not be saved: {message}'**
  String scheduleSaveFailed(String message);

  /// No description provided for @viewMonthCalendar.
  ///
  /// In en, this message translates to:
  /// **'View Month Calendar'**
  String get viewMonthCalendar;

  /// No description provided for @issues.
  ///
  /// In en, this message translates to:
  /// **'Issues'**
  String get issues;

  /// No description provided for @monthCalendar.
  ///
  /// In en, this message translates to:
  /// **'Month Calendar'**
  String get monthCalendar;

  /// No description provided for @monthlySchedule.
  ///
  /// In en, this message translates to:
  /// **'Monthly Schedule'**
  String get monthlySchedule;

  /// No description provided for @noShiftsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'No shifts scheduled for this month.'**
  String get noShiftsThisMonth;

  /// No description provided for @noMatchingAssignments.
  ///
  /// In en, this message translates to:
  /// **'No assignments match the active filters.'**
  String get noMatchingAssignments;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @reportEmptySchedule.
  ///
  /// In en, this message translates to:
  /// **'No schedule data is available. You can still create an empty report.'**
  String get reportEmptySchedule;

  /// No description provided for @reportPreviewPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select filters, then choose “Generate preview”.'**
  String get reportPreviewPrompt;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @department.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get department;

  /// No description provided for @allDepartments.
  ///
  /// In en, this message translates to:
  /// **'All departments'**
  String get allDepartments;

  /// No description provided for @generatePreview.
  ///
  /// In en, this message translates to:
  /// **'Generate preview'**
  String get generatePreview;

  /// No description provided for @print.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get print;

  /// No description provided for @saveSharePdf.
  ///
  /// In en, this message translates to:
  /// **'Save / share PDF'**
  String get saveSharePdf;

  /// No description provided for @reportDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Staff Schedule Report'**
  String get reportDefaultTitle;

  /// No description provided for @reportGeneratedAt.
  ///
  /// In en, this message translates to:
  /// **'Generated at'**
  String get reportGeneratedAt;

  /// No description provided for @reportEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get reportEmployee;

  /// No description provided for @reportPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get reportPosition;

  /// No description provided for @reportNoData.
  ///
  /// In en, this message translates to:
  /// **'No schedule data for the selected month'**
  String get reportNoData;

  /// No description provided for @reportSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get reportSummary;

  /// No description provided for @reportLegend.
  ///
  /// In en, this message translates to:
  /// **'Shift legend'**
  String get reportLegend;

  /// No description provided for @reportNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get reportNotes;

  /// No description provided for @reportEmployeeCount.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get reportEmployeeCount;

  /// No description provided for @reportAssignmentCount.
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get reportAssignmentCount;

  /// No description provided for @reportPreparedBy.
  ///
  /// In en, this message translates to:
  /// **'Prepared by'**
  String get reportPreparedBy;

  /// No description provided for @reportCheckedBy.
  ///
  /// In en, this message translates to:
  /// **'Checked by'**
  String get reportCheckedBy;

  /// No description provided for @reportApprovedBy.
  ///
  /// In en, this message translates to:
  /// **'Approved by'**
  String get reportApprovedBy;

  /// No description provided for @reportDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get reportDate;

  /// No description provided for @weekdayMondayShort.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMondayShort;

  /// No description provided for @weekdayTuesdayShort.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTuesdayShort;

  /// No description provided for @weekdayWednesdayShort.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWednesdayShort;

  /// No description provided for @weekdayThursdayShort.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThursdayShort;

  /// No description provided for @weekdayFridayShort.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFridayShort;

  /// No description provided for @weekdaySaturdayShort.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySaturdayShort;

  /// No description provided for @weekdaySundayShort.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySundayShort;

  /// No description provided for @googleAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow Google access'**
  String get googleAccessTitle;

  /// No description provided for @googleAccessLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get googleAccessLater;

  /// No description provided for @googleAccessAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get googleAccessAllow;

  /// No description provided for @googleSyncConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm calendar changes'**
  String get googleSyncConfirmTitle;

  /// No description provided for @googleSyncConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm and continue'**
  String get googleSyncConfirm;

  /// No description provided for @googleSyncNoWriteBeforeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Nothing is written to Google Calendar before confirmation.'**
  String get googleSyncNoWriteBeforeConfirm;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get unexpectedError;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @deactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivate;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get requiredField;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid non-negative number.'**
  String get invalidNumber;

  /// No description provided for @addEmployee.
  ///
  /// In en, this message translates to:
  /// **'Add employee'**
  String get addEmployee;

  /// No description provided for @editEmployee.
  ///
  /// In en, this message translates to:
  /// **'Edit employee'**
  String get editEmployee;

  /// No description provided for @deactivateEmployee.
  ///
  /// In en, this message translates to:
  /// **'Deactivate employee'**
  String get deactivateEmployee;

  /// No description provided for @deactivateEmployeeConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Deactivate {name}? Existing schedule assignments will be retained.'**
  String deactivateEmployeeConfirmation(String name);

  /// No description provided for @employeeCode.
  ///
  /// In en, this message translates to:
  /// **'Employee code'**
  String get employeeCode;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @position.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get position;

  /// No description provided for @departmentCode.
  ///
  /// In en, this message translates to:
  /// **'Department code'**
  String get departmentCode;

  /// No description provided for @departmentName.
  ///
  /// In en, this message translates to:
  /// **'Department name'**
  String get departmentName;

  /// No description provided for @shiftTemplates.
  ///
  /// In en, this message translates to:
  /// **'Shift templates'**
  String get shiftTemplates;

  /// No description provided for @shiftTemplatesDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure reusable shift codes, times, colors, and rates.'**
  String get shiftTemplatesDescription;

  /// No description provided for @addShiftTemplate.
  ///
  /// In en, this message translates to:
  /// **'Add shift template'**
  String get addShiftTemplate;

  /// No description provided for @editShiftTemplate.
  ///
  /// In en, this message translates to:
  /// **'Edit shift template'**
  String get editShiftTemplate;

  /// No description provided for @shiftCode.
  ///
  /// In en, this message translates to:
  /// **'Shift code'**
  String get shiftCode;

  /// No description provided for @shiftName.
  ///
  /// In en, this message translates to:
  /// **'Shift name'**
  String get shiftName;

  /// No description provided for @shortName.
  ///
  /// In en, this message translates to:
  /// **'Short name'**
  String get shortName;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get endTime;

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get workingHours;

  /// No description provided for @shiftRate.
  ///
  /// In en, this message translates to:
  /// **'Shift rate'**
  String get shiftRate;

  /// No description provided for @overnight.
  ///
  /// In en, this message translates to:
  /// **'Overnight'**
  String get overnight;

  /// No description provided for @manualRosterEditor.
  ///
  /// In en, this message translates to:
  /// **'Manual roster editor'**
  String get manualRosterEditor;

  /// No description provided for @addAssignment.
  ///
  /// In en, this message translates to:
  /// **'Add assignment'**
  String get addAssignment;

  /// No description provided for @selectDayToEdit.
  ///
  /// In en, this message translates to:
  /// **'Select a day to edit its assignments.'**
  String get selectDayToEdit;

  /// No description provided for @rosterCatalogRequired.
  ///
  /// In en, this message translates to:
  /// **'Add employees and shift templates before creating assignments.'**
  String get rosterCatalogRequired;

  /// No description provided for @previewChanges.
  ///
  /// In en, this message translates to:
  /// **'Preview changes'**
  String get previewChanges;

  /// No description provided for @deleteAssignment.
  ///
  /// In en, this message translates to:
  /// **'Delete assignment'**
  String get deleteAssignment;

  /// No description provided for @deleteAssignmentConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete {employee} from shift {shift}?'**
  String deleteAssignmentConfirmation(String employee, String shift);

  /// No description provided for @scheduleSaved.
  ///
  /// In en, this message translates to:
  /// **'Schedule saved.'**
  String get scheduleSaved;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  String workflowAddedCount(int count);

  String workflowUpdatedCount(int count);

  String workflowDeletedCount(int count);

  String workflowUnchangedCount(int count);

  String workflowWarningCount(int count);

  String workflowBlockedCount(int count);

  String get workflowScheduleFailedValidation;

  String get workflowReadyToConfirm;

  String get workflowWarningsBeforeConfirm;

  String get workflowCalendarCheckFailed;

  String get workflowNoValidatedPlan;

  String get workflowNoValidationResult;

  String get workflowItemsStillBlocked;

  String get workflowSyncPartialSuccess;

  String get workflowSyncSuccessful;

  String get workflowSyncFailed;

  String get startupTimeout;

  String startupFailed(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
