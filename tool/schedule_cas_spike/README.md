# Schedule CAS Storage Spike

**Status:** Prototype source only — not production-ready and not yet executed.

This package is deliberately isolated under `tool/`. It is not imported by the Flutter application and does not change the root `pubspec.yaml`, root lockfile, production repository, Schedule schema v1 or existing SharedPreferences records.

## Goal

Test whether Drift over SQLite can provide an atomic conditional Schedule write with a monotonically increasing generation and tombstones.

The prototype uses one SQLite UPSERT statement for create/update. Its conflict branch compares the stored generation, state and fingerprint before replacing the row. SQLite's primary-key conflict arbitration handles concurrent first-time creates. Conditional delete is one UPDATE statement that writes a tombstone rather than removing the row.

The revision token is opaque to callers. The fingerprint is SHA-256 of the canonical payload supplied to the spike. This package does not yet integrate `ScheduleJsonCodec`; production canonical serialization remains a later adapter task.

## Run locally

From this directory:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart test
```

The native test opens two independent Drift database instances, each hosted by its own executor isolate, against one temporary SQLite file. It checks stale writes, same-content generation advancement, ABA protection, tombstones and the two-writer outcome.

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

A single passing native test is necessary but not sufficient to accept Drift for production.
