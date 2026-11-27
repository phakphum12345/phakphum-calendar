# Changelog

All notable changes to Shift Tools are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Released versions follow semantic versioning where practical.

## [Unreleased]

### Pending in open Draft PRs — not released

The following changes are under review and are not part of a released build:

- PR #191: VAPID Web Push sender, subscription lifecycle, durable outbox worker, retry/dead-letter handling and scheduler command. Real-device delivery remains unaccepted.
- PR #192: per-section roster orientation, flexible XLSX/CSV/TSV/TXT import, source/merged-cell/color provenance, date correction and revision-bound persistence/recovery. Original workbook acceptance remains pending.
- PR #196: ETag-aware Calendar Sync coordination, durable operation ledger and retry/recovery. Controlled Google test-calendar acceptance remains pending.
- PR #201 and #203: rule conflict/precedence resolution and monthly Shift Pay statement calculation core. Statement persistence/UI and confirmed-assignment integration remain open.
- PR #202: immutable schedule-generation preview, approval and conditional commit foundation. End-to-end UI and base reconciliation remain open.
- PR #204: read-only Drive revision restore through Grid review, source-revision provenance and conditional Schedule commit. Per-assignment diff and real revision acceptance remain open.

Do not interpret this section as a release note or claim that these features are available on `main`.


### Added

- Shift Tools user-facing branding.
- Excel `.xlsx` import with worksheet selection, preview, column mapping,
  conversion issues, and import summaries.
- Canonical scheduling entities and repository/service contracts.
- Material 3 month, week, and day schedule views.
- Manual and deterministic automatic schedule-assignment foundations.
- Employee availability, coverage, department capacity, and conflict detection.
- Reusable scheduling rule engine and validation-result UI.
- Typed result/failure hierarchy and standardized controller state.
- Explicit dependency composition without a global service locator.
- `.codex` project context and root project-governance documentation.
- Date-first two-phase roster generation: resolve each section's dates and shift rows before reading worker names; reject cross-section month fallback.
- Isolate production ShiftParser date context at each section boundary so undated blocks cannot inherit the preceding block's month.

### Changed

- Schedule feature imports resolve to canonical domain entities through
  compatibility exports.
- ChangeNotifier controllers expose loading, error, success, and message state.

### Fixed

- Thai roster-period parsing supports numeric characters, flexible spacing, and
  abbreviated Buddhist-year ranges.

## [3.0.0+9] - 2026-07-22

### Added

- Multi-tenant SaaS foundation and tenant-isolation guard.
- Public API contracts, cursor pagination, and idempotency service.
- Plugin SDK and registry foundation.
- Platform-administration metrics foundation.
- Version 3 architecture documentation and tests.

## [2.0.0] - 2026-07-22

### Added

- Multi-hospital and department domain models.
- Role-based access control for Staff, Incharge, Manager, and Admin.
- Shift-exchange lifecycle and approval service.
- Organization-scoped audit event contract.
- Rule Engine 2.0 overlap, minimum-rest, and weekly-hours rules.
- Version 2 architecture documentation and tests.

## [0.7.0] - 2026-07-22

### Added

- User shift-change to Calendar-candidate mapping.
- Blocking behavior for unknown shift times.
- Workflow preview builder, controller, and dashboard.
- Received, given-away, blocked, and preview regression tests.
- ADR-0013 and workflow documentation.

## [0.6.0] - 2026-07-22

### Added

- Hospital roster and Thai Buddhist roster-period parsers.
- Flexible date-header detection and stable assignment-position keys.
- Original/current roster comparison and user shift-change classification.
- Parser/comparison tests and ADR-0012.

## [0.5.0] - 2026-07-22

### Added

- Durable synchronization history and failed-operation payload storage.
- Resume synchronization service and Calendar sync coordinator.
- Calendar-diff to synchronization-plan mapping.
- Deterministic SHA-256 synchronization IDs.
- Per-operation results, retries, and partial-failure history.
- History repository, controller, screen, serialization tests, ADR-0010, and
  ADR-0011.

## [0.4.0] - 2026-07-22

### Added

- Simulation models, plan builder, controller, and preview screen.
- Calendar synchronization commands and managed-event models.
- Google Calendar insert, update, delete, and listing adapter.
- Sequential synchronization executor and unit tests.
- Calendar preview/synchronization documentation and ADR-0009.

## [0.3.1] - 2026-07-22

### Added

- Configurable roster layout profile and shift-time catalog.
- Relationship resolution and Calendar diff models.
- Add, update, delete, and unchanged classification.
- Simulation summary, unit tests, and ADR-0008.

## [0.3.0] - 2026-07-22

### Added

- Typed Sheet cells, colors, merged ranges, and A1 conversion.
- Google Sheets normalization for values, formulas, formats, and merges.
- Configurable shift-color matching and parser contracts.
- Normalization tests and ADR-0007.

## [0.2.1] - 2026-07-22

### Added

- Authorized Google API client factory.
- Drive spreadsheet listing and original/current selection.
- Typed Sheets snapshot and Calendar access gateways.
- API foundation documentation and ADR-0006.

## [0.2.0] - 2026-07-22

### Added

- Google authentication domain/infrastructure scaffold.
- Official `google_sign_in` 7.x initialization.
- Drive, Sheets, and Calendar OAuth scopes.
- Authentication UI/controller and Drive Picker contract.
- Google Cloud setup documentation and ADR-0005.

## [0.1.0] - 2026-07-22

### Added

- Initial repository foundation.
- Core project documentation and ADR templates.
- Initial domain placeholders.
- GitHub Actions analysis/test workflow template.
