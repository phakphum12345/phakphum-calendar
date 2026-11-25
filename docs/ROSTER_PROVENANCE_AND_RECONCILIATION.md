# Roster Provenance, Identity and Revision Reconciliation

**Status:** Target domain specification; implementation coverage is tracked separately in the capability matrix.  
**Prepared:** 2026-11-24  
**Related:** [Master plan](UNIVERSAL_ROSTER_INTELLIGENCE_MASTER_PLAN.md), [Parser reliability](ROSTER_PARSER_RELIABILITY_SPEC.md), [Data Model](../DATA_MODEL.md), [Durable History and Resume](DURABLE_HISTORY_AND_RESUME.md)

## 1. Purpose

This document defines how an imported roster fact remains explainable from its original source through normalization, correction, persistence, generation and Calendar synchronization. It also defines safe comparison between source revisions.

The current `DATA_MODEL.md` is a proposed ShiftRecord sketch and must be reconciled with actual Dart entities and database migrations before adding new persisted fields or tables.

## 2. Provenance chain

```text
Source Provider + Source Identity
  -> Immutable Source Snapshot
  -> Worksheet / Section / Cell Evidence
  -> Parser Candidate + Rule Evidence
  -> Human Correction (if any)
  -> Canonical Assignment
  -> Revision / Change Set
  -> Generator Candidate
  -> Calendar Sync Intent
  -> Provider Outcome + Audit Event
```

Every transition should retain stable identifiers linking the previous and next stage. Provenance is a relationship, not a large copy of the entire source workbook in every record.

## 3. Source identity and snapshot

A source reference should distinguish:
- provider type (local file, Google Sheets, or future provider);
- provider-native ID where available;
- user/account or organization scope;
- display name (not a unique key);
- acquisition timestamp;
- content fingerprint where deterministic hashing is possible;
- provider revision/version token where available;
- file type and reader/parser version;
- permission/access mode.

A source snapshot represents the exact bytes or provider data read for an import. If the provider cannot provide immutable revisions, record that limitation and use a locally calculated fingerprint when lawful and technically feasible. Never treat a file name or sheet title alone as a stable identity.

Privacy: do not log raw workbook contents, names, tokens, private URLs or full source payloads. Hashing personal data does not automatically make it non-sensitive.

## 4. Cell and structural evidence

Where the reader exposes them, retain:
- spreadsheet/document ID and worksheet ID/name;
- 1-based row and column indexes;
- A1 coordinate;
- raw value, formatted/display value and formula separately;
- merged-range anchor and covered range;
- hidden row/column state when available;
- style/color metadata only when the reader exposes it;
- source range and section boundaries;
- extraction warnings.

A normalized cell must not collapse blank, formula-empty, merged continuation and missing/out-of-range into one indistinguishable value. If a reader cannot distinguish them, expose an explicit unknown evidence state.

## 5. Interpretation evidence

Each interpreted field should identify:
- raw observed value;
- normalized value;
- rule or mapping ID/version;
- source cell/span or provider evidence;
- resolution method (exact, configured alias, deterministic rule, user-confirmed, unresolved);
- confidence only if a calibrated and documented scoring method exists;
- findings and ambiguity candidates.

Do not display a numeric confidence score unless it has a defined meaning and calibration dataset. A source match is not proof of correctness.

## 6. Person identity

Names are labels; they are not safe primary keys.

Resolution precedence:
1. Explicit organization-scoped employee/member ID with valid authorization.
2. Explicit user-maintained alias mapping scoped to the selected profile/organization.
3. Exact normalized match when uniqueness is proven within the active scope.
4. Otherwise unresolved; request review.

Do not merge people because of substring similarity, transliteration similarity or shared first/last names. A collision must produce a review finding. Keep source spelling and canonical display name separate. Organization membership identity must not be inferred from a roster label alone.

## 7. Canonical assignment identity

