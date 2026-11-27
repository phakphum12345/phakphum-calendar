# End-to-End Acceptance Matrix

> This is the earlier acceptance catalogue for Shift Pay, Google authentication, platform installation and AI Assistant. The live cross-package completion state and current evidence are tracked in [project/ACCEPTANCE_MATRIX.md](project/ACCEPTANCE_MATRIX.md). Keep this document as a detailed domain scenario catalogue, not as the current overall completion status.

A feature is accepted only when its relevant tests pass on the exact code revision intended for release. A skipped, missing, cancelled, or unknown result is not a pass.

## 1. Shift-pay modes

| ID | Scenario | Expected result |
|---|---|---|
| PAY-001 | Personal user with no organization | Can create profile, shift types, rates, calculate, and view report |
| PAY-002 | Organization user with authorized role | Uses rules belonging only to selected organization |
| PAY-003 | User belongs to two organizations | Must select active organization; no cross-tenant rule leakage |
| PAY-004 | Hybrid, organization-first | Organization rule wins when both match; one amount only |
| PAY-005 | Hybrid, personal-first | Personal rule wins when both match; one amount only |
| PAY-006 | Hybrid, require-selection | Both matches trigger explicit source choice; no silent calculation |
| PAY-007 | Hybrid, only one source matches | The single matching source is selected and displayed |
| PAY-008 | No matching rule | Show not-configured state, not an assumed zero |
| PAY-009 | Included in salary | Show no additional shift pay as a distinct state |
| PAY-010 | Compensatory time | Show compensatory entitlement, not cash amount |
| PAY-011 | Invalid/conflicting rules | Block or request correction; never choose arbitrarily |
| PAY-012 | Unauthorized member edits organization rule | Denied at API/data layer and audited |

## 2. Rule and calculation behavior

- Fixed amount per shift.
- Hourly rate multiplied by actual payable hours.
- Explicit multiplier and base amount.
- Overnight shift crossing midnight.
- Break duration and paid/unpaid break treatment.
- Weekly day off, official holiday, festival/special day, and date overrides.
- Department, location, work point, and assignment-purpose scopes.
- Effective date boundaries and rule version changes.
- Currency precision and explicit rounding mode.
- Missing hours, invalid time range, and conflicting specificity.
- Planned/draft assignments excluded from actual totals.
- Confirmed/actual assignment included exactly once.
- Re-import, sync retry, duplicate event, and repeated report generation remain idempotent.

## 3. Persistence and historical integrity

- Encode/decode round-trip for all modes and rule fields.
- Migrate legacy shift-template data without loss.
- Existing saved templates remain unchanged unless user explicitly edits them.
- Invalid schema version fails safely with recovery guidance.
- Offline concurrent edits have deterministic conflict handling.
- Rule changes do not mutate prior calculation snapshots.
- Historical statement can be reproduced from its saved inputs and rule version.
- Backup/restore retains profile ownership and assignment linkage.

## 4. Monthly report

- Each actual assignment appears once.
- Every amount identifies source and rule version.
- Statement total equals the sum of eligible detail rows.
- Forecast, missing rule, included-in-salary, compensatory time, and zero amount are distinct.
- Filters by period/department/member do not alter underlying calculation.
- Export/print preserves currency, precision, and source details.
- User cannot view another user's personal report or an unauthorized organization's data.

## 5. Google authentication

- New ordinary non-tester account can sign in.
- OAuth consent cancellation returns safely to app.
- Basic identity sign-in works without optional API scopes.
- Calendar/Drive/Sheets scopes are requested only when feature starts.
- Denying an optional scope does not corrupt session.
- Token expiry, refresh, revoked consent, and re-consent work.
- Sign-out clears local session and follows provider revoke behavior where available.
- Wrong origin, redirect URI, bundle ID, package ID, or client ID produces actionable diagnostics.
- No secret or token is present in logs, source, or artifacts.
- One authorized API request succeeds for each feature advertised on each supported platform.

## 6. Platform installation

For every claimed supported platform:
- clean-machine/device installation succeeds;
- app launches without developer tools;
- first-run and account setup complete;
- data persists across restart;
- update/upgrade path works;
- uninstall/reinstall behavior is documented;
- artifact version and checksum are correct;
- platform-specific Google auth passes if advertised.

Specific:
- Android production signing and device installation.
- iOS signed distribution and real-device installation.
- Windows packaged dependencies and clean-machine smoke test.
- Linux dependencies and clean-machine smoke test.
- Web Pages deployment, exact deployed SHA, HTTP smoke test, PWA cache/update.
- macOS signed/notarized distribution only if included in support scope.

## 7. CI and PR governance

- Confirm PR base SHA and head SHA.
- Inspect all changed files and deletion count.
- Inspect review decisions and unresolved threads.
- Verify every required workflow/check on exact head SHA.
- Treat SKIPPED, UNKNOWN, cancelled, missing, or stale checks as not passing.
- Confirm mergeability and no unexpected base movement.
- Do not merge a Draft PR.
- Do not push directly to main.
- Do not deploy as part of verification unless explicitly authorized.

## 8. AI Assistant real-world readiness

- Offline/local help works without network and never fabricates a live provider response.
- Documentation-grounded answers identify the relevant versioned help source.
- A real configured provider works through the backend; fake-provider tests do not count as live proof.
- Provider secrets never appear in app bundles, source, logs, or API responses.
- Unauthenticated private requests are denied.
- Cross-user and cross-organization roster access is denied at the server boundary.
- Only explicitly selected and necessary roster fields are transmitted, with consent.
- Uncertain roster fields remain unresolved and display raw source evidence.
- AI output cannot mutate canonical roster, Google Sheets, or Google Calendar without explicit preview and confirmation.
- Existing calendar sync confirmation remains enforced.
- External research claims have valid retrieved sources; unavailable retrieval produces an honest unavailable state.
- Provider timeout, quota, revoked key, malformed output, and outage have safe actionable error states.
- Rate limits, request-size limits, concurrency limits, and prompt-injection defenses are tested.
- Conversation and report retention/deletion match the published privacy policy.
- A normal non-owner user completes the advertised AI journeys.
- Personal mode works without organization membership for the assistant capabilities it advertises.
- Every advertised platform passes install, auth, chat, and failure-state tests.
- Evidence records app version, environment, and exact deployed SHA.
- Core calendar/roster workflows remain usable without a paid AI provider.
