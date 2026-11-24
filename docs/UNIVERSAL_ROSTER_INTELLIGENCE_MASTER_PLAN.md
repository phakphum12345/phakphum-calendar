# Universal Roster Intelligence Platform — Master Plan

**Document status:** Planning baseline; not an implementation or release certification.  
**Prepared:** 2026-11-24  
**Repository baseline:** `main@c847d70b98c2693a11c1063e989c55f2ab825d04`  
**Owner:** Project maintainers

## 1. Product direction

Evolve the existing Phakphum Calendar / Shift Tools repository into a configurable roster-intelligence and calendar platform. It must ingest heterogeneous roster sources, identify independent roster sections, interpret dates, shifts and people, normalize records, expose uncertainty, reconcile revisions, generate useful outputs and synchronize only explicitly approved changes.

This is a capability-expansion plan. It does not claim that every target capability exists today. The source tree, migrations, tests, exact-head CI and observed runtime behavior remain authoritative.

## 2. Outcomes

1. Read multiple roster sections from one workbook without applying one section's period or layout to another.
2. Support user-defined organizations, departments, work areas, shift vocabularies and reusable profiles without hardcoded hospital-specific enums.
3. Preserve source coordinates and evidence from ingestion through preview, persistence, calendar events and audit history.
4. Detect ambiguity and conflict rather than silently guessing, shifting columns or inventing missing values.
5. Reconcile new roster revisions against prior records without duplicate assignments or destructive replacement.
6. Generate calendar and document outputs from validated canonical records and configurable templates.
7. Keep existing features operational while expanding coverage, with regression evidence for every behavior affected.
8. Keep routine development cost-conscious: prefer local deterministic processing and existing dependencies; introduce paid/external services only after a documented need and explicit approval.

## 3. Non-goals and safety boundaries

- Do not train or call a hosted AI model as a prerequisite for ordinary roster parsing.
- Do not send private roster names, assignments or source files to public services by default.
- Do not write to source spreadsheets.
- Do not mutate the active roster, persistent records or Google Calendar before preview and explicit confirmation.
- Do not silently correct malformed dates or infer a person's identity from weak text similarity.
- Do not treat roadmap text, a source file, a successful compile or a skipped workflow as proof of working behavior.
- Do not delete existing code, files, data, history or configuration solely because a task is unfinished or appears redundant. Prove replacement coverage and dependencies first.
- Do not push to main, merge, deploy, broaden OAuth scopes or change repository security settings without the required explicit authorization.

## 4. Target architecture

```text
Source Providers
  -> Readers / Extraction
  -> Workbook & Document Structure Model
  -> Section Detection
  -> Date / Person / Shift Interpretation
  -> Canonical Roster Model
  -> Validation & Evidence
  -> Reconciliation / Change Set
  -> Human Review & Approval
  -> Persistence / Timeline
  -> Generator / Export / Calendar Sync
  -> Audit & Observability
```

### 4.1 Architectural boundaries

| Boundary | Responsibility | Must not own |
|---|---|---|
| Source provider | Select, identify and acquire source content | Roster business rules |
| Reader | Extract raw values, formulas, formatting and coordinates | Person/shift decisions |
| Structure detector | Identify tables, sections, headers, ranges and merged regions | Persisting assignments |
| Interpreter | Resolve dates, people, shift codes and relationships | UI state or external writes |
| Domain model | Represent normalized roster facts and relationships | File-format parsing |
| Validator | Produce deterministic findings and severity | Silent data repair |
| Reconciler | Compare source revisions and produce proposed changes | Direct Calendar writes |
| Review workflow | Present evidence and collect human decisions | Bypassing validation |
| Generator | Render approved data into output formats | Re-interpreting raw source |
| Calendar adapter | Translate approved change sets to provider operations | Defining roster semantics |
| Audit/history | Record provenance, decisions and outcomes | Rewriting historical evidence |

Implementation should extend the current feature modules and services. Do not create parallel parsers, repositories, sync coordinators or timeline stores without an architecture decision explaining why the existing boundary cannot be extended.

### 4.2 Source capability policy

The repository documents local Excel/CSV/TSV/TXT import and Google Sheets/Calendar integrations. Treat each as a separate capability whose actual reader and live behavior must be verified. PDF, image/OCR, email, external scheduling systems and additional providers are future adapter candidates, not currently promised capabilities.

