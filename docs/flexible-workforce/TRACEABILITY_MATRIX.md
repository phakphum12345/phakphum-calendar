# Flexible Workforce & Shift Scheduler — Phase 0 Traceability Matrix

## Audit record

- Audit target: `main` at the repository state inspected on 2026-11-14.
- Documentation branch: `docs/flexible-workforce-scheduler-foundation`.
- Scope: source and test inventory for the initial requirements baseline.
- Method: inspect the tracked-file manifest and fetch representative Dart, PHP, and test files from `main`.
- Execution: source inspection only. No Flutter, PHP, database, browser, or end-to-end test suite was executed in this audit.
- Evidence rule: source presence is not proof of runtime behavior. A test file is not a PASS until the relevant test is executed against the identified commit.
- Status vocabulary: PASS / FAIL / SKIPPED / UNKNOWN. Current verification status for all requirements below is UNKNOWN unless explicitly stated otherwise.

## Repository evidence map

| Concern | Existing source evidence | Existing test evidence | Initial finding |
|---|---|---|---|
| Employee domain | `lib/domain/entities/employee.dart`; `lib/features/employees/application/employee_directory_service.dart` | `test/employee_directory_test.dart`, `test/employee_repository_test.dart` | Employee entity exists. It currently requires a Department and stores position as a string; profession/skill/qualification model not established by these files. |
| Canonical schedule | `lib/domain/entities/schedule.dart`; `lib/domain/entities/schedule_month.dart`; `lib/domain/entities/schedule_day.dart` | `test/canonical_schedule_adapter_test.dart`, `test/schedule_json_codec_test.dart` | Canonical aggregate exists and is month/day based. Revision, approval, publication, and tenant ownership are not fields on the inspected Schedule entity. |
| Shift assignments and templates | `lib/domain/entities/shift_assignment.dart`; `lib/domain/entities/shift_template.dart`; `lib/features/shift_templates/infrastructure/shared_preferences_shift_template_repository.dart` | `test/shift_template_test.dart` | Configurable shifts and location exist. Overnight is derived from time ordering. Explicit timezone, effective-dated template versions, and skill requirements were not found in the inspected entity. |
| Schedule generation | `lib/features/schedule_generation/application/schedule_generator.dart`; `auto_assignment_service.dart`; `conflict_detection_service.dart`; `coverage_checking_service.dart` | `test/schedule_generator_test.dart` | Manual and automatic assignment, coverage, availability/capacity conflict checks exist. Generator currently chooses active employees by department and location lock; qualifications/leave and generalized multi-organization constraints need further audit. |
| Rule validation | `lib/features/rules/application/rule_engine.dart`; `schedule_validation_service.dart`; `lib/features/rule_engine/application/rule_engine.dart` | `test/rule_engine_foundation_test.dart`; `test/rule_engine_consolidation_test.dart`; `test/v2/rule_engine_test.dart` | Rule registration and schedule/employee/assignment validation exist. Hard/soft semantics, unknown handling, stable rule versioning, and approval blockers require deeper inspection. |
| Import | `lib/features/excel_import/application/import_engine.dart`; `lib/features/excel_import/data/excel_reader_service.dart`; `lib/features/excel_import/presentation/controllers/excel_import_controller.dart` | `test/import_engine_test.dart`; `test/excel_import_controller_test.dart`; `test/canonical_import_calendar_vertical_slice_test.dart` | Spreadsheet mapping, row conversion, errors, warnings, and duplicate warnings exist. Full staged import transaction, per-operation decisions, and rollback guarantees need verification. |
| Export | `lib/domain/services/export_service.dart`; `lib/features/reports/infrastructure/monthly_schedule_pdf_service.dart` | `test/monthly_schedule_pdf_service_test.dart`; `test/monthly_schedule_report_mapper_test.dart` | Export abstraction and monthly PDF reporting exist. Three-mode template/page/custom designer workflow is not evidenced by the inspected source. |
| Organization and membership | `backend/app/Http/Controllers/Api/V1/OrganizationController.php`; `backend/database/migrations/2026_11_09_000002_create_organizations_and_memberships.php`; `backend/database/migrations/2026_11_09_000003_create_organization_shift_policies.php` | `backend/tests/Feature/OrganizationApiTest.php`; `backend/tests/Feature/OrganizationJoinRequestApiTest.php` | Backend organization, membership, roles, and organization shift policies exist. Full department hierarchy and end-to-end binding to Flutter canonical schedule/workforce entities need verification. |
| Tenant guard | `lib/features/tenancy/application/tenant_guard.dart`; `lib/features/tenancy/domain/tenant.dart` | `test/tenant_guard_test.dart`; `test/v2/access_control_test.dart` | Tenant access and same-tenant guard abstractions exist. Repository-level enforcement for every workforce/schedule read and write is not established by this evidence. |
| Schedule persistence | `lib/features/schedule/data/shared_preferences_schedule_repository.dart`; `lib/features/schedule/data/schedule_json_codec.dart` | `test/schedule_repository_test.dart`; `test/schedule_json_codec_test.dart` | Canonical schedule persistence uses SharedPreferences with versioned key prefix and alternating slots. Multi-user server persistence, tenant-scoped durable storage, and migration/recovery for new entities remain unverified. |
| History and audit | `lib/features/history/infrastructure/shared_preferences_sync_history_repository.dart`; `lib/models/audit_entry.dart`; `lib/services/roster_revision_service.dart` | `test/audit_entry_test.dart`; `test/roster_revision_service_test.dart`; `test/timeline_history_regression_test.dart` | Calendar sync history, roster revision, and audit-related models exist. Complete immutable audit coverage for import/generation/approval/publication/export is not established. |
| Calendar compatibility | `lib/features/calendar_engine/application/calendar_sync_plan_builder.dart`; `lib/features/calendar_engine/application/resilient_calendar_sync_executor.dart`; `lib/features/calendar_sync/application/calendar_sync_protocol_service.dart` | `test/sce_calendar_sync_executor_test.dart`; `test/sce_resilient_calendar_sync_executor_test.dart`; `test/google_calendar_workflow_integration_test.dart` | Existing sync planning, execution, resilience, history, and regression tests exist. Must preserve existing sync IDs, previews, confirmations, and resume semantics. |

