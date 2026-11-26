# End-to-End Completion Plan — Roster, Calendar Sync and Data Integrity

**Prepared:** 2026-11-26  
**Baseline:** `main@d18454680879a10c6efe9e44ffb37cd0695f25a6`
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
- PR #192 (Grid import, Schedule API and recovery foundations) remains Draft at head `2c3b8bfc04fd2dcb5487fb922d42a4d6f8bb5457`, based on current main `d18454680879a10c6efe9e44ffb37cd0695f25a6`. It now includes backend revision-aware CAS for the inventoried W-01–W-05/F-01 writers, exact snapshot identity and absent-state revision tokens, plus an A→B→A regression. The previous exact-head static-analysis failure exposed interface-promotion and stale snapshot-cache references; explicit capability casts and identity-map references have been corrected. The Android workflow's hard-coded SDK Manager path was also corrected. The latest exact-head matrix is running: Web and Dart Format have passed; Windows, Android, Linux and Backend jobs are in progress or queued; iOS/macOS remain pending. No exact-head overall gate is certified yet.
- PR #191 (notification outbox foundation) remains Draft at head `69cf20b8eba1d073f87ddaad0587237a9c414e7a` and is now based on current main `d18454680879a10c6efe9e44ffb37cd0695f25a6` (0 commits behind); no further rebase is needed. Its 8 current checks are successful. It remains enqueue-only: worker, retry/backoff, dead-letter and external delivery are future scope. It is not a Calendar sync fix.
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

1. The user-facing sync history and failed-operation queue remain local SharedPreferences. PR #196 adds a server-side lease and encrypted durable per-operation ledger plus explicit history-linked recovery when the backend is configured; it does not automatically replay on startup. Local-only mode without the backend origin still has no cross-device serialization or recovery.
2. Main still lacks provider-conditional update/delete protection and global sync coordination. Draft PR #196 at `148c97fc2263f7cf07705f83b3052a54f736a8be` adds ETag/If-Match mutation guards, owner/Calendar-scoped server leases, transactional ledger fencing, encrypted operation payloads and explicit recovery through the workflow controller. It is not merged or deployed. Exact-head CI is still running; local history remains a UI cache and local-only mode is not cross-device safe.
3. The Calendar preview document still lists integration work: build concrete plans with existing provider event IDs, timezone-aware event creation, connect preview to import/comparison, and persist/communicate retry and partial-failure outcomes. These statements must be reconciled with source and tests before marking any item complete.
4. The Grid recovery design says local two-slot journal and remote journal/Schedule writes are not one cross-table database transaction. The remote committed journal is a recoverable commit intent, not proof that the canonical Schedule write completed.
5. PR #192 now routes the inventoried backend-mode Schedule writers through the shared BackendScheduleRepository and caller-owned generation revisions. Snapshot tokens are identity-bound, absent-state tokens are separate, and an A → B → A regression is included. This is conditional on `ORGANIZATION_API_BASE_URL` being configured; the SharedPreferences fallback remains local-only and is not cross-device CAS. Conditional Schedule deletion/tombstones remain disabled, and the isolated SQLite spike is still not the production repository.
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

### 8.12 Live execution checkpoint — 2026-11-26 13:17 UTC

Latest branch tips after the final changes. Main base remains `d18454680879a10c6efe9e44ffb37cd0695f25a6`.

| PR | Head | Latest Actions state |
|---|---|---|
| #192 | `8643a86fb21fe33639e25577159a310ef15b98ef` | 13 workflow runs created at 13:15 UTC; most are queued and iOS/macOS/Windows/Android jobs are pending. 0 failures observed. No exact-head check is complete yet. |
| #196 | `1558ba00395be4fcc9bfc7a9fd1e2cb6adde9122` | 12 workflow runs created at 13:16 UTC; most queued, platform/backend jobs pending. 0 failures observed. No exact-head check is complete yet. |
| #191 | `69cf20b8eba1d073f87ddaad0587237a9c414e7a` | 8 successful checks, 0 failures. |
| #197 | `e1c3b59a787df5d73d4634132f36765cfd708bc4` | Docs update triggered Auto Detect CI (pending) and Cross-platform Runtime (queued). |

Do not read queued or pending as a runner pass. In particular, native macOS/iOS and all root-quality jobs have not yet completed on the latest #192/#196 heads. The backend coordination service remains undeployed and unverified at a live URL. All PRs remain Draft and no merge/deployment/production Calendar mutation is authorized.


### 8.13 Live execution checkpoint — 2026-11-26 13:40 UTC

This checkpoint supersedes the older PR snapshots above where they differ. Main remains `d18454680879a10c6efe9e44ffb37cd0695f25a6`. All four PRs remain Draft. No PR has been merged, no backend deployed, no production migration run, and no real Google Calendar event changed.

| PR | Current head | Latest exact-head evidence | Current assessment |
|---|---|---|---|
| #192 Grid import / Schedule persistence | `2c3b8bfc04fd2dcb5487fb922d42a4d6f8bb5457` | Web build and Dart Format Audit PASS. Windows, Android, Linux and Laravel Backend jobs are in progress/queued; iOS/macOS and core gate are pending. | Static-analysis errors from the preceding head were corrected by explicit interface casts and identity-cache lookup. Android SDK Manager discovery was made version-independent after the previous build failed on a hard-coded path. Exact-head full matrix is not yet certified. |
| #196 Calendar ETag / global coordination / recovery | `148c97fc2263f7cf07705f83b3052a54f736a8be` | Latest exact-head run is active: Windows/Web and format work in progress; Android/Linux/Backend queued; iOS/macOS pending. Earlier head exposed one Pint style issue, one duplicate named argument and the same Android SDK Manager path issue; these were corrected on the current head. | Adds ETag guards, owner/Calendar lease, transaction-fenced ledger writes, encrypted operation payload, owner-scoped run/operation reads, and explicit history-linked recovery. Exact-head CI still required. |
| #191 Notification Outbox | `69cf20b8eba1d073f87ddaad0587237a9c414e7a` | Base equals current main; 8/8 checks PASS. | No rebase needed. Outbox remains enqueue-only; no worker or delivery enabled. Draft retained pending review. |
| #197 execution documentation | `35463433e92d6bedca8de49e905a20d937959ab5` | Documentation-only branch; previous 7/7 checks PASS before this checkpoint refresh. | This plan is being reconciled to current PR heads and blockers. |

#### Verified implementation boundaries

