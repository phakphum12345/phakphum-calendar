# Google Integration — Function-Level Acceptance Matrix

- Baseline: `main` at `9aed0905e731efdf0c02b07bddffcd04f2f056b0` (2026-11-28).
- Scope: Google identity, incremental authorization, Calendar, Drive, Sheets, Contacts, employee-directory storage and backend identity handoff.
- Purpose: track every user-visible operation independently. A gateway class, successful compile, unit test, or green CI does not prove that a user journey works against Google.
- Status vocabulary:
  - `NOT_AUDITED`: implementation and behavior have not yet been traced end to end.
  - `IMPLEMENTED_UNVERIFIED`: source path exists, but acceptance evidence is incomplete.
  - `BLOCKED_EXTERNAL`: code may be ready, but Google Cloud, backend, platform or test-account setup is missing.
  - `IN_PROGRESS`: actively being implemented or tested.
  - `PASS_CODE`: deterministic automated code tests pass for the exact revision.
  - `PASS_LIVE`: controlled real-provider acceptance passed with recorded evidence.
  - `BLOCKED`: reproducible defect or missing prerequisite.
- Initial status is deliberately conservative. Existing source files are evidence of source presence only, not of complete behavior.

## 1. Identity and account lifecycle

| ID | Function / user outcome | Required acceptance | Initial status |
|---|---|---|---|
| AUTH-01 | Initialize Google sign-in once | Idempotent initialization; no duplicate listeners or competing sign-in lifecycles | NOT_AUDITED |
| AUTH-02 | Connect Google account | Supported-platform flow completes and returns the selected account | IMPLEMENTED_UNVERIFIED |
| AUTH-03 | Restore previous session | Relaunch restores only the expected account; signed-out state stays signed out | NOT_AUDITED |
| AUTH-04 | Show connected account | UI displays correct email/account and connection state without exposing credentials | NOT_AUDITED |
| AUTH-05 | Switch Google account | Old account's clients/data context are closed; new account is used for all subsequent requests | NOT_AUDITED |
| AUTH-06 | Sign out | Local session ends, listeners/clients are released, and app state is cleared safely | NOT_AUDITED |
| AUTH-07 | Disconnect / revoke grant | Provider grant is revoked where supported; app handles already-revoked grants | IMPLEMENTED_UNVERIFIED |
| AUTH-08 | Handle user cancellation | Cancellation is not reported as success or as an unexplained fatal error | NOT_AUDITED |
| AUTH-09 | Handle unsupported platform | Clear capability message; no false promise of native Google sign-in | IMPLEMENTED_UNVERIFIED |
| AUTH-10 | Handle initialization/provider failure | Retry path, safe error state and no stuck loading indicator | NOT_AUDITED |

## 2. Incremental authorization and token lifecycle

| ID | Function / user outcome | Required acceptance | Initial status |
|---|---|---|---|
| SCOPE-01 | Basic identity without data scopes | Sign-in does not request Calendar/Drive/Sheets/Contacts scopes | NOT_AUDITED |
| SCOPE-02 | Request Calendar read permission | Requested only when preview/comparison starts; denial leaves unrelated features usable | PASS_CODE |
| SCOPE-03 | Request Calendar write permission | Requested only for confirmed sync/write operation | PASS_CODE |
| SCOPE-04 | Request Drive discovery permission | Least-privilege metadata access; no broad Drive access by default | NOT_AUDITED |
| SCOPE-05 | Request Sheets read permission | Read-only permission is sufficient for import/preview | NOT_AUDITED |
| SCOPE-06 | Request Sheets write permission | Write permission requested only for a user-selected write action | NOT_AUDITED |
| SCOPE-07 | Request app-private Drive permission | Uses the signed-in user's appDataFolder, isolated per account | NOT_AUDITED |
| SCOPE-08 | Request Contacts permission | Optional, feature-triggered and never required for sign-in | NOT_AUDITED |
| TOKEN-01 | Refresh authorization before API call | Valid current credentials are attached without prompting on every request | NOT_AUDITED |
| TOKEN-02 | Expired access token | Refresh succeeds or produces a clear reconnect-required state | NOT_AUDITED |
| TOKEN-03 | Revoked/denied scope | API call fails safely; user can grant again without corrupting local data | NOT_AUDITED |
| TOKEN-04 | Account changes during operation | Old account's session is rejected; no cross-account request is sent | NOT_AUDITED |
| TOKEN-05 | Close authorized session/client | Close is idempotent; no leaked HTTP clients or stale credentials | PASS_CODE |
| TOKEN-06 | Secure credential handling | No token/secret in logs, source, web/mobile bundle or ordinary preferences | NOT_AUDITED |

