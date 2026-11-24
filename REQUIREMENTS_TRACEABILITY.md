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


---

## 2026-11-24 — Module ownership and consolidation requirements

| Requirement | Scope | Initial status | Required proof |
|---|---|---|---|
| RI-025 | One authoritative owner per capability across feature and legacy modules | UNKNOWN | Symbol-level call-site and dependency map |
| RI-026 | Safe consolidation of overlapping feature areas | PLANNED | Behavior/test parity, migration and explicit approval |
| RI-027 | Legacy workflow backward compatibility during modularization | PARTIAL | Existing public entry points and regression suite remain operational |

See [Module Catalog and Ownership Map](docs/MODULE_CATALOG.md). Directory presence is inventory evidence only; it does not establish runtime registration or feature completeness.


## 2026-11-24 — UI integration trace refresh

**Inspected branch:** `docs/universal-roster-intelligence-masterplan-2026-11-24`  
**Inspection commit at start of this refresh:** `ab48dc2217cd6ee27bce639dcd00187983ea8293`  
**Evidence type:** source and test-source inspection only; Flutter/Dart execution was not performed.

| Requirement | Exact source / test evidence | Updated status | Remaining proof |
|---|---|---|---|
| RI-008 Tabular import into canonical Schedule | `app.dart`, `ImportExcelPage`, `ImportSummaryPage`, `ImportedScheduleAdapter` | PASS — source path traced | Execute exact-head widget/integration tests |
| RI-010 Human identity and shift review | `ImportSummaryPage._resolvedRecords`; `test/import_summary_employee_review_test.dart` | PASS — source/test cases exist | Execute tests; add restart durability coverage |
| RI-011 Existing-schedule staging and explicit confirmation | `_loadExistingSchedule`, `ImportStagingPlanner`, `ImportStagingApplier`, `_saveSchedule` | PASS — source path traced | Execute staging tests and stale-revision/failure cases |
| RI-013 Tabular import save and reload | `AppDependencies.saveImportedSchedule`; `test/import_excel_page_test.dart` | PASS — integration test source exists | Runtime execution remains SKIPPED |
| Grid parser production workflow | `MonthlyRosterWorkbookScanner`, `HospitalRosterParser`, direct parser tests | UNKNOWN — no production UI route/caller established in inspected route tree | Identify product entry point and trace conversion/review/save |
| Provenance durability for both import paths | `ShiftRecord`, `MonthlyRosterSection`, `LegacyScheduleAdapter`, `ScheduleJsonCodec` | UNKNOWN — canonical schema v1 omits source/review evidence | Implement versioned envelope and atomic/recoverable commit |
| Staffing generation UI orchestration | `MonthlyRosterRequestBuilder`, `ScheduleGenerator`, `AutoAssignmentService` | UNKNOWN — no production route/controller invocation found in inspected tree | Define draft workflow, approval and persistence use case |
| Generated schedule persistence | `GenerationResult` and `ScheduleRepository` inspected separately | UNKNOWN — no generation-to-save orchestration found | Add approved commit use case and reload tests |
| Universal Generator Calendar execution | `GeneratorCalendarAdapter`, `GeneratorAdapterPreview` | SKIPPED — adapter explicitly preview-only | Separate authorized Calendar execution project/contract |

Important distinction: PASS in this table means the source path or test case exists and was inspected; it does not mean tests were executed or the full production behavior was runtime-verified. UNKNOWN and SKIPPED remain open.


## 2026-11-24 Grid import workflow design update