## Requirement traceability

| ID | Requirement area | Source evidence | Test evidence | Verification |
|---|---|---|---|---|
| WF-001 | Blank-by-default workspace and organization creation | Backend organization controller and migrations | Organization API tests | UNKNOWN |
| WF-002 | User-defined organization and nested department hierarchy | Organization backend evidence; department model exists in Flutter | Organization API tests; department-specific coverage not established | UNKNOWN |
| WF-003 | User-defined professions, positions, skills, and qualification validity | Employee entity has required department and string position; no inspected skill entity | No qualification-specific test identified in initial manifest review | UNKNOWN |
| WF-004 | Configurable shift definitions, overnight support, timezone and effective dates | ShiftTemplate entity and repository | Shift template tests | UNKNOWN |
| WF-005 | Configurable row/column schedule designer independent of canonical assignments | Schedule and ScheduleMonth aggregates exist; no layout module identified in initial inventory | No schedule-layout test identified | UNKNOWN |
| WF-006 | Draft generation with availability, capacity, and coverage validation | ScheduleGenerator, AutoAssignmentService, ConflictDetectionService | Schedule generator tests | UNKNOWN |
| WF-007 | Qualification, leave, location, and cross-period constraints | Availability/capacity and location lock evidence; qualification and leave integration not established | Further tests required | UNKNOWN |
| WF-008 | Hard/soft constraints with explicit unknown handling and rule versioning | RuleEngine and RuleResult/RuleViolation types | Rule engine tests | UNKNOWN |
| WF-009 | Import preview, mapping, validation, duplicate review, explicit confirmation | Excel import engine/controller and preview pages | Import engine/controller and vertical-slice tests | UNKNOWN |
| WF-010 | Import rollback/no mutation before confirmation | Import pipeline evidence exists; transaction and rollback semantics not yet inspected end-to-end | Dedicated persistence/rollback evidence not yet identified | UNKNOWN |
| WF-011 | Prebuilt Template export | ExportService abstraction and PDF reporting | PDF service tests | UNKNOWN |
| WF-012 | Generated Page export | No direct implementation evidence identified in initial source inventory | No direct test identified | UNKNOWN |
| WF-013 | Custom Design export | No direct implementation evidence identified in initial source inventory | No direct test identified | UNKNOWN |
| WF-014 | Human approval tied to exact schedule revision | Organization shift policy includes requires_approval; schedule approval lifecycle not identified | Approval lifecycle test not identified | UNKNOWN |
| WF-015 | Explicit publication separated from generation and Calendar sync | Existing Calendar workflow is separate; workforce publication lifecycle not identified | Publication lifecycle test not identified | UNKNOWN |
| WF-016 | Scoped authorization and organization isolation | Backend membership/controller and Flutter TenantGuard | Organization API and tenant guard tests | UNKNOWN |
| WF-017 | Complete audit of import/generation/approval/publication/export | Sync history, roster revision, audit model | Existing audit/history tests | UNKNOWN |
| WF-018 | Preserve personal roster and Calendar sync workflows | Existing canonical schedule adapters and Calendar engine | Calendar sync and regression tests | UNKNOWN |
| WF-019 | Backup, restore, migration, and tenant-scoped durable persistence | SharedPreferences repositories and Laravel migrations | Existing repository/migration tests require execution and broader coverage review | UNKNOWN |
| WF-020 | Windows/Web delivery and privacy-safe operation | Existing CI workflow inventory and repository security docs | Delivery checks and secret/privacy tests not executed in this audit | UNKNOWN |

