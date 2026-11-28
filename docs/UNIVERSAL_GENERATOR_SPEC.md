# Universal Roster Generator — Functional and Technical Specification

**Status:** Target specification; current adapter remains preview-only as described in [Universal Generator → Calendar Adapter](universal-generator-calendar-adapter.md).  
**Prepared:** 2026-11-24  
**Related:** [Master plan](UNIVERSAL_ROSTER_INTELLIGENCE_MASTER_PLAN.md), [Roster configuration roadmap](ROSTER_CONFIGURATION_AND_SYNC_ROADMAP.md), [Shift rules](SHIFT_PAY_RULES.md)

## 1. Purpose and scope

The Generator converts validated, normalized roster facts into reviewed outputs such as calendar-event candidates, schedule views, reports and export files. It is not a second parser and must not reinterpret raw spreadsheet content. It consumes canonical records plus a versioned profile/template and emits a deterministic generation result.

The current adapter in `lib/features/universal_generator_adapter/` is documented as a pure, preview-only boundary. This specification describes the complete target workflow; it does not claim that persistence, profile management, export formats or Calendar writes are already connected.

## 2. Design invariants

1. Generator input is normalized and validated; raw file parsing stays upstream.
2. Every output can be traced to source records, profile/template version and generation run.
3. The same input snapshot, profile version, generator version and clock-independent options produce the same output.
4. Unknown dates, identities, time zones and shift durations are not invented.
5. No output operation mutates source workbooks.
6. Preview and commit use the same immutable generation result or revalidate an exact fingerprint before commit.
7. Calendar writes remain behind the existing sync planner/gateway and explicit confirmation.
8. Existing generation and Calendar flows remain available during incremental rollout.
9. A new adapter must not create a competing Calendar repository, sync coordinator, event ID strategy or persistence layer.
10. All outputs expose validation findings and distinguish blocking from non-blocking warnings.

## 3. Input contract

A generation request should identify:

| Field | Requirement |
|---|---|
| generation_run_id | Stable ID for this attempt |
| source_snapshot_id | Immutable source/import snapshot |
| normalized_records | Validated roster records with stable IDs |
| profile_id / profile_version | Selected configuration and exact version |
| template_id / template_version | Output template and version |
| target | Calendar, schedule view, report or export target |
| timezone | Explicit IANA zone or offset policy for timed output |
| range | Explicit inclusive local-date range where applicable |
| options | Typed, validated target-specific options |
| requested_by | Authenticated actor or local user context |
| confirmation_state | Must be unconfirmed during generation and preview |

The request must not accept arbitrary raw spreadsheet cell maps as a substitute for canonical records. If provenance is unavailable, mark it explicitly as unavailable instead of synthesizing source coordinates.

## 4. Output contract

A generation result contains:
- generation run and input fingerprints;
- selected profile/template IDs and versions;
- generated candidate records;
- source-record-to-output-record relationships;
- validation findings;
- deterministic ordering information;
- output counts by created/updated/unchanged/blocked/skipped;
- a preview fingerprint;
- confirmation requirement and allowed next actions.

A Calendar candidate must retain the adapter's existing safety constraints: stable batch and source-record identity, explicit title, valid start/end ISO-8601 timestamps with timezone offset or UTC designator, positive duration and blocking findings for invalid input.

## 5. Template model

Templates are user-configurable mappings, not hardcoded hospital names. A template may define:
- output title pattern using approved fields;
- description pattern and optional source reference;
- target calendar selection (resolved through authorized existing account configuration);
- time interpretation policy;
- event grouping/splitting rules;
- color/category mapping where supported;
- date-range and filtering rules;
- output locale and formatting;
- conflict policy;
- version and lifecycle state.

Template evaluation must use an allowlisted expression vocabulary. Do not evaluate arbitrary code, shell fragments, SQL, HTML scripts or untrusted template expressions. Escape output for the target format.

