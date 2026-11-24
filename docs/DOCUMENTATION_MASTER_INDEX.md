# Master Documentation Index — Phakphum Calendar\n\n**Entry points:** [Documentation README](README.md) · [Master documentation index](DOCUMENTATION_MASTER_INDEX.md)

- Repository: `phakphum12345/phakphum-calendar`
- Inventory ref: documentation tree at PR #180 head before this update
- Purpose: one navigable catalog of the documentation set, grouped by domain with nested work topics.
- Rule: file existence is not implementation evidence; historical documents must be reconciled against current source and exact commit SHA.

## 1. Current delivery and governance
- [End-to-end completion plan](END_TO_END_COMPLETION_PLAN_2026-11-24.md)
  - Product mission and baseline
  - Workstreams, dependencies, delivery sequence
  - Release definition and exclusions
- [Remaining work index](REMAINING_WORK_INDEX.md)
  - P0 feature, auth, AI, and release blockers
  - P1 reconciliation and release hardening
  - Existing backlog outside immediate release
- [End-to-end acceptance matrix](END_TO_END_ACCEPTANCE_MATRIX.md)
  - Shift-pay, authentication, AI, installation, CI gates
- [PR delivery tracker](PR_DELIVERY_TRACKER_2026-11-24.md)
  - PR states, exact SHA snapshots, CI/review refresh rules
- [End-to-end completion audit 2026-11-23](END_TO_END_COMPLETION_AUDIT_2026-11-23.md)
  - Historical repository audit and observed gaps
- [End-to-end repository audit](END_TO_END_REPOSITORY_AUDIT.md)
  - Repository-level findings and reconciliation
- [Repository audit](REPOSITORY_AUDIT.md)
  - Earlier audit baseline
- [Project audit](PROJECT_AUDIT.md)
  - Project structure and quality audit
- [End-to-end workflow](END_TO_END_WORKFLOW.md)
  - Read, analyze, modify, test, verify, deliver workflow

## 2. AI Assistant and intelligent roster capabilities
- [AI Assistant end-to-end completion](AI_ASSISTANT_END_TO_END_COMPLETION.md)
  - Current reality: local-only support, no live provider, no roster AI backend endpoint
  - AI Support, roster analysis, external research, reports
  - Backend trust boundary, provider configuration, zero-cost fallback
  - Privacy, permissions, tools, confirmation, audit
  - Phased implementation and 20 acceptance tests
- [AI Support Chat](AI_SUPPORT_CHAT.md)
  - Thai support screen and local deterministic guidance
  - Pasted CSV/TSV analysis
  - Current limits and integration gaps
- [AI Provider Research Foundation](AI_PROVIDER_RESEARCH_FOUNDATION.md)
  - Provider-neutral design and proposed providers
  - Support/research/roster analysis/report capability boundaries
  - Server-side credentials, tenant authorization, privacy
- [Hybrid Roster AI](HYBRID_ROSTER_AI.md)
  - Rule-first parsing and AI proposals for unresolved fields
  - Allowlist, confidence, review, and no-write policy
- [AI Roster Analyzer Logic TH](AI_ROSTER_ANALYZER_LOGIC_TH.md)
  - Input frames, analysis records, daily roster plans
  - Duty classifications, warnings, source adapters
- [Smart Roster Analyze Generator](SMART_ROSTER_ANALYZE_GENERATOR.md)
  - Legacy/monthly parser comparison
  - Candidate recovery and duplicate review
- [Roster Knowledge Base Architecture TH](ROSTER_KNOWLEDGE_BASE_ARCHITECTURE_TH.md)
  - Organization profiles and shared knowledge
  - Provenance, privacy, confidence, manual mapping
- [Synthetic Roster Test Corpus](SYNTHETIC_ROSTER_TEST_CORPUS.md)
  - Synthetic fixtures and parser/analysis validation
- [Roster Phase 0 Source Audit](ROSTER_PHASE_0_SOURCE_AUDIT.md)
  - Source-format audit and parser prerequisites

## 3. Shift pay, workforce, and organization
- [Three-mode shift-pay implementation](SHIFT_PAY_THREE_MODES_IMPLEMENTATION.md)
  - Personal, Organization, Hybrid
  - Rule identity, source precedence, persistence, authorization
  - Actual assignment integration and monthly statement
