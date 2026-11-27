# Master Documentation Index — Phakphum Calendar

This index defines the documentation architecture, not a fixed implementation sequence. Workstreams progress according to verified dependencies and readiness.

- Repository: phakphum12345/phakphum-calendar
- Delivery: consolidated current-main documentation PR #188 (replaces stale PRs #178 and #180)
- Rule: document presence is not implementation evidence; every status needs source/runtime evidence and exact SHA.

## 1. Documentation tree

```text
docs/
├── README.md
├── DOCUMENTATION_MASTER_INDEX.md
├── architecture/       # system context, module boundaries, runtime topology
├── product/            # product scope, user modes, journeys
├── workforce/          # shift-pay lifecycle, rule conflict, statements
├── ai-assistant/       # capability, provider/backend, privacy/tools, research
├── identity/           # public authentication and account lifecycle
├── platform/           # platform support, install, signing, release
├── data/               # ownership, persistence and migrations
├── engineering/        # CI policy and change delivery
├── quality/            # test strategy and acceptance evidence
├── operations/         # zero-cost operations and observability
├── governance/         # document control and status policy
├── project/            # live completion plan, PR graph and acceptance evidence
├── adr/                # existing architecture decision records
├── ci/                 # existing CI/runner operations
├── flexible-workforce/ # existing workforce subproject docs
└── wiki/               # existing technical wiki and v2 references
```

Legacy root-level documents are retained and catalogued below. New canonical work belongs in domain folders; no historical files are bulk-moved or deleted by this change.

## 2. Project completion and live audit
- [Project completion home](project/README.md)
  - [Live completion master plan](project/PROJECT_COMPLETION_MASTER_PLAN.md)
  - [Work package status](project/WORK_PACKAGE_STATUS.md)
  - [PR dependency map](project/PR_DEPENDENCY_MAP.md)
  - [Acceptance matrix](project/ACCEPTANCE_MATRIX.md)
  - [Known limitations and external blockers](project/KNOWN_LIMITATIONS.md)

## 3. Architecture
- [Architecture home](architecture/README.md)
  - [System context and bounded contexts](architecture/SYSTEM_CONTEXT_AND_BOUNDED_CONTEXTS.md)
  - [Module boundaries and dependency rules](architecture/MODULE_BOUNDARIES_AND_DEPENDENCY_RULES.md)
  - [Runtime and deployment topology](architecture/RUNTIME_AND_DEPLOYMENT_TOPOLOGY.md)
- Existing decisions: [ADR directory](adr/); technical reference: [wiki](wiki/README.md).

## 4. Product
- [Product home](product/README.md)
  - [Product scope and Personal/Organization/Hybrid modes](product/PRODUCT_SCOPE_AND_USER_MODES.md)
  - [User journeys and capability boundaries](product/USER_JOURNEYS_AND_CAPABILITY_BOUNDARIES.md)
- Existing UX references: [APP_WIDE_UX_REDESIGN.md](APP_WIDE_UX_REDESIGN.md), [NEW_APP_STRUCTURE_TH.md](NEW_APP_STRUCTURE_TH.md).

## 5. Workforce, roster and shift pay
- [Workforce home](workforce/README.md)
  - [Shift-pay lifecycle](workforce/SHIFT_PAY_LIFECYCLE.md)
  - [Rule conflict and precedence](workforce/RULE_CONFLICT_AND_PRECEDENCE_POLICY.md)
  - [Assignment calculation and monthly statement](workforce/ASSIGNMENT_CALCULATION_AND_MONTHLY_STATEMENT.md)
- Existing specifications: [SHIFT_PAY_RULES.md](SHIFT_PAY_RULES.md), [SHIFT_PAY_THREE_MODES_IMPLEMENTATION.md](SHIFT_PAY_THREE_MODES_IMPLEMENTATION.md), [SHIFT_PAY_THREE_MODES_AND_PUBLIC_AUTH.md](SHIFT_PAY_THREE_MODES_AND_PUBLIC_AUTH.md), [ORGANIZATION_MEMBER_MANAGEMENT.md](ORGANIZATION_MEMBER_MANAGEMENT.md).
- Roster pipeline: [PARSER_FOUNDATION.md](PARSER_FOUNDATION.md), [REAL_ROSTER_PROFILE.md](REAL_ROSTER_PROFILE.md), [ROSTER_CONFIGURATION_AND_SYNC_ROADMAP.md](ROSTER_CONFIGURATION_AND_SYNC_ROADMAP.md), [ROSTER_DATE_FIRST_GENERATION.md](ROSTER_DATE_FIRST_GENERATION.md), [ROSTER_PHASE_0_SOURCE_AUDIT.md](ROSTER_PHASE_0_SOURCE_AUDIT.md), [ROSTER_SHIFT_TRANSACTIONS_AND_TIMELINE.md](ROSTER_SHIFT_TRANSACTIONS_AND_TIMELINE.md).
- [Flexible workforce subproject](flexible-workforce/README.md): requirements, architecture, data model, roadmap, traceability and acceptance.