- **Schedule CAS:** Backend mode uses the shared revision-aware repository for the inventoried W-01–W-05/F-01 writers. Revision tokens are bound to exact loaded snapshot identity; absent-state tokens are captured separately; the A → B → A test prevents stale token substitution. This does not make SharedPreferences local-only fallback cross-device atomic. Production safety depends on configuring `ORGANIZATION_API_BASE_URL` in every production build.
- **Calendar coordination:** Server leases are keyed by authenticated owner and Calendar ID. Operation create/update validates and locks the active lease in the same database transaction. The durable ledger stores canonical payload hashes and encrypted replay payloads; owner-scoped APIs return the run and operations. Explicit `recoverHistory(historyId)` reconstructs unfinished operations and resumes under a new lease. Startup replay remains disabled.
- **Recovery safety:** Inserts reconcile by stable Sync ID; updates compare desired provider state before enforcing the original ETag; deletes treat already-missing events as complete and reject changed events. No production Google Calendar write has been authorized.
- **Security:** The backend lock pins affected Symfony components to 8.1.12. Earlier audit on the lock-refresh run reported no advisories; current exact-head Laravel CI remains the required final proof. Encrypted ledger payloads depend on protecting and backing up Laravel `APP_KEY`; payload retention policy must be defined before production rollout.
- **Outbox:** PR #191 has current base and green CI, but only persists notification intents. Worker scheduling, retry/backoff, dead-letter behavior and real provider delivery remain unimplemented.

#### Remaining acceptance gates

1. Complete exact-head #192 Flutter analyze/tests, Composer audit/Pint/Laravel tests, Windows/Linux/Web/Android/iOS/macOS builds, CAS spike and core PR gate. Do not count queued, pending, skipped or cancelled jobs as PASS.
2. Complete exact-head #196 backend feature tests, Composer audit/Pint, Flutter format/analyze/tests and all platform builds. Re-run any cancelled jobs after the final head stabilizes.
3. Prove two independent Schedule clients racing the same generation yield exactly one commit; verify all writer paths and fail-closed local/backend mode boundaries.
4. Prove two Calendar clients contend on the same owner/Calendar lease, stale leases cannot write the ledger, and timeout/ambiguous insert/update/delete recovery never duplicates or overwrites unrelated events.
5. Verify local history can invoke explicit recovery using its stored serverRunId and clearly report missing server history without replay.
6. Confirm production backend URL, auth middleware, database locking semantics, APP_KEY backup/retention and rollback before any deployment.
7. Keep #191 Draft until independent review; no delivery worker or notification provider is authorized by the outbox foundation.
8. Keep all PRs Draft until exact-head checks and human review are complete. No merge, deployment, production migration or real-calendar write is authorized by this plan.



### 8.14 Live execution checkpoint — 2026-11-26 22:56 Asia/Bangkok

This checkpoint supersedes earlier PR-head and CI snapshots above where they differ. Main remains `d18454680879a10c6efe9e44ffb37cd0695f25a6`. All implementation PRs remain Draft. No PR was merged, no backend deployed, no production migration run, and no real Google Calendar event changed.

| PR | Current head | Exact-head evidence at this checkpoint | Assessment |
|---|---|---|---|
| #192 Grid import / Schedule persistence | `0507995bbd6533a369f0850d9e21a3fee9a94d94` | Current full matrix has been created; jobs are queued/pending. Earlier root test failure (three widget tests) was traced to demo-controller tests using the async device-backed Schedule repository. The widget test helper now injects an in-memory Schedule repository. Current exact-head tests are not yet complete. | Snapshot-bound CAS and all inventoried backend-mode writers are implemented; SharedPreferences fallback remains local-only. Production artifact workflows now require the shared HTTPS backend origin outside PR builds. |
| #196 Calendar ETag / global coordination / durable recovery | `4d3f1b92c7393b7fe683d190abb163a6ad6fc82d` | Laravel Backend CI, Web and Dart Format Baseline Audit PASS. Windows/Linux and iOS advisory are running; Android, iOS, macOS, Cross-platform Runtime, Auto Detect CI and Dependency Security are pending/queued. | Timeout tests exposed that the timeout wrapped response streaming but not the initial `http.Client.send`; the timeout now covers both send and response. Recovery now persists the newly acquired server run ID before replay and increments attempt count for valid failed→running ledger transitions. Exact-head Flutter/platform matrix remains incomplete. |
| #191 Notification Outbox | `12dc4a5a1902f62998e65cc85f880614f9919110` | Laravel Backend CI and Web PASS; Windows/Android are running; Linux, iOS advisory, Cross-platform Runtime, Auto Detect CI, PR Gate and Dependency Security are queued/pending. Base is `main` at `d184546...`, 0 commits behind; no rebase is required. | Outbox service tests now also cover user-scoped keys, canonical associative payload order and same-type/different-payload conflicts. Outbox remains enqueue-only; no worker, retry/backoff, dead-letter or provider delivery is enabled. |
| #197 execution documentation | `a18a9e5d00104bfcf23fd65da91162b9f4190ee4` | Earlier documentation checks passed; this checkpoint update will trigger new documentation CI. | Draft retained. |

#### Dependency security

- Laravel CI's `composer audit --locked` passed on the current #196 head and on #191's current head; #192's exact-head Laravel audit is queued.
- The first OSV scan passed and reported no issues in 132 Dart packages, but its log showed it had scanned only the root `pubspec.lock`, not the nested PHP lockfile. The workflow was corrected to scan recursively (`-r ./`) so both `pubspec.lock` and `backend/composer.lock` are included. The corrected exact-head scans for #192, #196 and #191 are queued and must not be marked PASS until their logs confirm both lockfiles were scanned and no blocking advisories were reported.
- An OSV scan, Composer audit or lockfile upgrade is evidence for known advisories at that exact lockfile revision; it is not proof that unknown vulnerabilities are absent.

#### Production deployment boundary

- The app uses backend Schedule CAS and Calendar coordination only when `ORGANIZATION_API_BASE_URL` is supplied at build time and the authenticated owner can reach the Laravel API.
- Non-PR Android, iOS, macOS, Windows and Linux release builds, plus GitHub Pages deployment, now fail closed unless the configured origin is HTTPS. PR builds remain available for compile/test evidence without production configuration.
- The repository contains the Laravel API and CI tests; this checkpoint does not prove that a live API is deployed or that the repository variable points to a healthy production database. Confirm the live origin, readiness, authentication, database locking semantics and `APP_KEY` backup/retention before rollout.
- Local-only SharedPreferences mode remains usable for development but does not provide cross-device Schedule CAS, Calendar run serialization or durable server recovery.

