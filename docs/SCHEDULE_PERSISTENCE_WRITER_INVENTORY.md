# Schedule Persistence Writer Inventory

**Review date:** 2026-11-24  
**Inspected branch:** `docs/universal-roster-intelligence-masterplan-2026-11-24`  
**Inspected head:** `229f896f2d9594e0b536fdb855d8d1fa619f5cb3`  
**Evidence type:** static source and test-source inspection; no Dart/Flutter test execution is claimed.  
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
| Production conditional CAS | FAIL | No conditional repository capability or storage atomicity exists in the inspected contract/implementation. |
| Global writer migration to CAS | FAIL | Current writers still call ordinary `save`. |
| Production Schedule delete caller | UNKNOWN | No caller found in inspected production paths; broader indirect call graph not exhaustively proven. |
| Generation-to-persistence path | UNKNOWN | No production approval/save orchestration established in this audit. |
| Startup journal discovery/index | FAIL | No index/enumeration/startup recovery path established. |
| Runtime tests on exact head | SKIPPED | Not executed in this audit. |

## 9. Relationship to the persistence ADR

This inventory is the first input to [ADR: Conditional Schedule Persistence and Journal Discovery](adr/CONDITIONAL_SCHEDULE_PERSISTENCE_AND_JOURNAL_DISCOVERY.md). The ADR remains **Proposed**. This document does not accept a database choice, introduce a fake CAS implementation, change Schedule schema v1, or authorize production migration.
