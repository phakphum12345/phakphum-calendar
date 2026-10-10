abstract final class GoogleScopes {
  static const String driveReadOnly =
      'https://www.googleapis.com/auth/drive.readonly';

  static const String driveAppData =
      'https://www.googleapis.com/auth/drive.appdata';

  static const String contacts = 'https://www.googleapis.com/auth/contacts';

  static const String spreadsheetsReadOnly =
      'https://www.googleapis.com/auth/spreadsheets.readonly';

  static const String calendarEvents =
      'https://www.googleapis.com/auth/calendar.events';

  static const List<String> required = <String>[
    driveReadOnly,
    spreadsheetsReadOnly,
    calendarEvents,
  ];
}
