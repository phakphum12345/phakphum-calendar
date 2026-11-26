# End-to-End Completion Plan — Roster, Calendar Sync and Data Integrity

**Prepared:** 2026-11-26  
**Baseline:** `main@c6ad63a5f9e7925dc1848deccb37bbba53768069`  
**Status:** Execution plan; not a completion claim  
**Owner workflow:** inspect → specify → implement → test exact SHA → review → merge with authorization → verify main

## 1. Completion objective

Deliver one dependable workflow from source acquisition through roster validation, persistence, Calendar preview, explicitly confirmed synchronization, verification, retry and recovery. Reuse the existing parser, roster, Schedule, generator, Calendar gateway, Timeline and audit boundaries. Do not create a parallel roster or sync subsystem.

A release is complete only when the exact production path is reachable in the UI, data-integrity and provider behaviors are proven by tests, operational configuration is documented, and post-merge evidence is green. A passing unit test or a design document alone is not completion.

## 2. Verified baseline and open work

### 2.1 Repository state

- PR #194 (multi-source roster ingestion roadmap) is merged.
- Its post-merge commit `c6ad63a5f9e7925dc1848deccb37bbba53768069` has 7/7 post-merge checks completed successfully.
- PR #193 (Xcode runner queue coalescing) was merged into main as d18454680879a10c6efe9e44ffb37cd0695f25a6 on 2026-11-26. The exact main commit has 15/15 checks completed successfully. PR #192 still overlaps the iOS/macOS workflow files and must be reviewed against this merged baseline.
- PR #192 (Grid import, Schedule API and recovery foundations) remains Draft at head 12e9245ba3c7df89428de48f6e73b2106a525973, based on current main d18454680879a10c6efe9e44ffb37cd0695f25a6. Its latest exact-head run has multiple failures: Dart static analysis, Composer dependency audit, macOS build, Linux release, Windows/Linux quality suites, Web build, Android build, Windows build and the core evidence gate; iOS is still queued and Pages is skipped. The three isolated SQLite CAS spike jobs passed, but this does not validate production CAS. It requires failure-by-failure repair, code-level review, migration-order review and production-writer inventory reconciliation.
- PR #191 (notification outbox foundation) remains Draft on an older base (7ae6b3020c0cc331e2ab730591df44646b0ef530) and requires rebasing, independent migration-order, idempotency, retry, worker and delivery-path review. It is not a Calendar sync fix.
- No Draft state is to be silently converted to Ready. No PR is merged solely because CI is green.

### 2.2 Existing foundations

The main branch already contains parser/import, Schedule, Google Sheets, Calendar preview/sync, retry/resume, sync ID and history code, along with substantial tests and documentation. These are reusable foundations, not proof that the full user journey is complete.

Relevant source-of-truth documents:
- `docs/ROSTER_CONFIGURATION_AND_SYNC_ROADMAP.md`
- `docs/CALENDAR_PREVIEW_AND_SYNC.md`
- `docs/SYNC_RELIABILITY.md`
- `docs/END_TO_END_ACCEPTANCE_MATRIX.md`
- `docs/REMAINING_WORK_INDEX.md`
- `docs/GRID_IMPORT_REVIEW_WORKFLOW.md`
- `docs/GRID_IMPORT_RECOVERY_AND_CONCURRENCY.md`
- `docs/adr/CONDITIONAL_SCHEDULE_PERSISTENCE_AND_JOURNAL_DISCOVERY.md`
- `backend/API_DOCUMENTATION.md` and `backend/DATABASE_SCHEMA.md`

### 2.3 Confirmed gaps and risk statements

1. The production sync-history repository is currently local SharedPreferences. This is not cross-device sync or a shared server-side operation ledger.
2. Main still lacks provider-conditional update/delete protection. Draft PR #196 (28552f0f06556d7bbf11e0ce5e38765d18d2203a) adds ETag/managed-identity capture, HTTP If-Match, stale-preview rejection and update/delete outcome reconciliation, but it is not merged, is based on the pre-#193 main SHA, and its iOS check is still queued while Pages is skipped. Even if #196 passes and merges, it explicitly does not serialize whole sync runs or provide a shared cross-device operation ledger; local sync history remains insufficient for cross-device coordination.
3. The Calendar preview document still lists integration work: build concrete plans with existing provider event IDs, timezone-aware event creation, connect preview to import/comparison, and persist/communicate retry and partial-failure outcomes. These statements must be reconciled with source and tests before marking any item complete.
4. The Grid recovery design says local two-slot journal and remote journal/Schedule writes are not one cross-table database transaction. The remote committed journal is a recoverable commit intent, not proof that the canonical Schedule write completed.
5. The #192 backend Schedule repository is not yet the repository for all Schedule writers: the inspected dependency graph still passes the legacy local repository to the main AppController and the general Schedule/Roster editor factories. Therefore backend CAS is not global even if the Grid import route uses it. The Schedule CAS ADR remains a prototype/evidence gate. Do not promote the isolated spike or claim global writer safety until every production Schedule writer is inventoried and migrated or safely coordinated. The #192 Grid workflow currently derives its review revision from a Schedule content fingerprint, while the backend repository maintains a generation-bearing server revision internally; the workflow does not consume that generation token. This leaves an ABA/stale-review gap (A → B → A) that must be closed by exposing and carrying the authoritative revision through review, journal and commit.
6. The universal multi-source roadmap is broader than the current Grid import PR. Camera/photo OCR, arbitrary URL ingestion, generic provider adapters, Google Drive acquisition and their platform capabilities must be verified independently; do not label them implemented based on the roadmap.
7. Google Calendar authorization, real-provider integration, token refresh/revocation, quota behavior and production configuration require separate verification. Mock gateway tests do not prove live Google behavior.
8. The backend API's ownership isolation, revision semantics, journal lifecycle and recovery endpoints need security and concurrency tests on the exact merged implementation. A successful backend CI run is necessary but not sufficient.

