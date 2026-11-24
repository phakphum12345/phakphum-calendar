# Grid Import Review Workflow

**Status:** Design specification; not implemented as a production workflow.  
**Prepared:** 2026-11-24  
**Related:** [Master plan](UNIVERSAL_ROSTER_INTELLIGENCE_MASTER_PLAN.md), [Parser reliability](ROSTER_PARSER_RELIABILITY_SPEC.md), [Provenance and reconciliation](ROSTER_PROVENANCE_AND_RECONCILIATION.md), [Universal Generator](UNIVERSAL_GENERATOR_SPEC.md), [Implementation boundary audit](IMPLEMENTATION_BOUNDARY_AUDIT_2026-11-24.md)

## 1. Purpose and boundary

Define an additive, human-reviewed application workflow that turns a section-aware monthly roster grid into canonical schedule assignments without bypassing the existing parser, identity review, schedule validation, persistence, or Calendar authorization boundaries.

This workflow is a design target. The existence of parser, adapter, diagnostics, repositories, and tests does not mean this workflow is currently reachable from a production UI.

Non-goals:
- replacing or changing the existing tabular Excel import route;
- automatically syncing imported assignments to Google Calendar;
- silently correcting dates, employee identities, shift labels, or malformed sections;
- deleting existing assignments when a source section is missing, partial, or blocked;
- changing the canonical Schedule schema or legacy Shift conversion semantics in the first implementation.

## 2. Existing source components

| Existing component | Verified responsibility | Boundary |
|---|---|---|
| `MonthlyRosterSectionParser` | Discovers section date headers, independent periods, rows, assignments and date anomalies | Parser output only |
| `MonthlyRosterParseReport` | Holds sections, assignments, warnings, sheet summaries and blocking date anomalies | In-memory parse evidence |
| `MonthlyRosterAssignment` | Carries worker label, row label, date, A1 cell, color, spreadsheet ID, sheet ID and sheet title | Source evidence is not canonical identity |
| `MonthlyRosterShiftAdapter` | Converts supported assignments to legacy `Shift` objects | Retains legacy matching and shift-rule behavior |
| `MonthlyRosterConversionDiagnostics` | Reports converted shifts, unconverted assignments and blocking date anomalies | Diagnostic only; no persistence |
| `ScheduleRepository` | Persists canonical Schedule | Does not atomically persist a separate provenance envelope today |

The adapter currently accepts compacted substring matches for worker names. Existing tests intentionally rely on name fragments. Do not replace this behavior with exact-only matching as a side effect of introducing the review workflow. Instead, treat adapter output as candidate generation and require a separate, unique canonical employee resolution before commit.

## 3. Target workflow

```text
Workbook / source reader
  -> MonthlyRosterWorkbookScanner
  -> MonthlyRosterParseReport
  -> section-level safety classification
  -> conversion diagnostics
  -> employee identity candidate review
  -> shift-template / shift-rule review
  -> canonical assignment preview
  -> schedule validation + stale-revision check
  -> explicit human confirmation
  -> durable schedule + provenance commit
  -> post-commit read-back verification
  -> separately authorized Calendar preview/sync
```

Each stage must expose its input, output, warnings, and whether it can mutate durable state. Parsing, diagnostics, matching, and preview are read-only.

## 4. Section-level safety classification

Every section receives one of these states:

- **READY** — date range is resolved, no blocking date anomalies exist, and assignments can proceed to identity/shift review.
- **BLOCKED_DATE** — explicit period is missing, invalid, ambiguous, duplicated, out of order, or has another blocking date-grid anomaly.
- **EMPTY** — valid section structure but no populated assignments.
- **UNSUPPORTED** — source structure cannot be interpreted by the configured parser/profile.
- **NEEDS_REVIEW** — structurally readable but has warnings or unresolved interpretation requiring a person.

A blocked section must not produce commit-ready assignments. It must not be silently dropped from the review screen, because the operator needs to see why it was excluded. A blocked section must never generate mass REMOVE proposals during reconciliation.

