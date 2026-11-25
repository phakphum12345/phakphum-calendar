# ADR: Conditional Schedule Persistence and Journal Discovery

**Status:** Proposed; not accepted for production implementation  
**Date:** 2026-11-24  
**Scope:** Flutter client persistence for canonical Schedule records and Grid-import recovery.

## Context

The current `ScheduleRepository` contract exposes `findById`, `loadMonth`, `save`, and `delete`. Its production implementation uses `SharedPreferencesAsync` and two alternating payload slots with an active-slot pointer. This improves recovery from an interrupted payload write, but the read/write/pointer sequence is not an atomic compare-and-set operation.

Grid import checks the Schedule revision before journaling and again immediately before repository save. A writer can still change the Schedule between the final read and save. Adding a process-local mutex would not protect against other repository instances, older write paths, other app processes, or other devices.

The app is a Flutter client with multiple target platforms. Replacing persistence with a mobile-only database or assuming all platforms share identical transaction semantics would create a platform regression.

## Decision status

No database package or storage engine is selected in this ADR. A platform compatibility and concurrency prototype is required before accepting a production decision. Do not add a persistence dependency solely to make the Grid-import code appear complete.

## Required repository evolution

Keep the existing `ScheduleRepository` contract source-compatible for existing callers during migration. Add a separate capability contract, conceptually:

```dart
abstract interface class ConditionalScheduleRepository {
  Future<Result<ConditionalScheduleWriteResult>> compareAndSet({
    required String scheduleId,
    required String expectedRevision,
    required Schedule replacement,
  });
}
```

The result must distinguish at least:
- saved: the expected revision matched and the replacement was committed;
- conflict: the current stored revision did not match;
- storage failure: the conditional operation could not be completed.

The absent Schedule state must have an explicit revision token. It must not be conflated with a present but empty Schedule.

This interface is a capability boundary, not an implementation. A backend qualifies only if comparison and write are atomic at the storage boundary and every Schedule writer participates in the same revision protocol. A wrapper that performs `findById` followed by `save` does not qualify.

## Proposed revision-token contract

The writer inventory confirms that the existing Grid workflow already computes a deterministic content fingerprint from `ScheduleJsonCodec.encode(schedule)` and uses an explicit `absent:<scheduleId>` value for a missing target. Reuse that canonical encoding for integrity/fingerprint evidence, but do **not** use a content hash alone as the concurrency revision.

A content hash alone has an ABA limitation: a Schedule can change from A to B and later return to byte-equivalent A. A stale editor holding the first A hash would then appear current even though intervening writes occurred. The concurrency token should therefore include a monotonically increasing per-Schedule generation.

Proposed storage metadata (not part of canonical Schedule schema v1):

- `generation`: non-negative integer, incremented by every successful conditional save or delete, including a save whose payload is unchanged;
- `state`: `live` or `deleted`;
- `contentFingerprint`: SHA-256 of the canonical `ScheduleJsonCodec.encode(schedule)` payload when state is live; absent for a tombstone;
- `revisionToken`: opaque token derived from schema version, generation, state and (for live records) content fingerprint.

The revision token is compared as an opaque value. A human-readable conceptual form may be `schedule-revision:v1:<encoded-schedule-id>:<generation>:<state>:<fingerprint>`; the Schedule ID is part of the token scope, and callers must not parse or manufacture it.

### Read and conditional-write semantics

The new capability should expose a read that returns both the current Schedule (nullable) and its revision token. The legacy `findById` remains source-compatible during migration, but it does not provide enough information for a stale-write-safe editor.

- **Never-created Schedule:** return an explicit generation-zero absent token, distinct from a live empty Schedule.
- **Conditional create:** compare against that absent token; atomically create generation one. Of two writers holding the same absent token, exactly one succeeds.
- **Conditional update:** compare the exact current revision token; atomically write the new Schedule, incremented generation and fingerprint.
- **Conditional delete:** compare the exact live token; atomically write a tombstone at the next generation instead of physically erasing the identity/revision record.
- **Recreate after delete:** compare against the tombstone token and increment generation again. A stale token from before deletion must not recreate the Schedule.
- **Conflict:** return the current revision (and, where appropriate, current Schedule) without mutating storage.
- **Storage failure:** leave the previous live record or tombstone recoverable; never report a save before the storage transaction commits.

Tombstones must not be physically purged during the first migration. Any later compaction needs a proven bound on stale-token lifetime or a coordinated epoch change; otherwise an old absent token could become valid again.

### Storage atomicity requirement

The payload, generation, state and fingerprint must be committed as one storage transaction or one atomic record replacement. Keeping them in separate keys is acceptable only if the chosen storage engine proves the complete compare-and-write operation is atomic across those keys. Two alternating payload slots plus an active pointer and read-back verification alone do not satisfy this requirement.

