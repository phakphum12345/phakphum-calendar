# Schedule Persistence Writer Inventory

**Review date:** 2026-11-25  
**Inspected branch:** `feat/universal-roster-grid-reconciled-2026-11-25`  
**Inspected head:** `1b2dafecf1f574ea5200905a4e524cd9fd38efa7` (before this inventory evidence update)  
**Evidence type:** production writer source inspection plus separate isolated CAS prototype CI evidence. No root-app Dart/Flutter test execution is claimed.  
**Decision:** inventory baseline only. No persistence behavior, schema, or production writer was changed by this audit.

## 1. Scope and method

The audit follows the canonical `ScheduleRepository` interface, its production implementation, injected repository consumers, legacy compatibility writes, import facades, Grid-import commit/recovery, and the directly related tests.

Primary contract and storage files:

- `lib/domain/repositories/schedule_repository.dart`
- `lib/features/schedule/data/shared_preferences_schedule_repository.dart`
- `lib/features/schedule/data/schedule_json_codec.dart`
- `lib/core/di/app_dependencies.dart`
- `lib/controller/app_controller.dart`
- `lib/features/schedule/presentation/controllers/schedule_controller.dart`
- `lib/features/shift_parser/application/grid_roster_import_workflow.dart`
- `lib/features/shift_parser/data/grid_roster_bundle_journal.dart`

The inventory distinguishes (a) a direct durable write, (b) a public/application facade that delegates to a direct write, and (c) an in-memory mutation that becomes durable only when a later writer is invoked.

## 2. Canonical storage contract

`ScheduleRepository` exposes four operations: `findById`, `loadMonth`, `save`, and `delete` (`lib/domain/repositories/schedule_repository.dart`, lines 5–10).

The production implementation found in the inspected tree is `SharedPreferencesScheduleRepository` (`lib/features/schedule/data/shared_preferences_schedule_repository.dart`). It stores a version-1 canonical JSON payload in two alternating slots and switches an active-slot pointer only after writing and reading back the inactive slot. This protects the previous active payload from a failed staged write, but it is not an atomic conditional write across independent repository instances.

The concrete key-value adapter uses `SharedPreferencesAsync`. The storage interface provides only `getString`, `setString`, and `remove`; it exposes no transaction, compare-and-set, lock, revision, enumeration, or atomic multi-key operation.

The repository's `delete(id)` removes the active pointer and both payload slots. No production call site invoking `ScheduleRepository.delete` was found in the inspected source paths. This is a negative static-search observation, not proof that no indirect/dynamic caller exists.

## 3. Production writer registry