## 3. Non-negotiable data and safety invariants

- No deletion or destructive rewrite of existing roster, Schedule, Timeline, Calendar event or audit data to make tests pass.
- Import and parsing never mutate the active roster or Google Calendar.
- A preview is immutable/revalidated against source fingerprint, profile/config version, canonical Schedule revision and target Calendar state before commit.
- Calendar writes require a distinct, explicit user confirmation immediately before execution.
- Only events carrying this application's managed marker and verified stable identity may be updated or deleted. Never modify unrelated user-created events.
- Stable event identity and provider event IDs must survive retries, app restarts and partial success.
- Unknown provider outcomes are reconciled by read-back before retry; never blindly repeat an ambiguous insert.
- A failed item must not cause successful items to be repeated on resume.
- Concurrent syncs from separate devices/processes must be serialized or guarded with provider ETags/revisions/leases; local mutexes are not global protection.
- Conflicting Schedule revisions fail closed and preserve the journal for user review; no silent rebase or overwrite.
- Every operation records actor, target, source fingerprint, preview/confirmation identity, timestamps, operation result and provider identifiers without logging tokens or sensitive payloads.
- Local-only mode must remain usable without a paid hosted service. Remote organization mode must be clearly distinguished and authenticated.
- A skipped, missing, pending or non-required check is never counted as PASS.

## 4. Work packages and exit gates

### WP0 — Baseline and documentation reconciliation

- Reconcile existing plans, ADRs, module docs and acceptance matrix; remove contradictions by updating existing source-of-truth files rather than creating duplicate specifications.
- Inventory actual UI entry points and call graphs for file, Sheets, camera, Schedule, generator, preview, Calendar, history and recovery.
- Record exact current main SHA, open PR heads, reviews, threads, checks, branch state and changed files.
- Establish test commands and baseline outcomes for Flutter, Laravel, parser fixtures and Calendar workflows.

**Exit:** every requirement maps to existing or planned source files, tests and evidence. Unknowns are explicitly marked UNKNOWN.

### WP1 — PR dependency and delivery hygiene

- Review #193's concurrency semantics and verify PR/ref isolation, push/manual dispatch grouping, cancellation policy and independent iOS/macOS workflows.
- Merge #193 only when its owner-authorized Ready state, exact-head CI, review and mergeability gates are satisfied.
- Rebase/retarget #192 after #193; resolve workflow overlap without dropping either change. Re-run the complete required matrix on the new head.
- Review #192's API controller, repository adapter, auth/tenant scoping, schema migration, journal lifecycle, idempotency and all existing Schedule writers.
- Review #191 separately; confirm outbox uniqueness, transaction boundary, lease/claim semantics, retry/backoff, dead-letter behavior, worker/scheduler wiring and migration order.
- Preserve Draft status unless explicitly authorized by the PR owner.

**Exit:** all three PRs have a documented review disposition, no unresolved blocking thread, current base, exact-head CI, and verified post-merge main where authorized.

### WP2 — Schedule persistence and import recovery

- Build a complete inventory of every Schedule write path: manual editor, legacy import, Grid import, restore, migration, sync, delete and test fakes.
- Select and document the production persistence concurrency strategy. The isolated CAS prototype is not production evidence.
- Ensure every writer uses the same revision/CAS or a transactionally equivalent mechanism. Define absent, live and tombstone states, generation advancement, canonical fingerprinting and stale-write response.
- Make journal enumeration/recovery deterministic; define index/slot ordering, orphan detection, bounded startup work, conflict isolation and retention.
- Test two independent writers, two app instances, stale tokens, ABA, same-content writes, delete/recreate, process interruption and migration rollback.
- Keep legacy records intact until migration is verified and rollback is possible.

**Exit:** no unguarded production writer remains; recovery is observable and non-destructive; active platform storage behavior is proven.

### WP3 — Universal source ingestion and parser reliability

