# Documentation Index

This file is the central map of project documentation. Prefer updating an existing canonical document over creating another document with overlapping scope.

## Project overview and status

- [README](README.md) — user installation, setup and usage.
- [Roadmap](ROADMAP.md) — planned product direction.
- [Implementation status](IMPLEMENTATION_STATUS.md) — current repository inventory and open gaps.
- [Requirements traceability](REQUIREMENTS_TRACEABILITY.md) — requirement-to-code/test evidence map.
- [Delivery status and merge policy](docs/DELIVERY_STATUS.md) — delivery gates and evidence policy.
- [Integration status](docs/INTEGRATION_STATUS.md) — integration progress.
- [Historical project audit](docs/PROJECT_AUDIT.md) — audit snapshot dated 2026-07-24; not current status.

## Architecture and engineering

- [Project architecture](docs/wiki/ARCHITECTURE.md)
- [Coding standards](docs/wiki/CODING_STANDARDS.md)
- [Contribution guide](docs/wiki/CONTRIBUTING.md)
- [Architecture Decision Records](docs/adr/) — accepted decisions and their rationale.
- [SCE 3.0 system design](docs/SCE_3_0_SYSTEM_DESIGN.md)
- [SCE 3.0 implementation map](docs/SCE_3_0_IMPLEMENTATION_MAP.md)

## Calendar, roster import and synchronization

- [Calendar preview and sync](docs/CALENDAR_PREVIEW_AND_SYNC.md)
- [Synchronization reliability](docs/SYNC_RELIABILITY.md)
- [Durable history and resume](docs/DURABLE_HISTORY_AND_RESUME.md)
- [Google setup](docs/GOOGLE_SETUP.md)
- [Platform support](docs/PLATFORM_SUPPORT.md)
- [End-to-end roster and sync completion plan (2026-11-26)](docs/END_TO_END_SYNC_COMPLETION_PLAN_2026-11-26.md)

These documents collectively cover the calendar engine and synchronization topics; a second `CALENDAR_ENGINE.md` or `SYNCHRONIZATION.md` is not created to avoid duplicate guidance.

## Timeline and shift management

- [Shift transaction calendar-sync E2E](docs/SHIFT_TRANSACTION_CALENDAR_SYNC_E2E.md)
- [Shift pay rules](docs/SHIFT_PAY_RULES.md)
- [Flexible workforce requirements](docs/flexible-workforce/REQUIREMENTS.md)
- [Flexible workforce traceability matrix](docs/flexible-workforce/TRACEABILITY_MATRIX.md)
- [Timeline archive implementation](lib/services/timeline_archive_service.dart)
- [Roster revision reader](lib/services/roster_revision_service.dart)
- [Roster timeline generator](lib/services/roster_timeline_generator.dart)

The timeline services and shift documents above are the current implementation references. A separate `TIMELINE_DOCUMENTATION.md` or `SHIFT_MANAGEMENT.md` should be added only if a genuinely uncovered workflow is documented.

## Backend API and database

- [Organization member management](docs/ORGANIZATION_MEMBER_MANAGEMENT.md)
- [Backend README](backend/README.md)
- [Backend security notes](SECURITY.md)
- [API documentation](backend/API_DOCUMENTATION.md)
- [Database schema](backend/DATABASE_SCHEMA.md)
- [API routes](backend/routes/api.php)
- [Database migrations](backend/database/migrations/)

The Laravel migrations are the source of truth for schema structure; update the schema document whenever a migration changes.

## Security and privacy

- [Security and privacy guide](docs/wiki/SECURITY_AND_PRIVACY.md)
- [Backend security notes](SECURITY.md)
- [Composer dependency lockfile](backend/composer.lock)
- [Authentication middleware](backend/app/Http/Middleware/AuthenticateGoogleAccount.php)

## Testing, CI and release

- [Testing guide](docs/wiki/TESTING_GUIDE.md)
- [CI auto-detection](docs/CI_AUTO_DETECTION.md)
- [Release process](docs/wiki/RELEASE_PROCESS.md)
- [GitHub Actions workflows](.github/workflows/)
- [GitHub Actions runs](https://github.com/phakphum12345/phakphum-calendar/actions)
- [Delivery status](docs/DELIVERY_STATUS.md)

## Canonical-source rule

When documentation and implementation disagree, use this order:

1. Current source code and database migrations.
2. Tests that exercise the current behavior.
3. Exact-head CI and post-merge evidence.
4. Current implementation/status documents.
5. Historical audits and older planning documents.

Do not infer that a feature works merely because it appears in a roadmap or design document.

## Universal Roster Intelligence and Grid Import

- [Universal Roster Intelligence master plan](docs/UNIVERSAL_ROSTER_INTELLIGENCE_MASTER_PLAN.md)
- [Roster intelligence capability matrix](docs/ROSTER_INTELLIGENCE_CAPABILITY_MATRIX.md)
- [Implementation boundary audit](docs/IMPLEMENTATION_BOUNDARY_AUDIT_2026-11-24.md)
- [Module catalog](docs/MODULE_CATALOG.md)
- [Parser reliability specification](docs/ROSTER_PARSER_RELIABILITY_SPEC.md)
- [Roster provenance and reconciliation](docs/ROSTER_PROVENANCE_AND_RECONCILIATION.md)
- [Grid import review workflow](docs/GRID_IMPORT_REVIEW_WORKFLOW.md)
- [Grid import recovery and concurrency](docs/GRID_IMPORT_RECOVERY_AND_CONCURRENCY.md)
- [Schedule persistence writer inventory](docs/SCHEDULE_PERSISTENCE_WRITER_INVENTORY.md)
- [Conditional Schedule persistence ADR](docs/adr/CONDITIONAL_SCHEDULE_PERSISTENCE_AND_JOURNAL_DISCOVERY.md)
- [Schedule CAS prototype](tool/schedule_cas_spike/README.md)
- [API and integration contracts](docs/API_AND_INTEGRATION_CONTRACTS.md)
- [Universal Generator specification](docs/UNIVERSAL_GENERATOR_SPEC.md)
- [Schedule generation review and commit](docs/SCHEDULE_GENERATION_REVIEW_AND_COMMIT.md)
- [Testing and release acceptance](docs/TESTING_AND_RELEASE_ACCEPTANCE.md)