An assignment key must be stable across harmless display changes but must not collapse distinct shifts. Candidate key dimensions include:
- source-independent canonical assignment ID where available;
- organization/schedule scope;
- person identity;
- local work date;
- shift definition or explicit time interval;
- work location/department;
- source lineage.

The exact canonical key must be chosen after auditing existing `sourceKey`, schedule assignment IDs, Calendar Sync IDs and database constraints. Do not introduce a second competing ID format. A change to a source coordinate must not necessarily create a new real-world assignment if the canonical identity remains the same; retain the old and new provenance.

## 8. Revision comparison

Compare a new validated snapshot with the last accepted snapshot and produce a proposed change set:

| Change kind | Meaning | Default safety |
|---|---|---|
| ADD | New assignment candidate | Review if identity or mapping uncertain |
| UPDATE | Same assignment identity, changed fields | Show field-level before/after |
| REMOVE | Previously accepted assignment absent from new source | Never auto-delete; require source completeness and policy |
| UNCHANGED | Equivalent canonical assignment | Preserve existing ID/history |
| CONFLICT | Multiple plausible matches or incompatible values | Block automatic resolution |
| UNRESOLVED | Insufficient evidence | Retain for human review |

Absence from a partial, truncated or malformed roster is not evidence of removal. A REMOVE proposal requires proof that the source region is complete for the compared period and that the new snapshot is valid. If the section is blocked, do not infer mass removals from its missing records.

## 9. Human corrections

A correction must retain:
- original value and source evidence;
- corrected value;
- actor and timestamp;
- reason or selected resolution;
- whether it applies to one record, one import run, one source profile or future imports;
- mapping/profile version affected.

A correction must not silently rewrite the original source or prior accepted snapshot. Saving a correction as a reusable rule is a separate explicit action.

## 10. Change-set transaction boundary

The reconciliation service should be pure or side-effect constrained: it returns a proposed change set. Persistence and Calendar operations are performed by existing application use cases only after review and confirmation.

Before applying:
- verify source snapshot and target revision have not changed;
- verify profile/rule versions match the preview;
- validate authorization and organization scope;
- re-check conflicts;
- apply the exact reviewed operation set;
- record per-item outcomes and audit evidence.

If the operation partially fails, preserve successful outcomes and resume only operations proven safe to retry.

## 11. Data retention and deletion

- Retention periods must be configurable and documented according to applicable policy.
- Do not retain full source files indefinitely by default.
- A source reference may be retained after source bytes are discarded, but the loss of reproducibility must be visible.
- Deleting a source reference must not silently delete canonical assignments or Calendar events.
- Deleting a person or organization must respect existing foreign keys, ownership and membership rules.
- Backups and restore must be separately tested; a revision log is not automatically a backup.

## 12. Test matrix

- Same file imported twice produces no duplicate canonical assignments.
- File renamed without content change is recognized as same content where provider identity allows.
- Same file changed produces a new snapshot and a revision diff.
- Different sources with the same assignment are candidates for reconciliation, not blindly merged.
- Partial/malformed source never creates mass REMOVE proposals.
- Changed employee display name preserves identity only with valid alias/ID evidence.
- Two people with similar names remain distinct.
- User correction is auditable and scoped.
- Profile update does not rewrite historical interpretation.
- Calendar retry reconciles ambiguous outcomes by stable ID.
- Organization scope prevents cross-tenant record matching.
- Data deletion/retention follows the documented lifecycle.

## 13. Acceptance

Production reconciliation requires stable identity mapping to existing entities, source snapshot/version handling, field-level change sets, safe REMOVE semantics, human review, transactional application, audit history and regression/E2E proof. Until those are verified, retain UNKNOWN/PARTIAL statuses in the capability matrix.


## 14. Current Flutter model and persistence compatibility constraints

