# Requirements Traceability

## Current evidence checkpoint — 2026-11-27

**Main SHA:** `68ef85361c2d08e2970160a36475592010d908f7`

The rows below supersede older PR/status snapshots in this file. Open-PR source is not part of `main` until merged and post-merge verified.

| Work package | Current source / PR | Exact-head CI evidence | Evidence state | Remaining acceptance |
|---|---|---|---|---|
| A. Universal roster import | #192 — `2f6f9043db8876ea5ed49d85961658fac95942ac` | New exact-head run pending after latest source/test changes | IN PROGRESS | Validate original X-OPD November 2569, 16 Nov–15 Dec 2569 and US Clinic ภปร.4 workbooks; verify ambiguous orientation and identity review |
| B. Schedule persistence | #192 — same head | New exact-head run pending | IN PROGRESS | Verify all production writers, true backend transaction/CAS across devices, tombstones and crash/restart recovery |
| C. Google Calendar Sync | #196 — `8e186790e447f9278eda8612a1bb1b6f7e7b77c9` | 13/13 workflows passed | IN PROGRESS | Controlled test-calendar insert/update/delete, provider timeout reconciliation and cross-device lease contention |
| D. Notifications | #191 — `cf7eaa22eaf81e04b0b444acfc3aee2a8ca51e5e` | 13/13 workflows passed | IN PROGRESS | Registered-device delivery, permission denial, expired subscriptions and deployed scheduler acceptance |
| E. Schedule generation | #202 — `ca6ebd095ef6566fcce00e9bc49e9c820470b80d` | 12/12 workflows passed | IN PROGRESS | Revalidate against current #192 base; verify UI, immutable preview, approval invalidation and post-commit read-back |
| F. Shift Pay | #201 — `d3f228dcdaea4f1a3771c271421226ab71ab00b5`; #203 — `9ddcca51de57b71c721f60665f3c9f8cf0e7bbcb` | #201 12/12; #203 11/11; 716 tests passed on #203 | IN PROGRESS | Durable statement persistence, statement UI, confirmed-assignment integration and verified contractor employment/payment rules |
| G. History restore | #204 — `ba73d30f4e332105c05c95d00f61517da1cd9689` | New exact-head run pending | IN PROGRESS | Per-assignment before/after diff, original Drive revision fixture and external-account acceptance |
| H. Organization/security | Existing membership/role/API foundations | Existing tests only; no new full tenant-isolation acceptance in this checkpoint | PARTIAL | Cross-organization negative tests, backend authorization, rate limiting and privacy-safe log review |
| I. Quality/performance/accessibility | Existing Flutter/backend CI and device layouts | No repository-wide benchmark or full accessibility acceptance evidence | PARTIAL / UNKNOWN | Large-workbook, event-volume, history, memory, keyboard, screen-reader and responsive-device tests |
| J. Documentation | This documentation reconciliation PR | Docs validation pending | IN PROGRESS | Keep API/schema and feature specifications synchronized with the final merged source |
| K. Release/deployment | No verified production deployment for this checkpoint | No exact-main workflow run/status entries returned for main SHA | BLOCKED — EXTERNAL DEPENDENCY | Production API health, deployed source SHA, migration/backup drill, rollback, release credentials and real integration acceptance |

Additional repository gates:
- PR #199 is closed without merge; its orientation foundation was superseded by parser integration in #192.
- All seven currently open PRs remain Draft and have no submitted reviews or review threads.
- GitHub reports `main.protected = false`, protection enforcement `off`, and no required status-check contexts.
- The exact main SHA above returned no workflow runs and no combined-status entries. Do not count that as a pass.
- CI green on a PR head is not product acceptance, deployment evidence or post-merge verification.


**Historical review date:** 2026-11-25  
**Historical repository snapshot:** `aed2f1177bdfc85f6ff53bb200116812a51bd9e3`  
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
