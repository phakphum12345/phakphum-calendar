# Implementation Boundary Audit — 2026-11-24

**Audit target:** `phakphum12345/phakphum-calendar`  
**Source ref:** `docs/universal-roster-intelligence-masterplan-2026-11-24` at `babf5238ccd78bb451bc74fd8e2f07e8c2a3cefb`  
**Code baseline:** inherited from `main@c847d70b98c2693a11c1063e989c55f2ab825d04`  
**Status:** Static source inspection only. No tests were executed in this audit.  
**Safety:** No source code, runtime data, Google resources, main branch or deployment was changed.

## 1. Executive findings

| Area | Evidence-backed finding | Current disposition |
|---|---|---|
| `ai_roster_analyzer` vs `roster_ai` | Different abstraction levels and output contracts; not a simple duplicate pair | Preserve both pending caller/wiring audit |
| `rule_engine` vs `rules` | Different rule models and evaluation contexts; both imported by application composition; share the core `RuleEvaluator` | Keep compatibility wrappers; define canonical ownership before migration |
| Import → parser → canonical model → generator | Import and parser have separate feature boundaries; full end-to-end ownership and generator wiring not yet established | Trace composition and adapters before changing contracts |
| Calendar sync | Two substantial sync paths exist: repository/diff/planner/executor path and calendar-engine plan/resilient gateway path | High-priority orchestration overlap; do not merge/delete yet |
| History / timeline / audit | Sync history, roster revision/timeline archive, and audit event represent distinct concepts | Keep separate until persistence and call-site evidence proves overlap |

## 2. AI roster analysis boundaries

### 2.1 Deterministic table analyzer

Source:
- `lib/features/ai_roster_analyzer/application/ai_roster_analyzer.dart`
- `lib/features/ai_roster_analyzer/domain/roster_analysis_models.dart`

Observed contract:
- Accepts normalized `RosterInputFrame` objects containing source metadata, column labels and row maps.
- Detects date/person/role/site/related-person/note columns heuristically.
- Classifies duty kinds deterministically and creates daily plans.
- Retains raw row text/cells and a confidence value.
- Does not expose an AI-provider interface in the inspected analyzer implementation.

Risk requiring follow-up:
- When a row date cannot be parsed, the analyzer emits a record using `_today()` with low confidence instead of representing the date as unresolved/null. This can make an unknown date appear assigned to a real calendar day. Confirm downstream consumers and consider a backward-compatible unresolved-date state rather than silently substituting the current date.

### 2.2 Hybrid field analyzer

Source:
- `lib/features/roster_ai/application/hybrid_roster_ai_analyzer.dart`
- `lib/features/roster_ai/domain/roster_ai_models.dart`
- `lib/features/roster_ai/domain/roster_ai_provider.dart`
- `test/hybrid_roster_ai_analyzer_test.dart`

Observed contract:
- Accepts individual field inputs with an allowlist and source-cell reference.
- Runs a deterministic `RosterRuleResolver` first.
- Calls an optional provider only when rules report ambiguity.
- Rejects proposals outside the allowlist or below the configured confidence threshold.
- Returns proposal/review statuses; `requiresUserConfirmation` is always true.
- Does not persist roster data or sync Calendar events.

Conclusion:
These modules are complementary, not interchangeable duplicates. The deterministic table analyzer is a broad table-to-plan interpreter; the hybrid analyzer is a field-level proposal pipeline. A future integration may compose them, but should not replace either contract without consumer mapping and compatibility tests.

## 3. Rule-engine boundaries

Sources:
- `lib/features/rule_engine/application/rule_engine.dart`
- `lib/features/rule_engine/domain/schedule_rule.dart`
- `lib/features/rules/application/rule_engine.dart`
- `lib/features/rules/domain/rule.dart`
- `lib/core/validation/rule_evaluator.dart`
- `lib/core/di/app_dependencies.dart`
- `test/rule_engine_consolidation_test.dart`

Observed differences:
- Legacy `rule_engine` evaluates a list of `ScheduledShift` values against `ScheduleRule` objects and returns `RuleEvaluationResult`.
- `rules` evaluates a `RuleContext` containing Schedule, ScheduleDay, ShiftAssignment and/or Employee and returns `RuleResult`.
- The two interfaces therefore have different domain inputs, violation contracts and consumers.
- Both delegate generic ordering/deduplication/evaluation behavior to `RuleEvaluator`.
- `AppDependencies` imports both engines and both rule sets, with separate constructor inputs and production defaults.
- The consolidation test explicitly verifies the canonical evaluator path and legacy wrapper behavior.

Disposition:
- Do not delete either package.
- Keep the generic evaluator as shared infrastructure.
- Identify which production workflow still requires the legacy scheduled-shift model.
- Migrate callers through an adapter only when behavior and violation severity remain equivalent.
- Retain tests for both interfaces until legacy callers are proven absent.

## 4. Calendar synchronization ownership

Sources inspected:
- `lib/features/calendar_sync/application/calendar_sync_service.dart`
- `lib/features/calendar_sync/application/calendar_sync_executor.dart`
- `lib/features/calendar_engine/application/resilient_calendar_sync_executor.dart`
- `lib/features/calendar_engine/application/calendar_sync_plan_builder.dart`
- `lib/features/workflow/application/calendar_sync_coordinator.dart`
- `lib/core/di/app_dependencies.dart`

