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