- Define source-provider capability contract and supported source matrix by platform.
- Implement/verify local XLSX, CSV, TSV and text ingestion; multi-sheet and multi-section scanning; source coordinates and provenance.
- Add Google Sheets/Drive acquisition with explicit authorization and cancellation.
- Add camera/gallery image acquisition and OCR only where an actual on-device or explicitly approved extraction engine is available. No silent cloud OCR or paid dependency.
- Treat arbitrary URLs as untrusted input: supported connectors only, safe fetching policy, content limits, no credential leakage or SSRF.
- Normalize Thai Buddhist Era and Gregorian dates, cross-month/year periods, row/column/header/section dates, merged headings, duplicate/missing/out-of-order dates and conflicting sources.
- Preserve raw values and show unresolved ambiguities; never silently guess.
- Support configurable shift aliases, custom shift types, overnight times, non-work categories and per-profile/source rules.

**Exit:** golden fixture matrix across all declared formats and layouts; parser diagnostics/provenance; no blocking ambiguity can reach commit.

### WP4 — Review, preview and roster commit

- Make the reviewed Grid workflow reachable through the production UI without replacing the existing import path prematurely.
- Separate source acquisition, analysis, correction, roster preview, active-source activation and Calendar sync.
- Bind preview to immutable source/profile/config/canonical revision fingerprints.
- Invalidate stale previews if any input or target revision changes.
- Make create/update/skip/blocked/duplicate/conflict actions inspectable at record level.
- Preserve prior roster and import history; require confirmation for activation and persistence.

**Exit:** widget/UI integration tests prove preview is exact and no mutation occurs before explicit confirmation.

### WP5 — Google Calendar synchronization correctness

- Trace the actual production path from reviewed roster to event mapper, diff engine, plan builder, preview, executor, gateway and history.
- Ensure plan operations carry verified Google event IDs and ETags; never infer update/delete targets from title/date alone.
- Use stable per-event Sync IDs derived from canonical source identity and assignment identity; validate legacy adoption and duplicate handling.
- Add cross-device/concurrent update/delete protection using provider ETags and/or a server-side lease/operation ledger with idempotency keys. Local history alone is insufficient.
- Add timezone and all-day/timed event tests, daylight-saving boundaries where applicable, overnight shifts and month/year edges.
- Make retry/resume idempotent per operation; reconcile ambiguous timeouts with provider read-back; never retry successful items.
- Persist a durable operation ledger/history with per-item outcomes, provider IDs, ETags, attempt count, last error, next retry and terminal state. Define local-only behavior when no backend is configured.
- Handle 401/token expiry, 403 insufficient scope, 404 deleted event, 409/412 conflict, 429 rate limit and 5xx/network timeout distinctly.
- Verify real Google Calendar read/write behavior in a controlled test calendar only after explicit authorization; do not touch the user's real calendar as a test.
- Keep delete operations disabled unless the user explicitly includes managed-event deletion in the preview.

**Exit:** duplicate/retry/concurrency/partial-failure integration suite passes; controlled provider test proves create/update/read-back and recovery; unrelated events remain untouched.

### WP6 — Notifications and operational observability

- Verify notification outbox is transactionally created with the domain change it announces.
- Ensure idempotent enqueue, claim/lease, retry/backoff, worker scheduling, dead-letter inspection and delivery adapter wiring.
- Prevent duplicate notifications after retry or concurrent workers.
- Provide actionable sync diagnostics without exposing tokens, personal roster content or private calendar data.

**Exit:** worker/queue execution and failure recovery are demonstrated, not just service-level tests.

### WP7 — Full acceptance and release

- Run focused tests for every changed module, then full Flutter format/analyze/test, Laravel feature tests, migration tests and platform builds.
- Validate Web, Android, iOS, Windows and Linux; treat macOS support according to current platform policy and PR #193 evidence.
- Run security/privacy review for OAuth scopes, ownership, tenant isolation, URL fetching and log redaction.
- Verify production configuration, health/readiness, deployment and rollback only where deployment access is authorized.
- Verify post-merge CI on exact main SHA and smoke test the released user journey.

**Exit:** all mandatory acceptance rows PASS with evidence links; no unresolved blocker, no skipped gate misreported as pass, and release notes/operations docs are current.

## 5. Acceptance matrix

| ID | Requirement | Required evidence | Initial status |
|---|---|---|---|
| DOC-01 | One reconciled roadmap and traceability matrix | Updated docs and links | IN PROGRESS |
| PR-01 | PR #193 resolved before #192 workflow rebase | Review, exact-head checks, post-merge SHA | BLOCKED by Draft/readiness |
| PR-02 | PR #192 reviewed and integrated safely | API/security/migration review and exact-head CI | BLOCKED by Draft/readiness |
| PR-03 | PR #191 outbox delivery path verified | Feature tests + worker execution | BLOCKED by Draft/readiness |
| DATA-01 | Every Schedule writer uses concurrency protection | Writer inventory + independent-writer tests | NOT PROVEN |
| DATA-02 | Journal recovery enumerates and isolates all records | restart/interruption/recovery tests | NOT PROVEN |
| SRC-01 | Declared source types work end-to-end | provider matrix + UI integration tests | PARTIAL |
| PAR-01 | Thai/BE/CE, cross-period and ambiguous dates are safe | golden fixtures + no-silent-guess tests | PARTIAL |
| UI-01 | Review/preview/confirmation are connected to production UI | widget/integration tests | NOT PROVEN |
| CAL-01 | Managed event create/update/delete targeting is exact | gateway integration + event-ID/ETag tests | PARTIAL |
| CAL-02 | Concurrent device sync is safe | lease/ETag/idempotency integration test | NOT PROVEN |
| CAL-03 | Retry/resume never duplicates successful writes | ambiguous-timeout and partial-failure tests | PARTIAL |
| CAL-04 | Durable per-item sync history and recovery | restart/cross-device tests | PARTIAL |
| CAL-05 | Real provider behavior works with least-privilege auth | controlled Google test calendar evidence | NOT PROVEN |
| NOT-01 | Outbox is wired to a real worker and delivery adapter | worker run + retry/dead-letter test | NOT PROVEN |
| REL-01 | Supported platforms and deployment are verified | exact-SHA builds and smoke tests | PARTIAL |