Warnings and anomalies must retain section title, source sheet, row/column or A1 evidence where available, and parser diagnostic code. Do not reduce all issues to a single import-level boolean.

## 5. Identity resolution

The source worker name is a label, not a primary key. Resolution order:

1. explicit organization-scoped employee ID from trusted source metadata;
2. user-maintained alias mapping scoped to the selected organization/profile;
3. exact normalized match only when unique in the active employee directory;
4. otherwise unresolved and blocked from commit until a reviewer selects a canonical employee.

Substring matching may help discover candidates but must never itself authorize persistence. Show source spelling and canonical employee identity side by side. Preserve unresolved assignments in the review report; do not discard them.

A reviewer decision must record the selected employee ID, source label, decision type, actor, timestamp, and scope. Reusable alias creation is a separate explicit action and must not be inferred from a one-time selection.

## 6. Shift and template resolution

For each row label, show:
- original section and row label;
- resolved shift template ID and display name, if any;
- whether resolution came from an explicit template, configured alias, or built-in legacy rule;
- start/end time and relevant shift attributes;
- ambiguity or unsupported-label diagnostic.

If multiple templates match, do not choose arbitrarily. If no configured template matches and a built-in rule is used, label it as a built-in rule so the reviewer can distinguish it from a user-configured template. Unsupported rows remain visible and cannot silently vanish from the conversion count.

The first implementation should wrap existing conversion behavior rather than rewrite shift-time rules. Any later rule changes require dedicated regression tests and an explicit compatibility review.

## 7. Preview and reconciliation

Preview must be immutable and include:
- source fingerprint/revision and parser/profile version;
- accepted target schedule ID and revision/fingerprint;
- per-section state and diagnostics;
- source assignment → canonical employee → shift template → proposed assignment links;
- proposed ADD, UPDATE, UNCHANGED, CONFLICT and UNRESOLVED classifications;
- excluded and blocked rows with reasons;
- exact included operations selected by the reviewer.

REMOVE is not part of the default first-release workflow. It may be proposed only after source completeness is proven for the same scope and period, and only through a separate explicit removal review. Absence from a blocked or partial section is never evidence of deletion.

Before commit, compare the current target schedule revision with the revision used to build the preview. If it changed, mark the preview stale and require a fresh preview; do not silently rebase reviewer decisions.

## 8. Persistence and recovery contract

The existing canonical Schedule repository does not atomically save an independent provenance record. Do not claim that two separate SharedPreferences writes form one transaction.

Preferred implementation order:
1. define a versioned, source-neutral provenance envelope and repository contract;
2. define an atomic bundle repository if the storage technology supports it; otherwise define a durable PREPARED/COMMITTED journal with deterministic recovery;
3. write the canonical schedule and provenance through one application use case;
4. read both back and verify schedule fingerprint, envelope linkage, and commit state;
5. recover incomplete PREPARED operations idempotently after restart.

Envelope minimum fields:
- envelope schema version and import run ID;
- source kind, source identity/fingerprint/revision and acquisition timestamp;
- parser/profile version;
- section and cell evidence references;
- candidate-to-canonical assignment links;
- identity and shift-rule decisions;
- diagnostics and included/excluded decisions;
- accepted target schedule ID/revision/fingerprint;
- lifecycle state and commit timestamps.

Do not store raw workbook bytes, full raw cell payloads, access tokens, or private URLs by default. Do not modify canonical Schedule schema v1 merely to attach provider-specific fields.

## 9. Required application API shape

The concrete names may follow repository conventions, but responsibilities should remain separated:

- `GridRosterImportUseCase`: coordinates scan, parse, diagnostics and read-only preview creation.
- `GridRosterReviewSession`: immutable review snapshot with source/target fingerprints and candidate rows.
- `GridRosterIdentityResolver`: proposes identity candidates; cannot persist decisions.
- `GridRosterCommitUseCase`: validates review completion and target freshness, then commits the reviewed bundle.
- `RosterImportBundleRepository`: stores/retrieves schedule + provenance with atomic or recoverable semantics.
- `GridRosterReviewController`: presentation state only; no direct repository bypass.