#### Current acceptance gates

1. Complete exact-head #192 Flutter analyze/tests, Composer audit/Pint/Laravel tests, Windows/Linux/Web/Android/iOS/macOS builds, native CAS contract and core PR gate.
2. Complete exact-head #196 Flutter format/analyze/full tests, Laravel audit/tests, all platform builds, cross-platform runtime and the corrected recursive Dependency Security scan.
3. Complete exact-head #191 Laravel tests, all required platform/core checks and recursive Dependency Security scan; keep notification delivery explicitly out of scope until a separately reviewed worker/claim/retry design exists.
4. Prove two independent Schedule clients using one revision yield exactly one commit; verify stale editors, A→B→A, absent-state creates and every inventoried writer.
5. Prove two Calendar clients contend on the same owner/Calendar lease; verify expiry/reclaim, expired release rejection, stale-token ledger fencing, duplicate operation idempotency, timeout/ambiguous update/delete reconciliation, and recovery after process termination.
6. Verify explicit history-linked recovery in the UI and show a safe error for missing server history without replay.
7. Confirm live HTTPS backend origin, authenticated access, production database transaction/locking behavior, Laravel `APP_KEY` protection/backup and rollback before any deployment.
8. Obtain human code review and explicit merge authorization. Keep all PRs Draft until exact-head checks and review are complete.

Queued, pending, skipped, cancelled, or older-head checks are not PASS. No merge, deployment, production migration, notification delivery or real-calendar write is authorized by this checkpoint.


### 8.15 Live execution checkpoint — 2026-11-26 23:10 Asia/Bangkok

This checkpoint supersedes 8.14 for current heads and statuses. Main remains `d18454680879a10c6efe9e44ffb37cd0695f25a6`. All implementation PRs remain Draft; no merge, deployment, production migration, notification delivery or real Calendar write has occurred.

| PR | Current head | Exact-head evidence now | Remaining exact-head checks |
|---|---|---|---|
| #192 Grid / Schedule CAS | `0507995bbd6533a369f0850d9e21a3fee9a94d94` | Laravel Backend CI, Web, Android, Linux, Windows and Auto Detect CI PASS. The targeted Dart/Flutter quality job reports one targeted test passed. | PR Gate, iOS build/advisory, macOS/Xcode, Cross-platform Runtime, Schedule CAS Storage Spike, Dart Format Baseline Audit and recursive Dependency Security are queued/pending. |
| #196 Calendar sync / durable recovery | `07f27fd7b31021049ea4ae4753decdb36c7672ba` | Prior head `4d3f1b9...` passed Laravel Backend CI, Web and Dart Format, but those results are stale after timeout, recovery, history UI and failure-state changes. | Current-head Dart Format is in progress; all other current-head jobs, including Laravel, platform builds, Cross-platform Runtime, PR Gate and recursive Dependency Security, are queued/pending. |
| #191 Notification Outbox | `12dc4a5a1902f62998e65cc85f880614f9919110` | Laravel Backend CI, Web, Windows, Android and Linux PASS. | iOS advisory and PR Gate are in progress; Cross-platform Runtime, Auto Detect CI and recursive Dependency Security are queued/pending. Base remains current main with 0 commits behind; no rebase is needed. |
| #197 execution documentation | `d0da7d297a27d9be69fcd472faf500d8ed9f554a` | Earlier Auto Detect CI and Cross-platform Runtime passed on the prior docs head. | Both checks for the current documentation head are queued. |

#### Recovery UI and lease-contention hardening

- The existing History utility now includes sync history and a confirmation-gated `กู้คืน` action. It calls the authenticated recovery service; it does not automatically replay at startup.
- Tests cover confirmation, successful history refresh and a missing-run/recovery error path.
- A Calendar lease conflict now leaves a failed history record with no failed-operation count and no provider write, so the UI does not offer an invalid recovery action for a run that never acquired a lease.
- A resume lease conflict preserves a failed history state rather than leaving a stale `running` entry. A newly acquired server Run ID is persisted before replay so a process crash can resume from the correct ledger.

#### Dependency security

- `composer audit --locked` passed on exact current heads #191 and #192; #196's current-head Laravel run is pending.
- The recursive OSV-Scanner workflow is present on all three implementation branches and is queued on each current head. Its first non-recursive run scanned 132 Dart packages and found no issue, but did not scan nested PHP dependencies; that earlier result remains insufficient.
- Do not mark Dependency Security PASS until the recursive run logs confirm both root `pubspec.lock` and `backend/composer.lock` were scanned and the scan completed without blocking advisories.

#### Remaining deployment boundary

- Production release workflows now require an HTTPS `ORGANIZATION_API_BASE_URL`; PR builds may still compile without production configuration.
- This is a configuration gate, not proof of a live API deployment. Verify that the configured endpoint is reachable, authenticated, backed by a persistent production database with supported transaction/locking behavior, and protected by a backed-up Laravel `APP_KEY` before release.
- Schedule CAS is per Schedule revision. Calendar coordination is per authenticated Google owner plus Calendar ID, so it serializes devices using the same Google account; it is not a tenant-wide lock for different Google accounts sharing one Calendar.

No current exact-head gate is fully green for #192 or #196. Queued, pending, skipped, cancelled and older-head results are not PASS. Keep all PRs Draft and do not merge until the full acceptance matrix, review and production backend readiness are verified.


### 8.16 Live execution checkpoint — 2026-11-26 23:20 Asia/Bangkok

Main remains `d18454680879a10c6efe9e44ffb37cd0695f25a6`. No implementation PR has been merged. The latest exact-head facts below supersede earlier checkpoint statuses.

| PR | Head | PASS evidence | Still pending |
|---|---|---|---|
| #192 | `0507995bbd6533a369f0850d9e21a3fee9a94d94` | Laravel Backend CI, Web, Android, Linux, Windows, Auto Detect CI, Pull Request Gate and Dart Format Baseline Audit. | iOS build/advisory, macOS/Xcode, Cross-platform Runtime, macOS CAS Storage Spike and branch-specific OSV workflow are queued/in progress. |
| #191 | `12dc4a5a1902f62998e65cc85f880614f9919110` | Laravel Backend CI, Web, Windows, Android, Linux and recursive Dependency Security. OSV log confirms `pubspec.lock` (132 packages) and `backend/composer.lock` (110 packages) were scanned; no issues found. | iOS advisory and Pull Request Gate are in progress; Cross-platform Runtime and Auto Detect CI are pending. Base remains current main, 0 commits behind. |
| #196 | `032790e4c18feda7f7d1dbf09580c6bc1d092479` | Previous head `4d3f1b9...` passed Laravel Backend CI, Web and Dart Format, but these are stale after subsequent recovery and History UI changes. | Current-head full CI has not completed; Laravel, Web, Format, platform builds, Cross-platform Runtime, Auto Detect, PR Gate and branch-specific OSV confirmation remain queued/in progress. |
| #197 | `32f575ecd3e4480c0ca10f334cb0c4fa6e830ff0` | Previous documentation checks passed. | Current documentation-head checks pending. |

