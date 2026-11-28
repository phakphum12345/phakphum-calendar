import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/google/google_scopes.dart';
import 'package:phakphum_calendar/services/google_auth_service.dart';

void main() {
  group('Google Web OAuth Client ID validation', () {
    test('accepts a Google OAuth web client ID', () {
      expect(
        GoogleAuthService.isValidWebClientId(
          '123456789012-abcdefghijklmnopqrstuvwxyz012345.apps.googleusercontent.com',
        ),
        isTrue,
      );
    });

    test('rejects the authorized JavaScript origin as a client ID', () {
      expect(
        GoogleAuthService.isValidWebClientId(
          'https://phakphum12345.github.io',
        ),
        isFalse,
      );
    });

    test('rejects a client secret in the client ID field', () {
      expect(
        GoogleAuthService.isValidWebClientId('GOCSPX-example-client-secret'),
        isFalse,
      );
    });
  });

  group('Google OAuth configuration ownership', () {
    test('does not expose end-user Web OAuth configuration', () {
      final service = GoogleAuthService();
      addTearDown(service.dispose);

      expect(service.canConfigureWebOAuth, isFalse);
    });
  });

  group('Google integration scope registry', () {
    test('keeps basic identity sign-in separate from API permissions', () {
      expect(
        GoogleScopes.rosterRead,
        contains(GoogleScopes.spreadsheetsReadOnly),
      );
      expect(GoogleScopes.rosterRead, contains(GoogleScopes.driveReadOnly));
      expect(
        GoogleScopes.rosterRead,
        contains(GoogleScopes.driveMetadataReadOnly),
      );
      expect(GoogleScopes.calendarRead, <String>[
        GoogleScopes.calendarEventsReadOnly,
      ]);
      expect(GoogleScopes.calendarMetadataRead, <String>[
        GoogleScopes.calendarReadOnly,
      ]);
      expect(GoogleScopes.driveFileDiscovery, <String>[
        GoogleScopes.driveMetadataReadOnly,
      ]);
      expect(GoogleScopes.spreadsheetRead, <String>[
        GoogleScopes.spreadsheetsReadOnly,
      ]);
      expect(GoogleScopes.spreadsheetWrite, <String>[
        GoogleScopes.spreadsheetsWrite,
      ]);
    });

    test('requests Calendar write permission only for a write workflow', () {
      expect(GoogleScopes.calendarWrite, <String>[
        GoogleScopes.calendarEvents,
      ]);
      expect(
        GoogleScopes.rosterRead,
        isNot(contains(GoogleScopes.calendarEvents)),
      );
      expect(
        GoogleScopes.calendarRead,
        isNot(contains(GoogleScopes.calendarEvents)),
      );
    });

    test('keeps Drive backup and Contacts transfer optional', () {
      expect(GoogleScopes.driveBackup, <String>[GoogleScopes.driveAppData]);
      expect(GoogleScopes.driveArchive, <String>[GoogleScopes.driveFullAccess]);
      expect(
        GoogleScopes.employeeDirectory,
        <String>[GoogleScopes.driveAppData],
      );
      expect(GoogleScopes.contactTransfer, <String>[GoogleScopes.contacts]);
      expect(
        GoogleScopes.rosterRead,
        isNot(contains(GoogleScopes.driveAppData)),
      );
      expect(GoogleScopes.rosterRead, isNot(contains(GoogleScopes.contacts)));
    });

    test('legacy read access remains compatible with existing workflows', () {
      expect(
        GoogleAuthService.readAccessScopes,
        containsAll(<String>[
          ...GoogleScopes.rosterRead,
          ...GoogleScopes.calendarRead,
        ]),
      );
    });
  });
}