| ID | Writer / entry point | Source location | Trigger / behavior | Current guard | Protocol v.2 disposition |
|---|---|---|---|---|---|
| W-01 | `ScheduleController.saveSchedule()` | `lib/features/schedule/presentation/controllers/schedule_controller.dart:200–223` | Explicit editor save; persists the controller's current canonical aggregate. `ScheduleWorkspacePage._save` calls it at `lib/features/schedule/presentation/pages/schedule_workspace_page.dart:291`. | No expected revision is passed to repository; repository `save` overwrites the active slot. | Migrate to conditional write; capture the loaded revision and reject stale editor saves. |
| W-02 | `AppController._replaceLegacyShifts(..., persist: true)` | `lib/controller/app_controller.dart:3080–3097` | Legacy compatibility mutations convert the flat shift list to a canonical Schedule and enqueue a repository save. The method has many callers (refresh/range/settings/sign-out and legacy mutation flows); representative call sites include lines 522, 547, 997, 1288, 1375, 1578, 1608, 2181, 2187, 2221, 2268 and 2397. | `_pendingScheduleWrite` serializes queued writes within this AppController instance only. It does not coordinate other controllers, repository instances, isolates, processes or devices. | High-priority migration. Route all callers through one revision-aware use case; do not mistake the local future chain for global CAS. Review sign-out's persisted empty aggregate semantics before changing behavior. |
| W-03 | `AppController.adoptCanonicalSchedule(..., persist: true)` | `lib/controller/app_controller.dart:3103–3112` | Adopts a canonical editor result at the legacy UI boundary and persists it directly. | No expected revision/CAS; direct `save`. | Migrate to the same conditional writer as W-01/W-02. Check whether editor callback wiring can cause sequential duplicate saves. |
| W-04 | `GridRosterImportWorkflow.commit()` | `lib/features/shift_parser/application/grid_roster_import_workflow.dart:160–232` | Commits a reviewed Grid workbook: reads target, validates review revision, writes PREPARED/COMMITTED journal, re-reads target, then saves canonical Schedule. | Source fingerprint, review snapshot, target revision and final read-before-save guard. The source explicitly documents the remaining read/save race. | Replace final read + save with atomic CAS. Keep journal ordering and conflict retention; do not silently rebase. |
| W-05 | `GridRosterImportWorkflow.recover()` | `lib/features/shift_parser/application/grid_roster_import_workflow.dart:239–288` | Replays a committed journal snapshot after verifying accepted fingerprint and that the live Schedule still equals the recorded base revision. | Two reads and revision/fingerprint checks before ordinary `save`; still has a final read/save race. | Use the same CAS contract as W-04. Recovery must be idempotent and a conflict must remain visible without overwriting. |
| F-01 | `AppDependencies.saveImportedSchedule()` | `lib/core/di/app_dependencies.dart:373–375` | Tabular import persistence facade; delegates directly to `scheduleRepository.save(schedule)`. Passed into `ImportExcelPage` as `scheduleSaver` from `lib/app.dart`. | No independent revision guard in this facade; staging/review checks occur upstream and must be traced end-to-end. | Keep as a compatibility facade during migration, but route through the shared conditional writer. |
| S-01 | `SharedPreferencesScheduleRepository.delete(id)` | `lib/features/schedule/data/shared_preferences_schedule_repository.dart` | Durable deletion API; removes pointer and both slots. | No tombstone, expected revision or conditional delete. | Inventory caller and define conditional delete/tombstone semantics before adding CAS. Do not delete data during the first migration. |

### Writer topology

```text
ScheduleWorkspacePage
  -> ScheduleController.saveSchedule
  -> ScheduleRepository.save
  -> SharedPreferencesScheduleRepository
  -> SharedPreferencesAsync

Legacy UI / refresh / range / mutation paths
  -> AppController._replaceLegacyShifts
  -> per-controller _pendingScheduleWrite queue
  -> ScheduleRepository.save
  -> SharedPreferencesScheduleRepository

Canonical editor adoption
  -> AppController.adoptCanonicalSchedule
  -> ScheduleRepository.save

Tabular import
  -> AppDependencies.saveImportedSchedule
  -> ScheduleRepository.save

Grid import
  -> GridRosterImportWorkflow.commit
  -> GridRosterBundleJournal.commit
  -> ScheduleRepository.save

Grid recovery
  -> GridRosterImportWorkflow.recover
  -> GridRosterBundleJournal.recover
  -> ScheduleRepository.save
```

## 4. Non-writer mutations and related persistence

- `ScheduleService.createSchedule`, `updateAssignment`, and `deleteAssignment` mutate the in-memory canonical aggregate. They do not themselves call the repository. The editor's explicit save is the durable boundary.
- `ScheduleAssignmentWriter`, `ManualScheduleService`, and `ScheduleGenerator` are generation/domain components. The inspected files do not establish a production generation-to-`ScheduleRepository.save` orchestration path. Do not classify an in-memory generated candidate as persisted.
- `GridRosterBundleJournal` writes its own two-slot journal records through its own key-value store. Its PREPARED and COMMITTED writes are not canonical Schedule writes and do not form a cross-store atomic transaction with the Schedule repository.
- `ScheduleJsonCodec` serializes canonical Schedule schema version 1. It does not itself persist data or provide a concurrency revision.

