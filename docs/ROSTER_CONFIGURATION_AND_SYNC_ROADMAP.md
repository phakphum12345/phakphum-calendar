# Roster Configuration & Intelligent Sync Roadmap

- Status: Active target roadmap; delivery evidence and remaining gaps are tracked in section 17.
- Repository: `phakphum12345/phakphum-calendar`
- Evidence baseline refreshed: `main@19a28843fa379c16417acff5fcdd691fc4f9818f` (2026-11-18)
- Execution rule: READ → ANALYZE → MODIFY → TEST → AUDIT
- Release rule: do not merge a PR while any required check is failing, pending, or otherwise unverified

## 1. Objective

Deliver a reliable, user-configurable roster import and calendar synchronization workflow. Users must be able to choose a roster source, define and save multiple reusable configuration profiles, correct parsing rules, inspect generated events, and explicitly confirm writes to Google Calendar.

The work must extend the repository's existing roster, Excel import, shift-template, preview, generator, calendar-sync, and history boundaries. It must not create a parallel roster or synchronization subsystem.

## 2. Existing foundations to reuse

The repository documentation already describes these capabilities:

- Excel/CSV/TSV/TXT import with worksheet selection and editable column mapping.
- Draft automated import with preview and explicit confirmation before saving.
- Shift templates with configurable short code, name, start/end time, color, work hours, shift rate, and work location.
- Google Sheets import as a partial integration.
- Google Calendar synchronization with review before writing.
- Existing roster, schedule repository, rule evaluation, validation, simulation/calendar preview, audit, and sync-history foundations.

These are documented foundations, not proof that every desired end-to-end behavior is complete. Phase 0 must inspect the actual source, tests, persistence, and UI before assigning implementation status.

## 3. Product principles and invariants

1. **User-defined rules are first-class data.** Do not hardcode a particular hospital, department, sheet layout, shift vocabulary, or date convention as a permanent rule.
2. **No silent guessing.** Ambiguous date, year, employee, section, shift, or time mappings must be surfaced for user resolution.
3. **Preview before mutation.** No roster save, active-source replacement, or Calendar write may happen before the relevant preview and explicit confirmation.
4. **Preserve source and history.** Profile changes and source changes must not erase original files, existing roster records, edit history, Timeline entries, or Calendar event history.
5. **Layer configuration.** Global defaults, reusable profile rules, source-specific rules, and per-event overrides are distinct layers with explicit precedence.
6. **No accidental global mutation.** Editing one event must not alter a saved profile unless the user explicitly chooses to save those changes back.
7. **Reuse canonical boundaries.** Extend existing entities, repositories, import adapters, templates, generators, and sync workflows; avoid duplicate stores and competing parsers.
8. **Account and source are separate.** Choosing a roster source must not create or switch the user's identity or require Google Sheets.
9. **Extensible providers.** Source providers must be pluggable; the initial UX may include local file, camera capture, and Google Drive, without making that list exhaustive.
10. **Evidence-based completion.** Report only tests, builds, CI checks, and production behavior that were actually observed.

## 4. Target user workflow

1. User enters the Login page; a source-choice prompt is shown:
   - Use the existing roster/source.
   - Change roster source.
2. If changing source, user chooses an available provider (for example device file picker, camera capture, or Google Drive).
3. The selected source is imported as a candidate. The existing active source remains intact.
4. User selects an existing configuration profile or creates a new one.
5. Reader analyzes the source using the selected profile and produces a draft.
6. User reviews date/section/column/employee/shift/time mappings and validation findings.
7. User corrects unresolved or incorrect mappings and can save reusable rules to a profile.
8. User previews the roster changes and generated Calendar events.
9. User explicitly confirms the requested operation.
10. The app commits roster changes and/or Calendar writes, records an audit trail, and verifies the result.
11. User can revisit prior sources, profiles, previews, sync outcomes, and Timeline history without losing existing records.

Changing source must not silently replace the active roster. Activation is a separate, explicit operation after successful analysis and confirmation.

## 5. Configuration model

### 5.1 Configuration layers and precedence

Use a documented, deterministic precedence model:

1. Built-in safe defaults (fallback only; never override explicit user choices).
2. User global preferences.
3. Selected reusable profile.
4. Source-specific mapping/rules associated with that profile.
5. Per-event override.

The effective configuration shown in the UI must make the applied values and their origin inspectable. A per-event override is local to that event unless explicitly saved to the profile.

### 5.2 Profile lifecycle

Users must be able to:

