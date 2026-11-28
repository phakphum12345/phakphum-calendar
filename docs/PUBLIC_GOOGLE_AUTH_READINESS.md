# Public Google Authentication — Readiness and External Actions

- Status: not verified for general public users
- Existing architecture decision: `docs/adr/ADR-0005-google-authentication.md`
- Existing setup guide: `docs/GOOGLE_SETUP.md`

## 1. Important distinction

Google authentication has two separate responsibilities:

1. **Identity** — sign the user into the application and identify the account.
2. **Authorization** — obtain permission to call Google APIs such as Calendar, Drive, Sheets, and Contacts.

A user should not need to grant every optional data scope merely to sign in. Request API scopes only when the user starts the feature that needs them, and explain the purpose.

## 2. Current repository observations

- The user-facing OAuth Client ID entry flow has been removed from the app. The app expects application-owner build/deployment configuration; a missing client ID is an owner-side release configuration issue, not a task for ordinary users.
- The inspected iOS `Info.plist` contains placeholder OAuth client identifiers.
- The repository still contains two Google authentication service entry points (`GoogleAuthService` and `GoogleAuthenticationService`). Consolidation behind the accepted shared gateway contract remains required; this change does not claim that migration is complete.
- Windows/Linux native sign-in is not established in the current implementation.
- The accepted ADR requires platform adapters, one app-facing session model, incremental scopes, secure token storage, and no plugin-specific account types leaking into application services.
- A successful compile or a sign-in test using the project owner/tester account is insufficient evidence for public-user readiness.

## 3. Required implementation

- Consolidate sign-in/sign-out/current-user/session handling behind one contract.
- Keep basic identity sign-in separate from optional Calendar/Drive/Sheets/Contacts access.
- Use least-privilege scopes and incremental consent.
- Handle consent cancellation, denied scopes, revoked grants, token expiry, re-consent, offline/provider failures, and sign-out.
- Keep tokens and secrets out of logs, repository files, build artifacts, and insecure preferences.
- Use secure platform storage for long-lived credentials; fail safely if secure storage is unavailable.
- Configure and test each platform independently. Do not label an unsupported platform as Google-auth capable.
- Keep OAuth client configuration in application-owner build/deployment configuration. Do not expose a Client ID text field or browser-local Client ID persistence to end users.
- Maintain privacy disclosures and explain what data each optional permission enables.

## 4. Platform acceptance

| Platform | Required verification |
|---|---|
| Web / GitHub Pages | Exact production origin, redirect URI, popup/redirect lifecycle, refresh/re-consent, sign-out, and API scope consent |
| Android | Correct package name and signing certificate fingerprints, OAuth client configuration, native sign-in, refresh and sign-out |
| iOS | Correct bundle ID, URL scheme/reversed client ID, real client IDs (no placeholders), native sign-in, refresh and sign-out |
| Windows | A supported installed-app OAuth flow, PKCE/state validation, loopback or approved redirect handling, secure token storage |
| Linux | A supported installed-app OAuth flow, PKCE/state validation, redirect handling, secure token storage |
| macOS | Only claim support if the app target, OAuth client, redirect, secure storage, signing and real-device/user testing are complete |

For every claimed platform, test with an ordinary Google account that is neither the OAuth project owner nor a configured test user.

## 5. Google Cloud Console / owner actions

These tasks cannot be completed by committing Flutter source code:

- Confirm the owning Google Cloud project and verified application identity.
- Configure OAuth consent branding, app name, support email, developer contact, authorized domains, privacy policy, and terms URL as applicable.
- Configure the production OAuth audience and publish the consent app.
- Complete Google's verification process for sensitive/restricted scopes when required.
- Configure exact web origins/redirect URIs and native client identifiers.
- Enable only the Google APIs actually used.
- Confirm the final list of scopes and data-retention disclosures.
- Provide real public client IDs to deployment configuration (client IDs are identifiers; never provide client secrets to a public Flutter client).
- Keep any server-side client secret in an appropriate secret store, never in the repository or mobile/web bundle.

Do not invent client IDs or claim these steps have been completed without owner-provided console evidence.

## 6. Security and privacy gates

- Never commit client secrets, refresh tokens, access tokens, service-account keys, or signing credentials.
- Validate OAuth state and use PKCE for installed-app authorization-code flows.
- Request Calendar/Drive/Sheets/Contacts permissions only when needed.
- Provide a clear disconnect/revoke path and describe what local data remains after sign-out.
- Minimize logs and diagnostic data; never log tokens or roster contents.
- Verify cross-account isolation and that a user's roster data is not exposed to another signed-in user.

## 7. Public readiness acceptance

- Consent screen is published for the intended audience.
- Any required Google verification is complete.
- A non-owner, non-tester account can sign in on each platform advertised as supported.
- Optional scopes are requested only when needed and denial does not break basic identity sign-in.
- Refresh/re-consent, sign-out, revoked access, and failure recovery work.
- A real authorized request succeeds for every Google API feature advertised on that platform.
- Privacy and installation documentation matches the actual behavior.

Until all applicable gates pass, status remains **NOT PUBLICLY VERIFIED**.
