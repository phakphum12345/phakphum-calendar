# Module Catalog and Ownership Map

**Inventory date:** 2026-11-24  
**Repository baseline for inventory:** `main@c847d70b98c2693a11c1063e989c55f2ab825d04`  
**Status:** Directory-level inventory from the repository tree. It is not a claim that every module is complete, active in production, or independently deployable.

## 1. Purpose

This catalog explains where to look before adding or changing a capability. It is intended to prevent duplicate modules, parallel services and accidental removal of legacy functionality.

A folder name establishes only that a directory exists. Before assigning ownership or changing code, inspect public classes, imports/call sites, dependency injection, tests and runtime wiring.

## 2. Architectural layers

| Layer | Repository area | Intended responsibility |
|---|---|---|
| Domain | `lib/domain/entities/` | Canonical business entities |
| Domain contracts | `lib/domain/repositories/` | Persistence/provider abstractions |
| Domain services | `lib/domain/services/` | Framework-independent business behavior |
| Core | `lib/core/` | Shared result types, dependency composition and cross-cutting primitives |
| Feature modules | `lib/features/` | Bounded contexts and feature workflows |
| Legacy/application services | `lib/services/` | Established services; migrate incrementally after call-site audit |
| Presentation | `lib/ui/`, feature presentation folders | Flutter screens and widgets |
| Application state | `lib/controller/`, feature controllers | User/application workflow state |
| Backend API | `backend/routes/`, `backend/app/` | Laravel transport, authorization and application services |
| Database | `backend/database/migrations/` | Authoritative persisted schema |

The intended dependency direction is Presentation → Application → Domain, with infrastructure implementing domain contracts. Legacy paths remain supported until their callers and capabilities are migrated.

## 3. Feature directory inventory

The following directories were present in the inspected repository tree.

### Identity, access and tenancy
- `access_control` — access-control feature area.
- `authentication` — sign-in and authentication workflow.
- `edition` — edition/capability boundaries.
- `organization` — organization workflows.
- `tenancy` — tenant-scoped behavior.
- `employees` — employee/personnel workflows.
- `admin` — administrative workflows.

### Roster acquisition and interpretation
- `excel_import` — local Excel import.
- `google_drive` — Google Drive source integration.
- `google_sheets` — Google Sheets source integration.
- `shift_parser` — roster/shift parsing.
- `roster_names` — roster name-related behavior.
- `ai_roster_analyzer` — roster analysis feature area.
- `roster_ai` — additional roster AI feature area; inspect ownership and overlap before extending either analyzer.

### Scheduling and business rules
- `schedule` — schedule workflows.
- `schedule_generation` — schedule generation.
- `shift_templates` — configurable shift templates.
- `shift_exchange` — exchange/transaction workflows.
- `relationship_engine` — roster relationship interpretation.
- `rule_engine` — rule evaluation.
- `rules` — additional rules feature area; verify boundaries with `rule_engine` before adding behavior.
- `simulation` — simulation and preview-related workflows.

### Calendar, synchronization and history
- `calendar_engine` — calendar domain/application logic.
- `calendar_sync` — provider synchronization workflows.
- `history` — history/revision workflows.
- `audit` — audit behavior.
- `diff_engine` — comparison/diff behavior.

### User experience, reporting and extensibility
- `dashboard` — dashboard.
- `reports` — reports.
- `ai_support` — AI support/chat area.
- `api` — API client/feature boundary.
- `plugin_system` — plugin extensibility.
- `universal_generator_adapter` — isolated preview-only Universal Generator → Calendar adapter.
- `workflow` — workflow orchestration.

## 4. Existing service-area inventory

Top-level services under `lib/services/` include:

- Calendar: `calendar_service.dart`, `calendar_color_service.dart`.
- Google and source access: `google_api_client.dart`, `google_auth_service.dart`, `sheets_service.dart`, `drive_archive_service.dart`, `drive_ownership_service.dart`.
- File import: `local_roster_file_service.dart`.
- Roster history: `roster_revision_service.dart`, `roster_timeline_generator.dart`, `timeline_archive_service.dart`.
- Shift interpretation: `shift_parser.dart`, `shift_time_service.dart`, `shift_color_service.dart`.
- User settings and notifications: `settings_service.dart`, `shift_alert_service.dart`.
- Shift transactions: `swap_request_service.dart`.
- Web push: `web_push_browser_bridge.dart`, platform-specific bridge, `web_push_subscription_client.dart`.

These services may overlap with newer feature modules. Their names alone do not prove duplication. Before consolidation, build a call-site map, compare behavior and test coverage, and preserve every externally used capability.

## 5. Backend controller inventory

The inspected Laravel API tree includes:
- `ClientErrorController`
- `GoogleAccountController`
- `HealthController`
- `OrganizationController`
- `ShiftTransactionController`
- `WebPushSubscriptionController`

Routes, middleware, request validation, authorization policies, service classes and migrations are authoritative. Do not move business logic into controllers merely to make the directory layout appear uniform.

## 6. Known boundary risks to audit

1. `ai_roster_analyzer` and `roster_ai`: establish whether these are separate bounded contexts, old/new implementations, or overlapping names. Do not delete either based on names.
2. `rule_engine` and `rules`: inspect imports, public APIs and test ownership before consolidation.
3. `calendar_engine`, `calendar_sync` and legacy `calendar_service.dart`: map orchestration and provider ownership to prevent duplicate sync paths.
4. `excel_import`, `shift_parser` and `local_roster_file_service.dart`: distinguish file reading, normalization, interpretation and legacy compatibility.
5. `history`, `audit`, `roster_revision_service.dart` and timeline services: distinguish user-visible revision history, security audit and calendar timeline.
6. `api` feature and Laravel backend: document which operations are local/domain, which are remote transport, and which are provider-specific.
7. Legacy `lib/models/`, `lib/services/`, `lib/controller/` and `lib/ui/`: do not assume a feature module has replaced the legacy route.

## 7. Required ownership record before implementation

For every cross-module change, record:

| Field | Required content |
|---|---|
| Owning feature | One authoritative module |
| Public contract | Input/output types and error semantics |
| Dependencies | Allowed modules and provider gateways |
| Composition | Where the feature is registered/injected |
| Persistence | Existing repository/table/file ownership |
| Call sites | All known production consumers |
| Tests | Unit, widget, integration and regression owners |
| Migration | Compatibility/deprecation path, if any |
| Removal gate | Proof no callers or unique capabilities remain |

## 8. Safe consolidation policy

Consolidation is allowed only when:
- all callers and entry points are inventoried;
- behavior and data contracts are compared;
- unique capabilities are migrated or intentionally retired with approval;
- migration and rollback are documented;
- regression tests cover the replacement;
- no historical user data or local work is discarded.

Incomplete work is not itself a reason for deletion. Remove verified duplicate implementations only after the replacement is proven equivalent or better and the user has approved the destructive change.

## 9. Follow-up audit sequence

1. Generate a symbol-level dependency/call-site map for the seven boundary risks above.
2. Compare public interfaces and runtime registrations.
3. Compare tests and identify behavior not covered by the apparent replacement.
4. Assign one owner per capability in the capability matrix.
5. Propose a minimal-diff consolidation plan; do not execute deletion in the audit stage.
6. Update this catalog only when source ownership changes are verified.