## 5. Core domain concepts

The design must preserve the raw source and distinguish evidence from interpretation.

- **RosterSource:** stable identity and provider metadata for the source.
- **RosterDocument:** one acquired file or provider snapshot, including content/version fingerprint where available.
- **RosterSection:** independently detected roster table or region, with its own title, layout, period and confidence.
- **CellEvidence:** sheet, row, column, A1 coordinate where available, raw/formatted value, formula, style, merged-range anchor and source fingerprint.
- **RosterPeriod:** inclusive local calendar start/end dates, calendar system, parsed year convention and source evidence.
- **PersonReference:** source spelling plus a stable resolved person identity only when supported by explicit mapping or adequate evidence.
- **ShiftDefinition:** configurable code, label, start/end time, location, color and business meaning.
- **ShiftAssignment:** person, period/date, shift, location, section, source evidence and resolution state.
- **AvailabilityRecord:** off, leave, unavailable, missing or other non-duty state; do not conflate absence with an empty cell.
- **RosterRelationship:** owner, actual worker, replacement, received/given-away, exchange or other configured relation.
- **ValidationFinding:** code, severity, affected section/cells/records, expected and observed values, evidence and remediation options.
- **ImportRun:** source snapshot, selected profile, parser version, findings, decisions and final outcome.
- **RosterChangeSet:** proposed additions, updates, removals and unresolved conflicts between revisions.
- **CalendarSyncIntent:** approved operations with stable identifiers and idempotency evidence.

These are conceptual contracts. Map them to existing Dart and backend models before adding new persisted entities or migrations.

## 6. Intelligence capability domains

### 6.1 Input and structure
- Provider abstraction and capability discovery.
- Workbook, worksheet, row, column, merged-cell and hidden-region awareness.
- Multi-table and multi-section detection in a single worksheet.
- Header, title, period, employee axis and shift axis detection.
- Raw cell coordinate preservation and reproducible source snapshots.
- Explicit distinction between blank, merged continuation, formula-empty and missing values.

### 6.2 Date and time
- Thai month names and abbreviations; Thai Buddhist Era and Gregorian years.
- Numeric Excel dates, formatted text, formulas and configured locale.
- Inclusive ranges, cross-month/year ranges, leap days and timezone boundaries.
- Section-local period resolution.
- Multiple candidate periods and ambiguity reporting.
- Weekday/date cross-checks as corroborating evidence, never silent repair.
- Preserve calendar dates as local date values; do not introduce timezone drift through duration arithmetic.

### 6.3 People and shifts
- Exact and user-confirmed aliases, name normalization and organization-scoped identities.
- Configurable shift vocabularies and profile-specific semantics.
- Overnight shifts, end-before-start interpretation, breaks and cross-midnight duration.
- Duty, leave, off, vacancy, replacement and exchange states as distinct concepts.
- Color/style as evidence only when a profile explicitly defines its meaning.
- Confidence and evidence for every non-trivial inference.

### 6.4 Canonicalization and reconciliation
- Stable source keys and canonical record identifiers.
- Duplicate detection with explainable match reasons.
- Revision-to-revision change sets.
- Preserve unchanged records and unrelated Calendar events.
- Conflicts for overlapping assignments, changed identities, missing slots and ambiguous deletions.
- Explicit merge policy and human resolution for conflicting sources.

### 6.5 Review, generation and synchronization
- Section-level and record-level review.
- Partial import for valid sections while blocking invalid sections.
- Preview that exactly matches the proposed persisted or Calendar operations.
- Reusable versioned profiles and templates.
- Output generation from approved canonical records.
- Idempotent Calendar operations, bounded retries, ambiguous-outcome reconciliation and resumable sync.
- Durable audit trail and safe recovery.

## 7. Delivery phases and gates