| Requirement | Existing evidence | Status / next gate |
|---|---|---|
| Section-aware Grid parsing | `MonthlyRosterSectionParser`, `MonthlyRosterParseReport`, section/date anomaly tests | PASS — source implementation and test cases inspected; runtime execution SKIPPED |
| Preserve source-cell evidence | `MonthlyRosterAssignment` carries sheet/spreadsheet IDs, A1 cell, row, section and date | PASS — in-memory source evidence exists; durable retention UNKNOWN |
| Conversion diagnostics | `MonthlyRosterConversionDiagnostics` reports converted/unconverted assignments and blocking date anomalies | PASS — diagnostic API exists; production review route UNKNOWN |
| Safe canonical employee resolution | Existing adapter uses substring matching for compatibility; no verified Grid-specific canonical identity review/commit route | UNKNOWN — must add explicit unique identity review before persistence |
| Shift-template resolution evidence | Adapter supports templates and built-in label rules; review display and durable decision record not established | UNKNOWN |
| Grid review UI and orchestration | `ImportExcelPage` Grid action → `GridRosterReviewPage` → `GridRosterImportWorkflow` → journal + canonical ScheduleRepository | PASS — source integrated; runtime SKIPPED |
| Schedule + provenance recoverable commit | `GridRosterBundleJournal` plus guarded canonical repository save/recovery replay | PASS — source/test added; runtime SKIPPED; not a cross-store atomic transaction |
| Grid service/UI persistence and recovery | UI invokes scan → review → conversion → journal → ScheduleRepository save; recovery runs before a new Grid scan | PASS — source integrated; runtime SKIPPED |
| Tabular import backward compatibility | Existing tabular UI review/staging/save/reload path and integration-test sources inspected | PASS — source/test-case evidence only; runtime execution SKIPPED |
| Calendar sync after Grid commit | Existing Calendar workflow is separately authorized; Grid-specific post-commit integration not established | SKIPPED — must remain disabled until explicit review and authorization |

**Evidence interpretation:** PASS in this section means implementation source is present and linked into the local XLSX import UI; it does not mean runtime tests passed. Google Sheets Grid import, verified reviewer identity, strict concurrent-writer CAS and Calendar sync remain unimplemented.


## 2026-11-24 Schedule generation workflow design update

| Requirement | Existing evidence | Status / next gate |
|---|---|---|
| Deterministic generation core | `ScheduleGenerator`, `AutoAssignmentService`, `ScheduleAssignmentWriter` | PASS — source implementation and unit-test cases inspected; runtime execution SKIPPED |
| Coverage/conflict reporting | `GenerationResult` exposes conflicts, uncovered requirements and assignment count | PASS — source-level behavior exists; full policy coverage remains PARTIAL |
| Availability/capacity input | `GenerationRequest` supports availability and department capacities; request builder does not expose them as parameters | PARTIAL — orchestration must load/pass required constraints |
| Generation preview and immutable fingerprint | No production preview lifecycle/fingerprint/approval call path established | MISSING |
| Human review and exact approval | No production generation review/approval route established | MISSING |
| Generation persistence and provenance | Candidate Schedule is returned in memory; generation commit and provenance recovery not established | MISSING |
| Calendar execution | `GeneratorCalendarAdapter` explicitly returns preview data only and has no sync gateway | SKIPPED — separate authorization and existing Calendar sync workflow required |
| Generation review/commit specification | `docs/SCHEDULE_GENERATION_REVIEW_AND_COMMIT.md` | PASS — design documented; implementation remains MISSING |

**Evidence interpretation:** PASS indicates inspected source behavior or design documentation only. No Dart/Flutter test or runtime execution was performed for this update.


## 2026-11-24 Section safety classifier implementation

| Requirement | Evidence | Status |
|---|---|---|
| Pure section readiness classification | `MonthlyRosterSectionSafetyClassifier` | PASS — source added |
| Blocking date anomalies remain isolated | `blockedDate` assessment with stable anomaly reason codes | PASS — source added; runtime test SKIPPED |
| Missing/reversed period blocks review | `SECTION_DATE_RANGE_UNRESOLVED` | PASS — source added; runtime test SKIPPED |
| Empty section remains explicit | `empty` state with `NO_ASSIGNMENTS` | PASS — source added; runtime test SKIPPED |
| Missing worker/shift label requires review | `needsReview` with source-cell reason codes | PASS — source added; runtime test SKIPPED |
| Assignment outside declared range requires review | `ASSIGNMENT_OUTSIDE_SECTION_RANGE` | PASS — source added; runtime test SKIPPED |
| Assessment authorizes persistence | `canCommit` is always false | PASS — fail-closed boundary |
| Production Grid UI integration | `ImportExcelPage` Grid action and `GridRosterReviewPage` call the workflow coordinator | PASS — source integrated; runtime SKIPPED |
| Dart formatting, analysis and Flutter test execution | No runtime environment available through repository connector | SKIPPED |

**Interpretation:** PASS means implementation source was committed to the working branch. The accompanying test source has not been executed. The classifier remains separate from the legacy adapter; the new Grid review workflow invokes it through `GridRosterReviewSessionBuilder`.