## 3. Google Calendar operations

| ID | Function / user outcome | Required acceptance | Initial status |
|---|---|---|---|
| CAL-01 | Verify Calendar access | Uses current account and read scope; handles empty/inaccessible primary calendar | IMPLEMENTED_UNVERIFIED |
| CAL-02 | Read calendar list / select target | User can select intended calendar; pagination and permission errors are handled | NOT_AUDITED |
| CAL-03 | Read existing events | Date range, timezone, pagination and event identity are correct | NOT_AUDITED |
| CAL-04 | Preview proposed changes | Preview exactly matches operations that would be submitted; no writes occur | IN_PROGRESS |
| CAL-05 | Create events | Writes only after explicit confirmation; stable managed identity prevents duplicates | IN_PROGRESS |
| CAL-06 | Update managed events | ETag/precondition and ownership markers prevent overwriting unrelated events | NOT_AUDITED |
| CAL-07 | Delete managed events | Only app-managed selected events can be deleted; confirmation and preconditions required | NOT_AUDITED |
| CAL-08 | Retry and ambiguous insert recovery | Reconcile provider state before retry; no duplicate events | NOT_AUDITED |
| CAL-09 | Multi-calendar / account isolation | Operations remain within selected account and calendar | NOT_AUDITED |
| CAL-10 | Timezone and all-day event handling | DST, local timezone, all-day and cross-midnight shifts remain correct | NOT_AUDITED |

## 4. Google Drive operations

| ID | Function / user outcome | Required acceptance | Initial status |
|---|---|---|---|
| DRIVE-01 | Discover spreadsheet files | Lists only eligible non-trashed spreadsheets with paging | IMPLEMENTED_UNVERIFIED |
| DRIVE-02 | Search/select a file | Selection is stable and bound to the current Google account | NOT_AUDITED |
| DRIVE-03 | Read file metadata | Handles missing fields, deleted files and access denied | NOT_AUDITED |
| DRIVE-04 | Read app-private directory | Uses current user's appDataFolder; never a shared owner account | NOT_AUDITED |
| DRIVE-05 | Save app-private data | Idempotent create/update, versioning and conflict behavior are verified | NOT_AUDITED |
| DRIVE-06 | Backup/archive original workbook | Only runs when explicitly selected; no accidental source mutation | NOT_AUDITED |
| DRIVE-07 | Restore Drive revision | Preview, validation, confirmation and audit before local restore | NOT_AUDITED |
| DRIVE-08 | Handle paging/quota/network failure | Retry/backoff and user-visible recovery without data loss | NOT_AUDITED |

## 5. Google Sheets operations

| ID | Function / user outcome | Required acceptance | Initial status |
|---|---|---|---|
| SHEET-01 | Read spreadsheet metadata | Correct spreadsheet identity, locale, timezone and worksheet metadata | IMPLEMENTED_UNVERIFIED |
| SHEET-02 | Read worksheet grid | Values, formulas, formatting, merges and source coordinates are preserved | IMPLEMENTED_UNVERIFIED |
| SHEET-03 | Read selected range | A1/range parsing, bounds, empty cells and large ranges are correct | NOT_AUDITED |
| SHEET-04 | Import roster | Original source, provenance, date axis and reviewer corrections are retained | NOT_AUDITED |
| SHEET-05 | Preview edits | Diff is accurate and does not mutate Google Sheets | NOT_AUDITED |
| SHEET-06 | Write worksheet values | Writes only to selected target/range after confirmation | NOT_AUDITED |
| SHEET-07 | Handle concurrent edits | Detects source revision changes; never silently overwrites newer edits | NOT_AUDITED |
| SHEET-08 | Handle quota/partial response | Bounded retry and actionable error; no duplicate or partial silent commit | NOT_AUDITED |

## 6. Contacts operations (optional capability)

| ID | Function / user outcome | Required acceptance | Initial status |
|---|---|---|---|
| CONTACT-01 | Explain and request Contacts access | Permission is optional and requested only when user starts transfer | NOT_AUDITED |
| CONTACT-02 | Read/import contacts | User sees scope and destination; duplicates and partial failures are handled | NOT_AUDITED |
| CONTACT-03 | Export/update contacts | Explicit preview/confirmation; no unintended contact overwrite | NOT_AUDITED |
| CONTACT-04 | Disconnect Contacts access | Contacts feature stops cleanly without breaking identity or Calendar | NOT_AUDITED |