- Create, name, edit, duplicate, archive, and select multiple profiles.
- Set a default profile and select a profile per source/work area.
- Save profile versions or equivalent change history with safe migration behavior.
- Inspect when a profile was last used and which source type it applies to.
- Export/import a profile where supported, without embedding roster personal data by default.
- Recover from invalid profile data without losing the last valid version.

Example labels such as PORTABLE, IPD, CT/ER, MRI, and MAM are illustrative user-defined profiles or work areas, not a fixed enum or hardcoded product taxonomy.

### 5.3 Persistence and isolation

Phase 0 must identify existing local and server persistence boundaries. Store profiles through the repository's established persistence architecture, with schema versioning and migration tests. Respect Personal and Organization edition boundaries and existing authorization policies. Do not claim cross-device synchronization unless it is implemented and verified. A local-only profile must be clearly identified as local-only.

## 6. Source provider architecture

Define a provider contract for capabilities such as source selection, access validation, content acquisition, metadata, cancellation, and stable source identity where available.

Initial provider candidates:

- Existing active roster.
- Local device files (including supported spreadsheet/text formats).
- Camera capture or image/document acquisition, subject to an actual supported extraction pipeline.
- Google Drive.
- Future providers through the same contract.

Provider availability is platform-dependent and must be capability-checked. Do not show an enabled action that cannot be completed on that platform. A provider must not bypass analysis, validation, preview, or confirmation. Keep source identity separate from account identity and authorization.

## 7. Reader and date/layout mapping

The profile and analysis workspace must support user-defined mapping for:

- Worksheet/tab and section selection.
- Header rows, data start/end rows, and repeated section boundaries.
- Date source: cell, column, row header, merged/header range, or section heading where supported by the actual file format.
- Employee/person column and optional identity mapping.
- Shift, department, location, work area, and notes columns.
- Multiple tables or sections within one worksheet.
- Source-specific aliases and ignored rows/columns with a visible reason.

Date handling must explicitly model:

- Day/month/year ordering and supported textual/numeric formats.
- Buddhist Era (พ.ศ.) and Gregorian Era (ค.ศ.) without silently treating one as the other.
- Two-digit year interpretation only when a profile defines an unambiguous rule.
- Month/year supplied by a sheet title, section title, row, column, or cell.
- Work periods crossing month or year boundaries (for example, a 16th-to-15th roster period).
- Date-only values separately from timestamp/time-zone values.
- Invalid calendar dates, missing years, contradictory date sources, and impossible ranges.

When two sources of date information conflict, retain the raw values, show the conflict, and require correction or a documented deterministic rule. Do not infer a date solely from a tab title when a section contains explicit dates that take precedence.

## 8. Shift and time rules

Reuse and extend the existing shift-template foundation. Support:

- Source labels, aliases, short codes, and canonical shift names.
- User-defined shift types; do not limit the model to a fixed set of Thai shift labels.
- Start and end times, including shifts crossing midnight.
- Work duration and optional break handling where the existing domain supports it.
- Rules scoped by profile, source, work location, department, and workday.
- Per-event time/name overrides.
- Validation for missing, overlapping, inverted, or implausible times.
- Explicit handling of non-work labels, leave, on-call, daytime coverage, and other special categories according to user-defined rules.

Do not assume that a label such as “กลางวัน” always represents a normal work shift. Its meaning and treatment must be configurable by the user and context.

## 9. Analyze, validate, and preview

Every import/generation run should produce an inspectable analysis result containing:

- Source and worksheet/section identity.
- Selected profile and profile version.
- Raw source coordinates or equivalent provenance for each parsed record.
- Parsed values and normalized values.
- Applied rule and mapping provenance.
- Imported, skipped, duplicate, warning, and error counts.
- Blocking errors and unresolved ambiguities.
- Date-range and section consistency checks.
- Existing roster/calendar conflict findings.
- Proposed creates, updates, and unchanged records.

The UI must support correcting a mapping or record and re-running analysis without losing the original source. Distinguish blocking errors from warnings. Users may proceed only when blocking errors are resolved and all required confirmations are explicit.

Preview must accurately represent the exact changes that the subsequent confirmed operation will attempt. If the source, profile, profile version, or target data changes after preview, invalidate or revalidate the preview before commit.

## 10. Generator and Calendar synchronization