## 6. AI Assistant
- [AI Assistant home](ai-assistant/README.md)
  - [Capability matrix](ai-assistant/AI_ASSISTANT_CAPABILITY_MATRIX.md)
  - [Provider and backend contract](ai-assistant/AI_PROVIDER_AND_BACKEND_CONTRACT.md)
  - [Privacy and tool governance](ai-assistant/AI_PRIVACY_AND_TOOL_GOVERNANCE.md)
  - [Research and reports](ai-assistant/AI_RESEARCH_AND_REPORTS.md)
- Master plan: [AI_ASSISTANT_END_TO_END_COMPLETION.md](AI_ASSISTANT_END_TO_END_COMPLETION.md).
- Existing foundations: [AI_SUPPORT_CHAT.md](AI_SUPPORT_CHAT.md), [AI_PROVIDER_RESEARCH_FOUNDATION.md](AI_PROVIDER_RESEARCH_FOUNDATION.md), [HYBRID_ROSTER_AI.md](HYBRID_ROSTER_AI.md), [AI_ROSTER_ANALYZER_LOGIC_TH.md](AI_ROSTER_ANALYZER_LOGIC_TH.md), [SMART_ROSTER_ANALYZE_GENERATOR.md](SMART_ROSTER_ANALYZE_GENERATOR.md), [ROSTER_KNOWLEDGE_BASE_ARCHITECTURE_TH.md](ROSTER_KNOWLEDGE_BASE_ARCHITECTURE_TH.md), [SYNTHETIC_ROSTER_TEST_CORPUS.md](SYNTHETIC_ROSTER_TEST_CORPUS.md).

## 7. Identity and integrations
- [Identity home](identity/README.md)
  - [Public authentication and account lifecycle](identity/PUBLIC_AUTHENTICATION_AND_ACCOUNT_LIFECYCLE.md)
- Existing: [PUBLIC_GOOGLE_AUTH_READINESS.md](PUBLIC_GOOGLE_AUTH_READINESS.md), [GOOGLE_SETUP.md](GOOGLE_SETUP.md), [API_FOUNDATION.md](API_FOUNDATION.md), [INTEGRATION_STATUS.md](INTEGRATION_STATUS.md), [RESEARCH_OS_CALENDAR_BRIDGE.md](RESEARCH_OS_CALENDAR_BRIDGE.md).

## 8. Platform and release
- [Platform home](platform/README.md)
  - [Installation and release matrix](platform/INSTALLATION_AND_RELEASE_MATRIX.md)
- Existing: [PLATFORM_SUPPORT.md](PLATFORM_SUPPORT.md), [INSTALLATION_RELEASE_READINESS.md](INSTALLATION_RELEASE_READINESS.md), [INSTALLATION_AND_USER_GUIDE.md](INSTALLATION_AND_USER_GUIDE.md), [DELIVERY_STATUS.md](DELIVERY_STATUS.md), [WEB_PUSH_NOTIFICATIONS.md](WEB_PUSH_NOTIFICATIONS.md).

## 9. Data and persistence
- [Data home](data/README.md)
  - [Data model and migration policy](data/DATA_MODEL_AND_MIGRATION_POLICY.md)
- Existing: [DURABLE_HISTORY_AND_RESUME.md](DURABLE_HISTORY_AND_RESUME.md), [SYNC_RELIABILITY.md](SYNC_RELIABILITY.md).

## 10. Engineering and quality
- [Engineering home](engineering/README.md)
  - [CI and quality policy](engineering/CI_AND_QUALITY_POLICY.md)
  - [Change delivery protocol](engineering/CHANGE_DELIVERY_PROTOCOL.md)
- [Quality home](quality/README.md)
  - [End-to-end test strategy](quality/END_TO_END_TEST_STRATEGY.md)