## Gaps and design decisions to resolve before implementation

1. **Do not replace the existing Schedule aggregate.** Determine whether workforce-specific metadata should be added through compatible entities/adapters or a versioned extension. Preserve legacy schedule codecs.
2. **Separate workforce identity from user login identity.** Employee, organization membership, and authenticated account are related but must not be conflated.
3. **Department and position are currently constrained.** The inspected Employee entity requires a Department object and stores position as free text. Decide a backward-compatible migration path for configurable hierarchies, professions, positions, and skills.
4. **Timezone is not explicit in the inspected ShiftTemplate.** Define how local shift times, overnight shifts, DST, and effective dates are represented before adding cross-region scheduling.
5. **Generation is not approval.** Keep generated schedules as drafts; add revision-bound validation and approval only after source audit confirms no equivalent workflow exists.
6. **Import staging must be proven.** Trace the controller, repository writes, confirmation callback, and failure paths before changing import persistence.
7. **Export is broader than PDF.** Inspect all export adapters and UI routes before designing three export modes. Do not assume the abstract ExportService is a complete renderer.
8. **Tenant enforcement must be end-to-end.** A TenantGuard abstraction alone does not prove all repositories or backend queries are scoped.
9. **Avoid SharedPreferences as multi-tenant server storage.** Keep current local persistence compatible while deciding the authoritative persistence boundary for organization data.
10. **Keep Calendar sync contracts unchanged.** No generated schedule should create/update/delete Calendar events without the existing plan, preview, confirmation, guarded execution, and history flow.

## Next audit sequence

- [ ] Read complete import controller and persistence call chain; identify exact confirmation boundary.
- [ ] Read all schedule/employee/shift repositories and JSON codecs; document compatibility constraints.
- [ ] Inspect rule definitions and severity handling; map each rule to hard/soft/unknown semantics.
- [ ] Inspect all report/export routes and adapters; confirm supported file types and current PDF behavior.
- [ ] Trace backend organization authorization, migrations, policies, and Flutter API gateway.
- [ ] Inspect approval/publication and audit implementation across the entire repository; do not infer absence from one folder.
- [ ] Execute targeted Flutter and backend test suites on a checked-out exact commit; record command, commit SHA, exit code, and test counts.
- [ ] Update this matrix with exact line references and PASS/FAIL/SKIPPED/UNKNOWN evidence before any schema or runtime implementation.

## Safety constraints

- No deletion or destructive migration.
- No overwriting existing personal schedules, templates, Calendar sync IDs, or history.
- No fabricated employee or organization data in production.
- Synthetic fixtures only in isolated tests.
- No automatic publishing or Calendar synchronization from generation.
- No merge or deployment without explicit authorization.


---

## Phase 0 deep audit — inspected on 2026-11-14

### Exact source and CI references

- Source baseline: `main` at `dae068b01847b3ca74cbd3ee41fb13aaa346d24e`.
- Confirmed `main` was identical to this baseline at audit time.
- Pull request validation commit: `5bfd985983a196a1c44b07ccc3d2292f19977212`.
- GitHub Actions run IDs: DISKPATH `43602399745`; Windows `43602399788`; Android `43602399768`; iOS `43602399753`; Linux `43602399741`; Web `43602399779`; Auto Detect CI `43602399800`.
- Test log evidence: Auto Detect CI job `132471022147` reports **523 tests passed**. Its Integration tests step was skipped.
- Windows job `132470994774` reports Static analysis and Flutter tests completed successfully; Windows release build was still in progress at the last inspection.
- Linux release build completed successfully.
- Web release build and artifact upload completed successfully; the GitHub Pages deployment job was **skipped**.
- Android APK and unsigned iOS builds were still in progress at the last inspection.
- DISKPATH generation/validation completed successfully.
- Backend/PHP test execution was not found in these workflow runs. Do not infer PHP PASS from Flutter tests.
- The workflow-run evidence is tied to the PR validation commit above, not to a locally executed test command.

### 1. Import controller → repository → confirmation boundary

**Inspected source**
- `lib/features/excel_import/presentation/controllers/excel_import_controller.dart`
- `lib/features/excel_import/application/import_engine.dart`
- `lib/features/excel_import/data/excel_reader_service.dart`
- `lib/features/excel_import/presentation/pages/import_excel_page.dart`
- `lib/features/excel_import/presentation/pages/column_mapping_page.dart`
- `lib/features/excel_import/presentation/pages/import_summary_page.dart`
- `lib/features/schedule/data/imported_schedule_adapter.dart`
- `lib/domain/repositories/import_repository.dart`
- `lib/domain/services/import_service.dart`

