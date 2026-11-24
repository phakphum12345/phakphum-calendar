# Grid Import Review Workflow

**Status:** Design specification; not implemented as a production workflow.  
**Prepared:** 2026-11-24  
**Related:** [Master plan](UNIVERSAL_ROSTER_INTELLIGENCE_MASTER_PLAN.md), [Parser reliability](ROSTER_PARSER_RELIABILITY_SPEC.md), [Provenance and reconciliation](ROSTER_PROVENANCE_AND_RECONCILIATION.md), [Universal Generator](UNIVERSAL_GENERATOR_SPEC.md), [Implementation boundary audit](IMPLEMENTATION_BOUNDARY_AUDIT_2026-11-24.md)

## 1. Purpose and boundary

Define an additive, human-reviewed application workflow that turns a section-aware monthly roster grid into canonical schedule assignments without bypassing the existing parser, identity review, schedule validation, persistence, or Calendar authorization boundaries.

This workflow is a design target. The existence of parser, adapter, diagnostics, repositories, and tests does not mean this workflow is currently reachable from a production UI.

Non-goals:
- replacing or changing the existing tabular Excel import route;
- automatically syncing imported assignments to Google Calendar;
- silently correcting dates, employee identities, shift labels, or malformed sections;
- deleting existing assignments when a source section is missing, partial, or blocked;
- changing the canonical Schedule schema or legacy Shift conversion semantics in the first implementation.

## 2. Existing source components

| Existing component | Verified responsibility | Boundary |
|---|---|---|
| `MonthlyRosterSectionParser` | Discovers section date headers, independent periods, rows, assignments and date anomalies | Parser output only |
| `MonthlyRosterParseReport` | Holds sections, assignments, warnings, sheet summaries and blocking date anomalies | In-memory parse evidence |
| `MonthlyRosterAssignment` | Carries worker label, row label, date, A1 cell, color, spreadsheet ID, sheet ID and sheet title | Source evidence is not canonical identity |
| `MonthlyRosterShiftAdapter` | Converts supported assignments to legacy `Shift` objects | Retains legacy matching and shift-rule behavior |
| `MonthlyRosterConversionDiagnostics` | Reports converted shifts, unconverted assignments and blocking date anomalies | Diagnostic only; no persistence |
| `ScheduleRepository` | Persists canonical Schedule | Does not atomically persist a separate provenance envelope today |

The adapter currently accepts compacted substring matches for worker names. Existing tests intentionally rely on name fragments. Do not replace this behavior with exact-only matching as a side effect of introducing the review workflow. Instead, treat adapter output as candidate generation and require a separate, unique canonical employee resolution before commit.

## 3. Target workflow

```text
Workbook / source reader
  -> MonthlyRosterWorkbookScanner
  -> MonthlyRosterParseReport
  -> section-level safety classification
  -> conversion diagnostics
  -> employee identity candidate review
  -> shift-template / shift-rule review
  -> canonical assignment preview
  -> schedule validation + stale-revision check
  -> explicit human confirmation
  -> durable schedule + provenance commit
  -> post-commit read-back verification
  -> separately authorized Calendar preview/sync
```

Each stage must expose its input, output, warnings, and whether it can mutate durable state. Parsing, diagnostics, matching, and preview are read-only.

## 4. Section-level safety classification

Every section receives one of these states:

- **READY** — date range is resolved, no blocking date anomalies exist, and assignments can proceed to identity/shift review.
- **BLOCKED_DATE** — explicit period is missing, invalid, ambiguous, duplicated, out of order, or has another blocking date-grid anomaly.
- **EMPTY** — valid section structure but no populated assignments.
- **UNSUPPORTED** — source structure cannot be interpreted by the configured parser/profile.
- **NEEDS_REVIEW** — structurally readable but has warnings or unresolved interpretation requiring a person.

A blocked section must not produce commit-ready assignments. It must not be silently dropped from the review screen, because the operator needs to see why it was excluded. A blocked section must never generate mass REMOVE proposals during reconciliation.

Warnings and anomalies must retain section title, source sheet, row/column or A1 evidence where available, and parser diagnostic code. Do not reduce all issues to a single import-level boolean.

## 5. Identity resolution

The source worker name is a label, not a primary key. Resolution order:

1. explicit organization-scoped employee ID from trusted source metadata;
2. user-maintained alias mapping scoped to the selected organization/profile;
3. exact normalized match only when unique in the active employee directory;
4. otherwise unresolved and blocked from commit until a reviewer selects a canonical employee.

Substring matching may help discover candidates but must never itself authorize persistence. Show source spelling and canonical employee identity side by side. Preserve unresolved assignments in the review report; do not discard them.

A reviewer decision must record the selected employee ID, source label, decision type, actor, timestamp, and scope. Reusable alias creation is a separate explicit action and must not be inferred from a one-time selection.

## 6. Shift and template resolution

For each row label, show:
- original section and row label;
- resolved shift template ID and display name, if any;
- whether resolution came from an explicit template, configured alias, or built-in legacy rule;
- start/end time and relevant shift attributes;
- ambiguity or unsupported-label diagnostic.