- Existing: [CI_AUTO_DETECTION.md](CI_AUTO_DETECTION.md), [ci/SELF_HOSTED_WINDOWS_RUNNER.md](ci/SELF_HOSTED_WINDOWS_RUNNER.md), [END_TO_END_WORKFLOW.md](END_TO_END_WORKFLOW.md), [COMPARISON_FOUNDATION.md](COMPARISON_FOUNDATION.md), [CALENDAR_PREVIEW_AND_SYNC.md](CALENDAR_PREVIEW_AND_SYNC.md), [SHIFT_TRANSACTION_CALENDAR_SYNC_E2E.md](SHIFT_TRANSACTION_CALENDAR_SYNC_E2E.md).

## 11. Operations and governance
- [Operations home](operations/README.md)
  - [Zero-cost operations and observability](operations/ZERO_COST_OPERATIONS_AND_OBSERVABILITY.md)
- [Governance home](governance/README.md)
  - [Document control and status policy](governance/DOCUMENT_CONTROL_AND_STATUS_POLICY.md)

## 12. Delivery and audit
- [Live project completion plan](project/PROJECT_COMPLETION_MASTER_PLAN.md)
- [Live work package status](project/WORK_PACKAGE_STATUS.md)
- [Live PR dependency map](project/PR_DEPENDENCY_MAP.md)
- [Live acceptance matrix](project/ACCEPTANCE_MATRIX.md)
- [Live known limitations](project/KNOWN_LIMITATIONS.md)
- [Historical end-to-end completion plan (2026-11-25)](END_TO_END_COMPLETION_PLAN_2026-11-25.md)
- [Historical PR delivery tracker (2026-11-25)](PR_DELIVERY_TRACKER_2026-11-25.md)
- [Historical remaining work index (2026-11-24)](REMAINING_WORK_INDEX.md)
- [END_TO_END_ACCEPTANCE_MATRIX.md](END_TO_END_ACCEPTANCE_MATRIX.md)
- [PR_DELIVERY_TRACKER_2026-11-25.md](PR_DELIVERY_TRACKER_2026-11-25.md) (historical snapshot)
- [PR_DELIVERY_TRACKER_2026-11-24.md](PR_DELIVERY_TRACKER_2026-11-24.md) (historical)
- Audit history: [REPOSITORY_AUDIT.md](REPOSITORY_AUDIT.md), [PROJECT_AUDIT.md](PROJECT_AUDIT.md), [END_TO_END_REPOSITORY_AUDIT.md](END_TO_END_REPOSITORY_AUDIT.md), [END_TO_END_COMPLETION_AUDIT_2026-11-23.md](END_TO_END_COMPLETION_AUDIT_2026-11-23.md).

