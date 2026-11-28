/// Canonical OAuth scopes used by every Google integration in the app.
///
/// Identity sign-in intentionally requests no data API scopes. Features request
/// only the scopes they need through the shared Google authorization gateway.
abstract final class GoogleScopes {
  static const String calendarEventsReadOnly =
      'https://www.googleapis.com/auth/calendar.events.readonly';
  static const String calendarEvents =
      'https://www.googleapis.com/auth/calendar.events';
  static const String calendarReadOnly =
      'https://www.googleapis.com/auth/calendar.readonly';

  static const String driveMetadataReadOnly =
      'https://www.googleapis.com/auth/drive.metadata.readonly';
  static const String driveReadOnly =
      'https://www.googleapis.com/auth/drive.readonly';
  static const String driveAppData =
      'https://www.googleapis.com/auth/drive.appdata';
  static const String driveFullAccess =
      'https://www.googleapis.com/auth/drive';

  static const String spreadsheetsReadOnly =
      'https://www.googleapis.com/auth/spreadsheets.readonly';
  static const String spreadsheetsWrite =
      'https://www.googleapis.com/auth/spreadsheets';

  static const String contacts = 'https://www.googleapis.com/auth/contacts';

  /// Compatibility scope list for the not-yet-migrated authentication adapter.
  ///
  /// New code must use feature-specific lists and must not request this list
  /// during basic identity sign-in.
  @Deprecated('Use the feature-specific scope lists instead.')
  static const List<String> required = <String>[
    driveReadOnly,
    spreadsheetsReadOnly,
    calendarEvents,
  ];

  /// Read access required by the existing roster import and review workflows.
  static const List<String> rosterRead = <String>[
    spreadsheetsReadOnly,
    driveMetadataReadOnly,
    driveReadOnly,
  ];

  /// Read-only Calendar access for preview and comparison workflows.
  static const List<String> calendarRead = <String>[
    calendarEventsReadOnly,
  ];

  /// Calendar metadata verification; separate from event read/write access.
  static const List<String> calendarMetadataRead = <String>[
    calendarReadOnly,
  ];

  /// Write access is requested only when the user starts a Calendar sync.
  static const List<String> calendarWrite = <String>[
    calendarEvents,
  ];

  /// Optional app-private Drive storage; not required for ordinary sign-in.
  /// Full Drive access is needed only to copy an original workbook to archive.
  static const List<String> driveBackup = <String>[
    driveAppData,
  ];

  /// Full Drive access is needed only to copy an original workbook to archive.
  static const List<String> driveArchive = <String>[
    driveFullAccess,
  ];

  /// App-private employee directory storage; does not expose the user's Drive.
  static const List<String> employeeDirectory = <String>[
    driveAppData,
  ];

  /// Metadata-only access for listing and checking accessible spreadsheets.
  static const List<String> driveFileDiscovery = <String>[
    driveMetadataReadOnly,
  ];

  /// Read-only access to spreadsheet cell data.
  static const List<String> spreadsheetRead = <String>[
    spreadsheetsReadOnly,
  ];

  /// Write access for creating or modifying worksheets.
  static const List<String> spreadsheetWrite = <String>[
    spreadsheetsWrite,
  ];

  /// Optional contact transfer; not required for roster or calendar features.
  static const List<String> contactTransfer = <String>[
    contacts,
  ];
}
