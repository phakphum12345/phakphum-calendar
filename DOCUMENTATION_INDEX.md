# Documentation Index

This file is the central map of project documentation. Prefer updating an existing canonical document over creating another document with overlapping scope.

## Project overview and status

- [README](README.md) — user installation, setup and usage.
- [Roadmap](ROADMAP.md) — planned product direction.
- [Implementation status](IMPLEMENTATION_STATUS.md) — current repository inventory and open gaps.
- [Requirements traceability](REQUIREMENTS_TRACEABILITY.md) — requirement-to-code/test evidence map.
- [Delivery status and merge policy](docs/DELIVERY_STATUS.md) — delivery gates and evidence policy.
- [Integration status](docs/INTEGRATION_STATUS.md) — integration progress.
- [Universal Roster Intelligence master plan](docs/UNIVERSAL_ROSTER_INTELLIGENCE_MASTER_PLAN.md) — cross-domain product, architecture, phases and acceptance.
- [Roster intelligence capability matrix](docs/ROSTER_INTELLIGENCE_CAPABILITY_MATRIX.md) — capability inventory and evidence requirements.
- [Historical project audit](docs/PROJECT_AUDIT.md) — audit snapshot dated 2026-07-24; not current status.

## Architecture and engineering

- [Implementation boundary audit (2026-11-24)](docs/IMPLEMENTATION_BOUNDARY_AUDIT_2026-11-24.md) — source-backed comparison of roster AI, rule engines, import/parser/generator, Calendar sync, history, timeline and audit ownership; static inspection only.

- [Project architecture](docs/wiki/ARCHITECTURE.md)
- [Module catalog and ownership map](docs/MODULE_CATALOG.md) — actual feature/service directory inventory, boundary risks and safe consolidation policy.
- [Coding standards](docs/wiki/CODING_STANDARDS.md)
- [Contribution guide](docs/wiki/CONTRIBUTING.md)
- [Architecture Decision Records](docs/adr/) — accepted decisions and their rationale.
- [SCE 3.0 system design](docs/SCE_3_0_SYSTEM_DESIGN.md)
- [SCE 3.0 implementation map](docs/SCE_3_0_IMPLEMENTATION_MAP.md)

## Calendar, roster import and synchronization

- [Parser foundation](docs/PARSER_FOUNDATION.md)
- [Roster parser reliability specification](docs/ROSTER_PARSER_RELIABILITY_SPEC.md) — section isolation, date evidence, malformed-header behavior and regression criteria.
- [Roster provenance and reconciliation](docs/ROSTER_PROVENANCE_AND_RECONCILIATION.md) — source snapshots, cell evidence, person identity, revision diffs and safe removals.
- [Grid import review workflow](docs/GRID_IMPORT_REVIEW_WORKFLOW.md) — section review, explicit canonical conversion, provenance journal/recovery, and remaining production integration gates.
- [Grid canonical converter](lib/features/shift_parser/application/grid_roster_canonical_converter.dart) — explicit-review-only conversion into a canonical Schedule candidate.
- [Grid canonical converter tests](test/grid_roster_canonical_converter_test.dart) — conversion, decision, collision and blocked-section test source.
- [Universal Generator specification](docs/UNIVERSAL_GENERATOR_SPEC.md) — deterministic templates, immutable preview and safe output integration.
- [Schedule generation review and commit](docs/SCHEDULE_GENERATION_REVIEW_AND_COMMIT.md) — current generation engine boundary, immutable preview, human approval, durable commit and separate Calendar authorization.
- [AI roster analyzer logic](docs/AI_ROSTER_ANALYZER_LOGIC_TH.md)
- [Hybrid roster AI](docs/HYBRID_ROSTER_AI.md)
- [Roster knowledge base architecture](docs/ROSTER_KNOWLEDGE_BASE_ARCHITECTURE_TH.md)
- [Calendar preview and sync](docs/CALENDAR_PREVIEW_AND_SYNC.md)
- [Synchronization reliability](docs/SYNC_RELIABILITY.md)
- [Durable history and resume](docs/DURABLE_HISTORY_AND_RESUME.md)
- [Google setup](docs/GOOGLE_SETUP.md)
- [Platform support](docs/PLATFORM_SUPPORT.md)

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
- [API and integration contracts](docs/API_AND_INTEGRATION_CONTRACTS.md) — dependency boundaries, auth, idempotency, errors and provider contracts.
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
- [Testing and release acceptance](docs/TESTING_AND_RELEASE_ACCEPTANCE.md) — evidence states, critical-path tests and exact-SHA release gates.
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