## 5. Existing test-source evidence

| Test source | Coverage present in source | Missing / not established |
|---|---|---|
| `test/schedule_repository_test.dart` | Save/load equivalence; not-found; malformed active payload; failed active-pointer write preserves prior payload; repeated saves; dedicated key prefix. | No concurrent independent writers, stale expected revision, atomic CAS, conditional create/delete, or runtime execution evidence in this audit. |
| `test/grid_roster_import_workflow_test.dart` | Grid scan/review/convert/commit; repository save; recovery and stale-target scenarios using an in-memory repository fake. | The fake's save is a simple assignment; no deterministic interleaving between final read and save and no multi-instance atomicity proof. |
| `test/schedule_controller_test.dart` | Controller behavior test source exists. | No exact-head execution evidence was collected in this audit. |
| `test/import_excel_page_test.dart` and import staging tests | Existing tabular import path has integration/widget test sources referenced by the traceability record. | Exact-head runtime execution and full stale-revision coverage remain unverified. |

**Execution status:** Flutter/Dart tests were not run as part of this source audit. Test-source presence is not a PASS for runtime behavior.

## 6. Findings and risks

1. **Global writer coverage is not yet guaranteed.** The production paths identified above all ultimately use the same repository interface, but several bypass a shared revision-aware use case.
2. **The legacy write queue is local only.** It orders writes from one `AppController`; it is not a storage-level concurrency primitive.
3. **Grid import is guarded but not race-free.** A writer can still commit after the final read and before `save`.
4. **Delete semantics are undefined for conditional persistence.** The interface exposes delete, but no production caller was found in the inspected paths. Conditional delete/tombstone behavior needs an explicit contract.
5. **Generation persistence remains a separate gap.** The inspected generation core creates candidates; no production save/approval path was established here.
6. **Journal and Schedule persistence are separate stores.** Read-back checks improve detection but do not create one atomic transaction across the two stores.
7. **Journal discovery is still missing.** The journal can be addressed by Schedule ID, but no startup index/enumeration path was found in this inventory.

## 7. Required migration order

1. Confirm this writer registry against all remaining production source paths and the full call graph; specifically trace every `_replaceLegacyShifts` caller and the import staging confirmation route.
2. Define one canonical revision function, including an explicit `absent:<scheduleId>` token and revision behavior for every successful save.
3. Define conditional save, conditional create and conditional delete semantics. A read-then-save wrapper does not qualify as CAS.
4. Select a storage implementation only after the cross-platform atomicity/durability matrix in the persistence ADR is proven.
5. Introduce one shared conditional write use case while preserving the legacy interface for unmigrated callers.
6. Migrate W-01 through W-05 and F-01; ensure no legacy writer bypasses the capability.
7. Prove two independent writers using the same revision yield exactly one successful commit.
8. Only then switch Grid commit/recovery to CAS and implement journal discovery/indexing as a separately tested capability.
9. Keep legacy data intact through the first migration release; add backup, idempotent migration, read-back verification and rollback before any cleanup.

## 8. Evidence state

| Item | State | Reason |
|---|---|---|
| Canonical repository contract identified | PASS | Source inspected at exact branch head. |
| Production SharedPreferences writer identified | PASS | Source inspected; two-slot/pointer behavior confirmed. |
| Schedule editor writer identified | PASS | Controller and UI call path inspected. |
| Legacy AppController writer identified | PASS | Durable write funnel and representative callers inspected. |
| Tabular import facade identified | PASS | Dependency facade and app wiring inspected. |
| Grid commit and recovery writers identified | PASS | Both repository save paths and guards inspected. |
| Isolated native SQLite CAS prototype contract | PASS | Run `45568406234` passed formatting, analysis and CAS/concurrency tests on macOS, Windows and Ubuntu for head `152db1c372c227704872dc9e676e9eca12d58044`; this is prototype-only evidence. |
| Production conditional CAS | FAIL | No conditional repository capability or storage atomicity exists in the inspected contract/implementation. The prototype is not wired into production. |
| Global writer migration to CAS | FAIL | Current writers still call ordinary `save`. |
| Production Schedule delete caller | UNKNOWN | No caller found in inspected production paths; broader indirect call graph not exhaustively proven. |
| Generation-to-persistence path | UNKNOWN | No production approval/save orchestration established in this audit. |
| Startup journal discovery/index | FAIL | No index/enumeration/startup recovery path established. |
| Full root-app runtime tests on current branch head | SKIPPED | The isolated CAS workflow does not run the full Flutter application suite. Exact-head root-app test evidence is still required. |