#### Dependency security evidence shared by all implementation PRs

- Git blob SHA for `pubspec.lock` is identical on #191, #192 and #196: `5786b7243fbfbc765b2d6d72d6da5c78fecb90fc`.
- Git blob SHA for `backend/composer.lock` is identical on #191, #192 and #196: `ea34e82baa0567e4bebea5e990b302685c468d2d`.
- #191's exact-head recursive OSV scan covered both lockfiles (132 Dart and 110 PHP packages) and reported no issues. Composer audit also passed on #191 and #192; #196's previous head ran the same locked graph and passed Composer audit.
- #192/#196 branch-specific OSV jobs are still queued; they remain workflow confirmations, not evidence of different dependency content.

#### Apple runner allocation

- The iOS and macOS workflows accept repository variables `IOS_RUNNER_LABEL` and `MACOS_RUNNER_LABEL`; if unset they default to GitHub-hosted `macos-15`.
- To route to a self-hosted Mac, register an online macOS runner with a custom label (for example `calendar-macos`) and set both variables to that label. A Windows self-hosted runner cannot execute Xcode or produce native iOS/macOS builds.
- Current iOS/macOS jobs are still queued. The presence of the Windows runner does not satisfy the Apple build gate, and no self-hosted macOS runner availability has been verified.

#### Recovery UI and scope

- #196 now includes a confirmation-gated History utility recovery action, but its new exact-head UI/controller tests have not yet completed.
- Recovery is offered only when local history contains a server Run ID. Local-only entries without a server Run ID are explicitly not recoverable from the History utility, avoiding cross-account replay of an unscoped local queue.
- Calendar lease scope remains authenticated Google owner + Calendar ID; different Google accounts sharing a Calendar require a separate tenant-level lock design.

Keep all implementation PRs Draft. No queued, pending, skipped, cancelled or older-head result is PASS. Do not merge until #192/#196 exact-head gates, #191 remaining checks, Apple runner allocation and live backend readiness are verified.


### 8.17 Live execution checkpoint — 2026-11-26 23:30 Asia/Bangkok

| PR | Current head | Latest status |
|---|---|---|
| #191 | `12dc4a5a1902f62998e65cc85f880614f9919110` | Laravel, Web, Windows, Android, Linux, Cross-platform Runtime, Auto Detect CI, Pull Request Gate and recursive Dependency Security PASS. iOS Advisory Evidence remains in progress. The OSV log explicitly scanned the identical Dart/PHP lockfiles and reported no issues. |
| #192 | `10875734d0a956c76933cd8cc94cfa1108585cd3` | Laravel Backend CI PASS; other exact-head jobs are running/queued after the CAS workflow runner-routing change. Previous head `0507995...` had Web, Android, Linux, Windows, Auto Detect CI, Pull Request Gate and Dart Format PASS. |
| #196 | `937708ee9f0e596556a019b2d999e7bbc68485cd` | Latest code includes History recovery UI and local-only fail-closed behavior. Current-head Auto Detect CI is pending; most platform/core jobs are still queued. The prior head's Windows analyzer failure was one `prefer_initializing_formals` lint, fixed by using an initializing formal; the next exact-head Windows run has not completed yet. |
| #197 | `67bb93a8ef297e74d1b4d5ac59d024c6cbaab424` | Documentation checkpoint updated; current documentation CI is pending. |

#### Apple runner allocation detail

The Schedule CAS spike run reports its macOS matrix job as `Native SQLite CAS contract (macos-latest)`, which confirms it is currently using the hosted fallback rather than a configured custom runner label. The iOS and macOS workflows already accept `IOS_RUNNER_LABEL` and `MACOS_RUNNER_LABEL`; the CAS spike now also consumes `MACOS_RUNNER_LABEL`.

To route all Apple jobs to a self-hosted Mac, the repository must have an online macOS runner registered with a custom label (for example `calendar-macos`) and the repository variables `IOS_RUNNER_LABEL` and `MACOS_RUNNER_LABEL` must both be set to that label. This configuration cannot be completed or verified from the repository code alone. Until the Mac runner is online and the variables are set, the Apple jobs remain pending on hosted macOS capacity.

No implementation PR has been merged. PR #191's green checks do not make #192 or #196 green; each PR must pass its own exact-head gates. The production HTTPS backend origin and live database are also not verified. Keep all PRs Draft.


### 8.18 Live execution checkpoint — 2026-11-26 23:36 Asia/Bangkok

- #191 remains at `12dc4a5a1902f62998e65cc85f880614f9919110`: Laravel, Web, Windows, Android, Linux, Cross-platform Runtime, Auto Detect CI, Pull Request Gate and recursive Dependency Security PASS. iOS Advisory Evidence is still in progress; the iOS build itself was not triggered by this backend-only Outbox PR.
- #192 remains at `10875734d0a956c76933cd8cc94cfa1108585cd3`: Laravel Backend CI, Web, Dart Format Baseline Audit and Android PASS. Auto Detect CI and Pull Request Gate are in progress; Windows is in progress; Linux, Cross-platform Runtime, Dependency Security and CAS spike are queued; iOS/macOS builds are pending.
- #196 remains at `937708ee9f0e596556a019b2d999e7bbc68485cd`: Laravel Backend CI PASS. Web, Windows and Linux are in progress; Auto Detect CI, iOS/macOS, Cross-platform Runtime, Pull Request Gate, Dart Format and Dependency Security are pending/queued.
- #197 remains at `2d6313cb4c7a352506a8dc258308ab6acd9d145e`; its documentation checks are queued.

The latest #192 CAS spike has passed Ubuntu; Windows is still running and macOS remains queued on the hosted `macos-latest` fallback. The exact same dependency lockfiles are already covered by #191's successful recursive OSV scan, but #192/#196 branch-specific scanner checks remain pending. No implementation PR is fully complete and none has been merged.


