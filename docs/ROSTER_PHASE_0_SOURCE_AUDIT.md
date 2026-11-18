# Roster Configuration & Sync — Phase 0 Source Audit

> **Historical snapshot notice (2026-11-18):** This audit records source observations from 2026-11-10 and is intentionally retained as a historical snapshot. Do not treat its old PR/CI state or open-work list as the current repository status. Use [the current traceability matrix](flexible-workforce/TRACEABILITY_MATRIX.md) and [the roster implementation roadmap](ROSTER_CONFIGURATION_AND_SYNC_ROADMAP.md) for evidence through main commit `19a28843fa379c16417acff5fcdd691fc4f9818f`. Findings below are not silently rewritten; later verified changes are tracked in those current-state documents.

- Repository: `phakphum12345/phakphum-calendar`
- Audited base: `main@df41b34b4b1afbc8ff883341a87f81489b24cb65`
- Audit date: 2026-11-10
- Status: source inspection in progress; test baseline and several call-site traces remain to be completed
- Method: READ → ANALYZE → MODIFY → TEST → AUDIT

## 1. Executive findings

The repository has substantial existing foundations and must be extended in place. The primary active roster pipeline is still centered on `AppController`, the legacy `ShiftParser`, `MonthlyRosterSectionParser`, `MonthlyRosterShiftAdapter`, and the existing Calendar workflow. The canonical schedule/import feature and a separate calendar-sync feature also exist; their call-site ownership must be kept clear to avoid parallel implementations.

The most important verified gaps are:

1. **Automatic Calendar write path bypassed the confirmation dialog.** After `loadRoster`, a legacy `settings.autoSync` value could trigger `prepareCalendarSync()` followed immediately by `syncCalendar()`. The normal UI confirmation dialog was not involved. This conflicts with the agreed preview-and-confirm invariant. A corrective change is included in the current follow-up PR: automatic roster reads no longer write Calendar, and `syncCalendar` requires an explicit confirmation signal and a previously prepared workflow.
2. **Monthly-grid shift conversion contains organization-specific hard-coded time rules.** `MonthlyRosterShiftAdapter._ruleForLabel` maps labels such as P1-P4, IPD, CT IPD, CT ER, ER, GEN, and 14-floor duty to fixed times. These are legacy behavior for the known workbook, not universal rules.
3. **A layout-profile model exists, but persistent profile lifecycle is not established in the inspected module.** `RosterLayoutProfile` contains row/column/date-pattern/alias fields, but the inspected parser feature has no matching profile repository, codec, or user-facing profile manager. References and other persistence locations still need a complete call-site search.
- A separate `ImportProfile` entity exists with a name, column-mapping map, and timestamps, and the abstract `ImportService` accepts one. The repository tree inspected in this audit contains no corresponding concrete `ImportProfileRepository` or persisted profile lifecycle. This is a partial domain/service contract, not proof of reusable profiles being available in the UI.
- `MonthlyRosterTemplateRepository` already persists versioned templates (format versions 1 and 2), with date ranges and grouped row labels. It does not store the full row/column/date-source mapping, year policy, shift aliases, or time rules required by the target profile model.
4. **The simple Excel import and monthly-grid parser are distinct paths.** The Excel import path supports an editable six-field column mapping, but its import engine uses the first row as the header and a limited date parser. The monthly-grid path supports cross-month sections but assumes a numeric day header across columns and the shift label in column A.
5. **Source selection is available but not a login-entry source-choice workflow.** The app supports local roster-file reading and Google Sheets selection for the signed-in Google account. The Login flow is Google identity authentication; the source-selection UI is in the dashboard. The agreed prompt to reuse the prior roster or change source at login is not present in the inspected login/authentication flow.
6. **History is split across several foundations.** Google Calendar event descriptions preserve a Timeline section; Google Drive revision history is read into local Timeline structures; sync history and failed-operation repositories are separate. The current sync-history SharedPreferences implementation caps the list at 100 entries and stores summary counts, not full roster/profile provenance.
7. **A second calendar-sync controller exists.** Its `sync()` method does not itself require a prior preview, and its screen enables sync based on account/month/shift count. Its production call-site status must be traced before deciding whether to harden it, retire it, or route it through the canonical workflow. The active `AppShell` roster sync path uses the legacy AppController → ShiftCalendarWorkflowController route.