**Verified behavior**
- XLSX reader allows only `.xlsx`, enforces a 15 MiB limit, and previews at most 50 rows; the full worksheet is read for conversion.
- Google Sheets uses a read-only data source and ownership verifier before worksheet rows enter the same conversion flow.
- Header mapping is a suggestion and is editable. Required date, shift, and employee fields are validated. Duplicate detection is within the imported batch and currently emits a warning while retaining the duplicate record.
- The summary page has an explicit `ยืนยันและบันทึกตารางเวร` action when a `scheduleSaver` callback is supplied. It saves the adapted canonical Schedule through the injected callback; failure is displayed and can be retried.
- `ImportRepository` stores import profiles only; `ImportService` is an abstraction returning assignments. Neither interface itself establishes a staged import-job transaction.

**Gaps / risks**
- There is no first-class staged ImportJob with per-row create/update/skip decisions, immutable preview snapshot, idempotency key, or rollback record in the inspected flow.
- Duplicate detection does not compare against existing employee/assignment records and does not provide an explicit resolution action.
- The adapter creates Employee objects from imported display names, derives IDs from department/name, and defaults missing department to `Unassigned`; shift times that cannot be parsed become zero-duration values. This is compatibility behavior, not verified identity resolution. Do not treat imported display names as verified master employee identities.
- The save callback is optional/injected; the page itself does not prove every application route supplies it. Confirm production route wiring before enabling bulk import as a guaranteed persistence workflow.
- No transaction spans schedule persistence plus any employee master-data writes; avoid introducing such writes without a staged migration and recovery plan.

**Verification**
- Relevant Flutter test files exist: `test/excel_import_controller_test.dart`, `test/import_engine_test.dart`, `test/import_summary_page_test.dart`, `test/google_sheets_import_data_source_test.dart`, `test/canonical_import_calendar_vertical_slice_test.dart`.
- CI log includes passing tests for all-row import with a 50-row preview and summary rendering. Whole Flutter unit suite: PASS (523 tests in Auto Detect CI log). Integration tests: SKIPPED. PHP tests: SKIPPED / no workflow evidence.
- Requirement WF-009: partial existing implementation; acceptance remains UNKNOWN until full workflow and source-to-record decisions are tested.
- Requirement WF-010: UNKNOWN; no complete rollback/idempotency evidence.

### 2. Schedule / Employee / Shift repositories and codecs

**Schedule**
- `lib/domain/repositories/schedule_repository.dart`
- `lib/features/schedule/data/shared_preferences_schedule_repository.dart`
- `lib/features/schedule/data/schedule_json_codec.dart`
- Canonical schedule repository uses schema key prefix `shift_tools.canonical_schedule.v1.`, an active pointer, and two alternating slots. It reads back and decodes the staged payload before changing the active pointer. Invalid JSON, wrong identity, unsupported schema, and storage failures are returned as controlled failures.
- The codec is schema version 1 and persists the schedule, embedded departments/employees/shift types, months, days, assignments, remarks, locations, and holiday names. It rejects unknown references and duplicate IDs.
- It does not persist schedule revision, approval, publication, or organization/tenant ownership in the inspected aggregate.

**Employee**
- `lib/domain/repositories/employee_repository.dart`
- `lib/features/employees/infrastructure/shared_preferences_employee_repository.dart`
- `lib/features/employees/infrastructure/employee_json_codec.dart`
- Employee repository uses versioned two-slot storage with read-back before pointer swap, validates required fields and duplicate employee codes, and supports whole-directory `saveAll`.
- Employee codec is format version 1. Employee requires a Department and a non-empty first name; position remains a string. No profession/skill/qualification references are persisted in this entity/codec.

**Shift template**
- `lib/domain/repositories/shift_template_repository.dart`
- `lib/features/shift_templates/infrastructure/shared_preferences_shift_template_repository.dart`
- `lib/features/shift_templates/infrastructure/shift_template_json_codec.dart`
- Shift template codec is format version 1 and stores times as minutes, display/color, working hours, location, Calendar defaults, reminder, rate, active flag, and sort order.
- Repository persists the full list under one SharedPreferences key and reads it back after write, but does not use the schedule/employee two-slot pointer strategy. A failed or interrupted single-key write has a different recovery profile.
- Explicit timezone, effective date range, break intervals, qualification requirements, and immutable template version history are not present in this inspected entity/codec.

**Compatibility tests**
- `test/schedule_repository_test.dart`, `test/schedule_json_codec_test.dart`, and `test/employee_repository_test.dart` cover round-trip, malformed/unsupported payloads, active-slot failure preservation, and complete employee-directory save.
- CI logs show schedule codec round-trip and unsupported-version tests passing; employee and schedule repository tests are included in the 523-test suite.
- Shift template repository/codec focused test execution is not individually evidenced in the extracted log.
- Do not change schema version 1 payloads in place. New fields need nullable/default-compatible decoding or a new explicit schema version with migration/rollback tests.