Statuses are intentionally conservative. They must be updated only with current evidence and exact commit references.

## 6. Execution and merge protocol

For each work package:
1. Read current source and tests; identify the smallest safe change set.
2. Update this plan and the relevant existing module/API/ADR docs.
3. Implement on a dedicated branch; do not commit directly to `main`.
4. Run targeted tests locally/CI and record exact SHA.
5. Inspect complete diff, migration effects, security boundary and data preservation.
6. Resolve review comments and required checks; distinguish PASS, FAIL, SKIPPED and UNKNOWN.
7. Obtain/confirm the required merge authorization for the specific PR.
8. Merge with expected head SHA only after all gates are met.
9. Verify merge commit, main SHA, post-merge CI and runtime smoke test.
10. Update the acceptance matrix and delivery status.

No destructive operation, OAuth scope expansion, paid provider adoption, production Calendar write, or production database migration is authorized by this plan alone.

## 7. Completion definition

The project may be called complete only when:
- the complete user journey works on the declared supported platforms;
- every acceptance requirement has PASS evidence;
- sync is idempotent, concurrency-safe, recoverable and auditable;
- data migration and rollback are verified without data loss;
- user confirmation boundaries are enforced in code and UI;
- exact-main post-merge checks and controlled runtime smoke tests pass;
- documentation matches the shipped implementation.

Until then, report the remaining items as open.
---

## 8. Live execution checkpoint — 2026-11-26 18:01 Asia/Bangkok

This checkpoint supersedes the older PR snapshot above where they conflict. It is an evidence update, not a completion claim.

### 8.1 Exact repository baseline

- Current main: d18454680879a10c6efe9e44ffb37cd0695f25a6.
- PR #193 merged at 2026-11-26T09:39:24Z; merge commit is the current main SHA.
- Post-merge checks on that exact main SHA: 15 completed / 15 success.
- PR #194 remains merged; its earlier merge commit checks were 7/7 success.

### 8.2 Current open delivery units

| PR | Current state | Exact head | Base relationship | Evidence / disposition |
|---|---|---|---|---|
| #196 Calendar ETag safety | Draft | 28552f0f06556d7bbf11e0ce5e38765d18d2203a | Based on pre-#193 main c6ad63a...; update/rebase required | 15 checks successful, iOS Xcode queued, Pages skipped; no review. Not merge-ready. |
| #192 Grid import and persistence recovery | Draft | 12e9245ba3c7df89428de48f6e73b2106a525973 | Base is current main d184546... | Multiple exact-head failures (static analysis, Composer audit, macOS/Linux/Windows/Web/Android builds and quality gates); iOS queued; Pages skipped. Repair before review/merge. |
| #191 Notification outbox | Draft | 62f0a2007ff9c105354044f52467bfd14e28a348 | Older base 7ae6b302... | No current-base certification. Separate from Calendar sync; review migration and delivery boundaries. |
| #193 Xcode queue | Merged | 20973ff9f48ae4476a74b060769cbab93821f5ea | Merged to current main | Post-merge main checks 15/15 success. |

### 8.3 Calendar sync defect boundary

- Current main's production ResilientCalendarSyncExecutor still retries update/delete through the unconditional gateway methods. Current main's Google gateway still uses ordinary update/delete calls. The Draft #196 change is therefore not yet active in production.
- #196 improves per-event stale-write safety through provider ETags and managed identity, but its own PR description confirms that whole sync runs are not globally serialized and history/failed-operation storage remain local SharedPreferences.
- The complete sync fix therefore needs both provider-level conditional writes and operation-level coordination/recovery. A local in-memory mutex alone is not sufficient across browser tabs, devices or app processes.
- Required server-side operation ledger/lease work must use the existing authenticated backend and existing persistence where viable; do not introduce a paid provider or new hosted dependency without approval.
- Do not test by writing to the user's real Calendar. Use fakes and a dedicated test calendar only after separate explicit authorization.

### 8.4 Immediate execution order