Observed paths:
1. `calendar_sync`: repository-managed event listing → diff engine → planner → executor. Supports dry-run, progress callbacks and continue-on-error behavior.
2. `calendar_engine`: explicit sync plan → gateway operations, retry handling, insert reconciliation, failed-operation persistence and sync-history recording.
3. `workflow`: coordinator/workflow boundary that composes sync planning and execution for application flows.
4. `domain/services/calendar_sync_service.dart` and legacy `services/calendar_service.dart` remain additional compatibility surfaces in the repository tree.

These paths overlap in their broad purpose but have materially different durability/recovery semantics. The resilient executor writes a running history record, retries operations and records failed operations. The simpler executor returns command results and does not itself provide the same durable recovery contract.

Required next audit:
- Trace all constructors and call sites for each sync service/executor.
- Identify the one production entry point for user-triggered Calendar sync.
- Compare create/update/delete identity and idempotency semantics.
- Verify which path is wired by `AppDependencies` and workflow composition.
- Add integration tests proving preview, approval, execution, retry and resume behavior before any consolidation.

## 5. History, timeline and audit are not synonyms

Sources:
- `lib/features/history/domain/sync_history_repository.dart`
- `lib/features/audit/domain/audit_event.dart`
- `lib/services/roster_revision_service.dart`
- `lib/services/roster_timeline_generator.dart`
- `lib/services/timeline_archive_service.dart`
- `docs/adr/ADR-0012-timeline-persistence-and-drive-backup.md`
- `test/timeline_history_regression_test.dart`

Observed responsibility distinctions:
- Sync history records execution lifecycle and aggregate inserted/updated/deleted/failed outcomes.
- Roster revision services represent source roster revisions and change history.
- Timeline generation/archive represents a user-facing chronological projection and its persistence/backup behavior.
- Audit events represent actor, organization, entity, action and occurrence time for accountability.

Potential overlap:
The same synchronization action may be represented in sync history and audit, while roster timeline may project the result. That is not automatically duplication: each has a different query purpose and data contract.

Required next audit:
- Map event producers and consumers for each store.
- Confirm whether audit persistence has a production repository/writer, not just a domain contract.
- Confirm whether timeline is derived from revisions, stored independently, or both.
- Document retention, deletion, privacy and organization scoping for each store.
- Avoid storing duplicate mutable copies of the same source payload.

## 6. Import → parser → canonical model → generator

Confirmed source boundaries from repository tree and composition:
- `lib/features/excel_import/data/excel_reader_service.dart`: spreadsheet acquisition/reading boundary.
- `lib/features/excel_import/application/import_engine.dart`: import application boundary.
- `lib/features/shift_parser/application/monthly_roster_workbook_scanner.dart`: workbook section scanning.
- `lib/features/shift_parser/application/monthly_roster_section_parser.dart`: section-local date structure and assignment population.
- `lib/features/schedule/data/imported_schedule_adapter.dart`: imported shift records to Schedule adaptation.
- `lib/features/schedule_generation/`: monthly roster generation domain/application boundary.
- `lib/features/universal_generator_adapter/`: isolated preview-only adapter per the module catalog.

The full route from every source provider through a single canonical roster model to every generator/output is not yet proven by this static inspection. Do not document this as a single complete pipeline until controller, DI, repository and generator call sites are mapped.

### Parser risk: heading number before explicit range

Source:
- `lib/features/shift_parser/domain/thai_roster_period_parser.dart`
- `lib/features/shift_parser/application/monthly_roster_section_parser.dart`
- `test/monthly_roster_section_parser_test.dart`

Observed parser behavior:
- `ThaiRosterPeriodParser.parse` collects day-month tokens and, when at least two are found, interprets the first two tokens as the range endpoints.
- A heading containing an organization/unit number immediately followed by a month/year, followed later by a parenthesized explicit date range, can therefore present an earlier day-month token before the actual range.
- Example shape: `GEN ... ภปร. 4 พฤศจิกายน พ.ศ. 2569 (1 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569)`. The first token pair can be interpreted as day 4 to day 1 rather than selecting the parenthesized range.
- The section parser selects a heading based on `_tryParsePeriod`, so a misleading successful parse can become the section period.

Required correction:
1. Parse explicit range expressions as a higher-priority syntactic unit, including parentheses and separators.
2. Treat standalone title dates and numeric unit identifiers as contextual evidence, not automatic range endpoints.
3. If multiple explicit ranges conflict, return an ambiguity/error finding instead of selecting the first pair.
4. Preserve current supported formats and add regression tests for legacy cases.
5. Add the supplied GEN heading and PORTABLE/US/CT period examples as independent-section tests.

### Malformed date columns

The section parser stores source column indexes and attaches date anomalies to each section. The adapter skips sections with blocking date anomalies. This is the correct isolation direction: do not shift a malformed column to fill a missing day, and do not let one invalid section invalidate unrelated valid sections.

The exact X-OPD duplicate-30 / missing-17–29 workbook case still needs a dedicated regression fixture. No inference is made here that current tests cover it.

## 7. Prioritized implementation backlog