## 9. Relationship to the persistence ADR

This inventory is the first input to [ADR: Conditional Schedule Persistence and Journal Discovery](adr/CONDITIONAL_SCHEDULE_PERSISTENCE_AND_JOURNAL_DISCOVERY.md). The ADR remains **Proposed**. The native CAS prototype is validated on three operating systems but does not establish Web/mobile/browser durability or production suitability. This document does not accept a database choice, introduce a fake CAS implementation, change Schedule schema v1, or authorize production migration.


## 2026-11-26 — Backend revision-token and Grid CAS follow-up

**Evidence:** PR #192 branch source update. This section supersedes the earlier Grid writer status where noted; it does not claim repository-wide CAS.

| Writer | Current repository path | Revision behavior | Status |
|---|---|---|---|
| W-01 / W-02 / W-03 | Legacy Schedule editor and AppController continue to use the local SharedPreferences repository | No caller-owned revision token or atomic CAS | OPEN — migrate with per-editor/per-controller snapshot tokens |
| W-04 Grid commit | Backend mode uses `ScheduleRevisionSource` for the server generation token and `ConditionalScheduleWriter.saveIfRevision` for the exact reviewed token | Server compares and writes atomically; A→B→A is rejected | IMPLEMENTED FOR GRID BACKEND PATH; exact-head tests required |
| W-05 Grid recovery | Uses the journal's original target revision in `saveIfRevision` | Server rejects a concurrent writer after the recovery read | IMPLEMENTED FOR GRID BACKEND PATH; exact-head tests required |
| F-01 imported Schedule facade/controller | Uses the backend repository when configured, but generic `save` still depends on the repository's shared revision cache | Not yet caller-bound for concurrent stale editor instances | OPEN |
| Local fallback | SharedPreferences two-slot repository | Crash-resilient staged write, no cross-instance CAS | OPEN — no global concurrency guarantee |

The backend repository's legacy `save()` method still uses a mutable revision cache keyed by Schedule ID. It is not a substitute for passing the revision captured by the editor/session that is being saved. A stale controller must never be allowed to adopt a newer cache token and overwrite a newer Schedule. Only the explicit `saveIfRevision(schedule, expectedRevision)` path is caller-bound.

## 10. 2026-11-26 — backend snapshot-bound CAS migration follow-up

This section supersedes the W-01 through F-01 backend-mode dispositions in section 9. It does not claim that the local SharedPreferences fallback is cross-device atomic.