1. Rebase/update #196 onto current main, inspect the full diff, finish iOS CI and add tests for 412, 404/410, ambiguous timeout, legacy adoption, unrelated-field preservation and resume. Keep Draft until ready.
2. Design and implement the shared sync-operation ledger/lease: stable idempotency key, per-calendar/operation scope, owner authorization, lease expiry/reclaim, state transitions, per-item provider IDs/ETags, attempt/backoff, and read-back reconciliation. Prove two independent clients cannot execute conflicting plans concurrently.
3. Reconcile #192 against current main and repair every failing exact-head check. Complete backend ownership isolation, all Schedule-writer revision/CAS inventory, generation-bearing revision propagation, journal recovery and UI integration before merge.
4. Rebase and independently review #191. Decide whether notification delivery is in the requested release scope; do not imply an outbox foundation sends notifications.
5. Complete source-provider and parser acceptance: local workbook/text formats, Google Sheets/Drive, camera/photo OCR only with a verified on-device/approved engine, URL safety, Thai BE/CE and cross-period dates, provenance and ambiguity review.
6. Complete production UI path: acquire → analyze → correct → preview → confirm → persist → Calendar preview → explicit Calendar confirmation → sync → provider read-back → durable history → retry/recovery.
7. Run exact-SHA Flutter, backend, migration, integration and supported-platform checks; then controlled test-calendar verification and post-merge main checks.

### 8.5 Updated acceptance status

| ID | Current status | Evidence required to change to PASS |
|---|---|---|
| PR-193 | PASS | Merged current main; 15/15 post-merge checks |
| PR-196 | IN PROGRESS | Rebased exact-head full CI + review + provider conditional-write tests |
| CAL-01 conditional mutation | PARTIAL | #196 merged and exact-head provider integration tests |
| CAL-02 cross-device serialization | NOT PROVEN | Shared lease/ledger + two-client race/reclaim tests |
| CAL-03 retry/resume | PARTIAL | Ambiguous update/delete, no-repeat-success, stale lease and process restart tests |
| CAL-04 durable history | NOT PROVEN | Server-backed per-item ledger and restart/cross-device read-back |
| DATA-01 Schedule writer concurrency | NOT PROVEN | All production writers use the same authoritative generation/CAS |
| DATA-02 import journal recovery | NOT PROVEN | Restart/interruption/orphan/conflict/rollback tests |
| SRC-01 multi-source ingestion | PARTIAL | Each declared provider works through the real review/preview path |
| UI-01 review and confirmation | NOT PROVEN | Production UI integration tests prove no writes before explicit confirmation |
| CAL-05 real Google provider | NOT PROVEN | Dedicated test-calendar create/update/read-back/recovery evidence |

No row becomes PASS from a roadmap, a Draft PR, a skipped check, or a mock-only test. Do not mark the overall project complete until every mandatory row has exact evidence and the shipped implementation matches these documents.
### 8.6 Production synchronization call graph

- The current application dependency container wires the main schedule workflow through `CalendarSyncGateway` → `CalendarSyncCoordinator` → `ResilientCalendarSyncExecutor`, with `ResumeSyncService` for failed operations. The default Google gateway is `GoogleCalendarSyncGateway`.
- The production history and failed-operation repositories created by this dependency container are `SharedPreferencesSyncHistoryRepository` and `SharedPreferencesFailedSyncRepository`; they are device-local.
- A separate `features/calendar_sync` module also exists with its own `CalendarSyncService`, `CalendarSyncExecutor` and `GoogleCalendarEventRepository`. Do not assume it is the active path or delete it based on directory names. Trace all imports/routes/widgets/callers before consolidation; avoid implementing the same fix twice.
- The transaction-specific flow in `AppController` uses the schedule workflow, then calls the backend shift-transaction start/complete/fail endpoints. Its existing `shift_transaction_sync_attempts` and `shift_transaction_calendar_events` tables are transaction-scoped; they do not replace a general per-user Calendar sync run/operation ledger.
- The next code change must preserve the existing explicit preview/confirmation boundary and route every production schedule sync through the same safety/coordination contract.
### 8.7 Follow-up execution checkpoint — after PR #196 branch refresh

- PR #196 was brought forward onto current main with merge commit `bf3cc412d6989dc3d8aca2eaee278ee448bbc9ca`; the PR now has zero commits behind main and no file conflicts. Subsequent review found that the conditional update path also needed to preserve the provider-owned `--- Timeline ---` audit section. That preservation, normalized diff comparison and an ambiguous-update reconciliation regression test were added.
- Latest PR #196 head: `d2dca7879168f1be01f89eaca1620c73dfbd615c`. At this checkpoint, 1 check is successful and 7 are pending; no failures or skipped checks have been reported yet. The PR remains Draft.
- PR #197 documentation checks: 5 successful and 2 pending at its then-current head; not yet certified complete.
- PR #192 exact head `12e9245ba3c7df89428de48f6e73b2106a525973`: 9 successful, 10 failed, 1 queued, and 1 skipped. The failures remain blockers; the skipped Pages job is not a pass.
- The timeline-preservation patch is a data-integrity correction within PR #196. It does not close the separate cross-device lease/operation-ledger gap. Do not merge #196 until all exact-head required checks complete and the code review is satisfied.
### 8.8 Live execution checkpoint — 2026-11-26 12:26 UTC

This update supersedes earlier PR-head and CI snapshots in sections 8.2 and 8.7 where they differ. Main remains `d18454680879a10c6efe9e44ffb37cd0695f25a6`. No PR has been merged by this execution.