### 3. Rule Engine — Hard / Soft / Unknown

**Inspected source**
- `lib/core/validation/rule_evaluator.dart`
- `lib/features/rules/application/rule_engine.dart`
- `lib/features/rules/application/schedule_validation_service.dart`
- `lib/features/rules/domain/rule_result.dart`
- `lib/features/rules/domain/rule_violation.dart`
- `lib/features/rule_engine/application/rule_engine.dart`
- `lib/features/rule_engine/domain/schedule_rule.dart`
- `lib/features/rule_engine/domain/default_schedule_rules.dart`

**Verified behavior**
- Shared RuleEvaluator deduplicates rule IDs and preserves registration order.
- The schedule rule engine exposes error and warning severities; `RuleResult.passed` is true when there are no errors, even if warnings exist.
- The separate schedule-rule engine exposes info, warning, and blocking severities.
- Default rules include invalid shift times and overlapping shifts as blocking, minimum rest and maximum weekly hours as warnings.
- Existing rules cover useful checks but do not establish a unified severity/policy contract across both rule engines.

**Gaps / risks**
- No explicit UNKNOWN / NOT_EVALUATED / missing-input state exists in the inspected RuleResult or RuleViolation contracts.
- No versioned rule-set snapshot or reproducibility identifier is exposed in these inspected types.
- The inspected ScheduleController.saveSchedule() calls repository.save() directly; it does not enforce validation as a mandatory save/approval gate.
- Warning vs blocking policy differs across the two rule engines. Do not consolidate or map severities until current callers and tests are traced.
- Requirement WF-008: partial existing rule infrastructure; hard/soft/unknown acceptance remains UNKNOWN.

### 4. Export and PDF / spreadsheet adapters

**Inspected source**
- `lib/domain/services/export_service.dart`
- `lib/features/reports/domain/report_service.dart`
- `lib/features/reports/domain/monthly_report_options.dart`
- `lib/features/reports/infrastructure/monthly_schedule_pdf_service.dart`

**Verified behavior**
- Generic ExportService is an interface returning bytes from a Schedule; no concrete implementation was identified in the tracked paths inspected.
- MonthlySchedulePdfService maps the canonical schedule to a report model and renders A4 PDF with orientation, language, summary, notes, legend, and department options.
- Print/share is abstracted through ReportOutputGateway.
- Thai fonts are fetched from a public GitHub raw URL at runtime by the default font loader.

**Gaps / risks**
- No evidence yet for prebuilt-template import/rendering, generated-page export, or a custom document designer.
- No XLSX/CSV export adapter was identified in the relevant tracked-path inventory.
- Runtime font download is a network dependency and can fail offline; bundle or cache fonts if offline/self-hosted behavior is required, subject to licensing.
- Requirements WF-011 through WF-013 remain UNKNOWN beyond the existing PDF report capability.

### 5. Organization API, permission, and tenant isolation

**Inspected source**
- `backend/routes/api.php`
- `backend/app/Http/Controllers/Api/V1/OrganizationController.php`
- `backend/database/migrations/2026_11_09_000002_create_organizations_and_memberships.php`
- `backend/database/migrations/2026_11_09_000003_create_organization_shift_policies.php`
- `lib/features/tenancy/application/tenant_guard.dart`
- `lib/features/tenancy/domain/tenant.dart`

**Verified behavior**
- Organization API routes require Google account middleware. Membership list is scoped to the authenticated user.
- Member listing requires active membership. Member addition and policy changes require owner/admin; non-member access is forbidden.
- Organization creation and initial owner membership plus default shift policies are written in a DB transaction.
- Backend tests cover owner creation, member addition, role-based policy denial, outsider denial, and unregistered account rejection.
- TenantGuard checks tenant existence/status and compares context tenant ID with resource tenant ID.

**Gaps / risks**
- Organization schema is currently organizations + memberships + shift policies; the inspected migration does not define a nested department hierarchy or bind canonical Flutter employee/schedule repositories to organization IDs.
- TenantGuard is a domain/application helper; the inspected backend organization endpoints authorize by organization membership, and local SharedPreferences repositories are not tenant-scoped.
- No end-to-end proof was found that every workforce/schedule read/write enforces both organization and tenant scope.
- Backend Feature tests were identified but not run in the observed GitHub Actions workflows. Backend/PHP status remains SKIPPED, not PASS.
- Requirement WF-016 remains UNKNOWN for full end-to-end isolation.

### 6. Approval, publication, and audit history

**Inspected source**
- `lib/features/audit/domain/audit_event.dart`
- `lib/models/audit_entry.dart`
- `lib/features/history/infrastructure/shared_preferences_sync_history_repository.dart`
- `lib/services/roster_revision_service.dart`
- `backend/app/Http/Controllers/Api/V1/OrganizationController.php` shift policy methods