## 2026-11-24 Grid identity candidate resolver implementation

| Requirement | Evidence | Status |
|---|---|---|
| Discover exact employee-code candidates | `GridRosterEmployeeIdentityResolver` | PASS — source added |
| Discover exact full/display-name and nickname candidates | Ranked exact matching with employee-ID deduplication | PASS — source added |
| Preserve duplicate exact identities as ambiguous | `ambiguousExactCandidates` | PASS — source added |
| Use substring matches only as suggestions | `suggestionsOnly` / `containsText` | PASS — source added |
| Exclude inactive employees | Active-only candidate scan | PASS — source added |
| Require explicit human confirmation | No selected ID; `canCommit == false` | PASS — fail-closed source contract |
| Persist reviewer identity decisions / reusable aliases | No review-session or alias repository yet | MISSING |
| Production Grid UI integration | `GridRosterReviewPage` now presents explicit employee/shift decisions and calls the workflow coordinator | PASS — source integrated; runtime SKIPPED |
| Runtime execution of resolver tests | Not run | SKIPPED |

**Compatibility:** The legacy `MonthlyRosterShiftAdapter` matching implementation and its fragment-matching tests were not changed. The new resolver is a separate proposal-only component.


## 2026-11-24 Grid shift-rule evidence API

| Requirement | Evidence | Status |
|---|---|---|
| Identify configured active template mapping | `resolveRuleForLabel` returns `configuredTemplate`, template ID and time range | PASS — source added |
| Identify built-in legacy mapping | Returns `builtInRule` and resolved code/time range without a fabricated template ID | PASS — source added |
| Reject duplicate active template aliases | Returns `ambiguousTemplate`; no arbitrary choice | PASS — source added |
| Keep unsupported and empty labels visible | Explicit `unsupportedLabel` and `emptyLabel` statuses | PASS — source added |
| Preserve legacy conversion mapping behavior | New API reuses existing private mapping implementation; conversion path unchanged | PASS — static source comparison |
| Require human review before commit | `requiresHumanConfirmation == true`, `canCommit == false` | PASS — fail-closed source contract |
| Runtime shift mapping tests | Test source added; not executed | SKIPPED |
| Durable mapping decision and Grid UI | Not implemented | MISSING |


## 2026-11-24 Immutable Grid review-session composition

| Requirement | Evidence | Status |
|---|---|---|
| Compose section safety assessment, identity candidates and shift-rule evidence | `GridRosterReviewSessionBuilder` | PASS — source added |
| Bind review snapshot to source fingerprint and target schedule revision | Required caller-supplied values; blank values rejected | PASS — source added |
| Preserve blocked section and its source assignments | Section review retains assessment and assignment evidence; blocked flag attached | PASS — source added |
| Keep review snapshot immutable | Session and section assignment collections wrapped unmodifiable | PASS — source added |
| Prevent preview from authorizing persistence | Session and assignment `canCommit == false` | PASS — fail-closed source contract |
| Durable reviewer decisions, stale-revision revalidation and commit | Not part of this preview builder | MISSING |
| Production UI route/controller | Not connected | MISSING |
| Runtime builder tests | Test source added; not executed | SKIPPED |


## 2026-11-24 Unresolved Grid section preservation

| Requirement | Evidence | Status |
|---|---|---|
| Preserve invalid/ambiguous explicit-period section in parse report | Parser creates section shell with original title/header row | PASS — source changed |
| Do not invent dates or assignments | Null start/end, empty assignments, blocking `unresolved_period` anomaly | PASS — fail-closed source behavior |
| Keep section visible to safety classifier/review builder | Classifier sees blocking anomaly; session builder retains section review | PASS — source path inspected |
| Conflicting explicit ranges regression | Existing parser test now expects retained blocked section and no assignments | PASS — test source updated; runtime SKIPPED |
| Raw unresolved cell-level assignment evidence | No unresolved-cell model added yet | MISSING |

## 2026-11-24 Grid provenance envelope and JSON codec

