# ADR-0012: Timeline persistence, migration, and Drive backup

- Status: Proposed; implementation and migration gates required
- Date: 2026-10-31

## Context and verified current state

The application already has several distinct storage mechanisms. They must not be
collapsed or replaced without a migration plan.

1. Canonical schedules use `SharedPreferencesScheduleRepository` with schema
   versioned keys and two alternating payload slots. This is the current local
   schedule store and must remain readable during any migration.
2. Employee and shift-template repositories also use SharedPreferences-backed
   implementations.
3. Sync history uses `SharedPreferencesSyncHistoryRepository`, bounded to 100
   entries by default. Failed operations use a separate
   `SharedPreferencesFailedSyncRepository`.
4. `TimelineArchiveService` stores complete roster revision snapshots and
   resumable checkpoints in SharedPreferences keys scoped by a SHA-256 digest
   of account ID and source file ID. It writes the revision before advancing
   the index, but uses the legacy synchronous SharedPreferences API.
5. `RosterRevisionService` lists and downloads Google Drive revisions. Its
   normal read path has a process-memory cache only; its transient path avoids
   retaining that cache. Neither path is a Drive backup writer.
6. `DriveArchiveService` creates idempotent monthly copies of the original
   roster file in ordinary Google Drive storage. It does not back up the local
   Timeline archive or provide restore.
7. `GoogleScopes.driveAppData` is declared, but it is not included in the
   current `GoogleAuthService.readAccessScopes` or
   `GoogleScopes.required`. The current app therefore must not assume that
   appData access has been consented to.

The existing local Timeline archive is real persistence, not just a memory
cache. However, SharedPreferences is a lightweight key-value store, not a
suitable long-term database for arbitrarily large roster snapshots. The
current code also has separate storage conventions and no end-to-end
cross-device Timeline backup/restore workflow.

## Decision principles

- Preserve every existing key, schedule payload, archive record, checkpoint,
  sync history entry, employee, template, and source Google file during rollout.
- Never clear or overwrite the legacy stores as part of authentication sign-out.
- Keep authentication/session credentials separate from roster and Timeline
  data. Sign-out may clear credentials and in-memory account state, but must
  not delete local Timeline data.
- Scope local and cloud data by stable Google account subject/ID and source
  file ID. Do not use email as the only durable identity key.
- Keep original Google Sheets/Drive files as source records; local and cloud
  archives are derived copies and must never silently write back to originals.
- Use an explicit, versioned manifest for every cloud backup, including account
  scope, source file ID, schema version, creation time, revision/checkpoint
  metadata, and integrity digest. Do not include OAuth tokens or secrets.
- Make backup and restore idempotent. Verify downloaded payloads and hashes
  before activating restored data. A failed or partial restore must leave the
  currently active local data unchanged.
- Do not assume Drive revision IDs alone provide a complete incremental
  change feed. Reconcile provider revisions and application checkpoints; detect
  gaps and perform a controlled rescan when necessary.
- Treat deletion as a synchronized tombstone only when the source confirms it;
  never infer deletion from an incomplete or failed listing.
- Request the narrowest required Drive scope only when the user enables cloud
  backup. The appData scope is a candidate for private app-owned backups; user
  visible archive copies remain a separate feature.

## Target storage boundaries

| Data | Current store | Intended responsibility |
| --- | --- | --- |
| Canonical schedules | SharedPreferences, dual slots | Preserve compatibility; migrate through a verified repository adapter if/when a database is adopted |
| Employees and shift templates | SharedPreferences repositories | Keep their existing ownership and migrate independently |
| Bounded sync history | SharedPreferencesAsync repository | Keep bounded operational history |
| Failed sync operations | SharedPreferencesAsync repository | Keep resumable operation payloads subject to privacy review |
| Timeline snapshots and checkpoints | TimelineArchiveService / SharedPreferences | Migrate to a database-backed Timeline repository after package/platform verification |
| Cloud Timeline backup | Not implemented | Add a versioned, idempotent backup/restore service behind a gateway |
| Monthly original-file archive | Google Drive copies | Keep as a separate source-file archival feature |
| OAuth session and credentials | Platform OAuth adapter | Keep separate from all roster and Timeline stores |

## Safe migration sequence

1. Inventory and measure existing keys, records, payload sizes, account/file scopes,
   and all readers/writers. Add read-only diagnostics; do not mutate data.
2. Choose and verify a Flutter database package for Web, Android, iOS, Windows,
   macOS, and Linux targets actually supported by the product. Define schema,
   indexes, transaction behavior, encryption/privacy requirements, and web
   persistence behavior before adding a dependency.
3. Implement a repository adapter that can read the legacy archive and write to
   the new store without changing current readers.
4. Copy legacy records in bounded batches. Verify record counts, revision IDs,
   timestamps, row/cell counts, and content digests. Keep the legacy copy intact.
5. Enable dual-read/verified-write or a guarded cutover only after parity tests
   pass. Retain rollback capability; never delete legacy keys during rollout.
6. Add Drive backup with explicit user consent and least-privilege scope. Upload
   immutable versioned backup objects and update a manifest only after upload
   verification.
7. Add restore to a staging namespace. Verify identity, schema, and digest, then
   activate atomically. Never merge a restored archive blindly over newer local
   data.
8. Add incremental sync using persisted revision/checkpoint metadata. On gaps,
   expired revision access, changed source identity, or invalid checkpoint,
   request a controlled rescan and preserve all already archived history.
9. Test sign-out, account switching, reinstall, device migration, interrupted
   upload/download, duplicate retries, quota/throttling, and partial corruption.

## Required acceptance tests

- Existing SharedPreferences schedule and Timeline records remain readable.
- Migration is repeatable and does not create duplicate revisions.
- A failed migration or restore leaves the previous active data unchanged.
- Restarting the app preserves local Timeline records and checkpoints.
- Signing out does not delete Timeline, schedule, or backup records.
- Switching accounts never exposes another account's Timeline.
- A second sync with no source changes performs no full historical export.
- A changed source revision fetches only the required new revision(s).
- Missing revision/checkpoint continuity triggers a safe rescan, not silent loss.
- Cloud backup and restore verify manifest and payload integrity.
- No access/refresh tokens, authorization codes, or client secrets enter backup,
  logs, SharedPreferences, or database records.
- All supported platform builds and repository tests pass before rollout.

## Explicit non-goals

- Do not replace or delete the current schedule store as part of the auth work.
- Do not conflate monthly source-file copies with Timeline backup.
- Do not silently enable Drive backup or request broader Drive permissions.
- Do not promise zero full scans until provider revision continuity and recovery
  behavior have been verified with real Google accounts.