**Verified behavior**
- AuditEvent and AuditRepository contracts exist, but no concrete AuditRepository implementation was identified in the inspected tracked paths.
- AuditEntry supports backward-compatible local JSON fields for actor, entity, and state transition; AuditLogPage reads entries from AppController.
- SharedPreferencesSyncHistoryRepository stores bounded Calendar sync history, not general workforce workflow audit.
- RosterRevisionService reads Google Drive revisions only; it is not a schedule approval or publication service.
- Organization shift policies configure whether selected shift-exchange workflows require approval; they do not represent approval of a schedule revision.

**Gaps / risks**
- No schedule-revision-bound approval lifecycle, explicit publish operation, or immutable workforce audit persistence was identified in the inspected source inventory.
- Existing local audit entries are not evidence of server-enforced immutability or organization-scoped audit retrieval.
- Requirement WF-014, WF-015, and WF-017 remain UNKNOWN.

### 7. Test execution and CI evidence

| Check | Result | Evidence |
|---|---|---|
| Flutter unit tests | PASS | Auto Detect CI job `132471022147`; log ends with 523 tests passed |
| Flutter static analysis | PASS | Auto Detect CI job `132471022147`; static analysis step completed successfully |
| Windows Flutter tests | PASS | Windows job `132470994774`; Flutter tests step completed successfully |
| Windows release build | UNKNOWN / IN_PROGRESS at last check | Windows job `132470994774` |
| Linux release build | PASS | Linux job `132470709377` completed successfully |
| Web release build | PASS | Web job `132470968892` completed successfully |
| GitHub Pages deployment | SKIPPED | Web deployment job `132471404207` conclusion skipped |
| Android release build | UNKNOWN / IN_PROGRESS at last check | Android job `132471038762` |
| iOS unsigned build | UNKNOWN / IN_PROGRESS at last check | iOS job `132471055355` |
| Integration tests | SKIPPED | Auto Detect CI job `132471022147` |
| Backend/PHP tests | SKIPPED / no run evidence | No PHP test job returned for this commit |
| DISKPATH generation/validation | PASS | Run `43602399745` |

The 523-test result is suite-level evidence. It does not independently mark every product requirement PASS. No local PowerShell test command was executed in this audit. No production Pages deployment occurred in the observed web run.

### Updated requirement disposition

- WF-009: existing XLSX/Google Sheets mapping, preview, conversion, and explicit schedule-save action are present; full import staging, duplicate decisions, and transaction semantics remain UNKNOWN.
- WF-010: UNKNOWN; rollback/idempotency across import operations not established.
- WF-011: existing PDF reporting only; template mode UNKNOWN.
- WF-012: UNKNOWN; generated-page export not evidenced.
- WF-013: UNKNOWN; custom design mode not evidenced.
- WF-008: partial rule infrastructure; unified Hard/Soft/Unknown semantics UNKNOWN.
- WF-016: partial organization membership authorization; end-to-end tenant isolation UNKNOWN.
- WF-014 / WF-015 / WF-017: schedule approval, publication, and complete workflow audit UNKNOWN.
- Existing schedule and employee repository round-trip/failure-preservation tests are included in the passing Flutter test suite; this is compatibility evidence, not a claim that new workforce requirements are complete.

### Next engineering gates (ordered)

1. Trace every production caller that supplies `scheduleSaver` and prove import cannot silently save or bypass the summary confirmation.
2. Design import staging and per-row decisions without treating display names as verified employee identities; preserve the current canonical schedule adapter until a migration is approved.
3. Add targeted tests for duplicate-vs-existing-record decisions, cancelled import, failed save, retry/idempotency, and no mutation before confirmation.
4. Define a single versioned rule outcome contract with PASS / FAIL / UNKNOWN and hard/soft policy while retaining adapters for both existing engines.
5. Define export capability boundaries and eliminate runtime network font dependency for offline output.
6. Establish organization/tenant scope at repository and backend query boundaries before adding department/workforce CRUD.
7. Implement revision-bound approval, explicit publication, and durable organization-scoped audit only after authorization and revision semantics are specified.
8. Run PHP backend feature tests and integration tests; these remain SKIPPED in current CI evidence.
9. Recheck all platform build workflows after completion; do not interpret in-progress jobs as PASS.

## Safety and non-actions

- No application runtime code, schema, or user data was changed during this audit.
- No files were deleted.
- No merge was performed.
- Web build artifact was produced by CI, but the Pages deployment job was skipped.
- No Calendar sync, schedule publication, or production deployment was performed.


---

## Production import wiring and current-head CI recheck — 2026-11-14

### Production composition-root trace

The production import save callback is wired, not merely injectable in tests:

