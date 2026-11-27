# Requirements Traceability

**Review date:** 2026-11-27  
**Repository snapshot:** `68ef85361c2d08e2970160a36475592010d908f7`  
**Status:** Evidence-based partial inventory. PARTIAL, MISSING, UNKNOWN and NEEDS REVIEW remain open work.

| Requirement | Primary implementation | Evidence / test surface | Status and remaining gap |
|---|---|---|---|
| Application architecture | `lib/core/di/app_dependencies.dart`, `lib/controller/app_controller.dart`, `lib/ui/app_shell.dart` | Flutter unit/widget/integration tests | PARTIAL — large controller and shell remain candidates for incremental extraction with behavior-preserving tests. |
| Frontend UI / UX | `lib/features/**/presentation/` | Widget tests and device-width checks | NEEDS REVIEW — verify critical flows at phone, tablet and desktop widths. |
| Backend / API | `backend/routes/api.php`, `backend/app/Http/Controllers/Api/V1/` | `backend/tests/Feature/` | IMPLEMENTED FOUNDATION — keep API docs and contract tests aligned with routes, validation and authorization. |
| Database / migrations | `backend/database/migrations/` | Laravel feature tests | IMPLEMENTED FOUNDATION — migrations are canonical; verify backup/restore and data-retention behavior. |
| Calendar engine | `lib/features/calendar_engine/` and Google Calendar gateways | `test/sce_*`, gateway and reconciliation tests | IMPLEMENTED FOUNDATION — live authorized Google integration and ambiguous network outcomes require environment-backed verification. |
| Scheduling engine | `lib/features/schedule_generation/`, `lib/features/schedule/` | schedule generation/validation tests | PARTIAL — expand large-roster and edge-case coverage. |
| Day/week/month/year views | `ScheduleWorkspacePage`, `ScheduleGrid`, `ScheduleYearOverview` | schedule page/widget tests | IMPLEMENTED FOUNDATION — source contains all four modes; verify year navigation, 12-month rendering, month selection and cross-month weeks. Year overview source is present; retain responsive and navigation regression tests. |
| Date/time/timezone | `RosterSyncPeriodFilter`, Google Calendar gateway | parser and gateway tests | PARTIAL — Bangkok wall-time conversion exists; add a cross-device timezone matrix and daylight/time-boundary cases where applicable. |
| Timeline history | `RosterRevisionService`, `RosterTimelineGenerator`, timeline archive | revision reader, parser and timeline tests | PARTIAL — historical revisions are read and transformed into timelines; blank/unassigned slots and removed roster positions need explicit semantics. |
| Historical restore | `RosterRevisionService` (read-only) | no complete restore flow established | MISSING for write/restore — define preview, conflict policy, explicit confirmation, audit trail and recovery; any Drive write-scope expansion requires separate approval. |
| Shift transactions | `lib/features/shift_exchange/`, `backend/app/Services/ShiftTransactions/` | backend API, composer and history widget tests | IMPLEMENTED FOUNDATION — PR #173 transaction foundation plus PR #187 sync-attempt/event reconciliation are merged; live provider calls remain unimplemented. |
| Shift Pay modes, persistence and calculation | Flutter source resolution plus backend profile/rule persistence and immutable calculation snapshots (PRs #181, #183, #186) | Flutter and Laravel tests; exact-head CI passed for merged PRs | IMPLEMENTED FOUNDATION — assignment/monthly statement integration and decimal precision parity remain open. |
| Organization membership | `OrganizationController`, organization admin gateway/panel | Laravel API and Flutter admin tests | IMPLEMENTED; POST-MERGE VERIFICATION — PR #171 merged the authenticated Flutter gateway, organization-scoped audit panel, cursor pagination, stale-response protection and tenant-isolation tests. Verify on current main. |
| Authentication / authorization | Google ID-token middleware and organization policies | token, middleware and authorization tests | IMPLEMENTED FOUNDATION — maintain issuer/audience/expiry and role/tenant regression coverage. |
| Notifications / reminders | `lib/domain/services/notification_service.dart` | interface exists; no concrete implementation found in inspected source | MISSING — implement platform delivery, permission handling, schedule/cancel, lifecycle behavior and tests after deciding supported platforms. |
| Web Push | subscription/API groundwork | backend feature tests and deployment configuration | PARTIAL — verify VAPID sender, RFC 8291 encryption, durable queue/scheduler, retries and user opt-in before claiming delivery support. |
| Import / export | shift parser, local file service, Drive archive, PDF/report services | parser/import/report tests | PARTIAL — map supported file formats, failure recovery and export fidelity. |
| Data validation | workbook scanner/parser diagnostics and Laravel validation | parser/API validation tests | IMPLEMENTED FOUNDATION — add property/fuzz tests for malformed, oversized and adversarial inputs. |
| Error handling / recovery | resilient sync executor, resume service and failed-operation storage | sync recovery tests | IMPLEMENTED FOUNDATION — verify retry, ambiguous provider responses and process restart across supported platforms. |
| Performance / reliability | batching, caching and retry services | no repository-wide baseline verified | UNKNOWN — add reproducible large-workbook, event-volume, memory and long-history benchmarks. |
| Local data protection | SharedPreferences/local revision and failed-operation persistence | source review and platform security tests | NEEDS REVIEW — define sensitivity, encryption, retention, export and deletion semantics. |
| Automated testing | `test/`, `integration_test/`, `backend/tests/` | unit, widget, integration and Laravel suites | PARTIAL — map every critical user journey to an assertion-bearing E2E test; file count alone is not coverage. |
| CI/CD and deployment | `.github/workflows/` | exact-head Actions and Pages metadata | UNKNOWN for current production release — latest observed deployed source SHA predates current main `dcb51b6`; verify deployment.json and live HTTP checks for the exact main SHA. |
| Security / dependencies | Google token middleware, Laravel authorization, Composer lockfile | security tests and `composer audit --locked` | IMPLEMENTED FOUNDATION — Composer remediation/gate merged in #154; rerun on current head and continue local-data/tenant-isolation review. |
| Documentation | root docs, `docs/`, `backend/` | Documentation Index, API/schema guides, this matrix | IN_PROGRESS — status and roadmap require ongoing source-based reconciliation. |

| Calendar Sync reconciliation | Backend attempt history and per-transfer provider mappings (PR #187) | Laravel retry/idempotency/validation tests | IMPLEMENTED FOUNDATION — live Google Calendar API creation and ambiguous external timeout reconciliation remain unimplemented. |

## Explicitly unverified

- Live Google Calendar behavior with an authorized account, including provider throttling, ambiguous insert outcomes and recovery after process restart.
- Correct interpretation of the original X-OPD November 2569 and US Clinic ภปร.4 workbook layouts; the original workbooks are required.
- Safe historical roster restoration. The inspected revision service is explicitly read-only.
- Concrete scheduled notifications and Web Push delivery in supported production environments.
- Post-merge membership audit behavior on current main, including owner/admin authorization, tenant isolation, pagination and refresh.
- Responsive behavior across real device sizes and accessibility navigation.
- Performance under large workbooks, many calendar events and long revision histories.
- Exact current-main production deployment; last observed deployed application-source SHA is older than current main.
- Current main exact-SHA workflow evidence; no PR-triggered workflow runs were returned for the current merge commit in this audit.

## Evidence rules

- Source proves that code exists, not that behavior works.
- Tests prove only the cases they execute.
- A skipped, queued, cancelled or missing check is not PASS.
- A build does not prove live integration, security or data integrity.
- Destructive data operations, OAuth write-scope expansion, repository-setting changes and deployment require their own explicit authorization.
- Re-run this matrix after every material merge and update the current snapshot SHA.

---

## 2026-11-24 — Grid import recovery and concurrency follow-up

| Requirement | Scope | Current source evidence | Status | Remaining proof |
|---|---|---|---|---|
| RI-025 | Reject recovery when canonical Schedule advanced after the journal base revision | `GridRosterImportWorkflow.recover`; `test/grid_roster_import_workflow_test.dart` | SOURCE + TEST ADDED; NOT EXECUTED | Run focused Flutter test on exact head |
| RI-026 | Idempotent recovery when canonical Schedule already matches accepted fingerprint | `GridRosterImportWorkflow.recover`; workflow regression test | SOURCE + TEST ADDED; NOT EXECUTED | Run focused Flutter test on exact head |
| RI-027 | Atomic conditional Schedule persistence across concurrent writers | `ScheduleRepository` currently has no conditional write contract; SharedPreferences uses read/write/pointer steps | MISSING | Implement transaction-backed CAS and interleaved-writer tests |
| RI-028 | Startup discovery/recovery for all journaled Schedule IDs | Journal currently accepts a Schedule ID; no durable index/enumeration contract | MISSING | Add versioned index, rebuild/recovery semantics and startup conflict reporting |

The new [Grid import recovery and concurrency contract](docs/GRID_IMPORT_RECOVERY_AND_CONCURRENCY.md) defines the safe implementation boundary and release gates. The two new workflow tests are source additions only; they have not been executed in a Flutter-capable environment. No atomic concurrency guarantee is claimed.


---

## 2026-11-24 — Schedule persistence writer inventory

**Inspected branch:** `docs/universal-roster-intelligence-masterplan-2026-11-24`  
**Inspected source head before this documentation update:** `229f896f2d9594e0b536fdb855d8d1fa619f5cb3`  
**Evidence type:** static source and test-source inspection only; runtime tests were not executed.

| Requirement | Scope | Source evidence | Status | Remaining proof |
|---|---|---|---|---|
| RI-029 | Identify canonical Schedule persistence contract and production adapter | `ScheduleRepository`; `SharedPreferencesScheduleRepository`; two-slot payload and active pointer | PASS — source inspected | Runtime/platform durability tests remain separate |
| RI-030 | Inventory editor, legacy compatibility, tabular import, Grid commit and Grid recovery write paths | `ScheduleController.saveSchedule`; `AppController._replaceLegacyShifts`; `AppController.adoptCanonicalSchedule`; `AppDependencies.saveImportedSchedule`; `GridRosterImportWorkflow.commit/recover` | PASS — primary paths identified | Complete call-graph confirmation and exact-head tests |
| RI-031 | Migrate every production writer to atomic conditional persistence | Current writers call ordinary `ScheduleRepository.save`; interface has no CAS capability | MISSING | Shared conditional write use case and independent-writer atomicity tests |
| RI-032 | Define conditional deletion and verify all production delete callers | Repository exposes `delete`, but no production caller was found in inspected paths | UNKNOWN | Exhaustive call graph; define tombstone/conditional-delete semantics before implementation |
| RI-033 | Identify generation-to-persistence commit path | Generation core returns candidates; no production approval/save orchestration was established in this audit | UNKNOWN | Trace UI/use-case orchestration and define approved durable commit |
| RI-034 | Replace Grid final read/save race with atomic CAS | Grid commit/recovery perform revision/fingerprint checks before ordinary save | MISSING | Interleaved two-writer test proving exactly one succeeds |
| RI-035 | Prove exact-head runtime regression suite | Test sources exist for repository, editor and Grid workflow | SKIPPED | Run Flutter/Dart tests on a runner and bind results to exact SHA |

The [Schedule Persistence Writer Inventory](docs/SCHEDULE_PERSISTENCE_WRITER_INVENTORY.md) records writer IDs W-01 through W-05, facade F-01, storage operation S-01, current guards, test-source evidence and migration order.

**Important:** PASS here means the relevant source path was identified and inspected. It does not mean the tests ran or that the persistence behavior is concurrency-safe. The AppController future queue is instance-local, and Grid's repeated reads do not close the final read/save race. No production CAS or startup journal discovery is claimed.


## 2026-11-24 — Monotonic revision-token contract refinement

| Requirement | Scope | Evidence | Status | Remaining proof |
|---|---|---|---|---|
| RI-036 | Monotonic Schedule revision tokens, ABA protection and tombstone-based conditional delete | Proposed ADR contract: generation + state + canonical content fingerprint; no implementation selected | PROPOSED — design only | Platform-backed atomic transaction, migration and interleaved-writer tests |


## 2026-11-24 — Cross-platform persistence candidate screening

| Requirement | Scope | Evidence | Status | Remaining proof |
|---|---|---|---|---|
| RI-037 | Screen transaction-capable storage candidates against active release platforms | Drift, sqflite companion packages, Sembast and existing SharedPreferences documented in the persistence ADR | PARTIAL — package-documentation screen only; no package selected | Prototype and execute atomicity, crash, migration and Web multi-tab tests on all five active targets |


## 2026-11-24 — Isolated Drift/SQLite CAS spike

| Requirement | Scope | Evidence | Status | Remaining proof |
|---|---|---|---|---|
| RI-038 | Prototype atomic conditional create/update/delete with monotonic revisions and tombstones | Isolated Drift package source and seven Dart test cases; independent SQLite 3.46.1 SQL spot-check with two connections observed one save and one conflict | PARTIAL — SQL semantics spot-checked; Dart/Drift runtime UNKNOWN | Generate Drift code and run tests; prove native OS matrix, Android/iOS device integration, Web multi-tab and crash recovery |

The spike has its own `pubspec.yaml` and is not a root application dependency. The root `pubspec.yaml`, root lockfile, production SharedPreferences repository, production Schedule schema and all production writer paths remain unchanged. The new workflow tests native SQLite behavior on Windows, Linux and macOS runners; this does not by itself prove Android/iOS runtime behavior or Web multi-tab behavior.


---

## 2026-11-26 — Caller-bound Schedule revisions and Grid conditional commit

| Requirement | Scope | Current source evidence | Status | Remaining proof |
|---|---|---|---|---|
| RI-039 | Carry authoritative backend generation token through Grid review and provenance; reject ABA | `ScheduleRevisionSource`; `GridRosterImportWorkflow.revisionFor`; Grid workflow ABA regression | SOURCE + TEST ADDED | Run focused Flutter tests on exact head |
| RI-040 | Grid commit/recovery use the exact reviewed/base revision at the backend write boundary | `ConditionalScheduleWriter.saveIfRevision`; `BackendScheduleRepository.saveIfRevision`; Grid workflow race regression | SOURCE + TEST ADDED — Grid backend path only | Run backend API and Flutter tests on exact head; controlled concurrent-writer verification |
| RI-041 | Migrate every editor, legacy AppController and imported-Schedule writer to caller-owned revision tokens | Legacy writers remain on local SharedPreferences; imported facade uses generic cached `save` | MISSING / OPEN | Per-controller snapshot tokens and explicit conditional save for every production writer |
| RI-042 | Provide atomic compare-and-set for local/offline fallback across independent instances | SharedPreferences two-slot repository remains non-transactional | MISSING / OPEN | Select a cross-platform storage transaction strategy and run multi-instance/platform crash tests |

The backend Grid path now closes the final read/save race and ABA gap by passing the exact server revision token from review/journal into the conditional write. This does not make the entire application concurrency-safe: other writer paths and the local fallback remain open. No global CAS claim is made.


## Live execution checkpoint — 2026-11-27

- Audited main SHA: `68ef85361c2d08e2970160a36475592010d908f7`.
- PR #192 is the integration branch for universal roster work: horizontal/vertical parser, XLSX scanner, source provenance, review and row correction are being kept in one workflow.
- PR #200 is superseded by the integrated implementation in #192; do not merge both parser branches.
- PR #199 orientation primitives and tests are being consolidated into #192; do not merge a duplicate foundation.
- PR #191 and #196 remain independent notification and Calendar Sync foundations.
- Exact-head CI on the current #192 branch must be re-fetched after the latest commit; previous green results do not apply to a moved head.
- Original X-OPD November 2569, 16 Nov–15 Dec 2569 and US Clinic ภปร.4 workbooks are not available for actual-file acceptance.
- See `COMPLETION_STATUS.md` and `IMPLEMENTATION_EVIDENCE.md` for live status and evidence boundaries.