These are proposed contracts, not claims that these classes currently exist.

## 10. Acceptance and regression tests

### Parser and section isolation
- each section retains its own date range;
- one malformed section does not block an independent valid section;
- blocked section remains visible and produces no commit-ready candidates;
- duplicate/missing/out-of-order date columns are not auto-shifted;
- the existing X-OPD malformed-header regression remains intact.

### Identity and shift mapping
- duplicate employee names remain unresolved until explicit selection;
- substring candidate matching does not authorize a commit;
- existing fragment-matching adapter tests remain unchanged and pass;
- ambiguous shift-template aliases remain unresolved;
- built-in shift mapping is identified in the review evidence;
- unsupported row labels remain visible and counted.

### Persistence and recovery
- schema-v1 canonical schedule fixtures still load unchanged;
- provenance envelope round-trips with stable IDs;
- crash after PREPARED is recoverable without duplicate assignments;
- repeated commit request is idempotent;
- review decisions survive restart;
- read-back verifies schedule and provenance linkage;
- stale target revision forces a new preview;
- blocked/partial source never produces mass REMOVE.

### End-to-end
- scan → review → explicit confirmation → persist → reload;
- excluded rows remain excluded after reload;
- source cell links/evidence remain available after reload;
- Calendar sync remains disabled until a separate authorized preview and confirmation;
- existing tabular Excel import tests and behavior remain unchanged.

A test source file is not a passing test result. Acceptance requires executing the relevant tests on the exact commit SHA and recording CI/runtime evidence separately.

## 11. Implementation sequence

1. Add pure section safety classification and tests.
2. Add immutable review-session model and source/target fingerprint contract.
3. Add identity candidate review without changing the legacy adapter.
4. Add shift/template resolution evidence and diagnostics.
5. Add versioned provenance envelope and repository/recovery design.
6. Add commit use case and persistence integration tests.
7. Add a dedicated Grid review UI route using the existing scanner/parser.
8. Add separate Calendar preview integration only after commit and authorization gates are proven.

Do not collapse these stages into one large change. Each stage must preserve existing tabular import behavior and have its own evidence.


## 12. Implementation progress — 2026-11-24

The following additive, pure application helpers have now been added on the working branch:

- `MonthlyRosterSectionSafetyClassifier` classifies a section as ready, blocked by date evidence, empty, requiring review, or unsupported. It retains the original section and returns stable reason codes. Its assessment never authorizes commit.
- `GridRosterEmployeeIdentityResolver` ranks active employee candidates by exact employee code, exact full name, exact display name, exact nickname, then substring suggestions. It returns candidate evidence only; it never selects an employee ID or authorizes commit.
- Unit-test source files cover section classification, blocked-section preservation, missing/out-of-range evidence, exact/ambiguous identity matches, stronger employee-code evidence, substring-only suggestions, inactive employees and unknown source names.

These helpers are not connected to a production Grid route/controller, canonical Schedule conversion, provenance repository or persistence. Existing `MonthlyRosterShiftAdapter` substring behavior is unchanged. Runtime test status remains SKIPPED until tests are executed on an available Flutter/Dart runner.


## 13. Shift-rule evidence implementation — 2026-11-24

The existing `MonthlyRosterShiftAdapter` now exposes `resolveRuleForLabel`, a read-only description of the exact mapping rule already used by the legacy converter. It reports:
- `configuredTemplate` with the canonical template ID and mapped time range;
- `builtInRule` with code/time details and no fabricated template ID;
- `ambiguousTemplate` when multiple active templates share an alias;
- `unsupportedLabel` or `emptyLabel` when no safe mapping exists.

This API reuses the adapter's existing rule implementation instead of introducing a second shift-time ruleset. Existing conversion behavior is retained. The returned mapping remains review-only (`requiresHumanConfirmation == true`, `canCommit == false`). Test sources cover configured, ambiguous, built-in, unsupported, empty and inactive-template cases; runtime execution remains SKIPPED.


