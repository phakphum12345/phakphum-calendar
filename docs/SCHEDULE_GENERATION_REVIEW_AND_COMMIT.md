# Schedule Generation Review and Commit Workflow

**Status:** Design specification; current generation engine is application-level and no production approval/persistence workflow has been verified.  
**Prepared:** 2026-11-24  
**Related:** [Master plan](UNIVERSAL_ROSTER_INTELLIGENCE_MASTER_PLAN.md), [Universal Generator](UNIVERSAL_GENERATOR_SPEC.md), [Grid import review](GRID_IMPORT_REVIEW_WORKFLOW.md), [Provenance and reconciliation](ROSTER_PROVENANCE_AND_RECONCILIATION.md)

## 1. Current implementation boundary

The following source components were inspected:

| Component | Current behavior | What it does not prove |
|---|---|---|
| `MonthlyRosterRequestBuilder` | Builds an empty monthly Schedule and CoverageRequirement values from a blueprint and staffing rules | Does not load/persist a roster or create a UI workflow |
| `GenerationRequest` | Immutable request containing schedule, month, employees, shift types, coverage requirements, availability, department capacities and locked duty points | Does not capture a durable source snapshot or approval |
| `ScheduleGenerator` / `AutoAssignmentService` | Produces a candidate Schedule, conflicts, uncovered requirements and assignment count | Does not persist the result |
| `GenerationResult` | Reports `completed` only when no uncovered requirements and no error-severity conflicts exist | `completed` is not human approval or commit status |
| `ScheduleAssignmentWriter` | Returns a new Schedule with an assignment added | Does not write to ScheduleRepository |
| `GeneratorCalendarAdapter` | Converts generator event records into Calendar preview candidates and blocking issues | Explicitly has no gateway, persistence or sync executor |

Existing tests cover manual assignment, unavailable employee rejection, coverage fulfillment, insufficient capacity, duplicate assignment detection and uncovered requirements. These test sources were inspected; they were not executed in this audit.

## 2. Target state lifecycle

```text
DRAFT
  -> VALIDATED_INPUT
  -> GENERATED_PREVIEW
  -> REVIEW_REQUIRED
  -> APPROVED (exact preview fingerprint)
  -> COMMIT_PREPARED
  -> COMMITTED
  -> READ_BACK_VERIFIED
  -> CALENDAR_PREVIEW (separate authorization boundary)
  -> CALENDAR_SYNCED (separate explicit confirmation)
```

Failure states must be explicit: INVALID_INPUT, BLOCKED_CONFLICT, INCOMPLETE_COVERAGE, STALE_PREVIEW, COMMIT_FAILED, RECOVERY_REQUIRED and SYNC_PARTIAL. A failed or incomplete generation may remain useful as a review draft but must not be represented as committed.

## 3. Input validation before generation

The application use case must validate:
- requested month and all coverage dates belong to the selected range;
- each referenced shift type, department/staff group and blueprint slot exists;
- staffing rules are compatible with the slot's allowed groups;
- required employee counts are non-negative and within configured limits;
- employee identities are canonical and active;
- availability and department capacity are loaded for the exact target period when configured;
- locked duty points refer to valid employee and location identifiers;
- source roster/import revision and policy versions are recorded where generation is based on imported data.

The current request builder does not accept availability or department capacities as parameters, even though `GenerationRequest` supports both. The orchestration layer must load and pass these constraints when the selected policy requires them; it must not silently assume unrestricted availability.

## 4. Immutable preview contract

A preview record should include:
- generation run ID and creation time;
- input schedule ID/revision/fingerprint;
- selected month and timezone policy;
- employee directory and shift-type catalog revision;
- blueprint, staffing-rule and policy versions;
- exact coverage requirements;
- generated candidate schedule fingerprint;
- created assignment count;
- conflicts, severity and affected employee/date/requirement;
- uncovered requirements and required coverage;
- reviewer selections and exclusions;
- preview fingerprint and expiration/staleness policy.