- Feed the validated canonical roster records into the existing generator and sync workflow.
- Do not maintain a second independent event-generation implementation.
- Use stable identifiers/idempotency strategy to prevent duplicate events and support safe retry/resume.
- Make create/update/skip decisions visible in preview.
- Require explicit confirmation immediately before external Calendar writes.
- Never write to Google Calendar as a side effect of parsing, analyzing, selecting a profile, or constructing a preview.
- Verify the actual Calendar response and persist per-item outcomes.
- Handle partial failures without repeating successful writes.
- Preserve event metadata and existing Timeline/audit history.
- Clearly separate local roster save, active-source activation, and Google Calendar synchronization as distinct user actions.

## 11. Audit, history, and recovery

Record enough metadata to explain how a roster/event was produced:

- Source identity and import timestamp.
- Profile ID/version and effective configuration fingerprint.
- Analysis/preview result identity.
- User corrections and overrides.
- Explicit confirmation actor/time and operation scope.
- Generator and sync outcome, including per-item errors.
- Links to existing roster records, audit history, and Calendar Timeline entries where available.

Use append-only or otherwise non-destructive history semantics consistent with existing repository architecture. Do not rewrite historical events when a profile changes. Backup/restore is a separate capability and must not be implied by profile persistence alone.

## 12. Phased implementation plan and exit criteria

### Phase 0 — READ / ANALYZE: repository audit and baseline

Inspect actual code and tests for source selection, Excel/CSV/TSV/TXT import, Google Sheets, shift templates, date parsing, schedule repository, generator, preview, Calendar sync, persistence, Timeline, audit, Personal/Organization edition, and all affected UI routes.

Deliverables:
- Current-state architecture and call graph.
- Existing reusable models/services and gaps.
- Data migration and backward-compatibility risks.
- Test baseline and reproducible known failures.
- A file-level implementation plan.

Exit: audit findings cite exact files/classes/tests; no implementation assumptions remain unverified.

### Phase 1 — Source and profile contracts

Design provider interfaces, profile entity/repository, schema versioning, configuration precedence, profile lifecycle, and source-to-profile association.

Exit: contract tests, persistence tests, migration tests, and isolation tests pass; existing saved data remains readable.

### Phase 2 — Configurable reader and date parser

Extend the existing import reader and mapping UI for layout/section/date configuration and provenance.

Exit: fixture tests cover multiple worksheets/sections, Thai/English labels, BE/CE, cross-month/year periods, explicit section dates, malformed dates, and ambiguous/conflicting dates. No silent guessing.

### Phase 3 — Shift/time rules

Connect aliases and context-scoped time rules to existing shift templates and canonical roster records.

Exit: tests cover aliases, unknown shifts, per-location rules, overnight shifts, special labels, overrides, and invalid times.

### Phase 4 — Analysis, validation, and preview UX

Unify draft analysis, issue resolution, correction, and preview semantics.

Exit: preview matches the proposed mutation set; blocking errors prevent confirmation; changes to inputs invalidate stale previews.

### Phase 5 — Generator and sync integration

Connect validated output to existing generation and Calendar sync workflows.

Exit: idempotency, partial failure, retry/resume, explicit confirmation, and real Calendar response verification pass integration tests. No unconfirmed Calendar writes.

### Phase 6 — History and persistence integration

Connect profile versions, source provenance, overrides, audit, roster history, and Calendar Timeline.

Exit: migration/regression tests prove existing roster records and historical Timeline/Event metadata remain readable and unchanged.

### Phase 7 — Full end-to-end and release audit

Run targeted tests, full Flutter analysis/tests, relevant backend tests, supported platform builds, CI, security/privacy checks, and post-merge verification.

Exit: all required checks for the exact PR head SHA are green; no unresolved blocking defects; main branch is verified after merge.

## 13. Test matrix

| Area | Minimum verification |
|---|---|
| Profiles | create/edit/duplicate/archive/default/version/reopen |
| Persistence | restart, migration, corruption recovery, edition isolation |
| Providers | capability availability, cancellation, invalid source, source switch rollback |
| Layout reader | worksheet, header, row/column, multiple sections, merged/header dates |
| Dates | D/M/Y, BE/CE, two-digit year policy, cross-month/year, invalid/conflicting dates |
| Shift rules | alias, unknown label, location/department scope, overnight, special category |
| Overrides | event-only override does not mutate profile |
| Preview | provenance, errors/warnings, stale-preview invalidation, exact mutation list |
| Generator | expected date/name/time, duplicate prevention |
| Calendar | explicit confirmation, idempotency, partial failure, retry/resume, verified outcome |
| History | old records, audit, app Timeline, Calendar event history preserved |
| UI | login source prompt, source picker, profile manager, mapping editor, preview, accessible errors |
| Regression | existing import, templates, schedule, personal/org, Google login and sync flows |