The existing `GridRosterImportWorkflow.revisionFor` and `scheduleFingerprint` are useful source-level starting points, but the current read-then-save workflow is not CAS. Move revision ownership into the repository/storage boundary; do not duplicate slightly different revision algorithms in controllers or import workflows.

Migration of existing SharedPreferences records must preserve the original slots, derive the initial fingerprint from the decoded canonical Schedule, assign an explicit initial generation, write an idempotent migration marker, read back and verify, and retain rollback data. Existing physically deleted IDs cannot be reconstructed from absent keys; after rollout, all deletes must use tombstones.

## Repository platform baseline

The current release support policy lists five active targets: Windows x64, Web, Android, iOS and Linux x64. macOS is preserved in the repository but currently paused with no active release workflow. See `docs/PLATFORM_SUPPORT.md`.

The current `pubspec.yaml` declares `shared_preferences` and `crypto` for this persistence path; it does not currently declare a relational database/transaction package. The production Schedule repository uses `SharedPreferencesAsync`. No storage package is selected by this ADR.

The storage prototype must pass the five active release targets. macOS compatibility should be recorded as a future reactivation gate rather than silently treated as a currently shipped target. The Web target is a first-class requirement; a mobile-only SQLite plugin is not sufficient.

## Candidate evaluation matrix

Evaluate each candidate on the exact platforms and deployment modes supported by this repository.

| Criterion | Required evidence |
|---|---|
| Android / iOS | Integration test on supported OS versions |
| Windows / macOS / Linux | Plugin support and integration test for each shipped desktop target |
| Web | Browser persistence behavior, transaction guarantees, quota and private-browsing behavior |
| Atomic conditional write | Two independent writers using one expected revision; exactly one succeeds |
| Durability | Process termination at each write boundary and recovery verification |
| Migration | Existing SharedPreferences schedules remain readable and are migrated without data loss |
| Concurrency scope | Documented behavior across repository instances, isolates, app processes and devices |
| Operations and cost | No mandatory paid hosted service for local-only use |
| Maintenance | Active package support, platform plugin health, backup/export strategy |

Do not infer atomicity from a package name, a local mutex, a successful single-writer test, or a read-back check. Record package versions and test environment in the final accepted ADR.

## Preliminary storage candidate screening (not a selection)

This is a package-documentation screen only. It does not establish that any candidate satisfies the repository's required concurrency, crash-recovery or migration behavior.