1. `lib/app.dart` registers `ImportExcelPage.routeName` and supplies `scheduleSaver: dependencies.saveImportedSchedule`.
2. The same route supplies `importedScheduleFactory: dependencies.createImportedSchedule` and `scheduleControllerFactory: dependencies.createImportedScheduleController`.
3. `lib/core/di/app_dependencies.dart` constructs the production `ScheduleRepository` as `SharedPreferencesScheduleRepository` by default. Its `saveImportedSchedule(Schedule)` delegates to `scheduleRepository.save(schedule)`.
4. `lib/features/excel_import/presentation/pages/import_excel_page.dart` converts the imported rows into an in-memory Schedule, then passes the production `scheduleSaver` into `ImportSummaryPage`. This conversion is not itself a persistence operation.
5. `lib/features/excel_import/presentation/pages/import_summary_page.dart` exposes the explicit `ยืนยันและบันทึกตารางเวร` button when the callback is present. The save is invoked only by that button; while saving it disables repeat taps; a failed result is shown and the action can be retried; a successful result disables the button.

**Conclusion:** the production route supplies the callback and the visible summary confirmation is the normal save boundary. The earlier uncertainty about whether the production route supplies `scheduleSaver` is resolved. This does not establish that every alternate/custom route supplies it, nor does it add staged row-level decisions, an idempotency key, or a multi-entity rollback transaction.

### Import requirement disposition update

- WF-009 remains **partial / UNKNOWN for full acceptance**: production confirmation and canonical schedule persistence are wired, but duplicate resolution against existing master data, row-level create/update/skip decisions, verified employee identity matching, and an immutable staged preview remain absent from the inspected flow.
- WF-010 remains **UNKNOWN**: no end-to-end rollback/idempotency guarantee has been demonstrated. The save currently persists one canonical Schedule aggregate; it does not coordinate employee master-data writes in a transaction.
- `test/import_excel_page_test.dart` proves the route's repository has no `imported` Schedule before the user taps `ยืนยันและบันทึกตารางเวร`, then verifies the saved Schedule after confirmation. `test/canonical_import_calendar_vertical_slice_test.dart` separately exercises canonical import-to-persistence, reload, validation, and subsequent schedule editing; it is not the confirmation-boundary test.

### Current PR-head CI recheck

- PR: #86, still Draft/Open and mergeable at the time of recheck.
- Branch head checked: `69748afa29fe34529de9e92729909ffd0279d10f`.
- Base: `dae068b01847b3ca74cbd3ee41fb13aaa346d24e`; compare remains 11 ahead / 0 behind.
- Auto Detect CI run `43603440055`: PASS. Static analysis PASS; unit test step PASS with **523 tests passed**. Integration tests SKIPPED.
- Linux run `43603440061`: release build PASS.
- Web run `43603440066`: web build and artifact upload PASS; GitHub Pages deploy SKIPPED.
- DISKPATH run `43603440121`: generation and validation PASS; manifest auto-commit step completed.
- Windows run `43603440073`: static analysis PASS; Flutter tests were still IN_PROGRESS at the last poll; Windows build/package steps had not started.
- Android run `43603440129`: release APK build IN_PROGRESS at the last poll; verification/package/upload had not started.
- iOS run `43603440082`: unsigned iOS build IN_PROGRESS at the last poll; verification/package/upload had not started.
- Backend/PHP feature tests: SKIPPED / no PHP workflow evidence.
- Reviews, review comments, and inline review threads: none returned at the recheck.
- The 523-test result is attached to the exact PR head above through its PR-triggered workflow run. It is suite-level evidence, not proof every requirement is complete.

### Remaining ordered gates

1. Finish Windows, Android, and iOS workflows and record terminal conclusions against the exact head.
2. Add import staging and explicit per-row identity/resolution decisions; reject or quarantine ambiguous employee/shift data rather than silently inventing master records or zero-duration shifts.
3. Define and test cancellation, retry, idempotency, and rollback boundaries for import.
4. Unify Hard / Soft / Unknown validation semantics and make validation policy explicit at save/approval boundaries.
5. Complete export adapter inventory and offline-safe licensed Thai font packaging.
6. Establish organization scope at persistence and backend query boundaries; add cross-tenant negative tests.
7. Design revision-bound approval, explicit publication, and durable audit.
8. Add and execute backend/PHP feature tests and integration tests.

### Safety

No application runtime source, database schema, user data, or Calendar data was changed by this recheck. No file was deleted, no PR was merged, and no deployment or Calendar synchronization was performed.


---

## Roster workflow delivery evidence — 2026-11-18

### Evidence baseline and interpretation