Use synthetic fixtures for tests; do not commit real staff rosters, personal data, OAuth tokens, or secrets.

## 14. Non-goals and safeguards

- Do not replace Google Sheets support; make it one provider among several.
- Do not require a new user account to change roster source.
- Do not hardcode a single spreadsheet layout, workplace, department, or shift list.
- Do not rewrite the existing roster/calendar architecture before Phase 0 proves it necessary.
- Do not silently replace the active source or delete old source data.
- Do not auto-sync ambiguous or unconfirmed results.
- Do not change existing API routes, ports, or OAuth behavior as incidental cleanup.
- Do not claim image/camera OCR support until a real supported extraction and verification pipeline exists.
- Do not merge when required CI checks fail or their state is unknown.

## 15. PR and release discipline

Deliver work in dependency order, with small reviewable PRs. Each PR must state scope, reused boundaries, migration impact, tests run, results, and remaining risks.

For every PR:
1. READ the current base and relevant implementation.
2. ANALYZE dependencies, compatibility, data safety, and failure modes.
3. MODIFY only the agreed scope.
4. TEST targeted behavior and regression coverage.
5. AUDIT diff, logs, security, persistence, and exact PR head SHA checks.
6. Fix failures and repeat TEST/AUDIT.
7. Merge only after required checks are confirmed green and merge authorization is clear.
8. Verify main after merge and record the resulting commit SHA.

## 16. Historical planning baseline and Phase 0 audit status

The statements in this section describe the original planning baseline and must not be read as the current implementation inventory. The delivered implementation through PR #108 is summarized in section 17; remaining work is listed in section 17.4. The target behavior and dependency sequence in sections 1–15 remain the governing design unless superseded by newer evidence.

### Historical Phase 0 source audit

The initial source-level findings are recorded in [Roster Phase 0 Source Audit](ROSTER_PHASE_0_SOURCE_AUDIT.md). That audit is a historical snapshot from 2026-11-10, not a current claim that the first execution task is still pending. Any remaining call-site tracing or fresh test baseline must be tracked as an explicit open item and verified against current main before closure.


## 17. Implementation status and evidence — 2026-11-18

This section records the roster-import/review/preview delivery track. It is a current-state supplement to the target workflow above, not a claim that every target capability is complete. The broader Flexible Workforce phases in `docs/flexible-workforce/ROADMAP.md` remain a separate product roadmap.

### 17.1 Delivered implementation

| Capability | Evidence | Current disposition |
|---|---|---|
| Review and correct import issues, then re-process without editing the source workbook | PR #100 | Merged |
| Selected read-only preview and proposed-change inspection | PR #101 | Merged |
| Synthetic roster layout corpus, including full-month, cross-year rollover, and non-contiguous date columns | PR #102; corpus expanded to 12 scenarios | Merged |
| Dynamic shift-template matching in parser paths | PRs #97, #98, #99, #103 | Merged; saved templates are consulted before legacy fallback rules |
| Employee identity resolution and review | PRs #105, #106 | Merged; unique exact matches may resolve, ambiguous/unmatched records require explicit review |
| Import → Review → Preview → Confirm local-save regression path | PR #104 | Merged; Calendar sync gateway is not called by the local confirmation path |
| Saved shift-template review in the actual import summary UI | PR #107 | Merged; unknown/ambiguous labels require explicit template choice; unresolved records block local save and Calendar preview |
| Wider roster workspace with collapsed Filters, Statistics, and Shift legend | PR #108 | Merged; table is the primary workspace |

### 17.2 Exact-head CI and merge evidence

The following PR heads were checked before merge. All listed PR-triggered required workflows completed with conclusion `success`:

| PR | Exact head SHA | Auto Detect CI | Linux | Web build | Android | Windows | iOS | PR Gate |
|---|---|---|---|---|---|---|---|---|
| #107 | `319ee846ae3a8b56c2734d509896789a3e8eff41` | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| #108 | `eb29be0dd6ef1bbe1a128fd01ee8f362a72e1012` | PASS | PASS | PASS | PASS | PASS | PASS | PASS |

- #107 merge commit: `047c51871e0434be6efc946612293765587f2b25`.
- #108 merge commit: `19a28843fa379c16417acff5fcdd691fc4f9818f`.
- Both PRs were confirmed closed with `merged=true`; review-thread lists were empty at the pre-merge check.
- The Web workflow built successfully; its Pages deployment step was skipped. No deployment was performed.
- The current `main` ref was compared with the #108 merge commit and returned `identical` (0 ahead / 0 behind).

### 17.3 Safety and scope boundaries