| Priority | Work item | Required proof |
|---|---|---|
| P0 | Fix explicit date-range precedence without regressing supported Thai date formats | Unit tests for unit-number heading, paired range, cross-month/year and ambiguous multi-range |
| P0 | Add multi-section workbook regression corpus for PORTABLE, MRI, X-OPD, GEN, US and CT special | Section-local dates; malformed X-OPD blocked only; other valid sections imported |
| P1 | Replace current-date fallback for unresolved AI analyzer dates with an explicit unresolved state or safe compatibility adapter | Tests prove no fabricated current-day assignment |
| P1 | Trace and document canonical import-to-schedule/generator call graph | DI/call-site evidence and end-to-end test |
| P1 | Establish production Calendar sync owner and map legacy paths | Exact caller graph plus retry/idempotency/resume tests |
| P2 | Map history/timeline/audit writers, readers, retention and projections | Repository and integration tests; no data loss |
| P2 | Define migration plan for legacy rule engine only if callers can be adapted | Backward-compatibility and parity tests |

## 8. Evidence status

| Check | Status | Notes |
|---|---|---|
| Source files inspected | PASS | Exact files listed above fetched from the audit branch |
| Feature directory inventory | PASS | Git tree for the branch inspected |
| AI module contracts compared | PASS | Different input/output responsibilities confirmed |
| Rule-engine contracts compared | PASS | Different model contracts and shared evaluator confirmed |
| Calendar sync implementations compared | PASS | Two distinct service/execution paths inspected |
| History/timeline/audit contracts compared | PARTIAL | Domain/service files inspected; complete writer/caller graph remains open |
| Full import/generator call graph | UNKNOWN | Not fully traced |
| User-provided malformed workbook regression | UNKNOWN | No workbook fixture available in repository tree |
| Automated tests executed | SKIPPED | Static connector inspection only; no local runner was invoked |
| Source code changed | NO at initial audit; YES in §10 | Parser and regression-test changes were added after the initial static inspection |
| Main branch changed | NO | All writes target this documentation branch |

## 9. Change-control rules

- Do not delete or rename modules as part of this audit.
- Do not remove unfinished work solely because it is incomplete.
- Preserve all existing public contracts until replacement tests and call-site evidence exist.
- Keep source parsing deterministic and local by default.
- Keep AI output as an allowlisted proposal requiring human confirmation.
- Do not perform Calendar writes, production data changes, deployment or main-branch merge in this audit.


## 10. Parser implementation update

**Updated after the initial static audit.**

Files changed:
- `lib/features/shift_parser/domain/thai_roster_period_parser.dart`
- `lib/features/shift_parser/application/monthly_roster_section_parser.dart`
- `test/sce_thai_roster_period_parser_test.dart`
- `test/monthly_roster_section_parser_test.dart`

Implementation:
- The period parser now checks adjacent date tokens for an explicit range separator (`-`, `ถึง`, or `to`) before falling back to the first two date-like tokens.
- This allows a title such as `GEN คลินิคพิเศษ ภปร. 4 พฤศจิกายน พ.ศ. 2569 (1 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569)` to resolve to 1–30 November 2026 instead of treating the unit number 4 as the range start.
- Multiple explicit ranges in one title are rejected as ambiguous.
- The section parser no longer downgrades an invalid/ambiguous explicit date range to a month-only fallback or the worksheet-tab month, including single-section sheets. Month-only fallback remains available when no explicit date range is present.
- Regression tests cover the numbered-unit heading, explicit parenthesized range, ambiguous multiple ranges, no worksheet-month fallback for conflicting ranges, and isolation of a malformed X-OPD duplicate-day section while preserving a valid PORTABLE section. Existing parser tests remain in place.

Validation:
- Source files and test additions were fetched back from GitHub after writing.
- A lightweight regex/token check against the supplied GEN heading found the intended adjacent range pair (1 November → 30 November).
- **Automated Flutter/Dart tests: SKIPPED** — this connector session cannot execute the repository's test runner. The self-hosted Windows workflow is manual-only and restricted to trusted `main`; no PR or main-branch workflow was triggered.
- **Formatting/analyzer: UNKNOWN** — not executed.
- No Calendar writes, data migration, deployment, PR creation or merge was performed.


## 11. Import and generator pipeline refinement

Additional source files inspected:
- `lib/features/excel_import/presentation/controllers/excel_import_controller.dart`
- `lib/features/excel_import/data/excel_reader_service.dart`
- `lib/features/excel_import/application/import_engine.dart`
- `lib/features/shift_parser/application/snapshot_normalizer.dart`
- `lib/features/shift_parser/application/monthly_roster_workbook_scanner.dart`
- `lib/features/shift_parser/application/hospital_roster_parser.dart`
- `lib/features/schedule/data/imported_schedule_adapter.dart`
- `lib/features/schedule/data/legacy_schedule_adapter.dart`
- `lib/features/schedule_generation/application/schedule_generator.dart`
- `lib/features/schedule_generation/application/monthly_roster_request_builder.dart`
- `lib/features/universal_generator_adapter/application/generator_calendar_adapter.dart`

### 11.1 Two import representations currently coexist

**Tabular import path**
`ExcelImportController → ExcelReaderService → ImportEngine → ShiftRecord → ImportedScheduleAdapter → canonical Schedule`

- Reads XLSX worksheets as row/cell values.
- Suggests column mappings and validates mapped records.
- Produces `ShiftRecord` values, then the schedule adapter builds the canonical `Schedule` aggregate.
- This path is generic column-oriented import, not section-aware monthly-grid parsing.