## 7. Employee directory and backend identity

| ID | Function / user outcome | Required acceptance | Initial status |
|---|---|---|---|
| EMP-01 | Load employee directory | Loads only the signed-in user's or authorized organization's data | NOT_AUDITED |
| EMP-02 | Save employee directory | Durable save, versioning and recovery; no cross-account leakage | NOT_AUDITED |
| EMP-03 | Sync across devices | Conflict detection and account isolation are verified | NOT_AUDITED |
| BACKEND-01 | Obtain backend identity token | Token audience/issuer/expiry are validated server-side | NOT_AUDITED |
| BACKEND-02 | Send authenticated API request | Same signed-in identity is used; token never appears in logs | NOT_AUDITED |
| BACKEND-03 | Handle backend unavailable/unauthorized | Local-first behavior is explicit; no false sync-success state | NOT_AUDITED |
| BACKEND-04 | Enforce tenant/account isolation | Negative cross-user and cross-organization tests deny access | NOT_AUDITED |

## 8. UX, observability and recovery

| ID | Function / user outcome | Required acceptance | Initial status |
|---|---|---|---|
| UX-01 | Connect/disconnect entry point | Simple action; user never enters OAuth Client ID or secret | IMPLEMENTED_UNVERIFIED |
| UX-02 | Permission explanation | Names the data and purpose before consent | NOT_AUDITED |
| UX-03 | Loading/progress state | Every async operation has bounded progress and cannot spin forever | NOT_AUDITED |
| UX-04 | Success/failure state | Success only after provider read-back or durable local commit as appropriate | NOT_AUDITED |
| UX-05 | Retry/reconnect action | Retry does not duplicate writes or discard local changes | NOT_AUDITED |
| UX-06 | Sync history | Shows operation, account, time, outcome and safe diagnostic details | NOT_AUDITED |
| UX-07 | Privacy-safe diagnostics | Redacts tokens, personal roster content and sensitive provider responses | NOT_AUDITED |

## 9. Cross-cutting acceptance scenarios

- [ ] Fresh install → connect a non-owner/non-tester Google account → sign out → reconnect.
- [ ] Account A connects, starts a request, switches to account B; verify no request completes under the wrong identity.
- [ ] Deny one optional scope; verify unrelated app features remain usable.
- [ ] Expire/revoke a grant during a request; verify safe failure and reconnect.
- [ ] Disable network / simulate timeout / rate limit; verify bounded retry and no duplicate write.
- [ ] Run concurrent clients against the same data; verify conflict detection and preservation.
- [ ] Verify all Google writes require the correct preview/confirmation gate.
- [ ] Verify no provider operation mutates unselected files, calendars, sheets or contacts.
- [ ] Verify token and personal data redaction in app, backend and CI logs.
- [ ] Repeat on every platform claimed as supported; do not infer platform support from another platform's result.

## 10. Evidence required to close a function

For each ID, attach:
1. Source path and relevant implementation entry point.
2. Unit/widget/integration test path and exact test name.
3. Exact PR head SHA and required CI results.
4. Controlled provider test result where applicable (provider, platform, account class, operation and sanitized outcome).
5. Failure/recovery evidence and data-preservation result.
6. User-facing documentation or UI evidence.

A function may be marked `PASS_CODE` only after code tests pass on the exact revision. Provider-dependent functions require `PASS_LIVE` before public-use readiness. No aggregate percentage may hide blocked or untested functions.

## 11. Current known blockers / boundaries

- PR #221 is merged into the baseline above and provides the canonical scope registry.
- PR #222 (gateway wiring) was merged as `9aed0905e731efdf0c02b07bddffcd04f2f056b0` after all 12 exact-head CI workflows succeeded. This establishes code-level gateway wiring only; real-provider acceptance remains open.
- The duplicate `GoogleAuthenticationService` lifecycle was replaced with a compatibility adapter over the canonical `GoogleAuthGateway` in PR #222. AUTH-01 and SCOPE-01 remain unverified until dedicated lifecycle and scope-prompt tests prove the behavior end to end.
- Real OAuth client IDs, consent publication/verification, exact platform redirects, backend configuration and non-owner/non-tester account acceptance are external release gates.
- This matrix covers Google integration only. Calendar sync, roster import, shift transactions, shift pay, AI, notifications, organization administration and platform release retain their own acceptance plans.

## 12. Evidence update after PR #222