- PR #104's Confirm path persists the canonical local Schedule only. It does not invoke Google Calendar writes.
- PR #107 blocks local save and Calendar preview while employee or shift-template resolution remains unresolved.
- No automatic Google Calendar write, production deployment, DISKPATH change, or file/data deletion was performed as part of PRs #107/#108 or this documentation update.
- CI success is evidence for the tested PR heads; it does not turn unrelated or unexecuted integration/backend checks into PASS.

### 17.4 Remaining work — not yet accepted as complete

1. Complete reusable source/profile lifecycle: profile creation/edit/duplicate/archive/versioning, source association, and recovery/migration.
2. Close remaining parser and layout edge cases with explicit ambiguity handling; do not silently infer dates, employees, or shift times.
3. Define import staging, row-level create/update/skip decisions, cancellation, retry, idempotency, and rollback boundaries.
4. Verify employee-directory and organization scoping end to end; current exact-match review does not prove full workforce master-data governance.
5. Add and execute relevant integration and backend/PHP test workflows; absence or skipped execution is not PASS.
6. Complete revision-bound approval, publication, and durable audit/history requirements before claiming enterprise workflow completion.
7. Preserve the separate explicit Calendar confirmation boundary and existing Timeline/event metadata throughout future work.

### 17.5 Phase disposition

The roster review, template-resolution, synthetic-layout, preview, and local-confirmation slices listed above are delivered. The overall configuration-and-sync roadmap remains **in progress** because the remaining items in 17.4 and the target exit criteria in sections 12–13 are not all verified. This status is intentionally conservative.


---

## 18. Universal multi-source roster ingestion — reconciliation plan (2026-11-26)

**Status:** Source-level reconciliation completed for the current `main` snapshot. Implementation is not yet complete. This section extends the existing roadmap; it deliberately does not create a second import specification or a parallel parser.

- Repository: `phakphum12345/phakphum-calendar`
- Audited base: `main@7ae6b3020c0cc331e2ab730591df44646b0ef530`
- Audit date: 2026-11-26
- Governing rule: inspect and extend existing boundaries; add a new file/class only when the gap is proven and no existing equivalent can be extended.
- Release rule: no merge while a required check is failing, pending, skipped, or unknown; no Calendar write without the existing explicit confirmation workflow.

### 18.1 Target outcome

A user must be able to bring a roster from any supported entry point—device file, Google Sheets/Drive, a supported web link, camera capture, or an image selected from the device—without having to choose a fixed spreadsheet layout first.

All supported source adapters must feed one shared analysis and review lifecycle:

`Select source → acquire/read → normalize → detect layout/sections → analyze → resolve ambiguities → preview → explicit confirmation → save roster → optional Calendar sync`

The input method must not determine a different set of roster rules. The same source content should produce equivalent normalized roster records regardless of whether it arrived as a local workbook, a Google Sheet, or a supported image/document extraction path.

A source provider is responsible for acquisition and access. A format reader is responsible for decoding its content. Layout detection and roster interpretation are shared downstream capabilities. Do not create one parser per provider.

### 18.2 Current-state reconciliation from source

| Entry point / capability | Existing implementation observed on audited `main` | Reconciled status |
|---|---|---|
| Device workbook and delimited files | `LocalRosterFileService` reads `.xlsx`, `.csv`, `.tsv`, and `.txt`; limits are 15 MB and 200,000 cells. `AppController.importLocalRosterFile()` and `importLocalMonthlyRosterFile()` feed existing roster parsing paths. | **EXISTS / PARTIAL** |
| Simple Excel import screen | `ExcelReaderService` uses `file_picker`, accepts `.xlsx`, reads worksheets, and exposes a 50-row preview. `ExcelImportController` and `ImportEngine` apply a six-field column mapping. | **EXISTS / PARTIAL**; a second file-reader path must be reconciled, not copied |
| Google Sheets URL | `AppShell._selectSourceByUrl()` accepts a Google Sheets URL and delegates to `AppController.selectSourceForCurrentAccount()`; `#gid=` selects a tab. | **EXISTS** for Google Sheets URLs, not arbitrary web URLs |
| Google Sheets / Drive selection | Existing recent-sheet selection, Drive picker UI, `GoogleSheetsImportDataSource`, `SheetsGateway`, `SpreadsheetSnapshot`, and ownership checks are present. | **EXISTS / PARTIAL**; preserve account/ownership checks |
| Camera capture | `image_picker` is used by `AppShell`; capture preview and size checks exist. The current capture flow saves the image and opens manual entry. | **EXISTS / PARTIAL**; capture is not table extraction |
| Device image / gallery | The monthly roster workspace can select an image and preview it before manual entry. | **EXISTS / PARTIAL**; no image-to-roster OCR pipeline was found |
| Image text/table extraction | The current manual-source dialog explicitly tells users that OCR is not used and asks them to read and enter the source manually. | **GAP** |
| General website/document URL | The source URL dialog is specifically for Google Sheets. The manual source-kind list includes “เว็บไซต์”, but that option does not fetch a web page or parse a linked roster. | **GAP** for general URL ingestion |
| Reusable layout configuration | `RosterLayoutProfile` contains date-header, name-column, shift-label, row-boundary, date-pattern, and alias fields. The inspected parser boundary does not establish a complete profile repository/editor lifecycle. `ImportProfile` and `ImportService` are also only a domain/service contract in the inspected tree. | **PARTIAL**; trace all persistence call sites before adding anything |
| Shared interpretation | The simple `ImportEngine` path and monthly `MonthlyRosterWorkbookScanner → MonthlyRosterSectionParser` path have different assumptions. `SnapshotNormalizer` already converts Sheets snapshots into parser inputs. | **PARTIAL**; reconcile the paths around shared normalized data and staging |

