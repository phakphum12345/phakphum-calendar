# Roster Configuration & Intelligent Sync Roadmap

- Status: Proposed implementation roadmap; documentation baseline only
- Repository: `phakphum12345/phakphum-calendar`
- Baseline: `main@2778f7fb835a121c75b84dc6cb5f28f25ed831de`
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

## 16. Current documentation status

This document records the agreed target behavior and implementation sequence. It does not claim that the features have been implemented. The first execution task is Phase 0 source-level audit, followed by implementation PRs in dependency order.
