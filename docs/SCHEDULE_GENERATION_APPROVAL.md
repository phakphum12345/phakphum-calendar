# Schedule generation preview and approval

## Status

- Source: implemented as an application workflow on the generation engine.
- Automated tests: regression source added; exact-head CI has not completed yet.
- UI: not yet connected to a dedicated review screen.
- Persistence: uses the revision-bound `ConditionalScheduleWriter` capability and verifies read-back.
- Production acceptance: not accepted; no deployment or multi-device generation test is claimed.

## Workflow contract

1. Load the canonical Schedule and capture its exact snapshot revision (or absent-state revision for a new Schedule).
2. Generate a candidate in memory. Preview does not write to the canonical repository.
3. Fingerprint the source Schedule, all generation inputs, employee-directory revision, shift-catalog revision and policy version.
4. Produce an immutable preview with run ID, candidate fingerprint, assignment operations, conflicts and uncovered requirements.
5. Require explicit approval bound to the exact preview and approver identity.
6. Before commit, reload the Schedule and verify the source revision and fingerprint.
7. Verify current directory/catalog/policy revisions and re-fingerprint all request inputs.
8. Re-run the generator and require the regenerated candidate fingerprint to equal the reviewed candidate.
9. Commit only a complete candidate with no blocking conflicts or uncovered requirements through atomic caller-revision CAS.
10. Read back the canonical Schedule and verify the persisted fingerprint.

Partial approval is intentionally not supported by this workflow. A preview with an error conflict, uncovered requirement or no proposed assignments cannot be approved.

## Implementation

- `lib/features/schedule_generation/application/schedule_generation_review_workflow.dart`
  - `preview`: immutable candidate and exact source/input evidence; no writes.
  - `approve`: creates approval evidence bound to run ID, source revision, candidate and input fingerprints, and policy versions.
  - `commit`: revalidates source and inputs, reruns generation, uses `saveIfRevision`, and reads back the result.
- `test/schedule_generation_review_workflow_test.dart`
  - preview does not write;
  - successful exact approval and CAS commit;
  - stale Schedule rejection;
  - directory/catalog/policy version invalidation;
  - incomplete preview cannot be approved;
  - mismatched approval cannot commit.

## Remaining work

- Add a dedicated UI for before/after diff, conflicts, uncovered coverage, exact operations and explicit approval.
- Resolve employee-directory, shift-catalog and policy revisions from authoritative repositories rather than relying on caller-provided version strings.
- Persist approval and generation operation provenance durably, with a recoverable PREPARED/COMMITTED journal and startup discovery after process crash.
- Add cross-device/backend CAS acceptance and retry-safe generation commit tests.
- Add tests for multiple departments, locked duty points, fairness metrics, large month workloads and time-zone boundaries.
- Add widget/integration tests for preview, stale invalidation, approval and recovery.
- Verify the exact post-merge main SHA and deployment separately.

This workflow does not sync Google Calendar. Calendar synchronization remains a separate explicit action after the generated Schedule is persisted and read-back verified.
