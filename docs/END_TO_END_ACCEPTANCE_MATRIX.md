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

| ID | Scenario | Expected result |
|---|---|---|
| ROSTER-001 | Horizontal dates across columns | Dates resolve before worker assignment |
| ROSTER-002 | Vertical dates down rows | Date axis is detected per section |
| ROSTER-003 | Mixed orientation in one worksheet | Each section is interpreted independently |
| ROSTER-004 | Multiple tables/departments in one worksheet | Sections remain isolated with source coordinates |
| ROSTER-005 | Merged/multi-level headers and spacer rows | Header provenance is retained; no worker row is consumed as a header |
| ROSTER-006 | Thai Buddhist Era and Gregorian dates | Calendar dates normalize correctly without changing displayed source values |
| ROSTER-007 | Partial month/cross-month/cross-year ranges | Only evidenced dates are assigned; ambiguous dates are not guessed |
| ROSTER-008 | Duplicate/missing/out-of-order dates | Precise blocking diagnostics identify source section/cell |
| ROSTER-009 | Ambiguous employee alias or shift label | Requires reviewer resolution; no silent assignment |
| ROSTER-010 | CSV/TSV/TXT with BOM and non-ASCII text | Same review/provenance pipeline as workbook import |
| ROSTER-011 | Re-import of same source fingerprint | Duplicate is detected; no duplicate assignments |
| ROSTER-012 | Partial import | Independently valid sections can be reviewed/imported without accepting invalid sections |
| ROSTER-013 | Real X-OPD November 2569, 16 Nov–15 Dec 2569 and US Clinic ภปร.4 files | Acceptance is recorded only after the original files are tested; synthetic fixtures do not substitute |

## 10. Schedule persistence, CAS and recovery

| ID | Scenario | Expected result |
|---|---|---|
| PERSIST-001 | Two writers use the same expected revision | Exactly one conditional write succeeds |
| PERSIST-002 | Stale editor/import writes after a newer revision | Typed conflict; no automatic retry using the newer revision |
| PERSIST-003 | Two processes/devices write concurrently | Backend transaction/CAS prevents lost update |
| PERSIST-004 | Crash between PREPARED and COMMITTED journal stages | Startup discovery and idempotent recovery |
| PERSIST-005 | Corrupt or unavailable journal storage | Explicit failure; never treat lookup failure as an empty journal |
| PERSIST-006 | Conditional delete/tombstone | Stale clients cannot recreate deleted data |
| PERSIST-007 | Recovery after restart | Only the exact reviewed assessment can be replayed |
| PERSIST-008 | Unrelated schedules have pending journals | Recovery is isolated by schedule |

## 11. Google Calendar synchronization and shift transactions

- Insert/update/delete use stable event identity and ETag preconditions.
- Lease scope, expiry, reclaim and stale-token fencing are verified across processes/devices.
- Ambiguous provider timeout is reconciled before retry; no duplicate event is created.
- Partial success is recorded per event and safely resumable after restart.
- Calendar preview identifies exact target calendar and proposed event changes.
- Explicit confirmation is required before external calendar writes.
- Give-up, receive and exchange transactions have durable state, audit, idempotency and conflict handling.
- Calendar event mutation alone never marks a shift transaction fulfilled.
- Tests use a controlled calendar; real user calendars are not mutated by automated tests.

## 12. Notifications and Web Push

- Subscription ownership is authenticated and endpoint replacement/deletion is safe.
- VAPID signature and RFC 8291 payload encryption are verified.
- Concurrent workers cannot claim the same delivery.
- Retry/backoff, dead-letter and delivery-attempt history are observable.
- Expired subscriptions are cleaned without leaking endpoint secrets.
- Permission denied, opt-out, app restart and timezone boundaries behave safely.
- A registered real browser/device receives the expected notification before delivery is accepted.
- Notification payloads/logs do not expose roster details or credentials.

## 13. Schedule generation approval and commit

- Preview binds Run ID, input Schedule revision, employee/catalog revisions, policy version and candidate fingerprint.
- Preview does not mutate canonical storage.
- Conflicts and uncovered staffing requirements are visible.
- Any source/policy change invalidates the old approval.
- Commit reloads and revalidates the exact preview before CAS write.
- Read-back verifies the committed result; crash recovery is idempotent.
- Calendar sync remains a separate action.

## 14. Historical revision restore

- Revision list is read-only and identifies the exact source revision.
- Preview binds source revision ID, snapshot content and target Schedule revision.
- Before/after assignment-level diff is visible before confirmation.
- User explicitly confirms the exact preview immediately before commit.
- Stale target revision is rejected; restore uses conditional Schedule commit and durable provenance.
- Drive source remains read-only; no Drive write scope is added for local Schedule restore.
- Real Drive revision export and non-owner account acceptance are required before production acceptance.

## 15. Organization, security and privacy

- Cross-organization reads/writes are denied at the API boundary.
- Owner/Admin actions are authorized server-side.
- Membership approval/removal/reactivation and role changes are audited.
- Pagination and stale-response handling cannot leak records across tenants.
- Tokens/secrets are never logged or exposed to clients.
- Rate limiting, payload-size limits, session expiry and revoked credentials are tested.

## 16. Performance and accessibility

- Large workbook parse time and peak memory are measured with reproducible fixtures.
- Large event volumes and long history timelines have benchmark baselines.
- Phone/tablet/desktop critical flows have responsive regression tests.
- Keyboard navigation and screen-reader labels are verified for import review, calendar, generation and Shift Pay.
- Malformed XLSX and API payloads have fuzz/property tests with bounded resource use.

## 17. Release and deployment

- Required workflows complete on exact PR head and exact post-merge main SHA.
- Independent review and unresolved-thread checks are complete.
- Main branch protection and required status checks are enforced.
- Backend migration, backup/restore and rollback are rehearsed.
- Production API health/readiness and deployed source SHA are verified.
- Platform release artifact is installed on a clean target device/machine.
- No skipped, cancelled, missing or unknown check is counted as PASS.

