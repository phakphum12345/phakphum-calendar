import 'package:flutter_test/flutter_test.dart';
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
}
