# Requirements Traceability

**Review date:** 2026-11-22  
**Repository snapshot:** `168559498de58a071ac43a81e410227f0f83ec4b`  
**Status:** Partial inventory; rows marked PARTIAL, MISSING or NEEDS REVIEW remain open work.

| Requirement | Primary implementation | Test / evidence | Status and gap |
|---|---|---|---|
| Application architecture | `lib/core/di/app_dependencies.dart`, `lib/controller/app_controller.dart`, `lib/ui/app_shell.dart`, `backend/routes/api.php` | Flutter tests and Laravel feature tests | PARTIAL — UI/controller are large monoliths; continue modularization |
| Frontend UI / UX | `lib/ui/app_shell.dart`, feature presentation widgets | Widget tests in `test/` | NEEDS REVIEW — targeted mobile/tablet/desktop usability audit remains |
| Backend / API | `backend/routes/api.php`, `backend/app/Http/Controllers/Api/V1/` | `backend/tests/Feature/` | PARTIAL — API docs and broader contract coverage required |
| Database / migrations | `backend/database/migrations/` | Laravel feature tests | IMPLEMENTED — schema document added; migration and backup/restore audit remains |
| Calendar engine | `lib/features/calendar_engine/` | `test/sce_*`, Google Calendar gateway tests | POST-MERGE VERIFICATION — idempotent inserts and selected-period preservation are merged; exact-head regressions passed, but main post-merge CI evidence remains UNKNOWN |
| Scheduling engine | `lib/features/schedule_generation/`, `lib/features/schedule/` | schedule generation and validation tests | PARTIAL — complete large-roster and edge-case coverage still required |
| Timeline management | `lib/services/roster_timeline_generator.dart`, `lib/services/timeline_archive_service.dart` | roster timeline and archive tests | PARTIAL — revision history exists; restoration and blank-slot semantics need work |
| Historical timeline | `lib/services/roster_revision_service.dart`, `lib/models/roster_assignment_timeline.dart` | revision reader and timeline generator tests | PARTIAL — read/history display exists; complete restore workflow not found |
| Shift / duty management | `lib/features/shift_parser/`, `lib/features/shift_exchange/`, `backend/app/Services/ShiftTransactions/` | parser, schedule and transaction tests | PARTIAL — broader end-to-end personnel and cancellation scenarios remain |
| Shift exchange / replacement | `lib/features/shift_exchange/`, `ShiftTransactionService.php` | `backend/tests/Feature/ShiftTransactionApiTest.php`, Flutter API-client tests | IMPLEMENTED FOUNDATION — full live multi-account workflow still requires environment verification |
| Synchronization engine | `CalendarSyncCoordinator`, `ResilientCalendarSyncExecutor`, `ResumeSyncService`, Google Calendar gateway | sync executor, resume and gateway tests | POST-MERGE VERIFICATION — PR #148 idempotency and PR #144 selected-month preservation are merged; exact-head tests passed, but main post-merge CI evidence remains UNKNOWN |
| Day / week / month / year calendar | daily, weekly and monthly schedule pages; `ScheduleWorkspacePage`; year overview proposed in PR #165 | schedule page, week-boundary and year-overview tests | IN_PROGRESS — PR #162's seven-day cross-month behavior is merged; PR #165 adds the 12-month year view on current main and awaits exact-head CI. Original PR #163 is superseded and conflict-blocked |
| Date / time / timezone | `RosterSyncPeriodFilter`, `GoogleCalendarSyncGateway` | date parsing and Calendar gateway tests | PARTIAL — Bangkok wall-time conversion exists; cross-device timezone matrix needs verification |
| Organization member management | `OrganizationController.php`, `OrganizationAdminGateway`, membership panel | Laravel API and Flutter gateway/widget tests | IMPLEMENTED FOUNDATION — PR #164 is merged; owner/admin role changes and soft removal preserve membership rows, protect owner membership and support reactivation. Dedicated append-only audit history remains unimplemented |
| Authentication / authorization | `AuthenticateGoogleAccount.php`, Google identity-token verifier | Google token and middleware tests | IMPLEMENTED FOUNDATION — continue issuer/audience/expiry and authorization regression tests |
| Notifications / reminders | `lib/domain/services/notification_service.dart`, `ShiftAlertService` | shift alert tests; no concrete scheduled delivery tests | PARTIAL — in-app shift/conflict alerts exist, but scheduled platform notifications are not wired to a concrete implementation |
| Import / export | `lib/features/shift_parser/`, Excel import, Drive archive and PDF/report services | parser, import and report tests | PARTIAL — import paths exist; export format and recovery matrix needs inventory |
| Data validation | parser diagnostics and Laravel request validation | parser and API validation tests | IMPLEMENTED FOUNDATION — add property/fuzz tests for malformed large workbooks and API payloads |
| Error handling / recovery | `ResilientCalendarSyncExecutor`, `ResumeSyncService`, failed-operation repository | sync recovery tests | IMPLEMENTED FOUNDATION — verify network ambiguity and process restart on every platform |
| Performance / reliability | sync batching, caching and retry services | No repository-wide benchmark suite identified | UNKNOWN — establish large-workbook, event-volume and memory baselines |
| Responsive design / mobile UI | Flutter presentation layer | existing widget tests | NEEDS REVIEW — verify compact widths, table visibility and navigation on real target sizes |
| Automated testing | `test/`, `integration_test/`, `backend/tests/` | 157 Dart test files plus Laravel feature tests | PARTIAL — count is not proof of requirement coverage; map critical flows to E2E tests |
| CI/CD / build / deployment | `.github/workflows/` | main SHA `e9ed13f`: 10 workflow runs succeeded; Web build succeeded but nested GitHub Pages deploy job was SKIPPED | IN_PROGRESS — `.github/workflows/web.yml` restricts deployment to `workflow_dispatch`, so normal main pushes do not deploy. Final Gate currently accepts the successful parent Web workflow even when its deployment job is skipped. Production URL and deployed SHA remain unverified; unsigned iOS output is not install-ready |
| Security / privacy | Google token middleware, Laravel authorization, `SECURITY.md` | security and feature tests | PARTIAL / POST-MERGE VERIFICATION — PR #154 merged the refreshed lockfile; exact-head `composer audit --locked` reports zero advisories and CI runs this gate; PR #151 metadata bounds and PR #152 diagnostic log redaction are merged; local data protection still needs review |
| Documentation | root docs, `docs/`, `backend/` | this index and traceability map | IN_PROGRESS — repository index and API/database guides are merged; keep docs synchronized with future implementation changes |

