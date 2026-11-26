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
- PR #193 (Xcode runner queue coalescing) remains Draft. Its inspected head had 15 successful checks and one skipped Pages deployment; it has no submitted review. PR #192 also edits the same iOS/macOS workflow files, so #193 must be resolved before rebasing/revalidating #192.
- PR #192 (Grid import, Schedule API and recovery foundations) remains Draft. Its inspected head had successful workflow checks, including Flutter, backend, cross-platform and native SQLite spike jobs; Pages deployment was skipped. It is a large change and requires code-level review, migration-order review, exact-head tests, and production-writer inventory reconciliation.
- PR #191 (notification outbox foundation) remains Draft and requires independent migration, idempotency, retry and delivery-path review.
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
2. The sync reliability specification explicitly states that simultaneous update/delete coordination across independent clients is not yet guaranteed.
3. The Calendar preview document still lists integration work: build concrete plans with existing provider event IDs, timezone-aware event creation, connect preview to import/comparison, and persist/communicate retry and partial-failure outcomes. These statements must be reconciled with source and tests before marking any item complete.
4. The Grid recovery design says local two-slot journal and remote journal/Schedule writes are not one cross-table database transaction. The remote committed journal is a recoverable commit intent, not proof that the canonical Schedule write completed.
5. The Schedule CAS ADR remains a prototype/evidence gate. Do not promote the isolated spike or claim global writer safety until every production Schedule writer is inventoried and migrated or safely coordinated.
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