| PR | Current head | Current evidence | Remaining blockers |
|---|---|---|---|
| #192 Grid import / persistence | `c9bc708f5047bd232b7b4ca7cac15342f9af5ea2` | Backend security refresh workflow passed; committed `backend/composer.lock` now pins `symfony/http-kernel`, `symfony/mailer`, and `symfony/routing` to `v8.1.12`. Laravel Backend CI on the latest head is PASS. Web/Linux and formatting had passed on the immediately preceding head; exact-head platform matrix is still running. | Windows/Android/iOS/macOS/runtime and full root quality gates still require exact-head results. Production Schedule writer inventory is not fully migrated; local SharedPreferences remains the default repository. |
| #196 Calendar ETag + coordination foundation | `1f3d5364bd69a813aa4427c977b77c1d58560fb6` | ETag/If-Match code retained. Added authenticated Laravel calendar sync leases, heartbeat/release, durable run records, per-run idempotent operation ledger, status/attempt guards, owner-scoped history reads and feature tests. Corrected route declarations after Laravel CI exposed literal newline escapes. | Latest exact-head Laravel CI and platform checks are queued. Flutter executor is NOT YET wired to acquire/heartbeat/release leases or persist operations. Therefore cross-device serialization and durable recovery are NOT proven. |
| #191 Notification Outbox | `69cf20b8eba1d073f87ddaad0587237a9c414e7a` | Updated branch to current `main` via merge commit `7c42241a24b4f22d51d750f5c6c721a6475ebbae` (8 ahead, 0 behind); applied patched Symfony lockfile from #192. Backend CI has been queued on the updated head. | Still Draft; outbox is enqueue-only and has no worker/provider delivery. Exact-head CI and review remain required. |
| #197 execution documentation | `9d8e66504160c7faf804c1de2e90ab74e25ce38d` | Documentation-only checkpoint; no code or production data changed. | Review and exact-head checks remain required. |

#### Security dependency evidence

- The first lock-refresh workflow attempt failed because Composer does not support `composer install --locked`; the workflow was corrected to use `composer install` (which consumes `composer.lock`).
- The corrected refresh workflow completed successfully. Its log shows `composer audit --locked` reporting no security vulnerability advisories, then Pint, Laravel bootstrap syntax and Laravel tests completed successfully before committing the lockfile.
- The resulting lockfile commit `08a0ea0fad29819ffe0accb1b44750245bd87638` changes only `backend/composer.lock`; the three affected Symfony packages are `v8.1.12`.
- The standard Laravel Backend CI was then re-triggered on the newer PR #192 head and passed. The same patched lockfile was copied to PR #191 so its backend gate no longer inherits the vulnerable baseline.

#### Production CAS boundary — still open

- PR #192's backend revision-aware repository provides server-enforced generation/fingerprint compare-and-swap for its Grid backend path. It is only selected for Grid when `ORGANIZATION_API_BASE_URL` is configured.
- `AppDependencies` still defaults general Schedule editing and the legacy AppController to `SharedPreferencesScheduleRepository`; the SharedPreferences two-slot write is crash-resilient but not cross-instance atomic CAS.
- The new server lease/operation tables in #196 are currently API foundations. Until `ResilientCalendarSyncExecutor` is integrated with the lease/ledger and every production Schedule writer carries caller-owned revision tokens, do not claim production-wide CAS or cross-device sync safety.

#### Current conservative acceptance status

| Requirement | Status | Evidence still required |
|---|---|---|
| Symfony dependency audit | PASS on #192 refresh workflow and latest #192 Laravel CI | Confirm standard exact-head checks remain green after subsequent commits. |
| PR #192 root/platform matrix | IN PROGRESS | Exact-head Flutter analyze/tests and Windows/Android/iOS/macOS/runtime checks. |
| PR #191 base freshness | PASS (0 behind main) | Exact-head CI and independent outbox review. |
| PR #191 notification delivery | NOT PROVEN | Worker, retry/backoff, dead-letter and provider delivery integration. |
| PR #196 server lease/ledger API foundation | IMPLEMENTED, TESTING | Exact-head Laravel feature tests and schema review. |
| PR #196 Flutter lease/ledger integration | NOT IMPLEMENTED | Executor acquire/heartbeat/operation record/release wiring and two-client race/restart tests. |
| Production-wide Schedule CAS | NOT PROVEN | Migrate or safely coordinate every writer; eliminate unguarded SharedPreferences production writes where multi-device guarantees are required. |
| Controlled Google Calendar verification | NOT AUTHORIZED | Separate explicit authorization for a dedicated test calendar only. |

All Draft PRs remain Draft. No merge, deployment, production migration or real-calendar write is authorized by this checkpoint.

### 8.9 Live execution checkpoint — 2026-11-26 12:44 UTC

This checkpoint supersedes the earlier implementation notes in section 8.8 where they differ. Main baseline remains `d18454680879a10c6efe9e44ffb37cd0695f25a6`. All four PRs remain Draft; no merge, deployment, production migration or real-calendar write has occurred.