These findings are source observations, not a claim that every path in the application has been audited or that all tests have been run.

## 2. Existing production boundaries observed

| Concern | Existing code boundary | Verified behavior |
|---|---|---|
| Main app orchestration | `lib/controller/app_controller.dart` | Loads account-scoped Sheets or local roster files; parses shifts; manages selected periods, alerts, source references, and Calendar preparation |
| Main app UI | `lib/ui/app_shell.dart` | Dashboard source selection; sync flow compares Calendar, handles pending conflicts, prepares a workflow, displays a confirmation dialog, then invokes sync |
| Excel reader | `lib/features/excel_import/data/excel_reader_service.dart` | Local `.xlsx` picker/reader; worksheet list; 50-row preview; full worksheet read for import |
| Column mapping | `lib/features/excel_import/domain/column_mapping.dart` and presentation controller/page | Editable date, shift, employee, department, location, and notes column mappings |
| Tabular import | `lib/features/excel_import/application/import_engine.dart` | Header suggestions from Thai/English aliases; row validation; duplicate hints; simple ISO/DMY date parsing |
| Monthly grid parser | `lib/features/shift_parser/application/monthly_roster_section_parser.dart` | Detects repeated numeric day-header rows, resolves section date periods, tracks source cell coordinates, warns for out-of-range dates |
| Thai period parser | `lib/features/shift_parser/domain/thai_roster_period_parser.dart` | Thai month names/abbreviations, Buddhist/Gregorian year normalization, cross-month/year period ranges, calendar-date validation |
| Layout model | `lib/features/shift_parser/domain/roster_layout_profile.dart` | Data-only profile fields for date headers, name columns, shift-label columns, data bounds, date patterns, and aliases |
| Shift templates | `lib/features/shift_templates/` and `lib/domain/entities/shift_template.dart` | Versioned SharedPreferences persistence; configurable time/location/rate/color; soft deactivation; defaults seeded only for an empty repository |
| Calendar workflow | `lib/features/workflow/application/shift_calendar_workflow_controller.dart` | Validates schedule, prepares provider plan, blocks invalid plans, and requires prepared state before its synchronize method executes |
| Calendar coordinator | `lib/features/workflow/application/calendar_sync_coordinator.dart` | Prepares managed/legacy event comparison and deterministic plan before execution |
| Resilient executor | `lib/features/calendar_engine/application/resilient_calendar_sync_executor.dart` | Executes deletes/inserts/updates, retries each operation, records summary history, stores failed operations for resume |
| Sync history | `lib/features/history/infrastructure/shared_preferences_sync_history_repository.dart` | Persists at most 100 summary entries in SharedPreferences |
| Calendar Timeline | `test/timeline_history_regression_test.dart` and Calendar event repository | Tests preservation of the existing Timeline section when an event is updated |
| Google Drive selection | `lib/features/google_drive/domain/roster_file_picker.dart`, `DriveGateway`, app-specific dashboard picker | Domain contracts exist; the module README says the cross-platform Drive Picker implementation is pending; the current app has a Google-owned Sheets picker in its dashboard |
| Authentication | `lib/features/authentication/application/authentication_controller.dart`, `lib/services/google_auth_service.dart` | Google account identity/session lifecycle; no roster-source prompt in the inspected authentication controller |

## 3. Detailed findings and risks

### 3.1 Reader and date parsing

**Simple Excel import**
- `ExcelReaderService` currently accepts `.xlsx` only (15 MB limit) and reads worksheets into row/cell models.
- Preview is limited to 50 rows; `readWorksheetForImport` reads all rows.
- `ImportEngine.suggestMapping` examines the first row as headers and suggests six semantic fields.
- `ImportEngine.convertRows` skips the first row when `hasHeaderRow=true`.
- Its date parser accepts `DateTime`, ISO-like values parsed by `DateTime.tryParse`, and a three-part day/month/year representation. A year greater than 2400 is reduced by 543.
- This does not yet provide profile-driven D/M/Y versus M/D/Y interpretation, configurable date-source precedence, two-digit-year policy, date-from-header mapping, or multi-section parsing in the same engine.