**Roster-grid parsing path**
`SpreadsheetSnapshot → SnapshotNormalizer → MonthlyRosterWorkbookScanner → MonthlyRosterSectionParser → MonthlyRosterShiftAdapter → legacy Shift`

- Preserves worksheet identity, cell coordinates, raw values, colors and merged-cell metadata.
- Scans worksheets independently and resolves section-local periods/date columns.
- Produces legacy `Shift` values from selected workers after section-level date validation.
- A compatibility adapter exists to convert legacy shifts into canonical schedule structures, but a complete production call graph from every scanner entry point to the canonical schedule writer was not proven in this inspection.

These are distinct input contracts and should not be collapsed into one parser. A future shared canonical import result should preserve source coordinates, original cell values, review decisions, section boundaries, date anomalies and identity-resolution state.

### 11.2 Generation has two separate meanings

- `ScheduleGenerator` produces staffing assignments from a `GenerationRequest`, staff directory, monthly blueprint, staffing rules and coverage requirements.
- `GeneratorCalendarAdapter` accepts already-created `GeneratorEventBatch` records and produces preview-only `CalendarEventCandidate` values. It has no Calendar gateway or sync executor.

They are not the same generation stage. The adapter is an output-boundary bridge; it does not generate a roster or staffing plan.

### 11.3 Integration gap to close

The repository currently contains:
1. Generic tabular import into `ShiftRecord`.
2. Section-aware roster-grid interpretation into legacy `Shift`.
3. Canonical `Schedule` domain and adapters.
4. Staffing-rule-based schedule generation.
5. Preview-only Universal Generator-to-Calendar adapter.

The missing proof is a single documented, tested orchestration contract that shows which user workflow selects each path, how review/approval state is retained, and how generated or imported records enter the canonical schedule without losing provenance. Treat this as an integration backlog item, not a reason to delete one of the existing paths.


## 12. Composition-root and persistence boundary verification

Additional exact source evidence:
- `lib/core/di/app_dependencies.dart`
- `lib/features/excel_import/presentation/controllers/excel_import_controller.dart`
- `lib/features/schedule/data/imported_schedule_adapter.dart`
- `lib/features/schedule/data/legacy_schedule_adapter.dart`
- `lib/features/schedule_generation/application/schedule_generator.dart`
- `lib/features/schedule_generation/application/monthly_roster_request_builder.dart`
- `lib/features/shift_parser/application/monthly_roster_workbook_scanner.dart`
- `lib/features/shift_parser/application/snapshot_normalizer.dart`

### 12.1 Tabular import persistence is exposed, not proven as one UI transaction

The composition root exposes separate operations:
- `createExcelImportController()` constructs the reader/import controller.
- `createImportedSchedule(records)` converts `ShiftRecord` values to a canonical in-memory `Schedule`.
- `loadImportedSchedule()` reads schedule id `imported` from `ScheduleRepository`.
- `saveImportedSchedule(schedule)` persists the supplied aggregate through `ScheduleRepository.save`.
- `createImportedScheduleController(schedule)` creates a repository-backed schedule controller.

The import controller itself converts mapped rows into `ShiftRecord` and `ImportSummary`; it does not call the schedule adapter or repository. The adapter constructs a `ScheduleService` and returns its schedule; it does not persist. Therefore the repository contains the necessary building blocks, but these separate methods do not prove that a production UI flow calls them in the correct order or atomically preserves review state. The exact route/widget call sites and failure handling remain to be traced.

### 12.2 Roster-grid compatibility conversion retains metadata outside Schedule

`LegacyScheduleAdapter.toCanonical` converts legacy shifts into canonical assignments and separately records source-oriented metadata (sheet title, source cell, category, exclusion/generated flags, linked shift key, source color and custom title) in `LegacyScheduleConversion`. This is a deliberate compatibility bridge, not evidence that the canonical `Schedule` aggregate itself persists that metadata. Any shared import result or persistence design must retain the conversion metadata alongside the canonical aggregate or provide a tested round-trip store.

The workbook scanner normalizes every supplied worksheet independently, preserving worksheet identifiers, A1 coordinates, raw values and background colors before section parsing. The `SnapshotNormalizer` path additionally preserves merged-cell state and anchor coordinates. These are different snapshot entry points; their caller selection and common provenance contract remain unproven.

### 12.3 Staffing generation currently builds a request; it does not commit it

`MonthlyRosterRequestBuilder.build` creates a new empty monthly `Schedule` and derives `CoverageRequirement` entries from the blueprint and staffing rules. `ScheduleGenerator.autoAssign` delegates to `AutoAssignmentService.generate(request)`. This confirms a staffing-assignment generation capability, but the inspected builder/generator pair does not load an existing imported schedule, persist the result, or route it to Calendar.

The separate `GeneratorCalendarAdapter.preview` remains a preview-only conversion boundary. It has no Calendar gateway, repository or sync executor dependency. Do not present it as a production roster-to-Calendar pipeline.

### 12.4 Verified boundary matrix

