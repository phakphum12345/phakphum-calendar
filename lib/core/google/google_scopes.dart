/// Canonical OAuth scopes used by every Google integration in the app.
///
/// Identity sign-in intentionally requests no data API scopes. Features request
/// only the scopes they need through the shared Google authorization gateway.
abstract final class GoogleScopes {
  static const String calendarEventsReadOnly =
      'https://www.googleapis.com/auth/calendar.events.readonly';
  static const String calendarEvents =
      'https://www.googleapis.com/auth/calendar.events';

  static const String driveMetadataReadOnly =
      'https://www.googleapis.com/auth/drive.metadata.readonly';
  static const String driveReadOnly =
      'https://www.googleapis.com/auth/drive.readonly';
  static const String driveAppData =
      'https://www.googleapis.com/auth/drive.appdata';

  static const String spreadsheetsReadOnly =
      'https://www.googleapis.com/auth/spreadsheets.readonly';

  static const String contacts = 'https://www.googleapis.com/auth/contacts';

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

  /// Write access is requested only when the user starts a Calendar sync.
  static const List<String> calendarWrite = <String>[
    calendarEvents,
  ];

  /// Optional app-private Drive storage; not required for ordinary sign-in.
  static const List<String> driveBackup = <String>[
    driveAppData,
  ];

  /// Optional contact transfer; not required for roster or calendar features.
  static const List<String> contactTransfer = <String>[
    contacts,
  ];
}