### 8.19 Live execution checkpoint — 2026-11-26 23:42 Asia/Bangkok

- #191 remains at `12dc4a5a1902f62998e65cc85f880614f9919110`: Laravel, Web, Windows, Android, Linux, Cross-platform Runtime, Auto Detect CI, Pull Request Gate and recursive Dependency Security PASS. Only the non-blocking iOS Advisory Evidence reporter remains in progress; the backend-only Outbox PR did not trigger a native iOS build.
- #192 remains at `10875734d0a956c76933cd8cc94cfa1108585cd3`: Laravel, Web, Android, Linux and Dart Format PASS. Cross-platform Runtime and Auto Detect CI tests are in progress; Windows release build and Pull Request Gate are in progress; recursive Dependency Security and CAS spike are queued; iOS/macOS builds are pending.
- #196 remains at `937708ee9f0e596556a019b2d999e7bbc68485cd`: Laravel, Web, Linux and Dart Format PASS. Windows Flutter tests, Android build and Auto Detect CI tests are in progress; iOS/macOS, Cross-platform Runtime, Pull Request Gate and Dependency Security are queued/pending.
- #197 documentation checks remain pending on the latest documentation head.

The #192 CAS spike's Ubuntu and Windows contracts have passed; its macOS contract remains queued on `macos-latest`. No current-head full gate is complete for #192 or #196. All implementation PRs remain Draft and unmerged.


### 8.20 Live execution checkpoint — 2026-11-26 23:50 Asia/Bangkok

- #191 (`12dc4a5...`): Laravel, Web, Windows, Android, Linux, Cross-platform Runtime, Auto Detect CI, Pull Request Gate and recursive Dependency Security PASS. Its remaining iOS Advisory Evidence job is a non-blocking observer; this backend-only PR did not trigger a native iOS build.
- #192 (`10875734...`): Laravel, Web, Android, Linux, Windows, Auto Detect CI, Pull Request Gate, Dart Format and recursive Dependency Security PASS. The exact OSV log scanned both lockfiles (110 PHP + 132 Dart packages) and reported no issues. Cross-platform Runtime is in progress; iOS is queued, macOS/Xcode is pending, and the CAS spike remains queued on its macOS leg. Ubuntu/Windows CAS contract legs passed.
- #196 (`8280b06...`): Laravel Backend CI PASS. Windows, Linux, Web and Android jobs are in progress; Auto Detect CI and Dependency Security are queued; iOS/macOS builds are pending. The prior exact-head run failed two widget tests because the History utility now reads SharedPreferencesAsync and the widget test setup mocked only the legacy SharedPreferences platform. The test setup now installs `InMemorySharedPreferencesAsync`; current-head test evidence is pending.
- #197 (`abf2041...`): current documentation-head Auto Detect CI and Cross-platform Runtime are in progress.

No current implementation PR has been merged. #192's core PR Gate is PASS but Apple and Cross-platform Runtime evidence is still pending. #196's new History UI and test-platform fix have not yet completed their exact-head matrix. Keep all implementation PRs Draft.


### 8.21 Live execution checkpoint — 2026-11-26 23:55 Asia/Bangkok

- #191 (`12dc4a5...`): Laravel, Web, Windows, Android, Linux, Cross-platform Runtime, Auto Detect CI, Pull Request Gate and recursive Dependency Security PASS. iOS Advisory Evidence remains an observer in progress; no native iOS build was triggered by the backend-only change.
- #192 (`10875734...`): Laravel, Web, Android, Linux, Windows, Auto Detect CI, Pull Request Gate, Dart Format and recursive Dependency Security PASS. Cross-platform Runtime remains in progress; iOS is queued, macOS/Xcode is pending, and the CAS spike's macOS leg is queued (Ubuntu/Windows legs passed).
- #196 current head is now `3dc978f707a7ab9797e76fcab0b88f22b73dbd53`. The History widget-test fix now initializes the async SharedPreferences platform and declares `shared_preferences_platform_interface` as a direct dev dependency, resolving the analyzer's `depend_on_referenced_packages` issue. Current-head CI and OSV scan have restarted; no result is yet PASS.
- Important lockfile correction: #196's `pubspec.lock` blob now differs from #191/#192 only because `shared_preferences_platform_interface` changed from transitive to direct-dev classification; package versions remain the same. Do not cite the older identical-blob SHA for current #196 until its new recursive OSV scan passes.
- #197 current documentation checks remain in progress/queued.

No PR has been merged. Keep #192/#196 Draft until the full exact-head platform matrix, Cross-platform Runtime, Apple builds and current-head security scan complete.


### 8.22 Live execution checkpoint — 2026-11-27 00:05 Asia/Bangkok

- #191 (`12dc4a5...`): Laravel, Web, Windows, Android, Linux, Cross-platform Runtime, Auto Detect CI, Pull Request Gate and recursive Dependency Security all PASS. iOS Advisory Evidence completed successfully as a non-blocking observer; this backend-only PR did not trigger a native iOS build.
- #192 (`10875734...`): Laravel, Web, Android, Linux, Windows, Auto Detect CI, Pull Request Gate, Dart Format, recursive Dependency Security and Cross-platform Runtime all PASS. iOS build remains queued; macOS/Xcode is pending; CAS spike remains queued on its macOS leg (Ubuntu/Windows legs passed).
- #196 (`3dc978f...`): Laravel Backend CI, Dart Format Baseline Audit and recursive Dependency Security PASS. The recursive OSV scan checked both lockfiles (110 PHP and 132 Dart packages) with no issues. Windows, Linux, Web, Android, Auto Detect CI, Cross-platform Runtime and Pull Request Gate are still running/in progress; Apple builds remain pending.
- #197 latest documentation checks remain in progress/queued.

#192 has a green core PR Gate but is not fully platform-complete because Apple build and macOS CAS evidence are pending. #196's exact-head test matrix is still running after the SharedPreferencesAsync test-platform fix. No implementation PR has been merged.



### 8.23 Live execution checkpoint — 2026-11-27 (current GitHub evidence)

This section supersedes prior PR/CI snapshots above where they conflict. Main is still `d18454680879a10c6efe9e44ffb37cd0695f25a6`. This checkpoint records GitHub API evidence collected for the exact PR head SHAs; it does not certify the overall product as complete.