| Boundary | Evidence | Status |
|---|---|---|
| XLSX read → tabular ShiftRecord | Reader and import controller source | PASS (source contract) |
| ShiftRecord → canonical Schedule | ImportedScheduleAdapter source | PASS (conversion contract) |
| Canonical Schedule → repository save capability | AppDependencies exposes ScheduleRepository.save | PASS (capability exposed) |
| Production UI calls conversion then save with review state | Exact route/call-site transaction not established | UNKNOWN |
| Roster-grid scan → legacy Shift | Scanner and parser source contracts | PASS (source contract) |
| Legacy Shift → canonical Schedule | LegacyScheduleAdapter source contract | PASS (conversion contract) |
| Legacy metadata survives canonical persistence | Metadata is returned separately; persistence contract not established | UNKNOWN |
| Monthly blueprint/rules → GenerationRequest | MonthlyRosterRequestBuilder source | PASS (request contract) |
| GenerationRequest → assignments | ScheduleGenerator delegates to AutoAssignmentService | PASS (generation entry point) |
| Generated Schedule → repository persistence | No persistence call in inspected builder/generator | UNKNOWN |
| Generated roster → Calendar sync | Universal adapter is preview-only | SKIPPED (not implemented by this adapter) |
| Automated Flutter/Dart execution | No runtime in connector session | SKIPPED |

### 12.5 Next implementation sequence (no destructive consolidation)

1. Trace the actual import screen route/widget and identify whether it invokes `createImportedSchedule`, `saveImportedSchedule`, and `createImportedScheduleController`; capture success, cancellation, duplicate, and repository-failure behavior.
2. Trace roster-grid scanner callers and the exact selection/review point that creates `MonthlyRosterShiftAdapter` output; preserve sheet/cell/date-anomaly metadata through canonical persistence.
3. Define one versioned, backward-compatible import provenance envelope that can wrap both `ShiftRecord` and legacy-grid conversion output without forcing the two source parsers into one implementation.
4. Trace generation UI/controller callers. Define whether generated assignments augment an imported Schedule or produce a separate draft; require preview and human approval before persistence.
5. Add integration tests for import → review → canonical conversion → save → reload and generation → preview → approval → save. Keep Calendar sync as a separate approved side-effect boundary.
6. Only after call-site and regression evidence exists, consider adapters or orchestration refactors. Do not delete either import path or alter existing persisted data as part of this work.


## 13. UI call-site and existing integration-test trace (follow-up correction)

This section supersedes the narrower uncertainty in §12.1 for the tabular Excel import UI. The actual route and call sites were located on the active branch.

### 13.1 Verified Excel import UI orchestration

Source trace:
- `lib/app.dart` registers `ImportExcelPage.routeName` and injects:
  - `dependencies.createExcelImportController`
  - `dependencies.createImportedSchedule`
  - `dependencies.createImportedScheduleController`
  - `dependencies.saveImportedSchedule`
  - `dependencies.loadImportedSchedule`
  - employee and shift-template repositories/controllers.
- `ImportExcelPage._runImport` awaits `controller.importRows(mapping)`, obtains the records, builds a canonical schedule, then opens `ImportSummaryPage`.
- `ImportSummaryPage._resolvedRecords` applies reviewed employee and shift-template selections to each `ShiftRecord`.
- When staging is enabled, `_loadExistingSchedule` loads the existing imported schedule; `ImportStagingPlanner` builds the review plan; `_currentSchedule` applies the selected included rows through `ImportStagingApplier`.
- `_saveSchedule` requires employee review, shift review, staging readiness, and no prior successful save before invoking the injected saver.
- `AppDependencies.saveImportedSchedule` calls `ScheduleRepository.save`.
- After a successful save, `_isSaved` becomes true; the Calendar page receives `enableCalendarSync: true` only in that state.

This confirms an actual tabular import → review/staging → canonical schedule → repository-save UI path. It is not merely a set of disconnected composition-root methods.

### 13.2 Existing integration-test evidence (test source inspected; execution not performed)

`test/import_excel_page_test.dart` contains a widget-level flow that:
1. Opens a generated XLSX workbook and selects its Roster worksheet.
2. Uses column mapping to produce a ShiftRecord.
3. Opens the ImportSummaryPage.
4. Asserts that the imported schedule does not exist in the repository before explicit confirmation.
5. Taps the confirmation/save action.
6. Reloads schedule id `imported` from the repository and asserts that one month was persisted.

`test/import_summary_employee_review_test.dart` includes widget tests that:
- Keep Save disabled while employee identity is ambiguous.
- Require an explicit employee selection before saving.
- Verify the selected canonical employee identity and department on the saved assignment.
- Lock employee/shift review controls after successful save.
- Build a workflow preview from the saved schedule and verify the expected addition.

These are substantive existing tests for import confirmation and review. Their presence is source-verified, but this connector session has not executed Flutter tests; runtime status remains **SKIPPED**, not PASS.

### 13.3 Roster-grid parser integration remains unproven

The repository contains:
- `MonthlyRosterWorkbookScanner` and its unit tests.
- `HospitalRosterParser` and date-first parser tests.
- `SmartRosterAnalyzeGenerator`, which merges legacy and monthly candidates for review and explicitly does not sync or mutate the source roster.

However, the inspected app route tree and composition root do not register a production UI flow that invokes `MonthlyRosterWorkbookScanner` or `HospitalRosterParser`. The tests call these parser classes directly. Therefore:
- Parser behavior and unit/e2e test contracts exist.
- Production UI selection, review, canonical conversion, provenance retention and repository persistence for the roster-grid path remain **UNKNOWN**.
- Do not infer that the generic Excel tabular import route also invokes the section-aware roster-grid parser.

