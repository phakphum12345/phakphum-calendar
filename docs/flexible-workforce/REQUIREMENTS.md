# Flexible Workforce & Shift Scheduler — Requirements

## 1. Purpose and scope

Deliver configurable workforce and roster scheduling capabilities within the existing Shift Tools / Phakphum Calendar product. The target is not a fixed hospital roster. It must support different organizations, departments, professions, positions, teams, locations, and schedule layouts through user-owned configuration.

This is an additive product capability. Phase 0 must map every requirement to existing source code and tests before implementation status is assigned. Existing personal roster workflows, known shift mappings, calendar synchronization, and historical data must remain compatible.

## 2. Product principles

- **Blank by default:** a newly created workspace contains no real organization, department, employee, roster, or schedule sample records.
- **User-defined:** names, professions, positions, shifts, locations, layout, and rules are configuration, not fixed enums.
- **Modular:** features depend on domain contracts, not on one profession or organization.
- **Import-first-class:** importing includes preview, mapping, validation, duplicate detection, error reporting, and explicit confirmation.
- **Human approval:** generated schedules remain Draft until authorized approval.
- **Auditable:** record actor, time, action, target, before/after or change summary, source, outcome, and correlation ID where appropriate.
- **Extensible:** new source formats, departments, rules, and layout types should be addable without rewriting the application core.
- **Privacy by design:** minimize personal data and do not transmit roster data to external services without a documented purpose and authorization.
- **Evidence-based:** missing evidence is UNKNOWN; not tested is SKIPPED; neither is PASS.

## 3. Users and tenancy

The model must support:
- multiple organizations/workspaces;
- departments and nested organizational units;
- teams and work locations;
- users with scoped roles;
- organization and department data isolation;
- personal preferences that do not mutate organization policy.

Illustrative professions (radiology, nursing, laboratory, pharmacy, emergency, administration, and support teams) are examples only. They must not be seeded as active departments or mandatory enums.

## 4. Functional requirements

### 4.1 Organization Manager

- Create, rename, archive, and group organizations and departments.
- Support parent/child departments and responsible owners.
- Configure organization-specific defaults without changing other workspaces.
- A newly created workspace remains empty until the user creates or imports data.

### 4.2 Workforce Manager

- Manage employee/staff identifier, display name, organization, department, profession, position, skills, status, employment type, availability, and optional contact or operational metadata.
- Allow optional fields to remain empty.
- Support active, inactive, archived, and other configurable lifecycle states.
- Avoid duplicate identities within the applicable tenant scope; provide a review workflow for possible duplicates.
- Do not generate fictitious employee identities to fill staffing gaps.

### 4.3 Position, profession, and skill management

- Professions, positions, grades, teams, and skills are user-defined entities.
- Assign one or more skills/qualifications to a person with optional validity dates and evidence references.
- Scheduling eligibility must be evaluated against the configured requirements and the validity of the qualification.

### 4.4 Shift Template Manager

A shift definition may include:
- user-defined code, name, category, start/end local time, and overnight behavior;
- break intervals and paid/unpaid classification;
- work days, effective dates, and timezone;
- minimum/maximum staffing;
- required positions, professions, skills, or qualifications;
- optional location, color, icon, and display metadata.

Do not assume that labels such as morning, afternoon, night, on-call, or special shift have universal times. Unknown or incomplete time rules must be surfaced and must block unsafe operations when required.

### 4.5 Location Manager

Support configurable organization sites, buildings, departments, rooms, service points, stations, equipment locations, and external locations. Location requirements may be attached to a shift, assignment, employee capability, or staffing rule.

### 4.6 Schedule Designer

- Define rows, columns, headers, ordering, grouping, date format, cell rendering, and optional merged cells.
- Support daily, weekly, monthly, yearly, and custom-period views.
- Support different layouts for different departments or schedule profiles.
- Keep layout metadata separate from canonical schedule assignments.
- Layout changes must not mutate roster facts.

### 4.7 Scheduling Engine

Inputs may include workforce eligibility, availability, leave, shift templates, staffing requirements, locations, approved rules, and planning horizon.

The engine must:
- generate a Draft schedule;
- evaluate hard constraints before proposing assignments;
- report soft-constraint scores or explanations separately;
- detect overlaps, unavailable workers, missing qualifications, staffing shortages, invalid shift times, and configured rest/continuous-work violations;
- provide deterministic results for identical inputs, configuration versions, and engine version where deterministic mode is selected;
- explain why an assignment was proposed or rejected;
- never invent employee names or qualifications.