| PR | Current head | Latest observed checks | Current assessment |
|---|---|---|---|
| #192 Grid import / persistence | `c9bc708f5047bd232b7b4ca7cac15342f9af5ea2` | 17 successful; 0 failed; macOS and iOS unsigned builds queued; iOS evidence in progress; Pages deploy skipped. | Backend security audit and Laravel CI pass; Web, Linux, Windows, Android and CAS contract checks pass. iOS/macOS exact-head build evidence is still outstanding. Production-wide Schedule CAS is still not proven: general Schedule writers continue to default to local SharedPreferences. |
| #196 Calendar sync coordination | `1f564a81a1bd707ca789c260239a284151d36b3f` | Exact-head CI has 13 queued and 1 in progress at this snapshot; no failures reported yet. | Added Laravel lease/run/operation APIs, Flutter executor integration, per-operation heartbeat/ledger updates, release, and coordinated ResumeSyncService. Schedule ID is persisted in local history. Backend feature suite passed 79 tests / 620 assertions in the dedicated verification run. Flutter exact-head quality/platform matrix is still pending. |
| #191 Notification Outbox | `69cf20b8eba1d073f87ddaad0587237a9c414e7a` | 8 successful; 0 failed; no pending checks. | Branch includes main (0 behind) and patched Symfony lockfile. Outbox remains enqueue-only; no worker or external delivery is enabled. |
| #197 execution documentation | `b431511ba504a0ee18fdfcd926448a20c0c20783` | 7 successful; 0 failed; no pending checks. | Documentation checkpoint passes. |

#### #196 coordination and recovery boundary

- When `ORGANIZATION_API_BASE_URL` is configured, the production `ResilientCalendarSyncExecutor` acquires the server lease before Calendar mutations, heartbeats between operations, records payload-hashed operation intents, stores provider outcomes and releases the lease.
- `ResumeSyncService` now uses the same lease and ledger. New sync history persists the original Schedule ID; old history without that ID fails closed in server-coordinated mode.
- Local-only mode remains usable but does not serialize across devices. The user-facing history and failed-operation queue remain local SharedPreferences; startup recovery does not yet load server operation history to reconcile an interrupted run. This is still an acceptance gap.
- Dedicated backend verification passed `composer audit --locked`, Pint, and 79 Laravel tests / 620 assertions. The initial CI failures exposed and fixed: Composer `--locked` misuse, route newline escapes, missing Carbon import, Dart nullable map lint, unused test import, and an incorrect await on the synchronous Google authentication getter.
- The Flutter formatter/analyzer/test workflow and exact-head cross-platform matrix are still running; do not mark them PASS until their own exact-head conclusions are success.

#### Updated acceptance matrix

| Requirement | Status | Remaining evidence |
|---|---|---|
| Symfony dependency security | PASS on #192/#191/#196 lockfiles | Standard exact-head Laravel CI on the latest commit. |
| Grid parser, web/Linux/Windows/Android and native CAS contract | PASS on #192 | iOS/macOS unsigned app builds and final core PR gate. |
| PR #191 base freshness and current CI | PASS | Independent review; delivery worker remains future scope. |
| Backend Calendar lease and durable operation API | PASS in dedicated verification | Standard exact-head backend CI and security review of server locking on supported production DB. |
| Flutter executor and resume lease integration | IMPLEMENTED, TESTING | Exact-head Flutter analyze/tests, E2E two-client race, timeout, ambiguous response, process-restart recovery. |
| Server history-driven restart recovery | NOT IMPLEMENTED | Read old server operations, reconcile provider state, resume safely after app restart. |
| Production-wide Schedule CAS | NOT PROVEN | Migrate every Schedule writer to caller-owned server revision tokens or fail closed in backend mode. |
| Real Google Calendar test writes | NOT AUTHORIZED | Separate explicit authorization for a dedicated test calendar only. |

Never count queued, in-progress, skipped or missing platform evidence as PASS. Keep all PRs Draft until the complete acceptance matrix and human review are satisfied.

### 8.10 Live execution checkpoint — 2026-11-26 13:02 UTC

Current exact PR heads after the latest CAS and coordination changes. Main baseline remains `d18454680879a10c6efe9e44ffb37cd0695f25a6`. All PRs remain Draft; no merge, deployment, production migration or production Google Calendar write has occurred.

| PR | Head SHA | Exact-head CI at this checkpoint | Assessment |
|---|---|---|---|
| #192 Grid import / Schedule persistence | `8a825ae41c3eb090c15664bb0eca7f1c5d2d0f91` | 15 checks queued; no failures yet. | Added snapshot-bound BackendScheduleRepository revisions, fail-closed unknown snapshots, W-01 editor CAS token, W-02/W-03 base-snapshot compare-and-save, F-01 create-only backend facade, local-only sign-out/source resets, and stale-editor concurrency test. Full exact-head platform evidence is pending. |
| #196 Calendar ETag / cross-device coordination | `271128769a5ba0e705eb510a90c56f464cddb604` | 13 checks queued; no failures yet. | Added Laravel lease/run/operation ledger APIs; Flutter executor and ResumeSyncService use the same lease/ledger when backend is configured; Schedule ID is persisted in history. Dedicated backend verification on the earlier same-source revision passed 79 tests / 620 assertions. Exact-head Flutter/platform checks are pending. |
| #191 Notification Outbox | `69cf20b8eba1d073f87ddaad0587237a9c414e7a` | 8 successful, 0 failed, 0 pending. | Branch includes latest main (0 behind) and patched Symfony lockfile. Outbox remains enqueue-only; no provider worker/delivery is enabled. |
| #197 execution documentation | `d825291d8ef706141100a48634d2558965e92ae2` | 7 successful, 0 failed, 0 pending. | Documentation checkpoint passes. |

