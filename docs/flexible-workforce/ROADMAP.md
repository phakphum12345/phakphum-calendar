# Flexible Workforce & Shift Scheduler — Roadmap

> **Related delivery track:** roster import, shift-template resolution, review, preview, and explicit Calendar-sync boundaries are tracked separately in [Roster Configuration & Intelligent Sync Roadmap](../ROSTER_CONFIGURATION_AND_SYNC_ROADMAP.md). Current implementation evidence is recorded in [TRACEABILITY_MATRIX.md](TRACEABILITY_MATRIX.md). Merged roster PRs through #108 do not close the broader Phase 0–9 workforce requirements below.

## Delivery policy

This roadmap is a proposed execution sequence. A phase is complete only when code, tests, documentation, and review evidence satisfy its exit criteria. Existing SCE capabilities must be audited before work is classified as new implementation.

| Phase | Scope | Main exit criteria |
|---|---|---|
| 0. Baseline & Traceability | Source audit, requirements map, architecture decisions, migration plan | Every requirement mapped to existing code / gap / decision; no unsupported PASS |
| 1. Workspace & Organization | Workspace, organization, department hierarchy, scoped permissions | Blank workspace; CRUD and isolation tests |
| 2. Workforce & Capabilities | Employee, profession, position, skills, qualification validity | Optional fields, dedupe review, scoped access tests |
| 3. Shift & Location Configuration | Shift templates, overnight/timezone, breaks, locations, staffing needs | User-defined templates; time and coverage validation |
| 4. Schedule Designer | Layouts, rows, columns, bindings, views | Distinct layouts render same canonical schedule without mutating data |
| 5. Import Governance | XLSX/XLS/CSV/JSON/PDF adapters, mapping, preview, duplicate and error reports | No persistence before explicit confirmation; no silent overwrite |
| 6. Export Engine | Prebuilt Template, Generated Page, Custom Design, mapping, preview, versioning | One schedule revision exports to supported formats and multiple layouts |
| 7. Scheduling & Constraints | Draft generator, hard/soft rules, availability, leave, coverage | Deterministic tested draft; explanations and unknown handling |
| 8. Approval & Audit | Review, approval, publication, revisions, audit | Only authorized approval can publish; exact revision is auditable |
| 9. Reporting & Production Readiness | Reports, backup/restore, performance, privacy/security, tenant isolation | End-to-end acceptance and operational recovery evidence |

## Phase 0 work breakdown

1. Inspect current domain models and repositories for Workspace, Organization, Department, Employee, ShiftType, ShiftTemplate, Schedule, Assignment, and Location.
2. Inspect current generator and rule engine; record actual behavior and test coverage.
3. Inspect import paths, staging/preview/confirmation, and persistence boundaries.
4. Inspect export and print implementations, if any, and identify the three required export modes.
5. Inspect approval, roles, audit, history, backup, and tenant isolation.
6. Create Requirements Traceability Matrix with evidence links to source/tests.
7. Record architecture decisions and schema migration strategy.
8. Split implementation gaps into small PRs with independent acceptance criteria.

## Dependencies

- Organization scoping precedes organization-aware workforce and schedule persistence.
- Workforce and shift/location configuration precede reliable constraint-aware generation.
- Canonical schedule and layout separation precede reusable export modes.
- Import staging and confirmation must exist before bulk import is enabled.
- Constraint validation precedes approval and publication.
- Audit and authorization are cross-cutting requirements, not final-phase add-ons.

## Change and release gates

- Work on a feature branch and submit a PR; do not commit directly to main.
- Preserve existing user data, Google Calendar sync IDs, and history.
- Do not delete existing files or replace broad existing architecture documents without a reviewed migration plan.
- Run formatting, static analysis, focused tests, full relevant tests, and CI.
- Report PASS / FAIL / SKIPPED / UNKNOWN separately.
- Do not merge or deploy without explicit user authorization.
- Do not add paid infrastructure or external AI dependencies without approval.