## 6. Generation pipeline

```text
Validated Canonical Snapshot
  -> Resolve Profile + Template Versions
  -> Validate Required Fields
  -> Apply Deterministic Mapping Rules
  -> Build Output Candidates
  -> Check Duplicates / Conflicts
  -> Attach Provenance
  -> Validate Output Contract
  -> Immutable Preview Result
  -> User Review + Explicit Confirmation
  -> Existing Target Adapter
  -> Verify Per-Item Outcomes
  -> Audit + History
```

Each stage returns typed results/findings; it must not silently discard a failed record. Partial success is allowed only when the target workflow supports section/item isolation and the preview makes exclusions visible.

## 7. Mapping and rule semantics

- A field may map directly from a canonical record or through a named, versioned transformation.
- Missing required values block only the affected output record when isolation is safe.
- Time mapping must distinguish date-only values, local wall time, explicit offset and UTC.
- Overnight shifts use explicit start/end dates or a validated overnight rule; never assume an end earlier than start means next day unless the selected shift definition says so.
- Employee display names and identifiers are not interchangeable.
- A color is presentation metadata, not proof of a shift relationship.
- Template defaults must not override explicit event-level values.
- Event overrides remain local unless the user explicitly saves them to a template.

## 8. Conflict and identity policy

Use existing stable source identifiers and Calendar sync identity strategy where possible. Do not deduplicate solely on title, employee name or date. Candidate matching should consider stable source keys and target metadata, and report uncertain matches for review.

A conflict result must explain:
- candidate output and existing target item;
- matching keys and their provenance;
- fields that differ;
- proposed action;
- whether the action is safe to retry;
- whether human resolution is required.

## 9. Preview and commit contract

A preview is immutable and bound to:
- source snapshot fingerprint;
- profile and template versions;
- normalized record IDs/versions;
- generator version;
- target identity and relevant target state;
- exact proposed operations.

Before commit, compare the current values with the preview fingerprint. If any relevant input changed, reject stale confirmation and require a new preview. A confirmation must identify the exact operation scope, not a broad implicit authorization.

The existing adapter must remain unregistered from production dependency composition until the preview UI, review, confirmation, audit and integration tests are complete. Calendar writes must continue through the existing sync planner and gateway.

## 10. Failure and recovery

- Validation failure: retain findings and block affected candidates.
- Target authorization failure: do not retry with broader scopes automatically.
- Partial target failure: record each item outcome and retry only safe failed items.
- Timeout with unknown outcome: reconcile target state by stable ID before retrying.
- Process restart: reload the durable run/operation state if the feature is enabled; otherwise report that resume is unsupported.
- Duplicate candidate: surface evidence and do not auto-delete or overwrite unrelated output.
- Template version changed: keep the original preview tied to the old version and require re-preview before applying a new version.

## 11. Test requirements

1. Valid and invalid ISO-8601 inputs; offset and UTC cases.
2. Missing/duplicate batch and source IDs.
3. Stable identity encoding with delimiter and Unicode cases.
4. Overnight and cross-month/year output boundaries.
5. Profile/template precedence and immutable versions.
6. Missing required fields and partial-record blocking.
7. Deterministic output ordering and fingerprint.
8. Stale preview invalidation.
9. Duplicate/conflict detection without title-only destructive matching.
10. Calendar adapter uses existing sync coordinator/gateway.
11. Explicit confirmation required and no side effect during preview.
12. Retry/resume and ambiguous provider outcomes.
13. Export escaping and formula-injection safety where spreadsheet output is supported.
14. Existing import and Calendar sync regression suite.

## 12. Acceptance gate

The Generator is production-ready only after profile/template persistence, review UI, immutable preview, exact confirmation, existing adapter integration, per-item outcome verification, audit/history and authorized test-account E2E are demonstrated on an exact commit. Until then, describe it as a specification or preview-only foundation, not a completed universal generator.