| PR | Exact head | Completed checks observed | Outstanding checks / disposition |
|---|---|---|---|
| #191 Notification Outbox | `12dc4a5a1902f62998e65cc85f880614f9919110` | Laravel Backend CI, Web, Windows, Android, Linux, Pull Request Gate, Auto Detect CI, Cross-platform Runtime, Dependency Security and iOS Advisory Evidence all completed successfully. | Backend enqueue foundation only; no delivery worker/provider is implemented. Keep Draft pending review and decision on delivery scope. |
| #192 Grid import / Schedule CAS | `10875734d0a956c76933cd8cc94cfa1108585cd3` | Android, Linux, Windows, Web, Laravel Backend CI, Pull Request Gate, Auto Detect CI, Dart Format Baseline Audit, Dependency Security, Cross-platform Runtime and iOS build completed successfully. | macOS/Xcode is pending. Schedule CAS Storage Spike is still in progress: Ubuntu and Windows passed; macOS leg is still running. Do not mark Apple/CAS matrix complete. |
| #196 Calendar ETag / lease / durable operation ledger | `3dc978f707a7ab9797e76fcab0b88f22b73dbd53` | Laravel Backend CI, Web, Windows, Android, Linux, Pull Request Gate, Auto Detect CI, Cross-platform Runtime, Dart Format Baseline Audit and Dependency Security completed successfully. | iOS and macOS Xcode builds are queued; iOS Advisory Evidence is in progress. Do not treat queued jobs as passed. |
| #197 execution documentation | `da9e81353851df38a7ccbaecc4dfabe1e8ea780c` | Auto Detect CI and Cross-platform Runtime completed successfully on this documentation head. | Documentation PR remains Draft; this checkpoint itself must run through the updated documentation PR checks after commit. |

#### Apple runner routing — verified workflow configuration

- `.github/workflows/ios.yml` uses `vars.IOS_RUNNER_LABEL || 'macos-15'`.
- `.github/workflows/macos.yml` uses `vars.MACOS_RUNNER_LABEL || 'macos-15'`.
- `.github/workflows/schedule-cas-spike.yml` uses `vars.MACOS_RUNNER_LABEL || 'macos-latest'` for its macOS matrix leg.
- The current #192 macOS build job and #196 iOS/macOS build jobs are queued; no completed Apple job evidence is available for those heads. The CAS macOS leg is in progress, not yet completed.
- Repository variable values and online self-hosted Mac runner availability have not been verified by the available evidence. Do not claim that the custom Mac runner is configured or available. A Windows runner cannot execute Xcode.

#### Code-level acceptance still open

- #192 and #196 remain Draft and unmerged. A green core PR Gate does not substitute for outstanding Apple/CAS jobs or code review.
- #196's documented lease scope is authenticated Google owner + Calendar ID; it is not a tenant-wide lock across different Google accounts sharing one Calendar.
- Local-only mode without the configured HTTPS shared backend remains without cross-device Schedule CAS, Calendar run serialization or server-side recovery.
- The active workflow's compatibility preview/sync paths must be checked to ensure a stable real Schedule ID reaches the durable Calendar ledger. A default `unknown` Schedule ID must never be treated as a valid production scope; fail closed until the real identity is propagated.
- Production backend reachability, persistent database locking/transaction behavior, authentication, Laravel `APP_KEY` backup/restore, and controlled Google test-calendar behavior remain unverified.
- No real Calendar writes, production migration, deployment, notification delivery or merge were performed by this checkpoint.

No queued, pending, in-progress, skipped, cancelled or older-head result is PASS. Keep all implementation PRs Draft until required exact-head checks, code review and production-readiness evidence are complete.


### 8.24 Live execution checkpoint — 2026-11-27 (refreshed exact-head evidence)

- #191 remains at `12dc4a5a1902f62998e65cc85f880614f9919110`; all 10 PR-triggered workflows observed are completed successfully. This remains an enqueue-only notification foundation, not delivery.
- #192 remains at `10875734d0a956c76933cd8cc94cfa1108585cd3`. Android, Linux, Windows, Web, Laravel Backend CI, Pull Request Gate, Auto Detect CI, Dart Format Baseline Audit, Dependency Security, Cross-platform Runtime and iOS completed successfully. The Schedule CAS Storage Spike completed successfully on Ubuntu, Windows and macOS. The separate macOS/Xcode build job is **cancelled**, not passed. Keep #192 Draft until the cancelled Apple build is rerun successfully and review/acceptance is complete.
- #196 remains at `3dc978f707a7ab9797e76fcab0b88f22b73dbd53`. Backend, Web, Windows, Android, Linux, Pull Request Gate, Auto Detect CI, Cross-platform Runtime, Dart Format and Dependency Security completed successfully. Both macOS/Xcode and iOS/Xcode jobs remain queued. These are not PASS.
- #197 documentation head `8a5db3b5f02e3cd753f29bc4fb4eac7be6a6808f`: Auto Detect CI and Cross-platform Runtime completed successfully; all jobs in both workflows completed successfully.
- #196 code review found that the compatibility sync path omits a real Schedule ID, so the plan builder's default `unknown` value can reach the shared-backend lease request. The backend currently validates only that `schedule_id` is a non-empty string; it does not reject the literal `unknown`. This is an identity/ledger correctness defect, not evidence of an observed provider write.
- A fail-closed guard and regression test have now been committed to the #196 branch: `06c34f29e83da7d8cc52414d83010605bec0c25e` adds the shared-mode guard; `990ba523367ca15794561ec27209723c87dcd525` adds a test proving an unknown Schedule ID is rejected before lease acquisition or Google Calendar mutation. Local test execution is not claimed; exact-head CI must validate these commits.
- The guard is intentionally limited to configured shared-backend mode. Local-only compatibility behavior remains unchanged. The durable correction for the compatibility workflow is still to propagate a real Schedule ID from the canonical Schedule, or to make that legacy path unavailable in shared mode.

No implementation PR has been merged. No Google Calendar provider write, production migration or deployment was performed. Cancelled, queued, pending, in-progress, skipped and older-head checks are not PASS.


### 8.25 Live execution checkpoint — 2026-11-27 (after targeted rerun)

