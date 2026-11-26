# Grid Import Recovery and Concurrency Contract

**Status:** Design contract; implementation is partial.  
**Last reviewed:** 2026-11-24  
**Scope:** Local XLSX Grid import, canonical Schedule persistence, and provenance journal.

## Backend journal synchronization and cross-device recovery

When `ORGANIZATION_API_BASE_URL` is configured, the Grid import workflow uses the authenticated Schedule API and the append-only remote import-journal API together with the existing local two-slot journal.

The remote journal's `COMMITTED` lifecycle has a deliberately narrow meaning: **the user-approved import payload and provenance have been durably recorded as a recoverable commit intent**. It does not assert that the canonical Schedule API write has already succeeded. The canonical Schedule is saved afterward with its expected revision (CAS); if that save fails, the committed journal is the recovery source. Recovery must still compare the current canonical revision/fingerprint before applying anything. The journal row and Schedule row are not written in one database transaction, so this protocol is recoverable and conflict-aware, not cross-table atomic.

The write order is deliberately fail-closed:

1. Re-read the canonical Schedule and verify the review base revision.
2. Append the remote PREPARED stage.
3. Commit and read back the local two-slot journal.
4. Append the remote COMMITTED stage with the canonical Schedule and accepted fingerprint.
5. Re-read the canonical Schedule and save with the backend revision token (CAS).

A failed remote PREPARED or COMMITTED stage prevents the canonical Schedule save. A local COMMITTED record is retained if the remote COMMITTED request fails, so local recovery remains possible. Remote PREPARED-only records are never replayed.

Recovery reads both the local journal and the authenticated remote journal, chooses the newest committed provenance timestamp, then applies the same base-revision and accepted-fingerprint guards before saving. A remote read failure is not treated as an empty journal and does not silently trigger local-only replay. The remote API is currently personal-account scoped; organization-shared roster persistence is a separate future scope.

The current UI uses `grid-<microseconds>` import-run identifiers. The backend therefore accepts bounded safe identifiers rather than requiring UUID syntax. API fingerprint fields are raw lowercase SHA-256 hex; the versioned provenance codec continues to store the `sha256:` prefix.

## 1. Safety invariants

1. A reviewed import is bound to one Schedule ID and the exact Schedule revision loaded before review.
2. A commit must reject a stale review before writing a journal record.
3. A committed journal bundle is recoverable only while the canonical Schedule is still at the recorded base revision, or when the canonical Schedule already matches the journal's accepted fingerprint.
4. Recovery must never replace a Schedule whose current revision differs from both the recorded base revision and the accepted fingerprint.
5. A PREPARED-only journal record is not a committed import and must never be replayed.
6. Recovery is idempotent: if canonical storage already equals the accepted fingerprint, return the canonical value without another write.
7. Calendar synchronization remains outside this workflow and requires a separate preview and explicit user action.

## 2. Current implementation boundary

| Capability | Current state |
|---|---|
| Review snapshot and target revision fingerprint | Implemented |
| Pre-journal stale revision check | Implemented |
| Journal PREPARED/read-back/COMMITTED protocol | Implemented |
| Committed provenance preserves prepared review decisions | Implemented |
| Read-before-save guard after journal commit | Implemented |
| Recovery when canonical save failed and base revision is unchanged | Implemented |
| Recovery conflict rejection | Implemented; regression test added |
| Idempotent recovery when accepted Schedule is already present | Implemented; regression test added |
| Atomic compare-and-set across concurrent writers | Not implemented |
| Cross-process/device writer exclusion | Not implemented |
| Automatic startup discovery of all journaled Schedule IDs | Not implemented |
| Recovery of every journal before any schedule is edited | Not implemented |

## 3. Why the current guard is not atomic CAS

The current `ScheduleRepository` contract exposes `findById`, `save`, and `delete`. It has no conditional write operation. The production SharedPreferences repository performs a read, writes an inactive slot, verifies the payload, and updates an active-slot pointer. These steps improve crash resilience, but they do not make a conditional write atomic against another writer.

The Grid workflow performs multiple revision reads around journal commit and before canonical save. This detects many stale-write cases, but a concurrent writer can still modify the Schedule between the final read and the subsequent save. A process-local mutex would not close this gap for legacy writers, other app processes, or another device.

**Do not describe the current implementation as atomic, transaction-safe, or concurrency-proof.**

## 4. Required architecture for real conditional writes

A future persistence implementation must provide a storage primitive with a genuine atomic condition-and-write boundary. Acceptable approaches include:

- A transactional local database with a revision column and an update condition such as `WHERE id = ? AND revision = ?`, verifying exactly one row changed.
- A storage service that exposes a server-enforced conditional update using an ETag/version precondition.
- Another storage engine whose documented transaction semantics provide equivalent cross-writer guarantees.

The operation should express the expected revision explicitly:

```text
compareAndSetSchedule(
  scheduleId,
  expectedRevision,
  replacementSchedule
) -> saved | revisionConflict | storageFailure
```

Requirements:
- The comparison and write occur in one atomic transaction at the storage boundary.
- The revision changes on every successful write.
- A missing Schedule uses an explicit absent token and must not be confused with an empty Schedule.
- A conflict returns the current revision or a typed conflict result; it must not silently retry with a newer revision.
- Existing repository callers retain backward-compatible behavior until they are deliberately migrated.
- Grid import must use the conditional write path before reporting success.
- Tests must run two interleaved writers and prove exactly one writer can commit against the same expected revision.

SharedPreferences alone does not provide this primitive. Do not simulate it with read-then-write code and call it CAS.

## 5. Startup recovery discovery

The journal is addressed by Schedule ID and currently has no safe index of all IDs with pending or committed bundles. The current app startup path initializes the legacy `AppController`; it does not enumerate Grid journal entries.

Before startup recovery can be implemented safely, define:
- A durable, versioned journal index or a storage API that can enumerate journal IDs.
- Index update/rebuild behavior when a process stops between journal-slot and index writes.
- A bounded recovery policy for large numbers of Schedules.
- A distinction between clean/no-journal, PREPARED-only, recoverable committed, corrupt journal, and revision conflict.
- A user-visible conflict report; startup must not silently choose a Schedule revision.
- A migration and retention policy for journal records.

Do not scan arbitrary SharedPreferences keys or infer Schedule IDs from encoded key fragments without a formal index contract.

## 6. Acceptance tests

Required automated tests:
- Stale review is rejected before journal mutation.
- Repository save failure leaves a committed journal that can be replayed when the base revision is unchanged.
- Recovery rejects a newer canonical Schedule and leaves it byte-for-byte/logically unchanged.
- Recovery is idempotent when the accepted fingerprint is already canonical.
- PREPARED-only records are never replayed.
- A corrupted newest slot does not cause a valid previous committed slot to be overwritten.
- Same importRunId with different content is rejected.
- Two concurrent writers using the same expected revision cannot both succeed once atomic CAS is implemented.
- Startup recovery handles each indexed Schedule independently and surfaces conflicts without blocking unrelated Schedules.

Runtime test execution remains a separate gate. Source-level tests are not evidence that the tests have passed.

## 7. Release gate

The Grid import workflow is not ready for a concurrency-safety claim or production-wide recovery claim until:
1. Atomic conditional persistence is implemented and tested against concurrent writers.
2. Startup journal discovery and conflict reporting are implemented.
3. Dart format, static analysis, focused tests, and the full regression suite run in a Flutter-capable environment.
4. Existing tabular import behavior is verified unchanged.
5. Calendar sync remains opt-in and is separately reviewed.

Until then, keep the current revision checks, report the remaining race honestly, and fail closed whenever a conflict is observed.