**Monthly grid parser**
- `MonthlyRosterSectionParser` detects rows with at least seven numeric day columns.
- It assumes column zero contains the row/shift label and that date columns proceed across the remaining columns.
- It scans above each header row for a section heading; a dated section heading takes precedence over a conflicting worksheet title.
- It maps displayed day numbers to a declared period and warns when dates are outside the range or out of order.
- `ThaiRosterPeriodParser` handles Thai month names and abbreviations, BE/CE normalization, cross-month/year ranges, and invalid calendar dates.
- Two-digit years are normalized by an implicit rule in this parser; the rule is not selected per profile.
- The existing tests cover cross-month periods, section headings overriding tab titles, leap years, Thai month names, and two-digit Buddhist-year cases.

**Risk:** the monthly parser is useful and should be preserved, but its layout assumptions and date policy must become explicit profile rules. Do not replace it with the simpler Excel row importer.

### Additional partial profile foundations confirmed

- `ImportProfile` is a domain entity with an ID, name, column mappings, and timestamps. `ImportService` is an abstract contract that accepts an `ImportProfile`, but the repository tree inspected here contains no concrete import-profile repository or durable profile manager.
- `MonthlyRosterTemplateRepository` is already persisted in SharedPreferences and migrates format version 1 into version 2. Its current data is limited to period start/end and grouped row labels; it is not the complete source/layout/date/time profile requested in the roadmap.
- `RosterLayoutProfile` remains a separate data-only model. The three partial models must be reconciled into one compatible profile boundary rather than creating a fourth profile system.

### Additional shift-rule duplication confirmed

- `MonthlyRosterShiftAdapter._ruleForLabel` in `lib/features/shift_parser/application/monthly_roster_section_parser.dart` contains hard-coded times and aliases for P1-P4, IPD, CT-IPD, CT-ER, ER, GEN, and 14-floor duty.
- The legacy `ShiftParser._ruleForLabel` in `lib/services/shift_parser.dart` contains a second hard-coded mapping for several of the same labels.
- `ShiftCatalog.known` in `lib/features/shift_parser/domain/shift_catalog.dart` is a third static category/period-to-time catalog. Its production call sites still need tracing.
- These are overlapping rule sources. Phase 3 must consolidate them behind the selected profile and existing ShiftTemplate boundary while retaining legacy compatibility fixtures.

### 3.2 Shift-time configuration

- `ShiftTemplate` is persistent and editable; its repository stores the template list under `shift_tools.shift_templates.v1`.
- `MonthlyRosterTemplateRepository` separately persists period ranges and grouped row labels, but does not carry shift-time rules or full layout mappings.
- `ShiftCatalog.known` is another static category/period-to-time catalog. The inspected legacy `services/shift_parser.dart` has its own `_ruleForLabel` / department / three-part rules for P1-P4, IPD, CT-IPD, CT-ER, ER, GEN, and 14-floor duty. The production use of `ShiftCatalog.known` still needs a call-site trace.
- Templates support code, display names, start/end time, overnight detection, working hours, location, calendar metadata, reminder, rate, activation, and sort order.
- The initial “กลางวัน” template is a break period with zero working hours, not a normal work shift.
- `MonthlyRosterShiftAdapter._ruleForLabel` separately contains fixed time mappings for several known row labels and categories. It does not resolve those mappings through the persisted ShiftTemplate repository.
- The profile model contains aliases and column lists, but the inspected path does not connect those fields to a persisted rule lifecycle.

**Risk:** a user's edited ShiftTemplate can diverge from the monthly-grid adapter's hard-coded hours. The next implementation must establish one effective rule-resolution boundary and preserve legacy mappings as an explicit migration/default profile, not universal truth.

### 3.3 Source providers and account identity

- The main app supports a local file source through `LocalRosterSource` and Google Sheets sources saved with an owner Google account ID.
- `LocalRosterFileService` supports XLSX, CSV, TSV, and TXT; its picker reads file bytes into memory and returns a `LocalRosterDocument`. It does not persist the file bytes or a durable file reference. `AppController.signOut` clears the in-memory local-source label and loaded roster state, so this local source cannot currently be reselected after restart/sign-out through the inspected path.
- `LocalRosterFileService` reads XLSX, CSV, TSV, and TXT bytes into an in-memory `LocalRosterDocument`; it does not persist the selected file bytes or a durable file reference. `AppController.signOut` clears the in-memory local source label and loaded roster state. Therefore local-source reuse after restart/sign-out is not implemented by this path.
- The dashboard can list owned Google Sheets, select several, choose a source by URL, and activate a saved source.
- The Excel import page has a local `.xlsx` picker and a Google Sheets import path.
- A camera flow exists in the dashboard, but the inspected path captures a photo and opens a manual-entry dialog; it is not evidence of a working OCR-to-roster pipeline.
- `google_drive/README.md` explicitly says the general cross-platform Google Drive Picker implementation is pending, while the legacy dashboard implements a narrower owned-Google-Sheets picker.
- The authentication controller manages Google identity and does not ask whether to reuse or change the roster source.
- The selected Sheets source is account-scoped; a source provider abstraction that separates account identity, source identity, and profile identity is still needed.

