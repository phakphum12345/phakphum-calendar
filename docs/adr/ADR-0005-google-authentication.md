# ADR-0005: Unified Google authentication and authorization

- Status: Accepted; cross-platform adapter migration in progress
- Date: 2026-07-22
- Updated: 2026-10-31

## Context

SCE needs one consistent Google account experience across Web and installed
Flutter applications. The same signed-in identity must be usable by the existing
Sheets, Drive, and Calendar workflows without duplicating application-level
authentication state or changing roster data.

The current implementation exposes `GoogleSignInAccount` from the
`GoogleAuthGateway`, and another authentication service also depends directly
on `GoogleSignInAccount`. This couples API authorization to one plugin and
prevents a platform-specific OAuth implementation from being substituted safely.

## Decision

Keep one application-facing authentication and authorization contract, with
platform-specific adapters behind it.

- Web uses the supported Google web sign-in flow and its browser authorization
  lifecycle.
- Android and iOS use their supported native Google sign-in flows.
- Desktop targets use a compatible installed-app OAuth flow only after its
  redirect, token lifecycle, and secure-storage behavior are implemented and
  verified for that target.
- The platform adapter is selected internally. The user-facing account state,
  sign-in/sign-out actions, scope requests, and API-client contract remain
  consistent.
- Authentication (who the user is) remains separate from authorization (which
  Google API scopes have been granted).
- Sheets, Drive, and Calendar consumers receive an authorized HTTP/API client
  through the shared contract; consumers must not depend on a plugin-specific
  account class.
- Request scopes at the point of use where practical. Preserve least-privilege
  access and existing read/write boundaries.

## Security requirements

- OAuth client IDs are public configuration; client secrets must never be
  embedded in the Flutter application, committed, or requested from users.
- Installed-app OAuth must use Authorization Code with PKCE and validate
  redirect state before exchanging an authorization code.
- Refresh tokens and other long-lived credentials must use platform-appropriate
  secure storage. Do not fall back to plaintext preferences or local files when
  secure storage is unavailable.
- Sign-out must clear the local credential/session state and revoke credentials
  where the provider flow supports it.
- Never log authorization codes, access tokens, refresh tokens, or secret values.

## Compatibility and rollout

- Preserve the existing Web and mobile sign-in behavior while introducing the
  shared contract.
- Migrate both existing authentication entry points to the same contract; do
  not maintain two independent signed-in identities.
- Keep existing Sheets, Drive, Calendar, import, and roster workflows wired to
  the shared authorized-client abstraction.
- A target is not considered supported merely because it compiles. Its sign-in,
  consent, token refresh, sign-out, secure-storage failure path, and at least
  one authorized request for each enabled Google API must be verified.
- Do not change roster data, sync semantics, or production defaults as part of
  the authentication migration.
- Do not merge until automated checks pass and platform-specific OAuth smoke
  tests have documented evidence.

## Consequences

- The application has one account/session model while retaining platform-native
  OAuth mechanics.
- Web authorization expiry and interactive re-consent must be handled without
  crashing the application.
- Platform-specific OAuth configuration and secure-storage prerequisites must
  be documented separately from the shared application contract.
- Windows and Linux remain unverified until their complete installed-app flows
  pass the rollout checks above.
