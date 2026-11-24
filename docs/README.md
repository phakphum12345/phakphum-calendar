# Documentation index

Start with the [Master Documentation Index](DOCUMENTATION_MASTER_INDEX.md) for the complete repository documentation catalog, grouped by domain with nested work topics.

## Current delivery package — 2026-11-24

| Document | Purpose |
|---|---|
| [Master documentation index](DOCUMENTATION_MASTER_INDEX.md) | Full documentation catalog with nested topics and links |
| [End-to-end completion plan](END_TO_END_COMPLETION_PLAN_2026-11-24.md) | Master scope, remaining work, dependencies, sequencing, risks, and completion gates |
| [Remaining-work index](REMAINING_WORK_INDEX.md) | Concise checklist of outstanding implementation and external actions |
| [Three-mode shift-pay design](SHIFT_PAY_THREE_MODES_IMPLEMENTATION.md) | Personal, Organization, Hybrid requirements and end-to-end data flow |
| [AI Assistant end-to-end completion](AI_ASSISTANT_END_TO_END_COMPLETION.md) | Current AI gaps, live-provider architecture, secure tools, research, privacy, and production acceptance |
| [Public Google authentication readiness](PUBLIC_GOOGLE_AUTH_READINESS.md) | OAuth architecture, user eligibility, platform requirements, and Google Console actions |
| [Installation and release readiness](INSTALLATION_RELEASE_READINESS.md) | Actual installability/signing matrix and release requirements |
| [End-to-end acceptance matrix](END_TO_END_ACCEPTANCE_MATRIX.md) | Unit, integration, authorization, AI, auth, installation, and release acceptance tests |
| [PR and delivery tracker](PR_DELIVERY_TRACKER_2026-11-24.md) | Snapshot of related PRs and exact-SHA evidence known at audit time |

## Product and feature documentation

- [Shift-pay rules](SHIFT_PAY_RULES.md)
- [Organization member management](ORGANIZATION_MEMBER_MANAGEMENT.md)
- [Roster configuration and sync roadmap](ROSTER_CONFIGURATION_AND_SYNC_ROADMAP.md)
- [Calendar preview and sync](CALENDAR_PREVIEW_AND_SYNC.md)
- [Durable history and resume](DURABLE_HISTORY_AND_RESUME.md)
- [Shift transactions and timeline](ROSTER_SHIFT_TRANSACTIONS_AND_TIMELINE.md)
- [AI roster analyzer logic](AI_ROSTER_ANALYZER_LOGIC_TH.md)
- [AI Support Chat](AI_SUPPORT_CHAT.md)
- [AI provider and research foundation](AI_PROVIDER_RESEARCH_FOUNDATION.md)
- [Hybrid roster AI](HYBRID_ROSTER_AI.md)
- [Smart roster analyze generator](SMART_ROSTER_ANALYZE_GENERATOR.md)
- [Roster knowledge base architecture](ROSTER_KNOWLEDGE_BASE_ARCHITECTURE_TH.md)

## Authentication, integrations, and APIs

- [Google setup](GOOGLE_SETUP.md)
- [API foundation](API_FOUNDATION.md)
- [Integration status](INTEGRATION_STATUS.md)
- [Research OS calendar bridge](RESEARCH_OS_CALENDAR_BRIDGE.md)

## Platform, installation, and delivery

- [Platform support](PLATFORM_SUPPORT.md)
- [Installation and user guide](INSTALLATION_AND_USER_GUIDE.md)
- [Delivery status](DELIVERY_STATUS.md)
- [CI auto detection](CI_AUTO_DETECTION.md)
- [Self-hosted Windows runner](ci/SELF_HOSTED_WINDOWS_RUNNER.md)

## Architecture decisions

See [architecture decision records](adr/).

## Status semantics

- **PASS** — direct evidence supports completion for the stated scope and exact revision.
- **FAIL** — evidence shows a requirement is not met.
- **BLOCKED** — an identified dependency or external action prevents completion.
- **IN PROGRESS** — implementation or verification is underway.
- **UNKNOWN** — evidence is missing, stale, or not sufficient.

A skipped, missing, cancelled, or unknown check is never a PASS. Historical audit documents remain useful for traceability but must not override a newer exact-SHA snapshot.
