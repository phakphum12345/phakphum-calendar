# Shift Tools Roadmap

> **Roster workflow delivery track:** the focused import/review/preview/Calendar-confirmation implementation is tracked in [Roster Configuration & Intelligent Sync Roadmap](../docs/ROSTER_CONFIGURATION_AND_SYNC_ROADMAP.md), with evidence in [Roster Traceability Matrix](../docs/flexible-workforce/TRACEABILITY_MATRIX.md). PRs #97–#108 include merged slices through 2026-11-18. This sub-track does not mean the broader Shift Tools Sprints or enterprise workforce roadmap are complete.

## Sprint 0 — Foundation

Status: Completed

- Rebrand the user-facing application to Shift Tools.
- Preserve package IDs, bundle IDs, and import paths.
- Establish Material 3 styling and cross-platform regression coverage.
- Create the initial clean feature folder structure.

## Sprint 1 — Excel Import

Status: Completed

- Select and validate `.xlsx` files.
- Read workbooks and choose worksheets.
- Preview the first 50 rows with sparse and merged-cell handling.
- Map source columns to schedule fields.
- Convert rows into import records.
- Report skipped rows, warnings, errors, and success statistics.

Remaining hardening:

- Import beyond the preview-row boundary.
- Persist import profiles.
- Convert import output directly into canonical schedule entities.
- Add configurable date formats and header-row selection.

## Sprint 2 — Scheduling Foundation

Status: In Progress

- Canonical Employee, Department, ShiftType, ShiftAssignment, Schedule,
  ScheduleDay, and ScheduleMonth entities.
- Month, week, and day views.
- Filters, search, statistics, zoom, holiday/today/selection states.
- Manual and automatic assignment foundations.
- Availability, coverage, capacity, and conflict detection.
- Reusable rule engine and validation-result UI.

Remaining:

- Add controllers and documentation for schedule generation workflows.
- Connect validation and generation to the schedule workspace.
- Persist schedules, availability, coverage, capacity, and rules.
- Add user-approved drag-and-drop mutations.

## Sprint 3 — Google Sheets

Status: Next

- Adapt the existing Google Sheets integrations to domain service interfaces.
- Select spreadsheets and worksheets through reusable application use cases.
- Map Sheet data through the same import profile and validation pipeline.
- Preserve read-only defaults and ownership checks.
- Add offline, timeout, permission, and quota handling.

## Sprint 4 — Calendar Integration

Status: Planned

- Adapt existing Google Calendar behavior to `CalendarSyncService`.
- Preview adds, updates, deletions, duplicates, and conflicts.
- Require explicit approval before external writes.
- Add retry, idempotency, audit history, and partial-failure recovery.
- Provide production-ready synchronization diagnostics.

## Milestones

### Completed

- Shift Tools branding foundation.
- Cross-platform Flutter application shell.
- Excel workbook reading, preview, mapping, and import summary.
- Domain-driven entity and contract foundation.
- Schedule visualization foundation.
- Rule engine foundation.
- Schedule-generation domain and services.
- Complete regression suite remains passing.

### In Progress

- End-to-end canonical schedule workflow.
- Persistent import profiles and schedules.
- Controller and presentation integration for generation and validation.
- Consolidation of legacy and domain-driven rule implementations.

### Next

1. Add repository implementations and application use cases.
2. Connect Excel imports to canonical schedules.
3. Complete the schedule-generation feature contract: models, controller,
   service, tests, and feature documentation.
4. Integrate rules, availability, coverage, and capacity into schedule editing.
5. Begin the Google Sheets adapter sprint.
