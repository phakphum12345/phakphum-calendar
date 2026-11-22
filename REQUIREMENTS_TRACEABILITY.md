# Requirements Traceability

**Review date:** 2026-11-22  
**Repository snapshot:** `e9ed13fb2f0ed82571ce7f2b39b57503d04e5ce5`  
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
| Monthly / yearly calendar | monthly roster and `RosterSyncPeriodFilter` | month boundary and leap-year tests | PARTIAL — monthly flow exists; dedicated yearly/day/week views not confirmed |
| Date / time / timezone | `RosterSyncPeriodFilter`, `GoogleCalendarSyncGateway` | date parsing and Calendar gateway tests | PARTIAL — Bangkok wall-time conversion exists; cross-device timezone matrix needs verification |
| User management / permissions | `OrganizationController.php`, organization membership and policy tables | organization API feature tests | PARTIAL — join and approval flows exist; role-change/removal endpoints not found |
| Authentication / authorization | `AuthenticateGoogleAccount.php`, Google identity-token verifier | Google token and middleware tests | IMPLEMENTED FOUNDATION — continue issuer/audience/expiry and authorization regression tests |
| Notifications / reminders | `lib/domain/services/notification_service.dart` | No concrete implementation or targeted tests found | MISSING — interface only; implement permission-aware platform service |
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

- A complete restore workflow for a historical roster assignment.
- Whether blank/unassigned cells and removed roster positions are represented as timeline versions.
- Dedicated daily, weekly and yearly calendar views.
- Concrete notification scheduling and cancellation on supported platforms.
- Member role changes and member removal with audit history.
- Encrypted local storage for cached roster revisions and failed sync payloads.
- Performance under large multi-sheet workbooks and long calendar histories.
- Production deployment and live Google integration behavior after the current code changes. The audited main Web build passed, but the Pages deployment job was SKIPPED; live URL and deployed SHA remain UNKNOWN.
- Branch protection is UNKNOWN because the connected GitHub integration could not read the protection endpoint (HTTP 403); the rulesets endpoint returned an empty list.
- PR #160 head `a79af5dab3a5a619fd37138b1764811ba8118626` had 2 successful workflow runs and 7 successful check runs; no reviews or inline review threads were returned.
- Post-merge `main` workflow execution for merge commit `e9ed13fb2f0ed82571ce7f2b39b57503d04e5ce5`; the combined commit-status endpoint returned no status entries.

## Evidence rules

- A source file proves that code exists, not that the behavior works.
- A unit test proves only the cases it executes.
- A skipped workflow is not a passing workflow.
- A build does not prove live integration, security or data integrity.
- Re-run this matrix after each major merge and update the implementation status snapshot.