PR #222 merged as `9aed0905e731efdf0c02b07bddffcd04f2f056b0`. Its exact pre-merge head passed all 12 CI workflows. The following are code-level evidence only:

| Function IDs | Current evidence | Status | Source / test |
|---|---|---|---|
| AUTH-01, AUTH-07 | Canonical auth gateway owns the Google sign-in lifecycle; compatibility adapter delegates instead of initializing a second lifecycle. Disconnect/revoke path is exposed. | IMPLEMENTED_UNVERIFIED | `lib/services/google_auth_service.dart`, `lib/features/authentication/infrastructure/google_authentication_service.dart` |
| SCOPE-01–SCOPE-08 | Feature-specific scope groups exist and legacy call sites were migrated. Tests verify group membership and separation of optional/write scopes, but not actual consent prompts and denial recovery. | IMPLEMENTED_UNVERIFIED | `lib/core/google/google_scopes.dart`; `test/google_auth_service_test.dart` |
| TOKEN-01 | Per-request header provider is invoked for each HTTP request and the test observes a changed bearer token between requests. This does not prove real Google token refresh. | PASS_CODE | `test/google_api_client_test.dart` — “refreshes authorization headers for each request” |
| TOKEN-05 | Authorized gateway session closes its owned HTTP client once even when close is called repeatedly. | PASS_CODE | `test/authorized_google_gateway_session_test.dart` — “authorized gateway session closes its client exactly once” |
| EMP-01, BACKEND-01 | Account-scoped gateway factories reject creation without an active Google account; backend identity token access is exposed through the canonical gateway. Server-side audience/issuer/tenant validation is not established by these client tests. | IMPLEMENTED_UNVERIFIED | `lib/core/di/app_dependencies.dart`; `test/app_dependencies_test.dart` — “Google integration gateways require the active Google account” |

No function is marked `PASS_LIVE`: the repository run did not authenticate against a controlled non-owner Google account or verify real provider-side effects. The post-merge main Final Gate is also tracked separately from the successful PR-head CI.

## 13. Execution order

1. PR #222 gateway wiring is merged; verify its post-merge main CI and preserve the real-provider release boundary.
2. Consolidate identity/session lifecycle and incremental scope authorization; close AUTH and SCOPE/TOKEN tests.
3. Complete Calendar read/preview/write/recovery operations.
4. Complete Drive and Sheets discovery/read/write/backup/restore operations.
5. Complete employee directory and backend identity/tenant isolation.
6. Implement and test optional Contacts transfer only if the product continues to expose it.
7. Complete UI states, diagnostics, platform acceptance and controlled non-owner provider tests.
8. Update this matrix with evidence links and actual status; never infer completion from PR merge alone.


## 13. Current implementation evidence — 2026-11-28

Main baseline observed after PR #225 merge: `953e5d00b85d281566ed8bc98453727cc9112ec3`.

The following functions have moved from an unaudited state into active implementation and code-level verification. These are not PASS claims:

| Function IDs | Current implementation / regression evidence | Status |
|---|---|---|
| SCOPE-02 | PR #225 merged as `953e5d00b85d281566ed8bc98453727cc9112ec3`; its exact-head tests and all 12 workflows passed. `test/google_scope_routing_client_test.dart` covers preview reads and denied write consent. | IN_PROGRESS |
| SCOPE-03 | PR #225 requests the Calendar write scope only for POST/PUT/PATCH/DELETE after the caller's explicit confirmation flow. Denied authorization fails before the mutation request is sent; exact-head tests and all 12 workflows passed. | IN_PROGRESS |
| TOKEN-05 | PR #225 caches account-bound clients by scope set and closes owned clients; retry-after-denial and close tests passed on the exact merged head. | IN_PROGRESS |
| CAL-04 / CAL-05 | PR #226 compares the prepared Calendar preview Schedule snapshot with the current effective Schedule immediately before archive/provider writes. Its regression test asserts that a stale preview produces zero Calendar inserts. Remaining exact-head platform checks are still running. | IN_PROGRESS |

Related work:
- [#225 — incremental Calendar authorization](https://github.com/phakphum12345/phakphum-calendar/pull/225) — merged
- [#226 — stale Schedule preview write guard](https://github.com/phakphum12345/phakphum-calendar/pull/226) — open

No live Google provider test has been performed. `PASS_CODE` records deterministic tests and exact-head CI only; these functions remain short of `PASS_LIVE` until controlled provider acceptance is recorded. Preview freshness must also cover any transaction/projection changes that can alter the effective Calendar payload, not only raw Schedule fields.