**Risk:** do not make source switching require a new account. Keep current account-scoped saved Sheets compatible while introducing a provider-neutral active-source reference.

### 3.4 Preview and Calendar writes

- The primary `AppShell._sync` path compares Calendar read-only, shows conflict warnings, prepares a validated workflow, asks the user to confirm, and only then calls the Calendar write method.
- `ShiftCalendarWorkflowController` requires a prepared plan and checks blocking validation/simulation failures before execution.
- Before the current follow-up change, `AppController.loadRoster` had a legacy `autoSync` path that called prepare and write directly without the UI confirmation dialog.
- Before the current follow-up change, `AppController.syncCalendar` could create a prepared workflow on demand when no previously prepared workflow existed. That allowed callers to bypass the explicit UI preparation/confirmation sequence.
- The separate `CalendarSyncController`/screen path should be audited for production call sites; its controller method can execute without a prior preview.
- The inspected `AppShell` and `AppDependencies` composition files do not directly reference `CalendarSyncController` or `CalendarSyncProtocolService`; the latter's full-repository call-site trace remains open. Its protocol adapter currently passes only create/update candidates into a service that owns a fresh diff, so delete/skip command semantics are not faithfully preserved. Do not wire this adapter into production until its request/plan contract is corrected and tested.
- `CalendarSyncProtocolService` converts only create/update commands to desired events; the handling of delete/skip commands needs a call-site and contract audit before that protocol is used for production deletion workflows.

**Risk:** every path to a provider write must be routed through one preview/validation/confirmation gate. A read, import, analysis, profile change, or preview must never write Calendar as a side effect.

### 3.5 Persistence, audit, and Timeline

- Canonical imported schedules are persisted through `ScheduleRepository`; existing tests cover persistence and editing of imported schedules.
- Shift templates are persisted separately in SharedPreferences.
- Sync history stores status and operation counts; the repository keeps up to 100 entries.
- Failed-operation payloads are stored separately for retry/resume.
- Google Calendar event updates preserve the existing Timeline section in the event description; regression tests cover idempotent Timeline append and preservation during updates.
- Historical Google Drive revisions are read and archived to local Timeline structures; failures are surfaced as warnings rather than silently claiming complete history.
- Profile/source provenance is not yet shown to be part of the durable sync-history entry.

**Risk:** do not replace or truncate the existing Timeline while adding profile history. Define retention and append-only semantics for each history stream, and preserve existing event metadata during migration.

## 4. Test inventory found (not a fresh test execution)

Existing targeted tests include:
- `test/excel_reader_service_test.dart`
- `test/column_mapping_test.dart`, `test/column_mapping_controller_test.dart`, `test/column_mapping_page_test.dart`
- `test/monthly_roster_cross_month_date_test.dart`
- `test/monthly_roster_section_parser_test.dart`
- `test/monthly_roster_all_dates_test.dart`, `test/monthly_roster_all_years_leap_test.dart`
- `test/shift_parser_test.dart`
- `test/smart_roster_analyze_generator_test.dart`
- `test/roster_source_identity_test.dart`
- `test/shift_template_test.dart`
- `test/canonical_import_calendar_vertical_slice_test.dart`
- `test/google_calendar_workflow_integration_test.dart`
- `test/timeline_history_regression_test.dart`
- `test/roster_revision_service_test.dart`

This list is a source inventory only. The tests have not been executed locally in this audit session. CI on each implementation PR must execute the relevant suites.

## 5. Prioritized implementation plan