- #192's previously cancelled macOS/Xcode job was explicitly re-queued with a single-job rerun. Its workflow run now reports the macOS job as queued; this is not PASS. The three-platform Schedule CAS Storage Spike remains completed successfully on Ubuntu, Windows and macOS.
- #196 latest head remains `990ba523367ca15794561ec27209723c87dcd525`. Backend CI, Dart Format Baseline Audit and Dependency Security have now completed successfully on this head. Windows and Android are in progress; Web, iOS advisory and PR Gate are in progress; Linux, Cross-platform Runtime and Auto Detect are queued; iOS/macOS Xcode are pending. No queued or in-progress result is PASS.
- #197 latest documentation head `5be4da36d9cb8068d5d67d7822c7b0ae977f8e3f` now has Cross-platform Runtime and Auto Detect CI queued. The previous docs head `8a5db3b5f02e3cd753f29bc4fb4eac7be6a6808f` passed both workflows, but that older-head evidence does not certify the new docs commit.
- No PR was merged. The #196 shared-mode Schedule identity guard and regression test remain subject to the full current-head matrix.


### 8.26 Live execution checkpoint — 2026-11-27 (roster date-gap repair)

- PR #192 head is now `f685d7b3bd047668828bebeea269d02215ca8c52`, based on main `d18454680879a10c6efe9e44ffb37cd0695f25a6`.
- Parser commit `15afa477a16e4a676b0a002b96dfbccd1ce6ad1c` adds an explicit missing-date report when a duplicate day in a declared range leaves dates unresolved, even when the date header is too short for the near-complete-header heuristic.
- Regression commits `6aa72e6259bd80682648e45a23d9382692134746` and `f685d7b3bd047668828bebeea269d02215ca8c52` assert that the November 2026 X-OPD header containing 1–16, 30, 30 reports both duplicate day 30 and missing 17–29 November. The last commit corrects the assertion to the parser's Gregorian date-message format.
- Exact-head CI for #192 is running. At the snapshot: Linux, Windows, Web, Laravel Backend CI, Dependency Security and Pull Request Gate are in progress; Auto Detect, Dart Format, Cross-platform Runtime, Android, iOS, macOS/Xcode and iOS Advisory are pending/in progress. No current-head result is yet confirmed PASS.
- Previous-head macOS/Xcode job for #192 was cancelled and has no runner name or step logs; it is not a test failure diagnosis and not a PASS. The prior CAS spike's three OS legs passed on its then-current head, but the latest parser commits require revalidation.
- On #196 head `990ba523367ca15794561ec27209723c87dcd525`, backend, format, dependency security, web, Linux, Android, Windows, Auto Detect, Cross-platform Runtime, and PR Gate passed. iOS and macOS Xcode jobs were cancelled without a runner name or step logs. Do not rerun blindly; verify the configured `IOS_RUNNER_LABEL` / `MACOS_RUNNER_LABEL` and actual available runner labels in repository settings first. No runner configuration has been changed in this work.
- The iOS and macOS workflow files use repository variables with `macos-15` fallback. The CAS spike uses `MACOS_RUNNER_LABEL` with `macos-latest` fallback. Repository Actions variable and runner inventory endpoints were not readable through the available connector; the actual configured variable values and self-hosted runner availability remain unverified.
- No implementation PR merged; no production data writes or deployment. Cancelled/queued/pending/in-progress/older-head checks are not PASS.


### 8.27 Live execution checkpoint — 2026-11-27 (production local Schedule CAS)

- PR #192 current head: `076f56831a5f4f553dac3aaa55cc718a5bfc9bf1`, base `d18454680879a10c6efe9e44ffb37cd0695f25a6`.
- Production `SharedPreferencesScheduleRepository` now implements `ScheduleRevisionSource` and `ConditionalScheduleWriter`. It uses a per-Schedule asynchronous lock shared by repository instances in the same Dart isolate, persisted monotonic generation plus payload fingerprint, exact snapshot revisions, and versioned absent-state revisions.
- Conditional local writes compare the caller-owned revision while holding the lock. Delete advances the generation and preserves a tombstone generation key; recreating the same content cannot reuse the old revision (ABA protection).
- Dual-slot persistence remains intact. Generation advances before switching the active pointer, so a failed pointer write leaves the old active payload readable but invalidates stale editor revisions.
- `ScheduleController` captures a current absent revision before creating a new Schedule, or verifies that its current in-memory content exactly matches the persisted snapshot before capturing that revision. Grid import, controller save, imported-schedule creation and the legacy AppController canonical writer now use conditional writes when the repository supports them.
- AppController no longer replaces an in-memory roster with an empty Schedule merely because the local repository has no saved record.
- Tests added for concurrent writes from two repository instances sharing one store, stale writer rejection, delete/recreate ABA protection, failed active-pointer fencing, and ScheduleController's first-save revision capture / mismatched snapshot rejection.
- Local SharedPreferences CAS is process-scoped and is not a cross-process or cross-device lock. The authenticated Laravel repository remains required for shared multi-device CAS.
- Exact-head CI for #192: Dart Format, Dependency Security and Laravel Backend CI passed. Windows, Linux, Android, Web, Cross-platform Runtime and PR Gate were in progress; the CAS Spike had Ubuntu/Windows in progress and macOS queued; iOS/macOS Xcode were pending. No incomplete result is PASS.
- Previous #192 and #196 Apple Xcode jobs were cancelled with no runner name or step logs. Their workflow files use `IOS_RUNNER_LABEL` / `MACOS_RUNNER_LABEL` repository variables with hosted-label fallbacks. The actual variable values and runner inventory remain unverified through the available connector; no runner settings were changed.

No implementation PR merged. No production data writes or deployment. Queued, pending, in-progress, skipped, cancelled and older-head checks are not PASS.


### 8.28 Live execution checkpoint — 2026-11-27 (local CAS analyzer repair)

- PR #192 current head is `825e54d4a46fdc0b1a60043e6c74e172b509a0dd`.
- Previous head `076f56831a5f4f553dac3aaa55cc718a5bfc9bf1` exposed two CI failures: static analysis and Linux release compilation both rejected reading `.message` from `Result<Schedule>`; static analysis also found a stale repository variable in the two-instance contention test and a redundant cast.
- Fixed by typing the revision-capture helper as `Failure<Schedule>?`, correcting the test to read from the first shared-store repository, and removing redundant casts. Commits: `e1cc31499eedb0217192514039052cc7a5985dc2`, `900b794c4b67e725caf8cc93eb6d2c188b829120`, `838a2c104174d8fae6022abc8e2abadbae8ad05a`.
- Additional controller regression: the constructor captures the original Schedule before the month-view initializer can add an empty viewed month. When the controller has no cached revision, it compares the persisted Schedule with that original snapshot, not the UI-mutated current value. Commits: `67d95ef2c36cdb00aa31c3f15234cd64449656e5`, test `825e54d4a46fdc0b1a60043e6c74e172b509a0dd`.
- Exact-head CI on `825e54d4a46fdc0b1a60043e6c74e172b509a0dd`: Dart Format Baseline Audit, Dependency Security and Laravel Backend CI passed. Linux, Windows, Web and Android were in progress; PR Gate and iOS Advisory were in progress; Cross-platform Runtime and CAS Spike were queued; iOS/macOS Xcode were pending. No other current-head result is PASS.
- The latest tests cover local absent-revision creation, exact persisted snapshot matching, mismatched stale snapshot rejection, same-revision contention across two repository instances, stale-write rejection, delete/recreate ABA fencing and active-pointer failure fencing.
- Local CAS remains limited to one Dart isolate/process. It is not advertised as cross-device synchronization. The backend Schedule CAS remains the multi-device source of truth when configured.