### 13.4 Generation and Universal Generator integration boundary

- `ScheduleGenerator.autoAssign` delegates to `AutoAssignmentService.generate`, which builds a new immutable Schedule value using `ScheduleAssignmentWriter` and returns a `GenerationResult` with conflicts and uncovered requirements.
- The inspected app dependency registration exposes schedule editing and imported-schedule capabilities, but no production route/controller invocation of `MonthlyRosterRequestBuilder` or `ScheduleGenerator` was found in the route tree.
- `GeneratorCalendarAdapter.preview` returns candidates and issues only. `GeneratorAdapterPreview` explicitly requires user confirmation and has no persistence or Calendar sync executor.
- No production roster-generation → approval → persistence → Calendar execution workflow is established by the inspected source.

### 13.5 Revised boundary matrix

| Boundary | Updated evidence | Status |
|---|---|---|
| Excel UI route → import controller | `app.dart` dependency injection and `ImportExcelPage` | PASS (source trace) |
| Import controller → ShiftRecord | Controller and ImportEngine contracts | PASS (source trace) |
| ImportSummary review → resolved records | Employee/shift review selections applied in `_resolvedRecords` | PASS (source trace) |
| Existing schedule load → staging plan | Injected loader and staging planner/applier | PASS (source trace) |
| Explicit confirmation → repository save | `_saveSchedule` → injected saver → `ScheduleRepository.save` | PASS (source trace) |
| Import UI → repository reload integration test | Test asserts absent before confirmation and present after save | PASS (test source); execution SKIPPED |
| Employee identity review before save | Widget tests assert disabled-until-selected and saved identity | PASS (test source); execution SKIPPED |
| Roster-grid parser → production UI | Direct parser tests found; production route not found in inspected tree | UNKNOWN |
| Roster-grid provenance → canonical persisted record | Conversion metadata is separate; end-to-end persistence not found | UNKNOWN |
| Monthly roster builder/generator → production UI | No route/controller invocation found in inspected tree | UNKNOWN |
| Generation result → repository save | No owning orchestration call found | UNKNOWN |
| Universal Generator preview → Calendar executor | Adapter is preview-only by explicit contract | SKIPPED (outside adapter scope) |
| Flutter/Dart test execution | No execution performed in connector session | SKIPPED |

### 13.6 Next safe implementation work

1. Keep the verified tabular import workflow intact; do not duplicate its already-tested review/save sequence.
2. Locate or define the intended user entry point for the roster-grid parser, then add an explicit reviewed conversion result that retains source sheet/cell, section, date anomaly and review-decision metadata.
3. Define whether generated rosters are new drafts or augmentations of imported schedules. Do not silently merge generated assignments into a saved schedule.
4. Add a generation orchestration controller with preview, conflict/uncovered-coverage review, explicit approval, and repository save only after approval.
5. Add end-to-end tests for roster-grid parse → review → canonical conversion → save/reload, and generation → preview → approval → save/reload.
6. Keep Calendar sync as a separate, explicit user-authorized side effect. No Calendar write is implied by parsing, generation, preview or repository save.


## 15. Staging, deduplication and generator test inventory refinement

Further test-source inspection found additional coverage beyond the UI tests listed in §13.

### 15.1 Import staging and re-import safety

- `ImportStagingPlanner` classifies create/update/skip/blocked rows, detects identical duplicate source rows, conflicting duplicate source rows and duplicate assignments already in the schedule.
- `ImportStagingApplier` applies only selected entries and throws if a CREATE would duplicate an existing assignment.
- `test/import_staging_persistence_e2e_test.dart` includes a persistence scenario that saves an original schedule, plans/applies selected changes, saves the staged result, then re-imports and verifies duplicate rows are skipped.
- `test/import_staging_review_integration_test.dart` checks that only selected rows are saved and that blocking review prevents the saver from being called.
- `test/import_staging_legacy_adapter_test.dart` covers conflicting source rows, missing date/identity, duplicate existing keys and delimiter-safe identities.

This means the tabular staging path has stronger source-level and test-source coverage than the initial boundary inventory implied. Runtime execution remains **SKIPPED** in this audit.

### 15.2 Staffing generator test coverage

`test/schedule_generator_test.dart` contains direct tests for:
- manual assignment;
- rejecting an unavailable employee;
- automatic assignment to satisfy coverage;
- insufficient coverage when capacity is reached;
- duplicate-assignment conflict detection;
- uncovered-coverage reporting.

These tests establish that the generator's core domain behavior has test cases. They do not establish a production UI workflow, approved persistence, or a Calendar handoff. No generation-specific persistence/orchestration test was identified in the inspected test inventory.

### 15.3 Updated interpretation

- Tabular import staging/re-import: substantial implementation and test-source coverage exists; execute exact-head tests before calling it runtime-verified.
- Roster-grid parsing: parser/scanner tests exist, but production route and provenance-preserving persistence remain UNKNOWN.
- Staffing generation: core assignment tests exist, but production workflow and persistence remain UNKNOWN.
- Provenance bundle persistence: still UNKNOWN; current canonical Schedule codec does not encode the source/review envelope described in §14.


## 16. Grid conversion identity and shift-rule risk