## Explicitly unverified behaviors

- A complete restore workflow for a historical roster assignment. Google OAuth currently uses Drive read-only scopes; a restore that writes back to Drive requires explicit approval to expand OAuth scopes.
- Whether blank/unassigned cells and removed roster positions are represented as timeline versions.
- PR #162's cross-month weekly view fix is merged. A refreshed year overview implementation is under PR #165; its CI and post-merge behavior remain to be verified.
- Concrete notification scheduling and cancellation on supported platforms; the current notification interface is not a delivery implementation. The target platforms and background-delivery requirement still need to be decided.
- Member role changes and soft removal from PR #164 are merged; detailed append-only membership audit history remains unimplemented.
- Encrypted local storage for cached roster revisions and failed sync payloads.
- Performance under large multi-sheet workbooks and long calendar histories.
- Live Google integration behavior and runtime workflows requiring user OAuth consent remain unverified. GitHub Pages deployment and the published-SHA smoke test passed for main merge commit `168559498de58a071ac43a81e410227f0f83ec4b`; the next post-merge SHA must be checked separately.
- Branch protection is UNKNOWN because the connected GitHub integration could not read the protection endpoint (HTTP 403); the rulesets endpoint returned an empty list.
- PR #160's previously audited head `a79af5dab3a5a619fd37138b1764811ba8118626` passed 2 workflow runs and 7 checks; subsequent documentation commits moved the branch to `06a9bc7bcf5a0b8b2d2a508c6bd52fa4efadc92e`, whose checks were also reverified successful before this refresh.
- For current main SHA `168559498de58a071ac43a81e410227f0f83ec4b`, the Pages deploy job and exact-SHA HTTP smoke test passed; 6 of 8 observed workflow runs were still queued or in progress at the audit checkpoint. Do not mark the whole main CI matrix PASS until all required runs complete.

## Evidence rules

- A source file proves that code exists, not that the behavior works.
- A unit test proves only the cases it executes.
- A skipped workflow is not a passing workflow.
- A build does not prove live integration, security or data integrity.
- Re-run this matrix after each major merge and update the implementation status snapshot.