The preview must not mutate the input Schedule or save anything. Any change to the input schedule, employee catalog, shift catalog, blueprint, staffing rules, availability or capacity invalidates approval and requires regeneration.

## 5. Human review rules

Review UI must show:
- proposed assignments grouped by date, department/location and shift;
- assignments already present in the source schedule versus newly generated assignments;
- conflicts and their severity;
- every uncovered requirement and shortfall;
- fairness/load distribution and relevant constraints when supported by measured data;
- exact rows included, excluded or manually changed;
- before/after diff against the input schedule.

Blocking error conflicts and uncovered requirements prevent the default full approval action. A partial-approval mode may be added only if it stores an exact approved subset and revalidates coverage and conflicts for that subset. It must never quietly convert an incomplete result into a fully completed schedule.

Manual changes after generation create a new preview revision and invalidate the prior approval fingerprint.

## 6. Commit boundary

Add a single application use case for committing an approved generation result. It must:
1. reload the target schedule and relevant catalog/policy revisions;
2. reject a stale preview;
3. validate the exact approved operation set again;
4. persist the canonical Schedule through the existing repository abstraction;
5. persist generation provenance and approval evidence using an atomic bundle or recoverable journal;
6. read back and verify the schedule fingerprint and provenance linkage;
7. record per-item outcomes and commit timestamp.

Do not call the repository directly from a widget. Do not save generated assignments during preview. Do not use two independent preference writes as if they were one atomic transaction. If durable provenance cannot be committed safely, fail closed and leave the candidate as a non-committed draft.

## 7. Calendar integration boundary

Calendar integration is a later, separate action:
- only a read-back-verified committed schedule may be offered for Calendar preview;
- use the existing Calendar sync planner/coordinator/gateway and stable sync identity strategy;
- show the exact target calendar and event diff;
- require separate explicit confirmation;
- retain per-event success/failure and ambiguous-outcome reconciliation;
- never infer Calendar sync success from local Schedule persistence.

The current `GeneratorCalendarAdapter` is preview-only. Do not register or describe it as a live Calendar execution pipeline.

## 8. Required tests

### Generator behavior
- deterministic output for identical input and versioned policy;
- source Schedule remains unchanged;
- unavailable employees, capacity limits and locked duty points are respected;
- duplicate assignments and overlapping shifts are surfaced;
- missing shift types and invalid staffing rules block generation;
- all uncovered requirements are reported;
- cross-month/year and timezone boundary behavior is explicit.

### Review and approval
- preview contains stable fingerprint and exact operation list;
- any input/catalog/policy change invalidates preview;
- unresolved blocking conflicts prevent full approval;
- partial approval (if implemented) stores exact selected subset and revalidates;
- manual edits invalidate previous approval.

### Commit and recovery
- no repository call before approval;
- stale preview cannot commit;
- repeated commit is idempotent;
- crash recovery does not duplicate assignments;
- saved schedule and provenance read back consistently;
- failed persistence leaves no false COMMITTED state;
- schema-v1 schedule fixtures remain compatible.

### Calendar boundary
- no Calendar calls during generation or schedule commit;
- Calendar preview requires committed read-back evidence;
- Calendar write requires separate explicit confirmation;
- ambiguous provider outcomes reconcile by stable event identity.

## 9. Implementation sequence

1. Add immutable generation preview/fingerprint model.
2. Add input snapshot and catalog/policy revision capture.
3. Add review state and conflict/uncovered presentation.
4. Add application-level commit use case and persistence/recovery contract.
5. Add controller and UI route without changing existing manual scheduling.
6. Add integration tests for preview → review → approval → commit → reload.
7. Connect Calendar preview through the existing sync workflow only after the prior gates pass.

Do not expand the current generator's responsibility to include Calendar writes. Preserve existing generation API behavior and test fixtures while adding orchestration around it.