## 14. Immutable review-session composition — 2026-11-24

Added `GridRosterReviewSessionBuilder` to compose the existing parser report, section safety assessments, employee candidate results and shift-rule evidence into one immutable review snapshot. Each session is bound to caller-supplied source fingerprint, target Schedule ID and target revision; blank evidence is rejected rather than synthesized.

Blocked-date and unsupported sections remain visible with their original assignments and are explicitly marked blocked. Identity and shift mappings remain proposals only. The session and every assignment expose `canCommit == false`; no repository, UI route, approval store or Calendar gateway is called.

Test sources cover a valid composed preview, preservation of assignments from a blocked section, and rejection of missing source/target revision evidence. Runtime execution remains SKIPPED.


## 15. Preserve unresolved-period sections — 2026-11-24

The parser previously emitted a warning and omitted a section when its explicit date period was invalid or ambiguous. It now retains a section shell with its original title/header row and a blocking `unresolved_period` anomaly. Start/end dates remain null, and no assignments or dates are fabricated. This lets the review layer show the blocked section instead of silently losing it.

The conflicting-explicit-ranges regression now asserts that the section remains in the report, has no resolved date range or assignments, and carries the blocking anomaly. The source/test change is committed; runtime execution remains SKIPPED.

## 16. Versioned provenance envelope and codec — 2026-11-24

Added an additive, separate provenance data contract:
- `GridRosterImportProvenance` is a version-1 envelope with import-run ID, source fingerprint, parser version, UTC creation time, target Schedule ID/revision, lifecycle and (only after commit) accepted Schedule fingerprint.
- Section evidence stores stable section ID/title, readiness code, optional date bounds and reason codes.
- Assignment evidence stores stable source assignment ID, section ID, optional source-cell reference/date, canonical employee/template IDs, rule kind, include/exclude/pending decision and paired reviewer evidence for final decisions.
- Diagnostics store codes/severity and optional section/cell references.

The envelope deliberately does not retain workbook bytes, raw cell values, source worker labels, secrets or arbitrary parser payloads. IDs and cell references are evidence pointers, not copied workbook content.

`GridRosterImportProvenanceJsonCodec` encodes a separate format discriminator and schema version. It rejects malformed structures, missing/wrongly typed required fields, unknown enum values and unsupported versions. Model invariants reject duplicate IDs, dangling section references, invalid date pairs, reviewer-less final decisions, invalid template evidence and committed envelopes without an accepted Schedule fingerprint.

This implementation does not modify `shift-tools.canonical-schedule` schema v1 or its codec/repository. Tests were added for round-trip evidence, include/exclude decisions, committed lifecycle, unsupported versions, missing fields, unknown enum values, privacy-minimizing serialization and model invariants. **Runtime status: SKIPPED** — tests, formatter and analyzer have not been run.

**Persistence remains MISSING.** The existing Schedule repository uses alternating slots for the Schedule payload only. It does not provide a transaction across Schedule and provenance. The new codec is not wired to storage and must not be described as atomic or production commit support. Next design step is a versioned bundle journal with explicit PREPARED/COMMITTED recovery semantics and crash-injection tests; do not implement it as two unrelated preference writes.

## 17. Recoverable Schedule + provenance bundle journal — 2026-11-24

Added:
- `lib/features/shift_parser/data/grid_roster_bundle_journal.dart`
- `test/grid_roster_bundle_journal_test.dart`

The journal stores the canonical Schedule JSON and versioned Grid provenance JSON together inside one versioned record, using two alternating slots per Schedule ID. Commit protocol:
1. Validate Schedule identity, matching import-run/source/target revision evidence, PREPARED/COMMITTED lifecycle and caller-supplied current target revision.
2. Write the next inactive slot as PREPARED and read it back through both codecs.
3. Replace that same inactive slot with COMMITTED and read it back again.
4. Recovery chooses the highest-generation valid COMMITTED record and never returns PREPARED-only content.
5. Repeating the same committed import run with identical Schedule content and accepted fingerprint is idempotent; conflicting reuse of a run ID is rejected.

