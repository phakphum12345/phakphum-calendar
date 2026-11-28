# Google Cloud and OAuth Setup

## Ownership model

Google OAuth is configured once by the application owner for the deployed app.
Ordinary users must never be asked to create, paste, or store an OAuth Client ID.

- The OAuth Client ID identifies this application; it is not the user's Google identity.
- Each user signs in with their own Google account and grants access to their own data.
- The application owner maintains the Google Cloud project, OAuth branding, platform clients, authorized origins and redirect URIs.
- Never use the owner's Google account as a shared data account or sync identity.

## Required APIs and least-privilege scopes

Enable only the APIs used by enabled features:

1. Google Calendar API
2. Google Sheets API
3. Google Drive API
4. Google People API only if Contacts transfer is enabled

Request scopes incrementally at the point of use. Do not request every optional scope during basic identity sign-in. Explain each permission before requesting it.

Existing feature scopes include:

```text
https://www.googleapis.com/auth/spreadsheets.readonly
https://www.googleapis.com/auth/calendar.events.readonly
https://www.googleapis.com/auth/calendar.events
https://www.googleapis.com/auth/drive.metadata.readonly
https://www.googleapis.com/auth/drive.readonly
https://www.googleapis.com/auth/drive.appdata
```

Contacts transfer, when enabled, additionally requires:

```text
https://www.googleapis.com/auth/contacts
```

## Platform OAuth clients

The application owner must register and configure the appropriate OAuth client for each supported target:

- Web: exact production and development JavaScript origins and redirect URIs.
- Android: package name and signing-certificate SHA fingerprints.
- iOS: bundle identifier, client ID and reversed-client-ID URL scheme.
- macOS: bundle identifier and the supported redirect configuration.
- Windows/Linux: do not advertise native Google sign-in until a supported installed-app OAuth flow, PKCE/state validation, redirect handling and secure token storage are implemented and tested.

Use build/deployment configuration for public client IDs, for example:

```bash
flutter build web \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_SERVER_CLIENT_ID
```

For native builds, provide the matching platform client IDs through the documented platform configuration. Client IDs are public identifiers. Never embed a client secret, refresh token, service-account key or private key in Flutter web/mobile artifacts.

## Consent publication and verification

The Google Cloud project owner must configure the app name, support email, developer contact, authorized domains, privacy policy, terms and exact requested scopes. An OAuth consent screen left in Testing is restricted to configured test users; it is not public-user readiness. Publish the intended audience and complete Google's verification process for sensitive/restricted scopes when required.

## User experience and security requirements

- The user sees a simple **Connect Google** action and connection status.
- The user never enters OAuth Client IDs, Client Secrets, access tokens or refresh tokens.
- Every user's Google authorization is scoped to that user's account.
- Sign-out, disconnect/revoke, denied consent, expired/revoked grants and re-consent must be handled.
- Do not log credentials or personal roster contents.
- Verify account isolation and the real API operations using a non-owner, non-tester Google account before declaring public readiness.

No real OAuth credentials are committed to this repository. Source-code changes cannot create or publish the owner's Google Cloud OAuth project; those external owner actions remain an explicit release gate.