If multiple templates match, do not choose arbitrarily. If no configured template matches and a built-in rule is used, label it as a built-in rule so the reviewer can distinguish it from a user-configured template. Unsupported rows remain visible and cannot silently vanish from the conversion count.

The first implementation should wrap existing conversion behavior rather than rewrite shift-time rules. Any later rule changes require dedicated regression tests and an explicit compatibility review.

## 7. Preview and reconciliation

Preview must be immutable and include:
- source fingerprint/revision and parser/profile version;
- accepted target schedule ID and revision/fingerprint;
- per-section state and diagnostics;
- source assignment → canonical employee → shift template → proposed assignment links;
- proposed ADD, UPDATE, UNCHANGED, CONFLICT and UNRESOLVED classifications;
- excluded and blocked rows with reasons;
- exact included operations selected by the reviewer.

REMOVE is not part of the default first-release workflow. It may be proposed only after source completeness is proven for the same scope and period, and only through a separate explicit removal review. Absence from a blocked or partial section is never evidence of deletion.

Before commit, compare the current target schedule revision with the revision used to build the preview. If it changed, mark the preview stale and require a fresh preview; do not silently rebase reviewer decisions.

## 8. Persistence and recovery contract

The existing canonical Schedule repository does not atomically save an independent provenance record. Do not claim that two separate SharedPreferences writes form one transaction.

Preferred implementation order:
1. define a versioned, source-neutral provenance envelope and repository contract;
2. define an atomic bundle repository if the storage technology supports it; otherwise define a durable PREPARED/COMMITTED journal with deterministic recovery;
3. write the canonical schedule and provenance through one application use case;
4. read both back and verify schedule fingerprint, envelope linkage, and commit state;
5. recover incomplete PREPARED operations idempotently after restart.

Envelope minimum fields:
- envelope schema version and import run ID;
- source kind, source identity/fingerprint/revision and acquisition timestamp;
- parser/profile version;
- section and cell evidence references;
- candidate-to-canonical assignment links;
- identity and shift-rule decisions;
- diagnostics and included/excluded decisions;
- accepted target schedule ID/revision/fingerprint;
- lifecycle state and commit timestamps.

Do not store raw workbook bytes, full raw cell payloads, access tokens, or private URLs by default. Do not modify canonical Schedule schema v1 merely to attach provider-specific fields.

## 9. Required application API shape

The concrete names may follow repository conventions, but responsibilities should remain separated:

- `GridRosterImportUseCase`: coordinates scan, parse, diagnostics and read-only preview creation.
- `GridRosterReviewSession`: immutable review snapshot with source/target fingerprints and candidate rows.
- `GridRosterIdentityResolver`: proposes identity candidates; cannot persist decisions.
- `GridRosterCommitUseCase`: validates review completion and target freshness, then commits the reviewed bundle.
- `RosterImportBundleRepository`: stores/retrieves schedule + provenance with atomic or recoverable semantics.
- `GridRosterReviewController`: presentation state only; no direct repository bypass.

These are proposed contracts, not claims that these classes currently exist.

## 10. Acceptance and regression tests

### Parser and section isolation
- each section retains its own date range;
- one malformed section does not block an independent valid section;
- blocked section remains visible and produces no commit-ready candidates;
- duplicate/missing/out-of-order date columns are not auto-shifted;
- the existing X-OPD malformed-header regression remains intact.

### Identity and shift mapping
- duplicate employee names remain unresolved until explicit selection;
- substring candidate matching does not authorize a commit;
- existing fragment-matching adapter tests remain unchanged and pass;
- ambiguous shift-template aliases remain unresolved;
- built-in shift mapping is identified in the review evidence;
- unsupported row labels remain visible and counted.

### Persistence and recovery
- schema-v1 canonical schedule fixtures still load unchanged;
- provenance envelope round-trips with stable IDs;
- crash after PREPARED is recoverable without duplicate assignments;
- repeated commit request is idempotent;
- review decisions survive restart;
- read-back verifies schedule and provenance linkage;
- stale target revision forces a new preview;
- blocked/partial source never produces mass REMOVE.

### End-to-end
- scan → review → explicit confirmation → persist → reload;
- excluded rows remain excluded after reload;
- source cell links/evidence remain available after reload;
- Calendar sync remains disabled until a separate authorized preview and confirmation;
- existing tabular Excel import tests and behavior remain unchanged.

A test source file is not a passing test result. Acceptance requires executing the relevant tests on the exact commit SHA and recording CI/runtime evidence separately.

## 11. Implementation sequence

1. Add pure section safety classification and tests.
2. Add immutable review-session model and source/target fingerprint contract.
3. Add identity candidate review without changing the legacy adapter.
4. Add shift/template resolution evidence and diagnostics.
5. Add versioned provenance envelope and repository/recovery design.
6. Add commit use case and persistence integration tests.
7. Add a dedicated Grid review UI route using the existing scanner/parser.
8. Add separate Calendar preview integration only after commit and authorization gates are proven.

Do not collapse these stages into one large change. Each stage must preserve existing tabular import behavior and have its own evidence.