| Writer | Updated behavior when `ORGANIZATION_API_BASE_URL` is configured | Current disposition |
|---|---|---|
| W-01 `ScheduleController.saveSchedule()` | Captures the revision attached to the exact loaded Schedule snapshot and calls `saveIfRevision`. After a successful save it adopts the new server revision. A controller without an observed snapshot/absent token fails closed. | IMPLEMENTED; exact-head tests pending. |
| W-02 `AppController._replaceLegacyShifts()` | Captures the previous canonical Schedule, reads the server target, compares the live payload with that exact base snapshot, then calls `saveIfRevision`. A remote change causes a visible persistence error rather than overwrite. The per-controller queue remains only an ordering aid. | IMPLEMENTED WITH CONFLICT GUARD; exact-head tests pending. |
| W-03 `AppController.adoptCanonicalSchedule()` | Uses the same base-snapshot compare plus server CAS as W-02. | IMPLEMENTED WITH CONFLICT GUARD; exact-head tests pending. |
| W-04 / W-05 Grid commit and recovery | Continue using the caller-owned revision captured by review/journal and `saveIfRevision`. | IMPLEMENTED FOR BACKEND PATH; exact-head tests pending. |
| F-01 `saveImportedSchedule()` | Backend mode is create-only against the explicit absent revision. Existing Schedule replacement must use the reviewed Grid workflow; no generic overwrite is permitted. | IMPLEMENTED CREATE-ONLY; exact-head tests pending. |
| S-01 Schedule delete | Backend repository refuses unconditional delete and reports that no data was deleted. | FAIL-CLOSED; conditional delete/tombstone is not implemented. |

### Repository and composition-root changes

- `BackendScheduleRepository` now binds revisions to the exact loaded Schedule object identity, not only a content fingerprint. A later A → B → A read cannot replace the original A editor's token with the newer generation. `save()` only accepts the exact snapshot instance that was previously read; unknown snapshots fail closed.
- The snapshot revision cache is bounded to 256 entries. Successful conditional writes bind the returned revision to the saved snapshot.
- `AppDependencies` now uses the configured BackendScheduleRepository as the single ScheduleRepository instance for production consumers when `ORGANIZATION_API_BASE_URL` is set; Grid import shares the same instance. With no backend origin, the existing SharedPreferences repository remains the local-development fallback.
- Empty roster resets during sign-out, account changes, source-sheet switching and local-source clearing are now local-only (`persist: false`). They no longer overwrite or clear the durable Schedule.
- `test/backend_schedule_repository_test.dart` now covers a stale editor after a second read, an unobserved snapshot failing closed, and backend delete making no request. `test/schedule_controller_revision_test.dart` covers two editors loaded at one revision: exactly one save can succeed.

### Snapshot identity and absent-state revision hardening

- ScheduleRevisionSource.revisionForSnapshot(schedule) resolves the revision attached to that exact object instance. The bounded identity-keyed cache deliberately retains separate revisions for equal-content snapshots, preventing ABA token substitution.
- revisionForAbsentSchedule(scheduleId) returns the absent-state token captured by the read that observed absence. It is not taken from the mutable latest-revision cache, so a concurrent read of a newly-created Schedule cannot authorize a stale create.
- W-02/W-03, Grid commit/recovery, Schedule editor create, and tabular import now use snapshot-bound or absent-state-bound revisions in backend mode.
- test/backend_schedule_repository_test.dart includes an A → B → A regression proving that an older A snapshot still submits its original revision and receives a server conflict.

### Remaining CAS boundaries

- Backend mode now fails closed for unbound or stale legacy snapshots. This prevents an unsafe write, but a caller that does not first load the canonical base may show a persistence error until its load/review path is migrated.
- The SharedPreferences fallback still has no cross-process/device CAS and must be described as local-only. It is not a production multi-device guarantee.
- Conditional Schedule delete now uses caller-owned revisions and durable tombstones in backend and local fallback. The local fallback remains same-process/isolate only; no cross-process guarantee is claimed.
- Generation-to-persistence approval flow and startup journal discovery/indexing remain separate open work packages.
- These changes are committed but are not certified until Flutter analyze/tests and the exact-head platform matrix pass. No merge or production migration is authorized.

### 10.1 Legacy writer conflict behavior and non-destructive resets