### P0 — Close unconfirmed Calendar-write paths
- Remove the legacy auto-write behavior after roster reads; preserve the legacy setting without allowing it to bypass confirmation.
- Require an explicit confirmation signal and an already-prepared workflow before `AppController.syncCalendar` can write.
- Keep the existing `AppShell` confirmation dialog as the user-facing authorization point.
- Add regression tests proving no Calendar operation occurs when confirmation or preparation is absent.

### P1 — Persisted reusable profile lifecycle
- Trace all references to `RosterLayoutProfile` and existing settings repositories.
- Add a versioned profile repository/codec through the established persistence boundary.
- Support create/edit/duplicate/archive/default/select and safe migration.
- Connect profiles to source/provider identity without coupling them to Google account identity.
- Add tests for restart, migration, multiple profiles, invalid payload recovery, and event-only overrides.

### P1 — Profile-driven reader and date resolver
- Extend the existing monthly parser and Excel import boundary rather than creating another parser.
- Make row/column/header/section/date-source mappings configurable.
- Add profile-controlled BE/CE, D/M/Y, two-digit-year, cross-month/year, and conflict policies.
- Preserve raw cell values, coordinates, and rule provenance.
- Unknown or contradictory date mappings must remain unresolved and block sync.

### P1 — Profile-driven shift/time resolution
- Replace implicit hard-coded monthly shift times with a resolver that uses selected profile rules and the existing ShiftTemplate boundary.
- Keep legacy mappings in a named compatibility/default profile for migration.
- Support aliases, location/department/workday scopes, special categories, overnight shifts, and per-event overrides.
- Ensure “กลางวัน” semantics remain user-configurable and do not assume every label is a work shift.

### P1 — Source selection and login UX
- Separate account identity, source provider, active source, and profile identity.
- Add the agreed login-entry prompt to reuse the prior source or change source.
- Preserve current local-file and account-scoped Sheets behavior.
- Keep provider availability capability-checked; camera/OCR must not be presented as complete until a real extraction path exists.

### P1 — Unified preview and sync lifecycle
- Trace the separate CalendarSyncController and CalendarSyncProtocolService call sites.
- Choose one canonical preview/plan/confirmation boundary and route active UI paths through it.
- Add preview staleness checks, idempotency, partial-failure recovery, and exact preview-to-write parity.
- Persist per-item outcomes and preserve existing Calendar Timeline metadata.

### P2 — History, backup, and release
- Connect source/profile versions and corrections to audit/history without rewriting historical records.
- Decide sync-history retention and backup/restore policy explicitly.
- Run full regression, static analysis, and all supported platform builds.
- Merge only when required checks for the exact PR head SHA are green; verify main after merge.

## 6. Unverified items to close before declaring Phase 0 complete

- Full call-site search for `RosterLayoutProfile`, `CalendarSyncController`, and `CalendarSyncProtocolService`.
- Full UI route trace for local roster import, saved Sheets, account switch, sign-out, and source activation.
- Persistence inventory for source selections, local roster references, event overrides, and profile-like settings.
- Fresh local or CI test baseline for all parser/import/calendar/history suites.
- Full regression confirmation that old roster data, app Timeline, Calendar event Timeline, and revision archives remain readable.

## 7. Current corrective work

The follow-up PR based on this audit removes the automatic Calendar write after roster reads, requires explicit confirmation and a prepared workflow before `AppController.syncCalendar` executes, updates both existing confirmation-dialog callers (`AppShell` and `PreviewChangesPage`), and adds a regression test. The first CI attempt caught the missing `PreviewChangesPage` argument at static analysis; that call site has since been updated. The latest generated-manifest head still requires a fresh completed CI run before merge.

## 8. CI evidence for this corrective PR

- The first static-analysis run found one remaining caller in `lib/ui/preview_changes.dart` that did not pass the new confirmation argument. That caller was updated to pass confirmation only after its existing confirmation dialog returns true.
- The current branch also runs the generated `DISKPATH` manifest workflow. That workflow may add a follow-up manifest commit; therefore the final check state must always be read from the final PR head SHA, not an earlier pre-manifest commit.
- No merge is permitted while the final head has missing, pending, cancelled, failed, or otherwise unverified required checks.
- The DISKPATH workflow can advance the PR head after the first PR workflows have started. Always inspect the final PR head SHA after manifest generation and ensure checks are attached to that exact SHA; results from a pre-manifest SHA do not prove the final head is green.
