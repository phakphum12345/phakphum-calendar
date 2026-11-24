# Requirements Traceability

**Review date:** 2026-11-24  
**Repository snapshot:** `d143449d47c8df3dee4ea6053258a84bb28d4e5`  
**Status:** Evidence-based partial inventory. PARTIAL, MISSING, UNKNOWN and NEEDS REVIEW remain open work.

| Requirement | Primary implementation | Evidence / test surface | Status and remaining gap |
|---|---|---|---|
| Application architecture | `lib/core/di/app_dependencies.dart`, `lib/controller/app_controller.dart`, `lib/ui/app_shell.dart` | Flutter unit/widget/integration tests | PARTIAL — large controller and shell remain candidates for incremental extraction with behavior-preserving tests. |
| Frontend UI / UX | `lib/features/**/presentation/` | Widget tests and device-width checks | NEEDS REVIEW — verify critical flows at phone, tablet and desktop widths. |
| Backend / API | `backend/routes/api.php`, `backend/app/Http/Controllers/Api/V1/` | `backend/tests/Feature/` | IMPLEMENTED FOUNDATION — keep API docs and contract tests aligned with routes, validation and authorization. |
| Database / migrations | `backend/database/migrations/` | Laravel feature tests | IMPLEMENTED FOUNDATION — migrations are canonical; verify backup/restore and data-retention behavior. |
| Calendar engine | `lib/features/calendar_engine/` and Google Calendar gateways | `test/sce_*`, gateway and reconciliation tests | IMPLEMENTED FOUNDATION — live authorized Google integration and ambiguous network outcomes require environment-backed verification. |
| Scheduling engine | `lib/features/schedule_generation/`, `lib/features/schedule/` | schedule generation/validation tests | PARTIAL — expand large-roster and edge-case coverage. |
| Day/week/month/year views | `ScheduleWorkspacePage`, `ScheduleGrid`, `ScheduleYearOverview` | schedule page/widget tests | IMPLEMENTED FOUNDATION — source contains all four modes; verify year navigation, 12-month rendering, month selection and cross-month weeks. PR #163 currently has zero diff against main. |
| Date/time/timezone | `RosterSyncPeriodFilter`, Google Calendar gateway | parser and gateway tests | PARTIAL — Bangkok wall-time conversion exists; add a cross-device timezone matrix and daylight/time-boundary cases where applicable. |
| Timeline history | `RosterRevisionService`, `RosterTimelineGenerator`, timeline archive | revision reader, parser and timeline tests | PARTIAL — historical revisions are read and transformed into timelines; blank/unassigned slots and removed roster positions need explicit semantics. |
| Historical restore | `RosterRevisionService` (read-only) | no complete restore flow established | MISSING for write/restore — define preview, conflict policy, explicit confirmation, audit trail and recovery; any Drive write-scope expansion requires separate approval. |
| Shift transactions | `lib/features/shift_exchange/`, `backend/app/Services/ShiftTransactions/` | backend API, composer and history widget tests | IMPLEMENTED FOUNDATION — PR #173 merged exchange-and-return composition and history filters; live multi-account and calendar-provider behavior remains environment-dependent. |
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