## 13. Complete root-level Markdown inventory
- [AI_ASSISTANT_END_TO_END_COMPLETION.md](AI_ASSISTANT_END_TO_END_COMPLETION.md)
- [AI_PROVIDER_RESEARCH_FOUNDATION.md](AI_PROVIDER_RESEARCH_FOUNDATION.md)
- [AI_ROSTER_ANALYZER_LOGIC_TH.md](AI_ROSTER_ANALYZER_LOGIC_TH.md)
- [AI_SUPPORT_CHAT.md](AI_SUPPORT_CHAT.md)
- [API_FOUNDATION.md](API_FOUNDATION.md)
- [APP_WIDE_UX_REDESIGN.md](APP_WIDE_UX_REDESIGN.md)
- [CALENDAR_PREVIEW_AND_SYNC.md](CALENDAR_PREVIEW_AND_SYNC.md)
- [CI_AUTO_DETECTION.md](CI_AUTO_DETECTION.md)
- [COMPARISON_FOUNDATION.md](COMPARISON_FOUNDATION.md)
- [DELIVERY_STATUS.md](DELIVERY_STATUS.md)
- [DOCUMENTATION_MASTER_INDEX.md](DOCUMENTATION_MASTER_INDEX.md)
- [DURABLE_HISTORY_AND_RESUME.md](DURABLE_HISTORY_AND_RESUME.md)
- [END_TO_END_ACCEPTANCE_MATRIX.md](END_TO_END_ACCEPTANCE_MATRIX.md)
- [END_TO_END_COMPLETION_AUDIT_2026-11-23.md](END_TO_END_COMPLETION_AUDIT_2026-11-23.md)
- [END_TO_END_COMPLETION_PLAN_2026-11-24.md](END_TO_END_COMPLETION_PLAN_2026-11-24.md)
- [END_TO_END_REPOSITORY_AUDIT.md](END_TO_END_REPOSITORY_AUDIT.md)
- [END_TO_END_WORKFLOW.md](END_TO_END_WORKFLOW.md)
- [GOOGLE_SETUP.md](GOOGLE_SETUP.md)
- [HYBRID_ROSTER_AI.md](HYBRID_ROSTER_AI.md)
- [INSTALLATION_AND_USER_GUIDE.md](INSTALLATION_AND_USER_GUIDE.md)
- [INSTALLATION_RELEASE_READINESS.md](INSTALLATION_RELEASE_READINESS.md)
- [INTEGRATION_STATUS.md](INTEGRATION_STATUS.md)
- [NEW_APP_STRUCTURE_TH.md](NEW_APP_STRUCTURE_TH.md)
- [ORGANIZATION_MEMBER_MANAGEMENT.md](ORGANIZATION_MEMBER_MANAGEMENT.md)
- [PARSER_FOUNDATION.md](PARSER_FOUNDATION.md)
- [PLATFORM_SUPPORT.md](PLATFORM_SUPPORT.md)
- [PROJECT_AUDIT.md](PROJECT_AUDIT.md)
- [PR_DELIVERY_TRACKER_2026-11-24.md](PR_DELIVERY_TRACKER_2026-11-24.md)
- [PUBLIC_GOOGLE_AUTH_READINESS.md](PUBLIC_GOOGLE_AUTH_READINESS.md)
- [README.md](README.md)
- [REAL_ROSTER_PROFILE.md](REAL_ROSTER_PROFILE.md)
- [REMAINING_WORK_INDEX.md](REMAINING_WORK_INDEX.md)
- [REPOSITORY_AUDIT.md](REPOSITORY_AUDIT.md)
- [RESEARCH_OS_CALENDAR_BRIDGE.md](RESEARCH_OS_CALENDAR_BRIDGE.md)
- [ROSTER_CONFIGURATION_AND_SYNC_ROADMAP.md](ROSTER_CONFIGURATION_AND_SYNC_ROADMAP.md)
- [ROSTER_DATE_FIRST_GENERATION.md](ROSTER_DATE_FIRST_GENERATION.md)
- [ROSTER_KNOWLEDGE_BASE_ARCHITECTURE_TH.md](ROSTER_KNOWLEDGE_BASE_ARCHITECTURE_TH.md)
- [ROSTER_PHASE_0_SOURCE_AUDIT.md](ROSTER_PHASE_0_SOURCE_AUDIT.md)
- [ROSTER_SHIFT_TRANSACTIONS_AND_TIMELINE.md](ROSTER_SHIFT_TRANSACTIONS_AND_TIMELINE.md)
- [SCE_3_0_DELIVERY_ROADMAP.md](SCE_3_0_DELIVERY_ROADMAP.md)
- [SCE_3_0_IMPLEMENTATION_MAP.md](SCE_3_0_IMPLEMENTATION_MAP.md)
- [SCE_3_0_SYSTEM_DESIGN.md](SCE_3_0_SYSTEM_DESIGN.md)
- [SHIFT_PAY_RULES.md](SHIFT_PAY_RULES.md)
- [SHIFT_PAY_THREE_MODES_AND_PUBLIC_AUTH.md](SHIFT_PAY_THREE_MODES_AND_PUBLIC_AUTH.md)
- [SHIFT_PAY_THREE_MODES_IMPLEMENTATION.md](SHIFT_PAY_THREE_MODES_IMPLEMENTATION.md)
- [SHIFT_TRANSACTION_CALENDAR_SYNC_E2E.md](SHIFT_TRANSACTION_CALENDAR_SYNC_E2E.md)
- [SMART_ROSTER_ANALYZE_GENERATOR.md](SMART_ROSTER_ANALYZE_GENERATOR.md)
- [SYNC_RELIABILITY.md](SYNC_RELIABILITY.md)
- [SYNTHETIC_ROSTER_TEST_CORPUS.md](SYNTHETIC_ROSTER_TEST_CORPUS.md)
- [WEB_PUSH_NOTIFICATIONS.md](WEB_PUSH_NOTIFICATIONS.md)
- [universal-generator-calendar-adapter.md](universal-generator-calendar-adapter.md)

## 13. Maintenance rules
- New documents belong in their domain folder; update its README and this index.
- A feature change updates requirements, architecture/data contracts, implementation/dependency map, acceptance tests and traceability.
- Avoid duplicate specifications; link to canonical documents.
- Retain historical documents until a dedicated migration review.
- Reconcile the recursive docs tree before claiming the inventory is current.
- Skipped, missing, cancelled, queued or unknown checks are never PASS.