The active implementation has two materially different source representations:
- Tabular import uses `ShiftRecord`, including source worksheet row number and optional reviewed `Employee` / `ShiftTemplate` references.
- Section-aware grid parsing uses `MonthlyRosterSection` / `MonthlyRosterAssignment`, including section title, row label/index, date, source cell, optional spreadsheet/sheet identity, background color, date columns and blocking date anomalies. The downstream legacy `Shift` also carries category, excluded/generated flags, linked shift key, source color, custom title and Calendar color.

The canonical `Schedule` contains months and assignments, not source snapshot, section, cell, review actor, rule version or date-anomaly evidence. `LegacyScheduleAdapter` returns source metadata separately from the canonical schedule. `ImportedScheduleAdapter` converts reviewed tabular records but does not retain the original `ShiftRecord` objects in the canonical aggregate.

The current durable canonical schedule format is `shift-tools.canonical-schedule`, schema version 1, encoded by `ScheduleJsonCodec` and stored through the alternating-slot `SharedPreferencesScheduleRepository`. The codec serializes schedule, departments, employees, shift types, months and assignments. It does not serialize import provenance or review decisions.

### 14.1 Compatibility decision

Do not add provider-specific provenance fields directly to `Schedule` or silently change canonical schedule schema version 1.

Introduce a separate, versioned import/review envelope at the application boundary. The envelope should reference (not duplicate) the canonical schedule ID and contain:
- envelope format discriminator and schema version;
- import run ID and source snapshot reference/fingerprint;
- source kind and parser/reader version;
- section and source coordinate evidence;
- normalized candidate-to-canonical assignment links;
- identity/shift resolution decisions and review state;
- blocking and non-blocking diagnostics;
- included/excluded row/section decisions;
- accepted schedule revision/fingerprint and timestamp;
- a status lifecycle such as DRAFT, REVIEW_REQUIRED, APPROVED, COMMITTED, or FAILED.

Do not store raw workbook bytes, raw cell payloads or secrets inside the envelope by default. Keep source evidence minimal and privacy-reviewed.

### 14.2 Atomicity and repository boundary

The existing `ScheduleRepository.save` commits one canonical `Schedule`; it has no transaction method that atomically saves a schedule and a separate provenance record. Writing a schedule first and provenance second can leave a committed schedule with missing audit evidence if the second write fails.

Before implementation, choose and test one of these explicit strategies:
1. A new import-commit repository/use case that persists a versioned bundle containing both schedule and provenance as one durable unit, while preserving existing schedule reads and schema-v1 data; or
2. A staged two-phase protocol with durable PREPARED/COMMITTED states, recovery on restart, and idempotent repair of incomplete commits.

Do not claim atomicity from two independent SharedPreferences writes. Do not replace or migrate existing canonical schedules without a tested rollback and compatibility path.

### 14.3 Identity and lineage rules

- A source cell locator is evidence, not a canonical assignment ID.
- A reviewed employee ID and shift-template ID must be preserved; never resolve identity from a display name after approval.
- A source revision may move a record to another cell without changing the real-world assignment; retain both lineage references.
- A malformed or blocked section cannot generate REMOVE proposals for assignments that are absent from that section.
- An excluded row remains visible in the review/audit envelope; it must not be silently discarded.
- Re-importing the same accepted source revision must be idempotent and must not duplicate canonical assignments.

### 14.4 Required tests before production acceptance

- Decode existing schema-v1 schedule fixtures before and after introducing the envelope; existing schedules remain readable.
- Round-trip an envelope with both tabular and grid source evidence.
- Simulate failure between staged and committed writes; recover without losing the prior accepted schedule.
- Retry the same import-run ID and source fingerprint; do not duplicate assignments.
- Preserve employee/shift review decisions and excluded-row reasons after restart.
- Verify source-cell/section lineage survives canonical conversion and reload.
- Verify malformed section blocks only its own proposed changes and never creates mass removals.
- Verify concurrent/stale target revision is rejected and requires a refreshed preview.

Until these tests execute on the exact candidate commit, provenance persistence remains **UNKNOWN** and must not be represented as implemented.