| Candidate | Active-target fit | Useful documented properties | Risks / proof still required | Preliminary disposition |
|---|---|---|---|---|
| [Drift](https://pub.dev/packages/drift) + [drift_flutter](https://pub.dev/packages/drift_flutter) | Package documentation lists Android, iOS, Windows, Linux and Web support; macOS is also listed. | SQLite-backed; built-in transactions and schema migrations. Web support uses WebAssembly and browser storage with a shared-worker fallback. | Web assets/setup, browser storage behavior, COOP/COEP edge cases, native database path/backup, independent-instance/process behavior and two-writer CAS tests must be proven in this app. | **First prototype candidate**, not approved. |
| [sqflite](https://pub.dev/packages/sqflite) + platform companion packages | Native Android/iOS plus Windows/Linux FFI; Web uses a separate package documented as experimental. | Familiar SQLite transaction API shared across companion packages. | Multiple package/factory configurations; Web experimental status and setup assets raise release risk for an active Web target. | **Secondary prototype candidate** only if Drift integration fails a concrete requirement. |
| [Sembast](https://pub.dev/packages/sembast) + [sembast_web](https://pub.dev/packages/sembast_web) | Native VM/Flutter and Web package support are documented. | Pure-Dart embedded document store with common API; can be backed by sqflite through an adapter. | The package describes its IO database as single-process. Cross-process safety depends on a different backing adapter; transaction/isolation semantics and multi-tab Web behavior must be independently proven. | **Do not select as-is** for global writer safety; retain only as a comparison candidate. |
| Existing SharedPreferences repository | Already integrated on current targets through the Flutter plugin. | Small dependency surface and existing two-slot/read-back recovery behavior. | No storage-level atomic compare-and-set or multi-key transaction in the current repository contract. | Retain during migration; **not sufficient** for the target CAS guarantee. |

### Prototype gate before choosing

1. Build a small storage-only spike with no production Schedule migration.
2. Run the same contract suite on Windows, Web, Android, iOS and Linux; record exact OS/browser/runtime and package versions.
3. Open two independent database/repository instances against the same store. Start both from one revision and force an interleaving; exactly one update must commit.
4. Repeat for create-if-absent, update, delete-to-tombstone, recreate-after-delete and same-content save (generation must still advance).
5. Kill/restart at each commit boundary and verify that readers see either the complete old record or complete new record, never mixed payload/revision metadata.
6. On Web, test two tabs, reload, browser restart, quota failure and supported browser storage fallback.
7. Compare backup/export, migration rollback, package maintenance and bundle/setup cost. Do not add a dependency to production until the prototype passes.

Package documentation references: Drift transaction and platform feature summary; Drift Web storage behavior; sqflite platform companion matrix and experimental Web package; Sembast platform factories and single-process IO description. The links above are starting evidence, not a substitute for app-specific integration tests.

## Isolated prototype status (2026-11-24)

An isolated spike now exists at `tool/schedule_cas_spike/`. It uses Drift with a SQLite single-statement conditional UPSERT for create/update and a conditional UPDATE for tombstone deletion. Its test source covers explicit absent-token creation, stale create/update rejection, ABA protection, same-content generation advancement, tombstone recreation rules, stale-token resurrection protection and two independent database instances.

A dedicated workflow (`.github/workflows/schedule-cas-spike.yml`) runs the native SQLite contract on Windows, Linux and macOS hosts. This is **source implementation only until a workflow run completes**. Android/iOS device integration, Web multi-tab storage, process-kill recovery, and browser quota/fallback behavior remain unproven. The spike's separate package manifest intentionally leaves the production dependency graph and root lockfile unchanged.

### Independent SQL semantics spot-check (not Drift runtime evidence)

The exact UPSERT/conditional-UPDATE SQL shape was separately exercised against SQLite 3.46.1 using two independent Python SQLite connections to one temporary database. The spot-check observed:
- create from absent token succeeds; a second stale absent-token create returns no row;
- expected-revision update succeeds; replaying the stale revision returns no row;
- delete writes the next-generation tombstone;
- a pre-delete live token cannot recreate the record; the current tombstone token can;
- two simultaneous independent writers using the same revision produced one `saved` outcome and one `conflict`, with one final committed payload.

This is **not** evidence that the Dart Drift adapter, the generated database, Drift's `customSelect` handling of SQLite `RETURNING`, or any of the five app targets work. It only reduces uncertainty about the SQL statement semantics. The Drift package workflow must still run before the prototype receives any runtime PASS.

The prototype scopes every revision token to its Schedule ID and rejects cross-Schedule token reuse. It currently hashes the payload supplied by its caller; it does not yet use `ScheduleJsonCodec`. This is deliberate isolation, not permission to substitute it into production. The prototype cannot justify accepting this ADR until exact-SHA test results and the complete active-platform matrix are attached.

## Migration sequence

1. Inventory every production Schedule write path, including editor, imports, restore, sync, migration, delete and test fakes.
2. Define one canonical revision algorithm and explicit absent token. Revision must change on every successful canonical write.
3. Prototype candidate storage engines on every shipped platform.
4. Prove atomic conditional writes with two independently instantiated writers and an interleaving test.
5. Implement the capability on the selected storage adapter while retaining the legacy interface for non-migrated callers.
6. Migrate every production writer to conditional writes or a transaction that updates the same revision record. Until this is complete, do not claim global concurrency protection.
7. Migrate existing SharedPreferences records with backup, idempotent migration marker, read-back verification and rollback instructions. Never delete legacy records during the first migration release.
8. Switch Grid import to the conditional write operation. A conflict must retain its journal and surface a reviewable conflict; never silently rebase.
9. Keep Calendar sync separate from Schedule persistence and require explicit preview/authorization.

## Journal discovery requirements

The current journal uses two slots per Schedule ID but has no enumeration API. Startup recovery requires a versioned index of Schedule IDs and lifecycle state, or a storage engine that can enumerate records transactionally.

The index design must define:
- journal-slot/index update ordering and repair after interruption;
- how an index entry is removed or archived without losing recoverability;
- detection of orphan journal slots and corrupt index records;
- bounded batch recovery and startup timeout behavior;
- conflict and corruption reporting that does not block unrelated Schedules;
- retention and schema migration policy.

Do not scan arbitrary SharedPreferences keys and guess Schedule IDs. Do not replay a committed journal automatically until conflict handling and user-visible reporting are implemented.

## Acceptance tests

- Two independent writers start from the same revision; exactly one conditional write succeeds.
- A stale expected revision never changes canonical storage.
- A missing Schedule can be created conditionally; only one writer can win.
- Every legacy write path is included in the concurrency migration inventory.
- Migration preserves existing schedules and can be retried after interruption.
- Journal/index interruption at every write boundary is recoverable or produces a surfaced, non-destructive error.
- Startup processes multiple journals independently; one conflict does not suppress unrelated recovery.
- Existing tabular import and Schedule editor regression suites pass on all supported platforms.

## Consequences

- The existing SharedPreferences repository remains the active production implementation until a proven replacement is selected.
- Grid import continues to use its current revision guards and fail-closed recovery behavior, with the read/save race explicitly documented.
- Startup journal discovery remains unimplemented until the index contract and migration are designed.
- This ADR must be updated to **Accepted** only after the prototype evidence and platform matrix are attached. Until then, all conditional-write and startup-recovery work remains a release blocker, not a passed capability.
