# Flexible Workforce & Shift Scheduler — Architecture

## 1. Architectural direction

Extend the existing Shift Tools / SCE Clean Architecture and feature boundaries. Do not introduce a parallel roster database, parser, rules engine, schedule generator, or calendar synchronization stack.

The canonical schedule remains the source of truth. Google Calendar is an external projection for explicitly selected and confirmed events.

## 2. Layers

    Presentation
      ├── Organization / Workforce screens
      ├── Schedule Designer / Schedule views
      ├── Import and Export experiences
      └── Draft / Validation / Approval screens

    Application
      ├── Organization use cases
      ├── Workforce and capability use cases
      ├── Schedule design and generation use cases
      ├── Import / Export orchestration
      └── Approval / Publication / Audit use cases

    Domain
      ├── Organization and Workforce entities
      ├── Canonical Schedule and Assignment entities
      ├── Shift / Location / Availability policies
      ├── Constraint evaluation contracts
      └── Import / Export / Approval value objects

    Infrastructure
      ├── Existing repositories and local persistence
      ├── Spreadsheet / CSV / JSON / PDF adapters
      ├── Template and file storage
      ├── Existing Google APIs and Calendar gateway
      └── Backup / audit persistence adapters

Dependency direction:

    Presentation → Application → Domain
    Infrastructure → Domain contracts

Domain logic must not depend on Flutter widgets, Google SDK payloads, or file-picker APIs.

## 3. Bounded feature modules

| Module | Responsibility | Reuse / boundary |
|---|---|---|
| Organization Manager | Workspace, organization, department hierarchy | Reuse tenant/workspace concepts if present |
| Workforce Manager | Employee and lifecycle | Reuse canonical Employee |
| Position & Skill Manager | Eligibility and qualification | Extend domain, avoid profession enums |
| Shift Template Manager | Shift definitions and staffing needs | Reuse existing ShiftType/template |
| Location Manager | Sites and work locations | Reuse existing location model if compatible |
| Schedule Designer | Rows, columns, layouts, views | Presentation metadata only |
| Scheduling Engine | Draft assignment generation | Reuse existing generator boundary |
| Constraint Validator | Hard/soft rule evaluation | Reuse Rule Engine and stable rule IDs |
| Leave & Availability | Availability and leave lifecycle | Connect to existing employee/schedule model |
| Import Engine | Read, map, validate, stage | Reuse current import adapters and preview |
| Export Engine | Render canonical schedule into target | New export profiles/templates as needed |
| Approval & Publication | Human approval and release state | Separate from generation and Calendar sync |
| Audit Manager | Change history and evidence | Reuse history/audit infrastructure |

Module names are logical boundaries, not a requirement to create one folder per name. Phase 0 must map them to the actual source tree and avoid redundant abstractions.

## 4. Canonical data flow

### Import

    File / Google Sheets / future provider
      → source adapter
      → normalized import candidate
      → column/field mapping
      → validation and duplicate detection
      → preview and user decisions
      → explicit confirmation
      → existing canonical repositories
      → audit record

The source file is not modified. Import staging is separate from active canonical records.

### Schedule generation

    Workforce + Skills + Availability + Leave
      + Shift Templates + Coverage + Locations
      + Versioned Rules + Planning Horizon
      → Scheduling Engine
      → Draft Schedule + Candidate Assignments
      → Constraint Validator
      → Validation Report
      → Human Review
      → Approval
      → Publish / Activate

Generation must not directly publish or synchronize to Google Calendar.

### Export

    Canonical Schedule Snapshot
      → Export Mode
          ├── Prebuilt Template
          ├── Generated Page
          └── Custom Design
      → Data Mapping
      → Render / Format Adapter
      → Export Preview
      → User Confirmation
      → File / Print Output
      → Export Audit Record

Export operates on a versioned schedule snapshot and must not mutate schedule assignments.

### Calendar synchronization

Continue to use the existing calendar diff, preview, confirmation, guarded execution, stable sync IDs, history, and resume flow. Only schedule records eligible under the existing sync policy may become Calendar events. Do not bypass current safety contracts.

## 5. Data and version boundaries

- Canonical schedule facts are independent of visual layout.
- Schedule revisions identify the exact inputs and rules used for generation.
- Rule sets and templates are versioned when changes can affect results.
- Export profiles and templates have their own version lifecycle.
- Import jobs retain source identity, mapping version, decisions, and result summary.
- Audit records reference entity IDs and revisions, avoiding unnecessary duplication of sensitive personal data.

## 6. Security model

- Every request is authorized against actor, workspace, organization, department, and action.
- UI hiding is not authorization.
- Reads and writes must enforce tenant scope in repository/service queries.
- Bulk import, export, approval, and publication require explicit scoped permissions.
- Audit access is restricted and itself auditable.
- Secrets and tokens must never be committed or written into logs.
- External provider access uses least privilege and existing repository OAuth contracts.

## 7. Migration and compatibility

1. Inspect actual models, repositories, generator, parser, rules, and UI.
2. Build a traceability map from these requirements to existing implementations.
3. Reuse compatible models and add adapters only where needed.
4. Preserve legacy imports and existing calendar sync IDs/history.
5. Introduce schema migrations with rollback/recovery strategy.
6. Keep old user data readable throughout migration.
7. Do not claim feature completion from documentation alone.

## 8. Observability

Each import, generation, validation, approval, export, and publication operation should have a correlation ID, actor, timestamp, input revision, configuration/rule versions, outcome, and actionable errors. Avoid logging full employee names or source contents unless explicitly justified.