- W-02 and W-03 now compare the exact prior canonical Schedule snapshot with the live backend snapshot before submitting `saveIfRevision`. A mismatch is surfaced as a persistence error; a writer does not silently adopt a newer shared revision. `AppController` loads its stable `legacy-runtime` canonical Schedule after Google account initialization/authorization before subsequent edits.
- The AppController queue now reports a failed repository result and allows a later queued attempt to proceed after the previous failure. The queue remains local to one controller; server CAS is the actual cross-instance guard.
- Sign-out, account-change, source-sheet switch, saved-sheet removal and local-source clearing now call `_replaceLegacyShifts(..., persist: false)`. Clearing an in-memory view no longer persists an empty Schedule or deletes/overwrites backend data.
- F-01 is create-only in backend mode: it reads the target's absent revision and uses `saveIfRevision`; an existing Schedule must be replaced through the reviewed Grid workflow.
- W-01 editor saves carry the revision captured when the exact Schedule snapshot was loaded. Two editors using the same base revision cannot both commit.

**Boundary:** backend mode is safe-by-fail-closed for the inventoried writers, but not every legacy workflow is guaranteed to save until it has loaded/compared its exact base snapshot. Local-only SharedPreferences mode remains non-atomic across devices. Conditional deletion remains disabled.


## 10.2 — 2026-11-27 exact-head source and CI reconciliation

**Inspected implementation head:** `bde4107660ceaa6031b495ef7e8904f55f1d97b9`  
**Exact-head CI:** 14/14 observed workflows succeeded, including root Flutter quality, Windows, Linux, Web, Android, native macOS/iOS unsigned builds, and the Schedule CAS Storage Spike on Ubuntu, Windows and macOS.

The earlier PR conversation findings about shared revision-cache substitution and incomplete writer propagation were rechecked against the final source at this head. The subsequent implementation changes address the specific unsafe paths as follows:

| Path | Current source evidence | Remaining boundary |
|---|---|---|
| W-01 ScheduleController | Captures the exact loaded snapshot/absent revision and calls `saveIfRevision`; it does not refresh a stale editor's token from a later read. | The local fallback is same-process/isolate only. |
| W-02 AppController legacy writes | `_saveCanonicalSchedule(next, base)` reads the live canonical record, compares it with the controller's persisted base snapshot, obtains the revision attached to that exact base object (or an absent token), then calls `saveIfRevision`. The per-controller queue is only local ordering. | Legacy mutations that have no verified persisted base fail closed rather than silently adopting a newer token. |
| W-03 canonical adoption | `adoptCanonicalSchedule` uses the previous persisted snapshot as the base and routes through the same conditional writer. | No production multi-device claim without configured backend. |
| W-04/W-05 Grid commit/recovery | Review context obtains the repository's authoritative snapshot/absent revision; provenance carries it through commit and recovery; final writes use `saveIfRevision`. | Journal and canonical Schedule are separate durable requests; startup discovery/index remains open. |
| F-01 tabular import | Backend mode is create-only: reads absence and uses the exact absent-state token. Existing records require reviewed Grid replacement. | A generic unreviewed overwrite is intentionally rejected. |
| S-01 delete | `ConditionalScheduleDeleter.deleteIfRevision` is implemented for backend and local repositories; unconditional `delete` fails closed. | Conditional tombstone behavior is implemented; exact-head Flutter tests and cross-process/local durability acceptance remain pending. |

Composition-root inspection confirms that normal production AppController, ScheduleController, imported Schedule controller and Grid workflow use the same configured `scheduleRepository` instance. When `ORGANIZATION_API_BASE_URL` is empty, the production graph selects SharedPreferences; that fallback does not provide cross-device CAS. The PR workflow's production-backend gate was skipped, so this run does not prove a deployed backend is configured or reachable.

Relevant exact-head regression sources include:
- `test/backend_schedule_repository_test.dart`: stale snapshot after a later read, A→B→A token preservation, caller-supplied revision, unobserved snapshot fail-closed and delete fail-closed.
- `test/schedule_controller_revision_test.dart`: two editors sharing one base revision cannot both save.
- `test/app_controller_runtime_gate_test.dart`: sequential canonical writes retain the latest persisted local snapshot.
- `test/grid_roster_import_workflow_test.dart`: review/commit/recovery and stale-target conflict behavior.