#### Production CAS boundary

- With `ORGANIZATION_API_BASE_URL` configured, `AppDependencies` uses one shared `BackendScheduleRepository` for production Schedule consumers. Grid import shares that instance.
- `BackendScheduleRepository.save()` binds its revision to the exact loaded Schedule snapshot fingerprint. A later read cannot silently replace an older editor's token. Unobserved snapshots fail closed. `delete()` is disabled until caller-owned conditional-delete/tombstone semantics exist.
- W-01 captures the editor's base revision and calls `saveIfRevision`. W-02/W-03 compare the live server Schedule with the exact previous canonical snapshot before calling `saveIfRevision`; a remote change is surfaced instead of overwritten. F-01 creates only against an absent revision; replacing an existing Schedule requires the reviewed Grid path.
- Sign-out, account change, source switch and local-source clearing are local-only resets; they do not persist an empty Schedule.
- This is backend-mode safe-by-fail-closed for identified writers, not a claim that every legacy workflow can save without first loading its base snapshot. The SharedPreferences fallback remains local-only and is not cross-device CAS.

#### Calendar recovery boundary

- When the backend origin and Google ID token are configured, both normal sync and resume acquire the same owner/Calendar lease, heartbeat, persist operation keys and payload hashes, record provider outcomes and release the lease.
- Server run/operation history is durable and owner-scoped. However, app startup does not yet load server history to recover a process-killed run; user-facing history and failed queue remain local SharedPreferences. Startup reconciliation remains open.
- Backend API feature tests and dependency audit passed in a dedicated verification workflow; exact-head CI on #196 remains queued and must be treated as UNKNOWN until completed.

#### Remaining acceptance gates

1. Wait for all 15 #192 checks and all 13 #196 checks on their exact current heads. No queued or skipped item is PASS.
2. Verify two-editor Schedule CAS conflict and backend-mode fail-closed behavior on exact-head Flutter tests.
3. Verify two-device Calendar lease race, expiry/reclaim, timeout/ambiguous response, duplicate operation replay, resume and release-on-error.
4. Implement server-history-driven recovery after process restart; local queue alone is not durable shared recovery.
5. Keep production Google Calendar writes disabled until a separate explicit authorization for a dedicated test calendar.

Do not mark the repository complete or merge any PR until these gates and human review pass.

### 8.11 Live execution checkpoint — 2026-11-26 13:12 UTC

Current exact heads after the final writer-safety changes in this work session. Main remains `d18454680879a10c6efe9e44ffb37cd0695f25a6`. No PR was merged, no backend was deployed, and no production Calendar event was changed.

| PR | Current head | Current exact-head checks | State |
|---|---|---|---|
| #192 | `8643a86fb21fe33639e25577159a310ef15b98ef` | 15 queued; 0 failures; no completed checks on this head yet. | Snapshot-bound CAS writer changes are committed; validation UNKNOWN until queue runs. |
| #196 | `e93d5cdd25ac0c076e544b1b87a5a06188073a16` | 12 queued; 0 failures; no completed checks on this head yet. | Executor and resume lease/ledger integration committed; validation UNKNOWN until queue runs. |
| #191 | `69cf20b8eba1d073f87ddaad0587237a9c414e7a` | 8 successful; 0 failures; 0 pending. | Current CI PASS; Draft retained pending human review. |
| #197 | `9a4e2acaff90016a14a2776dbd83efa7cb589787` | 2 successful, 1 in progress, 4 queued; 0 failures. | Documentation CI is still running on the current docs head. |

#### Deployment and runtime prerequisite

The Laravel coordination API exists in the repository and its dedicated backend feature verification passed on an earlier source revision. It has **not** been deployed or verified at a live `ORGANIZATION_API_BASE_URL` in this execution. Server-side CAS and cross-device Calendar leases activate only when the app is built/configured with that backend origin and a valid Google ID token. Without it, SharedPreferences/local-only behavior remains and is not cross-device safe. Do not interpret code or CI success as proof of live backend availability.

#### Remaining blockers

- Wait for all exact-head #192 and #196 CI jobs; their current queued checks are UNKNOWN, not PASS.
- Confirm the configured backend URL, authentication middleware and production database provide the intended atomic transaction/locking semantics before any rollout.
- Run controlled two-device Calendar sync tests against a dedicated test calendar only after separate explicit authorization.
- Implement server-history-driven startup recovery after process termination; current UI history and failed-operation queue remain local even though resume operations are ledgered when explicitly resumed.
- Keep all four PRs Draft and do not merge until exact-head CI, reviews, recovery acceptance and human approval are complete.