No implementation PR merged. No production data writes or deployment. Queued, pending, in-progress, skipped, cancelled and older-head checks are not PASS.


### 8.29 Live execution checkpoint — 2026-11-27 (sequential AppController CAS)

- PR #192 exact head: `483cab074abb8d0daf73a71f7a424c7072dcdc3c`.
- A further writer audit found that AppController retained the pre-save in-memory Schedule object after a successful conditional write. A later edit could therefore carry an old/unmapped snapshot revision. The controller now tracks the last successfully persisted Schedule and uses it as the base for queued writes, updating it only after a successful CAS.
- `LegacyScheduleConversion.withSchedule` rebinds the saved canonical snapshot while preserving source sheet, source cell, category, exclusion, generated, linked-shift, source-color, custom-title, Calendar color and relationship-comment metadata.
- `adoptCanonicalSchedule` waits for queued writes before adopting a new canonical snapshot. Regression tests cover three sequential local AppController writes and metadata preservation after rebinding.
- Current exact-head CI for #192: Laravel Backend CI passed. Linux, Windows, Android, iOS advisory, Dart Format, Auto Detect, Cross-platform Runtime, PR Gate and CAS Spike are queued/in progress; Web and Apple Xcode builds are pending. The latest head has no other certified PASS yet.
- Earlier compile/analyzer issues on head `076f56831a5f4f553dac3aaa55cc718a5bfc9bf1` were corrected on later commits. Head `825e54d4a46fdc0b1a60043e6c74e172b509a0dd` had several jobs cancelled as a newer commit superseded it; those cancellations are not PASS. Only exact-head checks count for merge.

No implementation PR merged. No production data writes or deployment. Local CAS is process-scoped; multi-device CAS remains server-enforced. Queued, pending, in-progress, skipped, cancelled and older-head checks are not PASS.


### 8.30 Live execution checkpoint — 2026-11-27 (compatibility Calendar sync identity)

- PR #196 current head: `3a0c7de7b2f0e520ceb3bd1b481a16c322d97ed4`, based on `d18454680879a10c6efe9e44ffb37cd0695f25a6`.
- The previous fail-closed guard prevented the literal `unknown` from entering shared lease scope, but left the compatibility path unable to sync when it had no schedule identity. The compatibility workflow now requires a stable Schedule ID for both candidate and user-change previews. AppController supplies `canonicalSchedule.id`; the workflow passes that ID through CalendarSyncCoordinator to CalendarSyncPlanBuilder.
- Switching between canonical Schedule preview and compatibility preview clears stale preview/preparation/validation/result state, preventing an old canonical plan from being executed after a candidate preview.
- Regression tests prove a compatibility candidate preview records the canonical Schedule ID in sync history and that blank/unknown IDs are rejected before provider reads. Exact-head CI for #196: Laravel Backend CI, Dart Format and Dependency Security passed; Linux, Windows, Android, Web, Cross-platform Runtime, PR Gate, iOS Advisory and Auto Detect were in progress/queued; Apple Xcode builds pending. No exact-head platform matrix is complete.
- PR #192 head `483cab074abb8d0daf73a71f7a424c7072dcdc3c`: Dart Format, Dependency Security, Laravel Backend CI, Linux, Android, Web, Cross-platform Runtime and Auto Detect passed. Windows, PR Gate and iOS Advisory remained in progress. Schedule CAS Spike passed on Ubuntu and Windows; macOS queued. iOS/macOS Xcode pending.
- PR #197 docs head `23cf9e11aa780f37d323decc6cce766bac0cf7cc`: Auto Detect CI passed; Cross-platform Runtime in progress.

No implementation PR merged. No production Calendar writes, production Schedule writes, migration or deployment. Apple build and CAS macOS queue are not PASS. Queued, pending, in-progress, skipped, cancelled and older-head checks are not PASS.


### 8.31 Live execution checkpoint — 2026-11-27 (compile-time Schedule identity enforcement)

- PR #196 current head: `22d648ee1ef522f3b9e06c1c0b82e39b52f51fc1`.
- Exact-head Auto Detect CI on the prior head `3a0c7de7b2f0e520ceb3bd1b481a16c322d97ed4` found two facade callsites that omitted the newly required Schedule ID. The CalendarWorkflowFacade now requires the Schedule ID for compare/synchronize, stores it with the comparison, rejects a comparison reused for another Schedule, and validates the ID before Calendar reads.
- `CalendarSyncPlanBuilder.build` and `CalendarSyncCoordinator.synchronize` now require `scheduleId` at compile time rather than defaulting to `unknown`. The plan-builder test asserts the identity is retained.
- Current exact-head CI for #196 has restarted on `22d648ee1ef522f3b9e06c1c0b82e39b52f51fc1`; all checks are queued, pending or in progress at this snapshot. No exact-head result is yet PASS.
- Previous head #192 `483cab074abb8d0daf73a71f7a424c7072dcdc3c`: Dart Format, Dependency Security, Laravel Backend CI, Linux, Android, Web, Cross-platform Runtime and Auto Detect passed; Windows passed; PR Gate and iOS Advisory were still in progress. CAS Spike passed on Ubuntu and Windows; macOS queued. Apple Xcode builds remained pending.
- Docs PR #197 head `3b388994e55423a0ae8b6e45a1271462ff9cfca5`: Auto Detect CI was queued and Cross-platform Runtime was in progress at the latest observed snapshot.

No implementation PR merged. No production Calendar writes or deployment. Required Schedule identity is now enforced through the compatibility workflow, facade, coordinator and plan builder; exact-head CI remains mandatory. Queued, pending, in-progress, skipped, cancelled and older-head checks are not PASS.
