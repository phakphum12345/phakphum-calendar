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
| Day / week / month / year calendar | daily, weekly and monthly schedule pages; `ScheduleWorkspacePage` | schedule page and month-boundary tests | IN_PROGRESS — Day/Week/Month views exist; PR #162 fixes weeks crossing month boundaries; PR #163 adds a 12-month year overview and is stacked on #162 |
| Date / time / timezone | `RosterSyncPeriodFilter`, `GoogleCalendarSyncGateway` | date parsing and Calendar gateway tests | PARTIAL — Bangkok wall-time conversion exists; cross-device timezone matrix needs verification |
| Organization member management | `OrganizationController.php`, `OrganizationAdminGateway`, membership panel | Laravel API and Flutter gateway/widget tests | IN_PROGRESS — PR #164 adds owner/admin role changes and soft removal, protects owner membership, and supports reactivation without deleting membership rows |
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
- A year overview is proposed in PR #163; it remains unmerged. PR #162's cross-month weekly view fix also remains unmerged.
- Concrete notification scheduling and cancellation on supported platforms; the current notification interface is not a delivery implementation. The target platforms and background-delivery requirement still need to be decided.
- Member role changes and soft removal are proposed in PR #164; detailed membership audit history remains unimplemented.
- Encrypted local storage for cached roster revisions and failed sync payloads.
- Performance under large multi-sheet workbooks and long calendar histories.
- Production deployment and live Google integration behavior after the current code changes. The audited main Web build passed, but the Pages deployment job was SKIPPED; live URL and deployed SHA remain UNKNOWN.
- Branch protection is UNKNOWN because the connected GitHub integration could not read the protection endpoint (HTTP 403); the rulesets endpoint returned an empty list.
- PR #160's previously audited head `a79af5dab3a5a619fd37138b1764811ba8118626` passed 2 workflow runs and 7 checks; subsequent documentation commits moved the branch to `06a9bc7bcf5a0b8b2d2a508c6bd52fa4efadc92e`, whose checks were also reverified successful before this refresh.
- The legacy combined commit-status endpoint returned no status entries, but GitHub Actions check-runs show 10 successful workflow runs for main SHA `e9ed13fb2f0ed82571ce7f2b39b57503d04e5ce5`; the Pages deployment job was SKIPPED.

## Evidence rules

- A source file proves that code exists, not that the behavior works.
- A unit test proves only the cases it executes.
- A skipped workflow is not a passing workflow.
- A build does not prove live integration, security or data integrity.
- Re-run this matrix after each major merge and update the implementation status snapshot.


---

## 2026-11-24 — Universal Roster Intelligence expansion requirements

**Planning baseline:** `main@c847d70b98c2693a11c1063e989c55f2ab825d04`  
**Status:** Initial planning inventory only. This addendum does not replace or retroactively validate the historical snapshot above.

| Requirement | Scope | Existing evidence to inspect | Initial status | Required proof |
|---|---|---|---|---|
| RI-001 | Multiple independent roster sections per worksheet | Monthly roster section parser and tests | EXISTS — VERIFY | Distinct periods/layouts in one workbook |
| RI-002 | Section-local period resolution | Thai period parser and monthly parser | UNKNOWN | Explicit range, title tokens and conflicting period tests |
| RI-003 | Thai BE/Gregorian and cross-month/year dates | Thai period/date tests | EXISTS — VERIFY | Complete locale, leap and year-boundary matrix |
| RI-004 | Preserve source row/column and merged-cell evidence | Excel reader and normalized cell model | EXISTS — VERIFY | Evidence survives preview and conversion |
| RI-005 | Duplicate/missing/out-of-order day diagnostics | Monthly section parser diagnostics | EXISTS — VERIFY | Exact-column diagnostics without column shifting |
| RI-006 | Configurable shift semantics | Shift templates and business rules | EXISTS — VERIFY | Multiple independent profiles and overnight shifts |
| RI-007 | Safe person identity and alias resolution | Roster/person models and organization membership | PARTIAL | Collision and wrong-person negative tests |
| RI-008 | Canonical normalized roster contract | Existing parser adapters and roster models | PARTIAL | All supported providers map without loss |
| RI-009 | Source revision and non-destructive reconciliation | Import/history/comparison services | UNKNOWN | Re-import, changed-source and duplicate tests |
| RI-010 | Evidence/confidence and human correction | Analyzer, import preview and mapping UI | PARTIAL | Inspectable evidence and auditable user decisions |
| RI-011 | Partial import by independent section | Conversion diagnostics and import workflow | EXISTS — VERIFY | One invalid section does not corrupt valid sections |
| RI-012 | Template-driven generation | Generator/adapter docs and output services | PARTIAL | Deterministic preview and output comparison |
| RI-013 | Import-to-Calendar provenance | Import history, timeline and Calendar sync | PARTIAL | Trace a record end-to-end using stable identifiers |
| RI-014 | Large-input performance and resilience | No repository-wide benchmark baseline identified | UNKNOWN | Reproducible time/memory and failure-recovery tests |
| RI-015 | Privacy and tenant isolation | Backend authorization and security tests | PARTIAL | Cross-tenant negative tests and redaction review |

Detailed acceptance is maintained in:
- [Universal Roster Intelligence master plan](docs/UNIVERSAL_ROSTER_INTELLIGENCE_MASTER_PLAN.md)
- [Roster parser reliability specification](docs/ROSTER_PARSER_RELIABILITY_SPEC.md)
- [Roster intelligence capability matrix](docs/ROSTER_INTELLIGENCE_CAPABILITY_MATRIX.md)

Statuses must be updated only after source inspection and executed tests on an identified commit. File existence or a planning document is not implementation proof.


---

## 2026-11-24 — Generator, provenance, API and release requirements

| Requirement | Scope | Initial status | Required proof |
|---|---|---|---|
| RI-016 | Deterministic generator input/output contract | PARTIAL | Same snapshot/profile/template produces stable output and fingerprint |
| RI-017 | Versioned templates and mapping precedence | PLANNED | Lifecycle, precedence, migration and stale-preview tests |
| RI-018 | Immutable preview and explicit confirmation | PARTIAL | Exact preview fingerprint is revalidated before mutation |
| RI-019 | Source snapshot and cell-level provenance | PARTIAL | Source evidence is traceable through canonical record and output |
| RI-020 | Person identity and collision-safe alias resolution | PARTIAL | Similar-name negative tests and organization-scoped identity |
| RI-021 | Revision reconciliation and safe removals | UNKNOWN | Malformed/partial source never proposes mass deletion |
| RI-022 | API contract and idempotency policy | PARTIAL | Route/client contract, authorization and replay tests |
| RI-023 | Provider capability and adapter isolation | PARTIAL | Unsupported provider/platform paths fail visibly without bypass |
| RI-024 | Exact-SHA test/release evidence | PARTIAL | Every required check tied to current head; skipped deployment is not pass |

Supporting specifications:
- [Universal Generator specification](docs/UNIVERSAL_GENERATOR_SPEC.md)
- [Roster provenance and reconciliation](docs/ROSTER_PROVENANCE_AND_RECONCILIATION.md)
- [API and integration contracts](docs/API_AND_INTEGRATION_CONTRACTS.md)
- [Testing and release acceptance](docs/TESTING_AND_RELEASE_ACCEPTANCE.md)

These are target contracts, not claims that the features are complete. Update statuses only after auditing source and running the stated tests on an exact commit.
