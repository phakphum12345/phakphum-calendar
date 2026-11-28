# End-to-End Acceptance Matrix

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


## 9. Universal roster import

- Detect date orientation independently for every table section; horizontal, vertical and mixed sections coexist.
- Preserve zero-based source coordinates, date-axis coordinates, assignment-axis coordinates and A1 provenance.
- Support multiple tables and departments per worksheet, partial/cross-month periods and Thai Buddhist Era/Gregorian date evidence.
- Never guess missing dates or silently choose between ambiguous orientations.
- Duplicate, missing, conflicting, unresolved and out-of-order dates block the affected section with source coordinates.
- Preview is read-only; date correction rebuilds from the retained source grid and revalidates the section.
- XLSX bytes pass through the actual Excel reader and Grid scanner; CSV/TSV/TXT and Google Sheets paths remain supported.
- Actual X-OPD November 2569, 16 Nov–15 Dec 2569 and US Clinic ภปร.4 workbooks pass without template-specific row/column constants.

## 10. Persistence and recovery

- Every production writer uses snapshot-bound atomic compare-and-set.
- Two writers with the same revision yield exactly one successful write.
- Journal startup discovery, idempotent recovery, corrupt-journal reporting and conditional delete/tombstone are verified.
- Stale clients cannot recreate a deleted schedule.
- Cross-device backend contention and local fallback semantics are tested separately.

## 11. Calendar Sync and shift transactions

- Durable scoped lease/ledger, expiry/reclaim and stale-token fencing pass multi-client tests.
- Insert/update/delete use stable identities and ETags; ambiguous provider outcomes reconcile before retry.
- Controlled Google test calendar verifies insert, update, delete and recovery.
- Approved canonical schedule and read-back verification precede external writes.
- ยกเวร / รับเวร / แลกเวร have durable transaction state, audit and idempotency.

## 12. Notifications

- Outbox worker claim/fencing, retry/backoff, dead-letter and delivery history are implemented.
- VAPID sender and RFC 8291 payload encryption are verified.
- Subscription ownership, opt-in/out, expiry cleanup and safe logging are tested.
- Successful delivery reaches a registered test device/browser.

## 13. Generation, Shift Pay and history restore

- Generation preview binds exact schedule, employee/catalog, rules and policy revisions; stale approval is invalidated.
- Commit reloads and validates exact revisions, uses conditional persistence and records provenance.
- Shift Pay uses confirmed assignments, one resolved rule source, exact decimal/rounding policy and immutable historical statements.
- History restore previews a diff, checks source revision, requires confirmation and commits conditionally with audit/recovery.

## 14. Organization, quality and release

- Backend authorization and tenant isolation pass cross-tenant negative tests.
- Responsive, keyboard, screen-reader and accessibility flows pass on supported devices and widths.
- Large-workbook, event-volume and history benchmarks record reproducible measurements.
- Fuzz/property tests cover malformed XLSX/API payloads and migration/backup/restore.
- Release evidence identifies exact deployment SHA, health/readiness, artifacts, rollback and restore drills.