- [Three modes and public auth requirements](SHIFT_PAY_THREE_MODES_AND_PUBLIC_AUTH.md)
  - Product-level requirements and public-user boundaries
- [Shift-pay rules](SHIFT_PAY_RULES.md)
  - Day classification, rule dimensions, salary-included and compensatory treatment
  - Configurable shift types and break-relief behavior
- Flexible workforce documentation:
  - [README](flexible-workforce/README.md)
  - [Requirements](flexible-workforce/REQUIREMENTS.md)
  - [Architecture](flexible-workforce/ARCHITECTURE.md)
  - [Data model](flexible-workforce/DATA_MODEL.md)
  - [Roadmap](flexible-workforce/ROADMAP.md)
  - [Traceability matrix](flexible-workforce/TRACEABILITY_MATRIX.md)
  - [Acceptance tests](flexible-workforce/ACCEPTANCE_TESTS.md)
- [Organization member management](ORGANIZATION_MEMBER_MANAGEMENT.md)
  - Roles, membership lifecycle, audit and access controls

## 4. Roster, parser, and schedule workflow
- [Roster configuration and sync roadmap](ROSTER_CONFIGURATION_AND_SYNC_ROADMAP.md)
  - Configuration, source selection, mapping, preview, sync
- [Roster date-first generation](ROSTER_DATE_FIRST_GENERATION.md)
  - Date-first extraction and period handling
- [Real roster profile](REAL_ROSTER_PROFILE.md)
  - Real-world roster profile and configuration
- [Parser foundation](PARSER_FOUNDATION.md)
  - Structural parsing, normalization, date and shift handling
- [SCE 3.0 system design](SCE_3_0_SYSTEM_DESIGN.md)
  - System boundaries and workflow design
- [SCE 3.0 implementation map](SCE_3_0_IMPLEMENTATION_MAP.md)
  - Module map and implementation coverage
- [SCE 3.0 delivery roadmap](SCE_3_0_DELIVERY_ROADMAP.md)
  - Delivery increments and dependencies
- [Comparison foundation](COMPARISON_FOUNDATION.md)
  - Source comparison and difference model
- [Calendar preview and sync](CALENDAR_PREVIEW_AND_SYNC.md)
  - Preview, confirmation, event creation/update
- [Roster shift transactions and timeline](ROSTER_SHIFT_TRANSACTIONS_AND_TIMELINE.md)
  - Assignment transaction history and timeline
- [Shift transaction calendar sync E2E](SHIFT_TRANSACTION_CALENDAR_SYNC_E2E.md)
  - Transaction-to-calendar integration and end-to-end validation
- [Durable history and resume](DURABLE_HISTORY_AND_RESUME.md)
  - Persistence, history, resume and recovery
- [Sync reliability](SYNC_RELIABILITY.md)
  - Retry, duplicate prevention, and failure recovery

## 5. Authentication, Google integrations, APIs
- [Public Google authentication readiness](PUBLIC_GOOGLE_AUTH_READINESS.md)
  - Public OAuth audience, client IDs, redirect URIs, verification
  - Platform support, normal-user tests, external owner actions
- [Google setup](GOOGLE_SETUP.md)
  - OAuth setup and Google project configuration
- [API foundation](API_FOUNDATION.md)
  - Authorized Google client, Drive/Sheets/Calendar API contracts
- [Integration status](INTEGRATION_STATUS.md)
  - Active app shell and integrated feature modules
- [Research OS calendar bridge](RESEARCH_OS_CALENDAR_BRIDGE.md)
  - Research OS integration boundary
- [Google Workspace setup HTML](google-workspace-setup.html)
  - Setup walkthrough page

## 6. Platform, installation, UX, and release
- [Installation and user guide](INSTALLATION_AND_USER_GUIDE.md)
  - First-run, install and user guidance
- [Installation release readiness](INSTALLATION_RELEASE_READINESS.md)
  - Signing, packaging, clean install and release criteria
- [Platform support](PLATFORM_SUPPORT.md)
  - Supported targets and limitations
- [Delivery status](DELIVERY_STATUS.md)
  - Required and optional CI/build workflows
- [Web push notifications](WEB_PUSH_NOTIFICATIONS.md)
  - Push subscription and notification workflow