Key source files already present (do not recreate them): 

- `lib/ui/app_shell.dart`
- `lib/controller/app_controller.dart`
- `lib/services/local_roster_file_service.dart`
- `lib/features/excel_import/data/excel_reader_service.dart`
- `lib/features/excel_import/application/import_engine.dart`
- `lib/features/excel_import/presentation/controllers/excel_import_controller.dart`
- `lib/features/excel_import/presentation/pages/import_excel_page.dart`
- `lib/features/excel_import/data/google_sheets_import_data_source.dart`
- `lib/features/google_sheets/domain/spreadsheet_snapshot.dart`
- `lib/features/shift_parser/application/snapshot_normalizer.dart`
- `lib/features/shift_parser/application/monthly_roster_workbook_scanner.dart`
- `lib/features/shift_parser/application/monthly_roster_section_parser.dart`
- `lib/features/shift_parser/domain/roster_layout_profile.dart`
- `lib/features/excel_import/application/import_staging_planner.dart` and the existing staging/review/apply components.

### 18.3 Architecture rules

1. **One source-neutral import lifecycle.** Reuse the existing source, snapshot, parser, canonical schedule, staging, review, and Calendar workflow boundaries. Provider-specific code must not create a second schedule model or write directly to Calendar.
2. **Separate acquisition from interpretation.** Local files, Google Sheets/Drive, camera/gallery, and supported URLs may use different acquisition adapters. Once decoded, they must enter the same normalized representation with source identity and provenance preserved.
3. **Format readers are capability-based.** A file extension is a hint, not proof of content. Validate actual file type, size, encoding, worksheet availability, and supported features before parsing. Unsupported content must produce a clear actionable result, not a guessed conversion.
4. **Flexible layout detection.** Do not require a fixed first header row, first column, or one table per sheet. Detect candidate header rows, date rows/columns, section boundaries, merged cells where source metadata permits, repeated blocks, blank spacer rows, non-contiguous date columns, and multiple tables. Let users correct the detected mapping.
5. **Date and shift interpretation remain configurable.** Support explicit dates, date cells, numeric day headers, section headings, Buddhist/Gregorian years, cross-month/year periods, aliases, and user-defined shift rules. If evidence conflicts or remains ambiguous, ask for correction; do not silently guess.
6. **Image extraction is an evidence-producing adapter.** Camera/gallery input must retain the original image, allow crop/rotate/perspective correction where appropriate, extract text/table candidates with confidence and coordinates, and send uncertain cells to user review. Do not treat OCR output as confirmed roster data. Prefer on-device/offline processing where feasible; do not introduce paid/cloud OCR without a separate cost, privacy, and consent review.
7. **General URL handling is constrained.** Recognize supported providers (initially Google Sheets/Drive) and supported downloadable document types. Validate scheme, host, redirects, content type, size, and authentication. Never fetch arbitrary internal/private network addresses or follow unsafe redirects. A URL labelled “website” is not an import until content acquisition and parsing are implemented.
8. **One review/commit boundary.** Every source produces a draft with source provenance, detected mappings, confidence, warnings/errors, duplicates, and proposed row-level create/update/skip decisions. Changes to source/profile/target after preview must invalidate or revalidate that preview.
9. **Keep mutations separate.** Importing/reading an asset, analyzing it, and previewing it must not replace the active source, delete records, or write Calendar. Local roster save, active-source activation, and Google Calendar sync remain distinct user-confirmed operations.
10. **Privacy and cancellation.** Keep files/images local unless the user explicitly authorizes remote processing. Do not log roster content, staff names, raw URLs with secrets, or image bytes. Cancellation and permission denial must leave the prior roster unchanged.