**Disposition:** the previous three review findings are addressed in the current source for the inventoried backend-mode paths; do not describe this as globally production-accepted until the backend is deployed and tested with independent authenticated clients against the actual production database. Local SharedPreferences remains single-process/isolate only. Conditional delete, generation-to-persistence approval, startup journal discovery, and atomicity across journal + Schedule stores remain open. No production Schedule data was changed.

## 10.3 — 2026-11-27 conditional deletion and local snapshot-bound write follow-up

**Implementation source head before this documentation update:** `bc013553f5c0e9e118d5d6846126a81be350d24b` on the PR #192 branch. The backend Laravel CI job succeeded for this head; the full Flutter/platform matrix was still running when this section was written.

### Conditional delete contract

- Added `ConditionalScheduleDeleter.deleteIfRevision(scheduleId, expectedRevision)`. The expected revision must be the exact revision captured by the caller; an empty or stale token fails.
- Backend deletion writes a tombstone and stores `deleted_from_revision`. A retry using either the original source revision or the tombstone revision is idempotent.
- Deleting an absent identity creates a tombstone against the observed `absent:` token. A stale client using that absent token cannot later create/resurrect the Schedule.
- Local SharedPreferences deletion writes a versioned tombstone into the inactive slot, verifies it, advances the generation and switches the active pointer. It retains the original source revision for idempotent retries. A stale writer cannot recreate a deleted identity.
- Unconditional `ScheduleRepository.delete(id)` remains fail-closed in both production repositories; it never silently deletes data.
- Backend and local repository `save()` now require a revision attached to the exact loaded Schedule object. Unobserved or copied snapshots fail closed; production writers use explicit `saveIfRevision`.

### Source and test evidence

| Area | Source / test | Evidence |
|---|---|---|
| Domain capability | `lib/domain/repositories/conditional_schedule_deleter.dart` | Interface added |
| Backend repository | `lib/features/schedule/data/backend_schedule_repository.dart` | Sends caller-owned expected revision; records returned tombstone revision |
| Local repository | `lib/features/schedule/data/shared_preferences_schedule_repository.dart` | Snapshot-bound save; staged tombstone/read-back; idempotent retry |
| Backend API | `backend/app/Http/Controllers/Api/V1/ScheduleController.php` | Conditional live/absent delete, source-revision tombstone, retry handling |
| Backend schema | `backend/database/migrations/2026_11_25_000004_create_schedule_records_and_import_journals.php` | `deleted_from_revision` retained |
| Backend tests | `backend/tests/Feature/ScheduleApiTest.php` | Live delete, stale resurrection rejection, source-token retry, tombstone-token retry, absent delete and stale create rejection |
| Local tests | `test/schedule_repository_test.dart` | Snapshot-bound save, fail-closed unbound save, live/absent tombstone, idempotent retry and stale create rejection |
| Client tests | `test/backend_schedule_repository_test.dart` | Exact caller revision is sent on DELETE and tombstone revision is retained |

### Remaining persistence acceptance

- Exact-head Flutter tests and platform workflows must finish successfully before this implementation is accepted.
- The SharedPreferences fallback uses a per-repository-instance lock and two-slot recovery. It is not cross-process, cross-isolate or cross-device CAS. The configured backend is the authoritative cross-device CAS boundary.
- Backend multi-client concurrency still needs a controlled test against the actual production database engine; SQLite feature tests do not prove MySQL/PostgreSQL row-lock behavior.
- Journal discovery/indexing and PREPARED/COMMITTED recovery across the separate journal and Schedule stores remain open. The two writes are not one atomic transaction.
- Generation-to-persistence approval remains open.

**Disposition:** conditional delete/tombstone source implementation is present and backend tests passed on the implementation head. Do not mark Package B ACCEPTED until exact-head Flutter tests, independent backend-client concurrency, startup journal recovery and production database acceptance are complete.