- [App-wide UX redesign](APP_WIDE_UX_REDESIGN.md)
  - Navigation, responsive UX and visual consistency
- [New app structure TH](NEW_APP_STRUCTURE_TH.md)
  - Application structure proposal and module organization

## 7. API, architecture, and universal generator integration
- [Universal generator calendar adapter](universal-generator-calendar-adapter.md)
  - Adapter boundary and calendar integration
- Wiki:
  - [Wiki index](wiki/README.md)
  - [Architecture](wiki/ARCHITECTURE.md)
  - [Version 3 architecture](wiki/VERSION_3_ARCHITECTURE.md)
  - [Public API V3](wiki/PUBLIC_API_V3.md)
  - [Plugin SDK V3](wiki/PLUGIN_SDK_V3.md)
  - [Rule engine specification](wiki/RULE_ENGINE_SPEC.md)
  - [Security and privacy](wiki/SECURITY_AND_PRIVACY.md)
  - [Coding standards](wiki/CODING_STANDARDS.md)
  - [Contributing](wiki/CONTRIBUTING.md)
  - [Testing guide](wiki/TESTING_GUIDE.md)
  - [Release process](wiki/RELEASE_PROCESS.md)
  - [Version 2 wiki index](wiki/v2/README.md)

## 8. Architecture decision records
- [ADR-0001 Project structure](adr/ADR-0001-project-structure.md)
- [ADR-0002 State management](adr/ADR-0002-state-management.md)
- [ADR-0003 Local storage](adr/ADR-0003-local-storage.md)
- [ADR-0004 Calendar sync](adr/ADR-0004-calendar-sync.md)
- [ADR-0005 Google authentication](adr/ADR-0005-google-authentication.md)
- [ADR-0006 Drive file selection](adr/ADR-0006-drive-file-selection.md)
- [ADR-0007 Sheet normalization](adr/ADR-0007-sheet-normalization.md)
- [ADR-0008 Comparison before sync](adr/ADR-0008-comparison-before-sync.md)
- [ADR-0009 Managed calendar events](adr/ADR-0009-managed-calendar-events.md)
- [ADR-0010 Sync reliability](adr/ADR-0010-sync-reliability.md)
- [ADR-0011 Durable history storage](adr/ADR-0011-durable-history-storage.md)
- [ADR-0012 Text-first roster comparison](adr/ADR-0012-text-first-roster-comparison.md)
- [ADR-0012 Timeline persistence and Drive backup](adr/ADR-0012-timeline-persistence-and-drive-backup.md)
- [ADR-0013 Block on unknown shift time](adr/ADR-0013-block-on-unknown-shift-time.md)
- [ADR-0013 Shift transactions](adr/ADR-0013-shift-transactions.md)
- [ADR-0014 Multi-source multi-period review](adr/ADR-0014-multi-source-multi-period-review.md)

## 9. CI, engineering and contributor operations
- [CI auto detection](CI_AUTO_DETECTION.md)
  - Capability detection and workflow routing
- [Self-hosted Windows runner](ci/SELF_HOSTED_WINDOWS_RUNNER.md)
  - Runner setup, operation, and troubleshooting
- [Wiki contributing](wiki/CONTRIBUTING.md)
  - Contribution workflow
- [Wiki coding standards](wiki/CODING_STANDARDS.md)
  - Formatting and code quality
- [Wiki testing guide](wiki/TESTING_GUIDE.md)
  - Unit, integration, and release tests
- [Wiki release process](wiki/RELEASE_PROCESS.md)
  - Versioning and release procedure

## 10. Document maintenance rules
- Every new feature must update its domain specification, traceability, acceptance tests, and this index.
- Every status must identify scope and evidence; distinguish PASS, FAIL, BLOCKED, IN PROGRESS, and UNKNOWN.
- Historical audit snapshots must retain their date and must not be presented as current status.
- Avoid duplicate specifications; link to the canonical document instead.
- Do not delete historical documents merely to simplify navigation.
- Reconcile this inventory against the repository tree during each documentation audit.

## 11. Repository documentation inventory
This index covers the documentation tree observed for the PR #180 documentation branch, including nested `adr/`, `ci/`, `flexible-workforce/`, and `wiki/` documents. New files added by this update are linked above. Re-run a recursive tree inventory before declaring the list current on main.