### 18.4 Gap-only implementation phases

| Phase | Work to perform in existing boundaries | Exit criteria |
|---|---|---|
| A — Entry-point reconciliation | Trace every UI action to its reader, controller, source identity, and destination. Reconcile the two local-file flows and the two image/manual-entry flows. | Source-to-code call graph and capability matrix are accurate; no duplicate path is added |
| B — Shared source normalization | Reuse or extend existing `LocalRosterSource`, Sheets snapshot, `SnapshotNormalizer`, `ShiftParserInput`, and staging contracts. Add only missing metadata/adapter capability. | Equivalent tabular sources produce the same normalized cells and provenance |
| C — Universal layout and rule resolution | Extend the existing scanner/parser/profile/mapping UI for variable headers, rows/columns, sections, date origins, aliases, and corrections. | Synthetic fixtures pass for irregular layouts, multiple sections, non-contiguous dates, BE/CE, and cross-month/year periods |
| D — Image/document extraction | Add extraction only after confirming supported platform libraries and privacy/cost constraints. Reuse the camera/gallery preview and existing review/staging path. | Camera and gallery fixtures produce editable candidates; low-confidence or missing cells block confirmation; manual entry remains available |
| E — Link/provider completion | Extend the existing URL/Drive/Sheets selection path with provider detection and safe acquisition for explicitly supported links. | Google Sheets continues to work; supported document links import through the same pipeline; unsupported/unsafe URLs fail closed |
| F — Unified review and persistence | Route all adapters through the existing staging, employee/shift resolution, preview, and canonical schedule persistence. Keep Calendar sync separately confirmed. | All channels share create/update/skip, duplicate, correction, cancel, retry, and preview invalidation behavior |
| G — End-to-end and release reconciliation | Run source-specific tests, shared golden-corpus tests, full Flutter checks, platform checks, security/privacy review, exact-head PR gates, and post-merge verification. | Every required check for the exact head is green; main is checked after merge; no pending/skipped/unknown gate is counted as pass |

### 18.5 Regression and acceptance matrix

Use synthetic fixtures only. For the same logical roster, create equivalent examples as XLSX, CSV, TSV, Google Sheets snapshots, camera photographs, and gallery images. Compare canonical output rather than requiring the internal reader implementation to be identical.

Required cases:

- A clean rectangular table; headers on rows other than row 1; blank/title rows; merged headings; repeated header blocks; multiple sections per sheet.
- Dates across rows or columns; explicit date cells; numeric day headers; non-contiguous dates; BE/CE; 28/29/30/31-day months; 16th-to-15th periods; year rollover; duplicate, missing, out-of-order, and contradictory dates.
- Different employee/shift column positions; multiple name/shift columns; aliases; unknown shifts; duplicate names; ambiguous employee identity; empty cells and non-work labels.
- CSV/TSV quoting, delimiter detection, UTF-8 and Thai text, malformed encoding, formula/date cells, file-size and cell-count limits, corrupt files, cancellation, and unsupported file types.
- Images with rotation, perspective, shadows, low contrast, handwriting, overlapping cells, cropped dates, and low-confidence OCR. Every uncertain value must be reviewable and must not be silently committed.
- Google Sheets URL with and without `gid`, Drive selection, revoked access, non-owned/unauthorized documents, inaccessible tabs, expired credentials, and unsupported URLs.
- Equivalent source fixtures must yield equivalent normalized assignments; source provenance must still identify the original provider/file/sheet/page/image and source coordinates.
- Existing import, parser, template, employee-review, schedule-preview, persistence, Timeline, Personal/Organization edition, and Calendar-confirmation tests must remain green.

Existing tests to extend before considering new test files include:

- `test/local_roster_file_service_test.dart`
- `test/excel_import_controller_test.dart`
- `test/import_engine_test.dart`
- `test/import_excel_page_test.dart`
- `test/google_sheets_import_data_source_test.dart`
- `test/monthly_roster_workbook_scanner_test.dart`
- `test/monthly_roster_section_parser_test.dart`
- `test/monthly_roster_layout_profile_test.dart`
- `test/synthetic_roster_corpus_test.dart`
- `test/import_staging_planner_test.dart`
- `test/import_staging_review_integration_test.dart`
- `test/import_preview_review_confirm_vertical_slice_test.dart`
- `test/roster_import_calendar_preview_e2e_test.dart`

