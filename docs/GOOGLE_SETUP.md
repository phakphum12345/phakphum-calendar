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

Feature scopes are registered in `lib/core/google/google_scopes.dart` and requested through the canonical `GoogleAuthGateway.clientFor` boundary:

| Integration operation | OAuth scope | When requested |
| --- | --- | --- |
| Read spreadsheet cells | `spreadsheets.readonly` | Spreadsheet import/read |
| Create or modify worksheets | `spreadsheets` | Only when a worksheet write is requested |
| Read Calendar events | `calendar.events.readonly` | Preview and comparison |
| Create, update or delete Calendar events | `calendar.events` | Only when Calendar sync/write is requested |
| Verify Calendar metadata | `calendar.readonly` | Calendar metadata gateway |
| List accessible spreadsheet files | `drive.metadata.readonly` | File picker and access check |
| Read arbitrary Drive files | `drive.readonly` | Only for workflows that read Drive file content |
| Employee directory in app-private storage | `drive.appdata` | Employee directory sync |
| Copy original workbook to archive | `drive` | Only when the user enables original-file archiving |
| Transfer Google Contacts | `contacts` | Optional Contacts import/export |

The broad `drive` and `spreadsheets` scopes are not part of basic sign-in. The app-private employee directory uses `drive.appdata`; it is not stored in a shared owner account.

## Gateway and account isolation

Production gateways are created from the signed-in account through `AppDependencies` and `GoogleAuthGateway.clientFor`. Each authorized gateway session records the account ID used to obtain its client and owns that client until the feature closes the session. A session is rejected if the active account changes while authorization is being obtained. Scoped HTTP clients request fresh authorization headers for each API request without opening a new consent prompt; a missing/revoked grant or account switch fails with a reconnect-required error.

The compatibility authentication service delegates to the same `GoogleAuthGateway`; it does not create a second `GoogleSignIn` lifecycle or request Calendar, Sheets, Drive or Contacts data scopes during identity sign-in. Existing legacy workflows also request their operation scopes through that same gateway.

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