A failed attempt to write the new COMMITTED record leaves the prior committed slot available. The implementation deliberately does not change canonical Schedule schema v1 or the existing ScheduleRepository API.

**Important storage guarantee:** this is a recoverable two-slot protocol, not a database transaction. SharedPreferences does not provide a documented cross-key transaction or a durable atomic-write guarantee. The journal validates read-back and preserves the previous committed slot during the staged protocol, but power-loss durability and platform-specific storage behavior still require runtime testing. The caller must reload/revalidate the live Schedule revision immediately before invoking commit; the journal checks the revision supplied by the caller and cannot independently query the ScheduleRepository.

Test source covers successful commit/recovery, stale revision rejection, idempotency, interruption before committed write with previous-generation recovery, and PREPARED-only rejection. **Runtime status: SKIPPED** — no Dart formatter, analyzer or Flutter test command has been executed in this connector session.

**Still not integrated:** no production Grid import UI/controller invokes this journal yet; no canonical Grid conversion is wired to it; no Calendar side effect is performed. Treat this as an additive persistence primitive, not a completed production E2E path.


## 18. Reviewed Grid-to-canonical conversion — 2026-11-24

Added:
- `lib/features/shift_parser/application/grid_roster_canonical_converter.dart`
- `test/grid_roster_canonical_converter_test.dart`

The converter consumes an immutable `GridRosterReviewSession`, the target canonical Schedule, current active employee/template snapshots, and an explicit reviewer decision for every source assignment. Decision IDs are derived from the source fingerprint plus section/source-cell identity; missing or unknown decisions fail closed.

Conversion rules:
1. Target Schedule ID must match the review session, and duplicate/invalid target month/day structures are rejected.
2. Every source assignment requires an explicit include/exclude decision with reviewer identity and timestamp.
3. A blocked date/unsupported section cannot contribute included assignments; its source assignments may only be explicitly excluded.
4. Assignments outside their declared section date range cannot be included.
5. Included assignments require an active selected employee and a resolved shift rule. Configured templates must still exist and be active; built-in rules create deterministic canonical ShiftType identifiers.
6. Existing Schedule months and assignments are preserved. A duplicate employee + shift assignment on the same day is rejected instead of silently deduplicated or overwritten.
7. The output is a Schedule candidate plus PREPARED provenance. A separate helper creates COMMITTED provenance only when the caller supplies an accepted Schedule fingerprint.

This conversion is intentionally pure: it does not save the Schedule, invoke the Bundle Journal, update the existing ScheduleRepository, or trigger Calendar synchronization. The converter checks the target revision carried by the review session only indirectly through the resulting provenance; the production orchestrator must reload the actual target Schedule/revision immediately before commit.

Test source covers reviewed conversion, required decisions, preservation/collision handling, and blocked-section exclusion. **Runtime status: SKIPPED** — formatter, analyzer and Flutter tests have not been run in this connector session.

**Remaining E2E work:** connect the converter to a production import controller/review UI, obtain the live target revision from the repository, commit the bundle through the journal, recover on startup, and only then offer an explicit Calendar-sync handoff.


## 19. Local XLSX workbook-to-Grid scanner

Added:
- `lib/features/shift_parser/application/grid_roster_workbook_scanner.dart`
- `test/grid_roster_workbook_scanner_test.dart`

The scanner:
- fingerprints the original XLSX bytes with SHA-256;
- adapts each worksheet's complete `ExcelRow` set to the source-neutral `ShiftParserInput`;
- scans every worksheet independently using a stable workbook-local worksheet index;
- aggregates sections, assignments, warnings and per-sheet scan summaries;
- isolates a worksheet read failure so successfully read sheets remain available for review;
- leaves the local spreadsheet ID empty, preventing source links from being fabricated as Google Sheets URLs.