The first delivery may use deterministic rule-based assignment; an optimization solver is a later capability and must not be claimed until implemented and tested.

### 4.8 Constraint Validator

Hard constraints may include:
- required position/skill/qualification;
- employee availability and approved leave;
- overlapping assignments;
- minimum staffing and maximum capacity;
- valid shift interval and timezone;
- configured rest and working-hour limits;
- location and role eligibility.

Soft constraints may include:
- fair distribution of shifts and hours;
- preferred days or shift types;
- reducing consecutive heavy shifts;
- reducing unnecessary location changes;
- balancing unpopular shifts.

Every rule evaluation must produce a clear result such as PASS, FAIL, SKIPPED, or UNKNOWN, with rule ID, severity, explanation, and relevant input references. A missing input must not silently pass.

### 4.9 Leave and availability

- Record availability windows, unavailable windows, leave requests, approval status, and effective dates.
- Keep requested, pending, approved, rejected, and cancelled states distinct.
- Scheduling must use the approved policy for each state; pending leave must not be silently treated as approved or ignored.

### 4.10 Import Engine

Initial supported formats are XLSX, XLS where a supported parser is available, CSV, JSON, and PDF where the document structure permits reliable extraction. Unsupported or low-confidence PDF extraction must be reported rather than guessed.

Required flow:

    Select → Inspect → Parse → Preview → Map → Validate
    → Detect duplicates → Report → Confirm → Persist

- Preserve the source file or a controlled source reference according to retention policy.
- Show row/cell-level errors and warnings where available.
- Allow mapping corrections before persistence.
- Detect exact and probable duplicates without silently discarding ambiguous records.
- Never overwrite existing records automatically.
- Confirm create/update/skip decisions explicitly and record the import report.

### 4.11 Export Engine

Export must offer three distinct modes:

1. **Prebuilt Template:** choose a system-provided template or a user-imported template and map canonical data into defined cells/regions.
2. **Generated Page:** export the schedule as it appears in the generated/view page, preserving supported grouping, row/column structure, styles, colors, and visible labels.
3. **Custom Design:** allow users to design their own output, including headers, logo, tables, fields, colors, dimensions, spacing, and placement.

Shared requirements:
- select/import template or design profile;
- map canonical data to template fields/cells;
- preview before export;
- support XLSX, CSV where tabular, PDF, and print where the target layout supports them;
- save reusable templates/profiles;
- version templates and retain ownership/compatibility metadata;
- report unsupported formatting or data loss before export;
- export must not regenerate or mutate the underlying schedule;
- a single canonical dataset may be exported to multiple formats and layouts.

CSV cannot preserve visual styling or merged cells; explain this limitation in preview.

### 4.12 Approval, publication, and audit

- Generation creates Draft only.
- Validation blockers prevent approval unless an explicitly authorized override policy exists and is audited.
- Approval records approver, timestamp, schedule revision, validation summary, and decision.
- Publishing is a separate action from generation and approval.
- Any post-approval change creates a new revision or returns the schedule to a review-required state.
- Audit history is append-only at the application contract level.

### 4.13 Security, privacy, and operations

- Role-based access control with organization/department scope.
- Enforce authorization at application/service boundaries, not only in UI.
- Protect sensitive employee fields and avoid unnecessary logging.
- Encrypt data in transit and at rest where supported by the chosen storage.
- Define retention, export, backup, restore, and deletion policies.
- Tenant isolation tests are required.
- External AI or cloud processing of roster data is opt-in and must be disclosed; local deterministic processing is preferred when practical.

## 5. Non-functional requirements

- Testable domain rules without Flutter or provider SDK dependencies.
- Stable IDs, timestamps, explicit timezone handling, and schema versions.
- Import/export operations should be recoverable and produce inspectable reports.
- Large schedules should be processed without blocking the UI; use bounded background work where supported.
- Accessibility and Thai/English localization should be considered in user-facing workflows.
- Existing app platforms and delivery contracts remain governed by the repository's platform support documentation.

## 6. Out of scope until separately approved

- Payroll calculation or legal compliance certification.
- Automated employee performance scoring.
- Fully autonomous publication of schedules.
- External AI inference using employee data by default.
- Replacing existing Google Calendar synchronization behavior.
