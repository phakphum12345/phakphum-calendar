# Schedule CAS Storage Spike

**Status:** Prototype source only — native CI contract validation passed on 2026-11-25; not production-ready.

This package is deliberately isolated under `tool/`. It is not imported by the Flutter application and does not change the root `pubspec.yaml`, root lockfile, production repository, Schedule schema v1 or existing SharedPreferences records.

## Goal

Test whether Drift over SQLite can provide an atomic conditional Schedule write with a monotonically increasing generation and tombstones.

The prototype uses one SQLite UPSERT statement for create/update. Its conflict branch compares the stored generation, state and fingerprint before replacing the row. SQLite's primary-key conflict arbitration handles concurrent first-time creates. Conditional delete is one UPDATE statement that writes a tombstone rather than removing the row.

The revision token is opaque to callers. The fingerprint is SHA-256 of the canonical payload supplied to the spike. This package does not yet integrate `ScheduleJsonCodec`; production canonical serialization remains a later adapter task.

## Validation evidence

GitHub Actions workflow: [Schedule CAS Storage Spike](https://github.com/phakphum12345/phakphum-calendar/actions/runs/45568406234)

- Run: `45568406234`
- Validated head: `152db1c372c227704872dc9e676e9eca12d58044`
- Result: **PASS** on `macos-latest`, `windows-latest`, and `ubuntu-latest`.
- All jobs completed dependency resolution, Drift code generation, canonical formatting check, static analysis, and CAS/concurrency contract tests.
- The contract includes Schedule-ID-scoped revision tokens and rejects cross-Schedule token reuse for writes and deletes.

This is evidence for the isolated native prototype only. It is not evidence that the production Flutter app uses CAS, that the full root test suite passed on this head, or that Web/mobile/browser durability and concurrency have been proven.

## Run locally

From this directory:

```sh
flutter pub get
dart run build_runner build
flutter test
```

The native test opens two independent Drift database instances, each hosted by its own executor isolate, against one temporary SQLite file. It checks stale writes, same-content generation advancement, ABA protection, tombstones, stale-token resurrection, two-writer outcomes and close/reopen durability.

## Web adapter

`SpikeDatabase.forApplication()` uses `drift_flutter` with explicit WASM and worker URIs. A Web build must supply matching `sqlite3.wasm` and `drift_worker.dart.js` assets from the same Drift release. They are intentionally not copied into the production `web/` directory by this spike.

Web multi-tab behavior is not proven by the native test. It requires a separate browser test against the configured worker/storage mode, including reload, restart, quota and supported browser fallback.

## Explicitly out of scope

- No production dependency or DI wiring.
- No migration of SharedPreferences data.
- No production writer changes.
- No claim of atomicity across different devices or cloud synchronization.
- No startup journal index or automatic replay.
- No production CAS capability declaration until platform evidence passes.

## Required evidence before accepting the ADR

Run the contract on Windows, Web, Android, iOS and Linux. Record exact SDK, package lock, OS/browser and test output. For native platforms, use two independent connections to the same durable file. For Web, use two browser tabs and the actual shared-worker storage mode. Simulate process termination around commit boundaries and verify old-or-new complete records.

A passing native test is necessary but not sufficient to accept Drift for production. After platform validation, integrate through a compatibility-preserving repository capability, migrate every durable Schedule writer, and prove startup journal discovery/recovery before enabling production use.