The section-aware grid parser does have a conversion adapter: `MonthlyRosterShiftAdapter` is defined alongside `MonthlyRosterSectionParser` in `lib/features/shift_parser/application/monthly_roster_section_parser.dart`. It converts non-blocked section assignments to legacy `Shift` values for selected target names and optional shift templates. `MonthlyRosterConversionDiagnostics` reports unsupported assignments that the adapter did not convert.

Two behavior constraints require deliberate handling before this adapter is exposed as a production import workflow:

1. **Target-name matching is substring-based.** The adapter compacts names and accepts a worker when `targets.any(normalizedWorker.contains)`. Existing tests intentionally pass name fragments (for example, separate first/last-name fragments) and expect a full display name to match. Replacing this with strict exact matching would regress existing behavior; retaining it without an ambiguity review can select multiple people with overlapping names. A future workflow must surface all candidates and require canonical employee selection before committing, while preserving the legacy adapter behavior for existing callers.
2. **Shift-template alias ambiguity is fail-closed, but fallback rules remain.** If multiple active templates match a row label, the adapter returns no rule for that row. When no configured template matches, built-in label rules map known labels to fixed time intervals. The conversion diagnostics can expose unconverted rows, but the reviewed workflow must show which configured template or built-in rule produced each shift and allow correction before persistence.

Existing test-source evidence:
- `test/monthly_roster_section_parser_test.dart` covers section discovery, independent ranges, invalid date isolation, selected-worker conversion, cross-month dates and legacy name-fragment matching.
- `test/monthly_roster_conversion_diagnostics_test.dart` checks unsupported shift labels remain visible.
- `test/smart_roster_analyze_generator_test.dart` checks legacy/monthly deduplication and duplicate candidates.

No production route or persisted review record was established for these adapter outputs. Treat conversion output as a review candidate, not an approved canonical schedule.


## 17. Additive Grid section safety classifier

**Implementation added after the UI and persistence boundary trace.**

Files added:
- `lib/features/shift_parser/application/monthly_roster_section_safety.dart`
- `test/monthly_roster_section_safety_test.dart`

The pure `MonthlyRosterSectionSafetyClassifier` classifies an existing `MonthlyRosterSection` as:
- `ready`: valid date range, no blocking date anomalies, populated assignments with worker and shift labels inside the declared range;
- `blockedDate`: date anomalies, unresolved date range, or reversed range;
- `empty`: valid section with no assignments;
- `needsReview`: missing worker identity/shift label or an assignment outside the declared section range;
- `unsupported`: missing section title.

The assessment exposes stable reason codes, `canEnterReview`, and a deliberately fail-closed `canCommit == false`. It does not mutate parser output, change the legacy adapter's substring matching, persist data, or enable Calendar sync. It is not yet wired to a production route/controller.

Tests were added for each state, preservation of assignments in blocked sections, source-cell reason codes, and the no-commit invariant. **Runtime status: SKIPPED** — tests and Dart analyzer/formatter were not executed through the connector environment.


## 18. Additive Grid employee identity candidate resolver

**Implementation added after the section safety classifier.**

Files added:
- `lib/features/shift_parser/application/grid_roster_employee_identity_resolver.dart`
- `test/grid_roster_employee_identity_resolver_test.dart`

The resolver searches active canonical `Employee` records and returns ranked candidate evidence:
1. exact employee code;
2. exact full name;
3. exact display name;
4. exact nickname;
5. substring suggestions.

Exact employee-code evidence outranks weaker exact name/nickname matches. Duplicate candidates at the strongest exact-match rank remain ambiguous. Substring matches are suggestions only. Empty and unknown source labels have explicit statuses.

Safety boundary:
- the resolver never selects an employee ID;
- every result requires human confirmation;
- `canCommit` is always false;
- no alias is saved or inferred;
- the existing `MonthlyRosterShiftAdapter` substring behavior is unchanged.

Tests were added for unique and duplicate exact names, employee-code priority, substring suggestions, inactive employees, blank and unknown labels. **Runtime status: SKIPPED** — test sources were not executed in this environment.


## 19. Shift-rule mapping evidence without a parallel ruleset

The existing `MonthlyRosterShiftAdapter` now exposes a read-only `resolveRuleForLabel` API. It delegates to the same private rule implementation used by legacy conversion and reports whether a mapping came from one active configured template or a built-in legacy rule. It also explicitly reports duplicate active template aliases, empty labels and unsupported labels.

The API materializes the supplied template iterable once before inspection and resolution, so both passes use the same template snapshot. It returns template ID and resolved time range only when evidence supports them. It never chooses between ambiguous templates and never authorizes persistence.

Added test source:
- `test/monthly_roster_shift_rule_resolution_test.dart`

Coverage includes configured template, duplicate alias, built-in P1 morning rule, unsupported/empty labels and inactive templates. Existing conversion path and built-in mapping implementation remain in place. **Runtime status: SKIPPED** — tests were not executed.


## 20. Immutable Grid review-session composition

Files added:
- `lib/features/shift_parser/application/grid_roster_review_session.dart`
- `test/grid_roster_review_session_test.dart`

`GridRosterReviewSessionBuilder` composes section assessments, identity candidate resolution and shift-rule mapping evidence into a read-only snapshot. It requires a source fingerprint, target Schedule ID and target revision from their owning sources; it does not generate these values. It preserves blocked sections and their assignment evidence, and explicitly marks those rows blocked.