### 18.6 PR and repository reconciliation

- `main` remains the audited baseline for this section. Open PRs are not counted as delivered functionality until merged and verified on `main`.
- PR #192 (`feat(roster): add reviewed Grid import and persistence recovery foundations`) was Open/Draft at the audit snapshot. Its changed-file diff and tests must be reviewed as an existing workstream before implementing overlapping grid, staging, or persistence behavior. Reuse its accepted changes after merge; do not copy its implementation into a second path.
- PR #193 concerns Xcode runner queue behavior, not roster ingestion. PR #191 concerns notification outbox behavior, not roster ingestion. Do not pull either into this workstream.
- The existing `ROSTER_CONFIGURATION_AND_SYNC_ROADMAP.md` is the governing plan. This section is an additive reconciliation; the historical Phase 0 snapshot and prior implementation evidence remain unchanged.
- No new Markdown file, parser, source provider, image pipeline, profile repository, or test file is authorized by this plan alone. First extend the relevant existing file and test. A new file is justified only when the audit proves there is no suitable existing boundary and the addition is directly required by a verified gap.
- Keep implementation PRs narrow and dependency-ordered. Record exact base/head SHAs, changed files, reviews, workflow runs, job-level results, and merge commit. Merge only after required gates pass and merge authorization is explicit; then verify the merged commit and main branch.

### 18.7 Current disposition

The current app has useful source-specific entry points, but they do not yet provide a universal, source-neutral import lifecycle. In particular, image capture currently leads to manual entry rather than OCR/table extraction, and the general website option is metadata/manual entry rather than URL ingestion. The two local-file/import paths and two monthly/legacy parsing paths must be reconciled before adding more adapters.

**Overall status: IN PROGRESS.** Phase A source-level audit is complete for the paths listed above. Phases B–G are planned, not implemented or passed. This document update does not claim OCR, arbitrary URL import, universal layout detection, or end-to-end cross-source parity is already available.

## 19. Current implementation checkpoint — 2026-11-27

This section supersedes the earlier main-snapshot statements in sections 17–18 for current delivery status. It records open-PR work, not merged functionality.

| Area | Current work | Evidence / remaining gap |
|---|---|---|
| Per-section orientation | PR #192 integrates horizontal/vertical/mixed axis handling into the roster import pipeline; PR #199 was closed without merge as superseded | Exact latest #192 CI is pending; original workbook acceptance remains open |
| Workbook source evidence | PR #192 captures merged-cell anchors, background colors, A1 coordinates and source fingerprints | Theme-color resolution and all real workbook variants still need verification |
| Delimited sources | PR #192 adds CSV/TSV/TXT to the shared Grid review lifecycle | Validate Thai encodings, large files and user-selected ambiguous orientation |
| Date-first parsing | Existing date-first parser and diagnostics are extended in #192 | Validate cross-month/cross-year and long-range source fixtures, including real 6+ month schedules |
| Employee/shift resolution | Existing template/identity review is reused; unknown or ambiguous records remain unresolved until review | Alias collision, multiple departments and profile lifecycle acceptance remain open |
| Persistence/recovery | #192 consolidates caller-revision CAS, durable journal discovery, explicit recovery assessment, conditional tombstones and APP_KEY-backed encryption of Schedule/journal payloads | Cross-device backend transaction, APP_KEY backup/restore, conditional delete/tombstone and crash-restart acceptance remain open |
| Calendar Sync | #196 adds durable coordination/ETag-aware operation handling | Controlled Google test-calendar acceptance remains external |
| Notifications | #191 adds Web Push sender/outbox worker/retry path | Registered-device and deployed scheduler acceptance remain external |
| Schedule generation | #202 adds revision-bound preview/approval/commit foundation | Revalidate base against #192 and complete UI/read-back recovery |
| Shift Pay | #201 rule conflict/precedence; #203 monthly statement calculation core | Statement persistence/UI and confirmed-assignment integration remain open |
| Historical restore | #204 adds read-only Drive revision restore through Grid review and conditional Schedule commit | Per-assignment diff and real Drive revision acceptance remain open |

Current main remains `68ef85361c2d08e2970160a36475592010d908f7`. All open feature PRs are Draft and unreviewed. Main branch protection is disabled; no exact-main CI or production deployment is claimed. See [Implementation Status](../IMPLEMENTATION_STATUS.md) and [Requirements Traceability](../REQUIREMENTS_TRACEABILITY.md).