| Phase | Scope | Exit gate |
|---|---|---|
| 0. Repository baseline | Exact main SHA, PR/CI, source inventory, docs, local/untracked-work constraints | Evidence-backed capability matrix; no unapproved writes |
| 1. Parser reliability | Section-local parsing, dates, columns, validation and regression corpus | Supplied multi-section cases have deterministic expected outcomes |
| 2. Universal structure | Reader contracts, section detection, layout profiles and source evidence | Multiple unrelated layouts parse without hardcoded source names |
| 3. Canonical roster model | People, shifts, assignments, availability and relationships | Round-trip and mapping tests; migration safety if persistence changes |
| 4. Reconciliation | Fingerprints, duplicates, revisions, change sets and conflicts | No duplicate or destructive replacement in regression/E2E cases |
| 5. Review and recovery | Evidence UI, approvals, partial import, undo/restore design | Invalid/ambiguous data cannot bypass review; recovery tested |
| 6. Generator and templates | Profile lifecycle, template mapping, preview, export | Generated output matches approved canonical records |
| 7. Calendar integration | Approved sync intent, idempotency, resume, ambiguous-outcome reconciliation | Test-account E2E proves preview-to-provider consistency |
| 8. Platform and UX | Responsive workflows, accessibility, errors and offline/local behavior | Target-width and platform acceptance matrix passes |
| 9. Security and scale | Privacy, tenant isolation, large-file performance, reliability | Threat, load, memory and recovery evidence reviewed |
| 10. System acceptance | Full end-to-end acceptance and release evidence | All required gates pass on exact commit; no unknown required gate |

Phases may be split into small PRs and sequenced by dependency. A later phase must not be marked complete merely because its design document exists.

## 8. Quality attributes and measurable acceptance

- **Correctness:** expected dates, assignments and change sets match a reviewed source corpus.
- **Traceability:** every imported assignment links to source evidence and import run.
- **Safety:** malformed or ambiguous data is blocked or routed to review.
- **Compatibility:** existing supported inputs and user workflows remain covered by regression tests.
- **Determinism:** the same source, profile and parser version produce the same normalized result.
- **Idempotency:** replaying an import or sync intent does not create duplicate records/events.
- **Recoverability:** interrupted operations can resume or be safely reconciled.
- **Performance:** establish measured baselines for workbook size, section count, assignment count, memory and import duration before setting numeric SLOs.
- **Privacy:** minimize personal data in logs, telemetry, fixtures and external requests.
- **Extensibility:** new providers and profiles use contracts rather than special-case branching throughout the application.

## 9. Required test strategy

1. Unit tests for readers, section detection, date parsing, shift interpretation, normalization and reconciliation.
2. Golden fixtures with synthetic and consented/redacted real-world layouts.
3. Property/fuzz tests for malformed dates, merged ranges, empty cells, duplicate headers and large inputs.
4. Regression tests for every previously supported parser and import path.
5. Widget tests for review, mapping, validation, preview and confirmation.
6. Integration tests across Reader → Parser → Canonical Model → Persistence → Calendar adapter.
7. Failure-injection tests for cancellation, process restart, timeouts and ambiguous provider outcomes.
8. Performance tests with documented dataset sizes and machine/runtime context.
9. Security tests for tenant isolation, authorization, logging redaction and secret handling.
10. Exact-head CI and authorized test-account E2E evidence before release claims.

## 10. Documentation and change control

- Keep this document as the cross-domain roadmap.
- Use the parser reliability specification for detailed date/section behavior.
- Use the capability matrix and root traceability matrix to connect requirements to source/tests/evidence.
- Update existing canonical documents rather than adding duplicate guides.
- Record architectural changes as ADRs.
- Every implementation PR must list affected requirements, regression tests, migration/data risk, UI impact and evidence.
- Status vocabulary: **PASS, FAIL, SKIPPED, UNKNOWN, PARTIAL, PLANNED**. SKIPPED and UNKNOWN are never PASS.
- Historical audit snapshots remain immutable in meaning; add a dated refresh rather than silently rewriting old evidence.

## 11. Current known open questions

- The exact raw-cell layout for the supplied X-OPD and US sections has not been inspected from the original workbook; the user's transcription is sufficient to create parser-level regression cases, but not to prove merged-cell or hidden-column provenance.
- The suspected US heading-token ambiguity is a hypothesis until reproduced by a focused unit test against the current parser.
- The existing parser's greedy monotonic date-column resolver needs a full behavior audit before replacement.
- Existing Excel and local-file readers have overlapping responsibilities; compare contracts and call sites before consolidation.
- PDF/image/OCR providers, scheduled notification delivery and any additional cloud AI remain unverified or future scope.

## 12. Definition of done

A requirement is complete only when implementation, tests, review, documentation and observable evidence agree. No destructive cleanup, production write, OAuth scope expansion, main-branch push, merge or deployment is implied by this plan.