This is a preview composition boundary only. It does not save reviewer choices, revalidate a live target revision, create canonical Schedule assignments, persist provenance, expose a UI route or call Calendar services. Both session and assignment report `canCommit == false`.

Tests cover composition, blocked-section preservation and required source/target evidence. **Runtime status: SKIPPED** — no Dart/Flutter test runner was executed.


## 21. Preserve sections with invalid or ambiguous periods

The `MonthlyRosterSectionParser.generateDateStructure` path no longer drops a section when its explicit period cannot be resolved. It retains a `MonthlyRosterSection` with original title and header row, null date bounds, no assignments, and a blocking `unresolved_period` anomaly. This gives downstream review a visible blocked section while avoiding fabricated dates or assignment rows.

The conflicting-explicit-ranges test was updated to require this preserved section. The section safety classifier and review-session builder already preserve the section assessment. Raw unresolved date-cell/worker-cell associations are still not represented as assignments; a future review UI may need a separate unresolved-cell evidence model.

**Runtime status: SKIPPED** — parser tests were not executed.

## 22. Separate Grid provenance envelope and JSON codec

Added:
- `lib/features/shift_parser/domain/grid_roster_import_provenance.dart`
- `lib/features/shift_parser/data/grid_roster_import_provenance_json_codec.dart`
- `test/grid_roster_import_provenance_json_codec_test.dart`

The envelope records import/source/parser/target revision evidence, section readiness and reason codes, source-cell references, canonical employee/template links, review decisions and reviewer evidence, diagnostics and lifecycle. It avoids copying workbook bytes or raw cell values. Model invariants reject duplicate IDs, dangling section references, incomplete reviewer evidence, invalid template IDs and committed state without an accepted Schedule fingerprint.

The JSON codec uses its own format discriminator and schema version 1. It validates required field types, timestamps, date-only values and enum values; unknown schema versions fail explicitly. This is separate from the canonical Schedule codec and does not alter the `shift-tools.canonical-schedule` version-1 payload.

**Boundary:** this is a data model and codec only. No provenance repository, atomic bundle write, crash recovery, Grid UI, canonical conversion or Calendar sync was added. Existing alternating Schedule slots protect only the Schedule payload and cannot prove a two-object transaction. **Runtime status: SKIPPED** — new tests are source-only and were not executed; Dart format/analyze also not run.

## 23. Reviewed Grid-to-canonical conversion

Added:
- `lib/features/shift_parser/application/grid_roster_canonical_converter.dart`
- `test/grid_roster_canonical_converter_test.dart`

The converter requires explicit reviewer decisions for every parsed source assignment, validates active employee and configured-template references, rejects included assignments from blocked sections or outside section date bounds, preserves existing canonical Schedule months/assignments, and rejects duplicate employee/shift/day collisions. It returns a Schedule candidate with PREPARED provenance; it does not persist, call the Bundle Journal, or trigger Calendar sync.

The converter uses stable source IDs from source fingerprint + section + source sheet/cell coordinates. A separate helper derives COMMITTED provenance only when an accepted Schedule fingerprint is provided. The target Schedule ID must match the review session. The actual live revision must still be reloaded by a future production orchestrator before journal commit.

**Runtime status: SKIPPED** — conversion test source was added but not executed; Dart format/analyze and Flutter tests remain unrun.


## 24. Local XLSX multi-sheet Grid scanner

Added:
- `lib/features/shift_parser/application/grid_roster_workbook_scanner.dart`
- `test/grid_roster_workbook_scanner_test.dart`

The scanner fingerprints workbook bytes with SHA-256, adapts each worksheet to `ShiftParserInput`, parses worksheets independently, aggregates section/assignment/warning summaries, and isolates a worksheet read error from other sheets. Local workbook IDs are not represented as Google spreadsheet IDs; source URL generation therefore remains unavailable rather than fabricated.

The current Excel reader does not expose background colors or hidden-sheet metadata. The scanner does not infer these values; its hidden flag is only a default placeholder and must not be treated as verified visibility evidence. This adapter currently handles the local XLSX row model and is not wired into the import UI/controller.

**Runtime status: SKIPPED** — scanner tests and Dart tooling have not been executed.


## 25. Grid import workflow coordinator

Added:
- `lib/features/shift_parser/application/grid_roster_import_workflow.dart`
- `test/grid_roster_import_workflow_test.dart`

The coordinator binds a review session to a live canonical Schedule revision (or an explicit absent-target token), converts explicit decisions, re-reads the target before commit, writes the recoverable bundle journal, and saves through the existing ScheduleRepository. Recovery replays a committed bundle only when the live repository remains at the recorded base revision; observed intervening Schedule changes are conflicts. The coordinator re-reads before saving, but the ScheduleRepository contract has no atomic compare-and-set operation, so strict multi-writer exclusion is still missing.

The scanner now carries its SHA-256 workbook fingerprint on `MonthlyRosterParseReport`, including filtered reports. The coordinator does not invoke Calendar sync and is not yet called by a production screen or application startup hook. It also cannot guarantee a race-free save against another concurrent writer until the repository exposes a conditional/CAS write.

**Runtime status: SKIPPED** — service-level test source was added but not executed; Dart format/analyze and Flutter tests remain unrun.