- Current repository baseline: `main@19a28843fa379c16417acff5fcdd691fc4f9818f`.
- This section supplements the original Phase 0 enterprise/workforce inventory; it does not retroactively change the 2026-11-14 source-only audit into a runtime verification.
- The WF-001–WF-020 rows above retain their existing **UNKNOWN** status for full requirement acceptance unless a requirement is explicitly narrowed and verified below. A passing Flutter suite or a merged feature PR does not prove the entire workforce requirement.
- PR references: [#97](https://github.com/phakphum12345/phakphum-calendar/pull/97), [#98](https://github.com/phakphum12345/phakphum-calendar/pull/98), [#99](https://github.com/phakphum12345/phakphum-calendar/pull/99), [#100](https://github.com/phakphum12345/phakphum-calendar/pull/100), [#101](https://github.com/phakphum12345/phakphum-calendar/pull/101), [#102](https://github.com/phakphum12345/phakphum-calendar/pull/102), [#103](https://github.com/phakphum12345/phakphum-calendar/pull/103), [#104](https://github.com/phakphum12345/phakphum-calendar/pull/104), [#105](https://github.com/phakphum12345/phakphum-calendar/pull/105), [#106](https://github.com/phakphum12345/phakphum-calendar/pull/106), [#107](https://github.com/phakphum12345/phakphum-calendar/pull/107), [#108](https://github.com/phakphum12345/phakphum-calendar/pull/108).

### Roster-specific requirement traceability

| Roster requirement | Implementation evidence | Verification evidence | Disposition |
|---|---|---|---|
| Correct an import issue and re-run mapping without changing the source workbook | PR #100 | Merged PR and its regression coverage | PASS for the scoped in-memory correction path |
| Inspect selected schedule changes before local save | PR #101 | Merged read-only selected preview | PASS for the scoped preview |
| Handle complex roster table layouts | PR #102 | Synthetic corpus expanded to 12 scenarios, including full-month, year rollover, and non-contiguous date columns | PASS for the listed fixtures; not universal parser coverage |
| Resolve configured shift labels dynamically | PRs #97–#99 and #103 | Matching uses saved templates before legacy fallback; unknown labels remain unresolved in covered tests | PASS for covered parser/template paths; legacy fallback remains for compatibility |
| Resolve employee identity during review | PRs #105–#106 | Unique exact matches can resolve; duplicates/ambiguous/partial/unknown matches require explicit review | PASS for covered resolver and UI behavior; not full organization-wide identity governance |
| Import → Review → Preview → Confirm | PR #104 | E2E test covers local canonical save/reload; preview does not call Calendar sync gateway | PASS for the tested local workflow; Google Calendar write is a separate explicit action |
| Apply configured shift templates in the production import review UI | PR #107 | Exact saved template can resolve; unknown labels require explicit choice; unresolved employee/template state blocks local save and Calendar preview | PASS for the covered widget/UI cases |
| Give the roster table the available workspace width | PR #108 | Exact-head CI succeeded; UI test verifies collapsed controls can be expanded | PASS for the implemented layout behavior |

### Exact-head CI evidence for the latest two PRs

| PR | Head SHA | Auto Detect CI | Linux | Web build | Android | Windows | iOS | Pull Request Gate |
|---|---|---|---|---|---|---|---|---|
| #107 | `319ee846ae3a8b56c2734d509896789a3e8eff41` | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| #108 | `eb29be0dd6ef1bbe1a128fd01ee8f362a72e1012` | PASS | PASS | PASS | PASS | PASS | PASS | PASS |

- #107 merged as `047c51871e0434be6efc946612293765587f2b25`.
- #108 merged as `19a28843fa379c16417acff5fcdd691fc4f9818f`.
- Review-thread lists were empty at the pre-merge checks. Both PRs were subsequently verified as merged.
- Web build passed, but Pages deployment was skipped; no deployment was performed.
- `main` and the #108 merge commit compare as identical (0 ahead / 0 behind).
- These are PR-triggered CI conclusions on the exact head SHAs. They do not assert that separate integration or backend/PHP suites ran.

### Remaining requirements and non-PASS states

The following remain **UNKNOWN** or require new evidence before acceptance:

- Full reusable import-profile lifecycle, profile version history, source-to-profile association, and recovery.
- Full import staging with per-row create/update/skip decisions, duplicate resolution against existing records, cancellation, idempotency, retry, and rollback.
- Complete date/layout ambiguity coverage beyond the 12 synthetic fixtures.
- End-to-end organization/tenant isolation across Flutter repositories and backend query boundaries.
- Unified hard/soft/unknown rule semantics and revision-bound validation.
- Revision-bound approval, explicit publication, and durable workflow audit.
- Complete export modes beyond the existing PDF/report evidence.
- Integration tests and backend/PHP feature tests where no successful execution evidence is recorded.
- Backup/restore and cross-device persistence claims.

### Safety and execution notes

- Local schedule confirmation remains separate from Google Calendar synchronization; no Google Calendar write was performed by PR #104 or #107.
- No files or user data were deleted, no DISKPATH change was made, and no production deployment occurred in the #107/#108 delivery.
- Keep SKIPPED, missing, and unexecuted checks distinct from PASS in future updates.