| Requirement | Evidence | Status |
|---|---|---|
| Store import-run, source fingerprint, parser version and target Schedule revision | `GridRosterImportProvenance` envelope | PASS — source added |
| Preserve section-level readiness, date bounds and reason codes | `GridRosterProvenanceSection` | PASS — source added |
| Link source assignment/cell to canonical employee/template and review decision | `GridRosterAssignmentProvenance` | PASS — source added |
| Preserve reviewer identity/time for final include/exclude decisions | Model requires reviewer ID and UTC timestamp as a pair | PASS — source invariant |
| Preserve diagnostics without copying raw workbook values | Code/severity and optional section/cell references only | PASS — source contract |
| Reject duplicate IDs, dangling section links and invalid committed state | Envelope constructor invariants | PASS — source added |
| Versioned strict JSON round-trip | `GridRosterImportProvenanceJsonCodec`, format discriminator and schema v1 | PASS — source added; runtime SKIPPED |
| Reject unknown versions/enums and malformed required fields | Codec exceptions and tests | PASS — source/test added; runtime SKIPPED |
| Preserve canonical Schedule schema v1 | No changes to `ScheduleJsonCodec` or canonical repository | PASS — files unchanged in this work |
| Recoverable Schedule + provenance journal | `GridRosterBundleJournal` stores both encoded payloads in a versioned two-slot record | PASS — source added; runtime SKIPPED |
| PREPARED → read-back → COMMITTED protocol | Inactive slot staged and decoded before committed record replaces it | PASS — source contract; no platform durability guarantee |
| Previous committed slot preserved during interrupted replacement | Alternating slot selection avoids overwriting the latest committed slot while staging | PASS — source/test added; runtime SKIPPED |
| Recovery excludes PREPARED-only records | `recover` returns only highest-generation valid COMMITTED record | PASS — source/test added; runtime SKIPPED |
| Stale target revision guard | Commit requires caller-supplied current revision to equal provenance target revision | PASS — source contract; live repository revalidation remains caller responsibility |
| Idempotent retry and conflicting run-ID protection | Same run + identical Schedule/fingerprint returns existing bundle; conflicting reuse rejected | PASS — source/test added; runtime SKIPPED |
| Atomic/durable cross-key transaction | SharedPreferences has no documented cross-key transaction or durable atomic-write guarantee | UNKNOWN — not claimed |
| Local XLSX multi-sheet Grid scanner | SHA-256 source fingerprint, per-sheet parsing/summaries and per-sheet read-error isolation | PASS — source/test added; runtime SKIPPED |
| Reviewed Grid-to-canonical conversion | Pure converter requires explicit per-assignment reviewer decisions; preserves target Schedule and returns PREPARED provenance | PASS — source/test added; runtime SKIPPED |
| Blocked sections and out-of-range assignments | Blocked sections can only be excluded; out-of-range assignments cannot be included | PASS — source/test added; runtime SKIPPED |
| Existing Schedule preservation and collision handling | Existing months/assignments retained; duplicate employee+shift/day collision fails closed | PASS — source/test added; runtime SKIPPED |
| Strict concurrent-writer compare-and-set | Repository interface has no atomic CAS; coordinator uses repeated read-before-save checks only | MISSING — race remains |
| Grid workflow coordinator | Scan report → live target load/revision → review → conversion → journal → canonical repository save/recovery replay | PASS — source/test added; runtime SKIPPED | 
| Grid review UI default safety | All assignments default to excluded; widget test asserts no implicit inclusion | PASS — source/test added; runtime SKIPPED |\n| Production Grid UI/controller invokes conversion | `ImportExcelPage` → `GridRosterReviewPage` → workflow coordinator → canonical repository | PASS — source integrated; runtime SKIPPED |
| Calendar sync after explicit approval | Not wired by this change | MISSING |
| Dart format, analyze and Flutter tests | Not executed in connector environment | SKIPPED |
| Verified reviewer identity | Reviewer label is typed by the operator and stored as reviewer evidence; no identity provider validates it | MISSING |
| Google Sheets Grid adapter | Grid scanner currently accepts local XLSX only | MISSING |
| Excel hidden-sheet and background-color evidence | Current ExcelReaderService does not expose these fields | UNKNOWN |

**Interpretation:** PASS means source/test contract exists, not that runtime tests passed. The journal is a recoverable two-slot persistence primitive, not a database transaction. Platform durability remains unverified. The UI calls recovery before a new Grid scan, but recovery is not yet an app-startup hook. Strict compare-and-set is missing, and Calendar handoff remains separate.