**Current source limitation:** the existing `ExcelReaderService` exposes cell values but not Excel background formatting or hidden-sheet metadata. The scanner records `hidden: false` as an unavailable/default field, not as verified evidence that a worksheet is visible; it does not infer colors. The adapter currently supports the local XLSX row model. Google Sheets and other source adapters still need to supply their actual source metadata and formatting evidence.

**Runtime status: SKIPPED** — scanner tests were added but not executed in this connector session. The scanner is not yet connected to an ImportExcelPage action or production review controller.


## 20. Grid import orchestration and canonical repository recovery

Added:
- `lib/features/shift_parser/application/grid_roster_import_workflow.dart`
- `test/grid_roster_import_workflow_test.dart`

The workflow coordinator now composes the implemented pieces:
1. Scan all workbook worksheets and carry the XLSX SHA-256 fingerprint on the parse report.
2. Load the target Schedule through `ScheduleRepository.findById`; create an empty candidate only when the target is genuinely absent.
3. Bind the review session to either the canonical Schedule content fingerprint or an explicit `absent:<scheduleId>` revision token.
4. Convert only explicit per-assignment reviewer decisions.
5. Re-read the live Schedule immediately before commit and reject a changed revision.
6. Commit the Schedule + provenance bundle to the journal, then save the canonical Schedule through the existing repository API.
7. If the canonical repository save fails after the journal reaches COMMITTED, `recover(scheduleId)` replays the bundle only if the live repository is still at the recorded base revision. If a newer Schedule is observed, recovery fails with a conflict instead of intentionally overwriting it. The current ScheduleRepository interface has no compare-and-set operation, so a concurrent write in the final read/save window is still a known race and must be closed before claiming strict multi-writer safety.

The workflow does not synchronize Calendar. The caller still needs to present the review and explicit approval in a production UI. The journal and canonical repository use separate persistence writes; recovery is a replay protocol, not a cross-store atomic transaction. The coordinator performs a final read-before-save check, but the repository has no atomic compare-and-set API; strict concurrent-writer exclusion remains MISSING.

Test source covers a local workbook scan through review/convert/commit/save, replay after repository save failure, and stale-target rejection. **Runtime status: SKIPPED** — Flutter/Dart tests, analyzer and formatter were not executed in this connector session.


## 21. Import screen entry point and human review UI

Added:
- `lib/features/shift_parser/presentation/pages/grid_roster_review_page.dart`
- `test/grid_roster_review_page_test.dart`
- Grid workflow composition in `AppDependencies.createGridRosterImportWorkflow()`
- Grid review entry action in `ImportExcelPage`
- Full-worksheet read access in `ExcelImportController.readAllRows()`

The existing Excel import page now exposes a separate **Grid** action for local XLSX workbooks. It scans every worksheet, attempts journal recovery for target Schedule `imported`, loads active employees and shift templates, and opens the review page. The original column-mapping/tabular import path is left intact.

Review UI behavior:
- Worksheet read/parse warnings are carried into the review session and shown before any decision.
- Every assignment starts excluded; no worker is auto-selected.
- The reviewer must provide a reviewer label, explicitly opt assignments in, and select an employee.
- Resolved built-in/configured shift rules are shown. An explicit active Shift Template can be selected to override an unsupported or ambiguous source label.
- Date-blocked sections cannot be included; their source assignments remain visible and are excluded.
- The save action requires at least one included assignment and calls the repository-backed workflow. Calendar sync is not invoked.

**Identity limitation:** the reviewer label is self-reported input, not authenticated identity evidence. A future identity provider integration is required before treating reviewer attribution as verified.

**Source limitation:** this entry point is for local XLSX workbooks. Google Sheets is not routed through this Grid scanner yet. Excel cell colors and hidden-sheet metadata are not exposed by the current reader and remain unavailable.

**Runtime status: SKIPPED** — UI, scanner, workflow and converter tests have not been run; Dart format/analyze have not been run. The UI is source-integrated but not yet runtime-verified.
