# Synchronization Reliability

## Sync ID

SCE creates a deterministic Sync ID from:

- Spreadsheet ID
- Sheet ID
- A1 cell coordinate
- Shift date
- Shift category
- Shift period

The canonical value is hashed with SHA-256 and stored as a private Calendar
extended property.

## Concrete sync plan

`CalendarSyncPlanBuilder` combines:

- Calendar diff candidates
- Existing SCE-managed Calendar events

It then creates concrete operations:

- Insert command
- Update operation with Google event ID
- Delete operation with Google event ID

## Retry behavior

The resilient executor retries each operation independently.

Default:

```text
2 attempts per operation
```

New managed inserts use a deterministic Google Calendar event ID derived
from the stable `sceSyncId`. If an insert conflicts or returns an ambiguous
error, the gateway reads that event ID and verifies the stored `sceSyncId`
before treating the write as successful.

For older events that use server-assigned IDs, the executor also looks up
managed events in the target interval and reconciles by `sceSyncId` before
another insert attempt. Exactly one match is adopted and its provider event ID
is retained. Multiple matches or a failed verification lookup remain failed;
the executor does not blindly issue another insert when the provider outcome
is unknown.

Resume performs the same lookup before inserting and again after an ambiguous
insert failure. Deterministic provider IDs make concurrent inserts for the same
sync identity duplicate-resistant, but Google documents that globally
distributed ID collisions are not guaranteed to be detected at creation time.
Concurrent update/delete coordination across independent clients remains a
separate concern.

## Partial success

Synchronization continues after an individual operation fails.
The final status is:

- Success
- Partial success
- Failure

Each operation result retains its type, reference ID, and error message.

## History

A history entry records:

- start and finish timestamps;
- inserted count;
- updated count;
- deleted count;
- failed count;
- final status.

The production dependency setup uses `SharedPreferencesSyncHistoryRepository`
to persist sync history locally on the device. This is not server-side storage
or cross-device synchronization.

## Safety

Insert retries and resume re-check existing managed events by deterministic Sync
ID before another insert. If verification fails or finds duplicate IDs, the
operation remains failed for review rather than risking another provider write.
This does not serialize simultaneous syncs from independent devices.

## Current backend coordination checkpoint — 2026-11-27

PR #196 extends the legacy deterministic Sync ID/reconciliation layer with authenticated backend coordination. Its current recorded head is `8e186790e447f9278eda8612a1bb1b6f7e7b77c9`; 13/13 exact-head workflows passed. The PR remains Draft and unreviewed.

- Lease scope: authenticated Google owner + Calendar ID; it does not serialize different Google accounts that share a Calendar.
- Durable run records and per-operation ledger include stable operation keys, canonical payload hashes, attempt counts and guarded state transitions.
- Replay payloads are encrypted with Laravel `APP_KEY` and exposed only through owner-scoped reads.
- The production executor and explicit recovery service use the coordination API when `ORGANIZATION_API_BASE_URL` is configured.
- History recovery follows the exact server Run ID, obtains a new lease and replays only unfinished operations. Opening History does not replay.
- Update/delete operations enforce provider ETag and managed Sync ID; ambiguous inserts reconcile by stable Sync ID.
- A failed server history request remains an error; it is not treated as an empty ledger.

**Still unaccepted:** deployed HTTPS backend reachability, production database lock/unique-constraint behavior under contention, APP_KEY backup/restore, controlled Google test-calendar multi-device contention, lease expiry/reclaim, ambiguous provider outcomes, ETag conflicts and explicit recovery. No production Calendar write, migration or deployment is claimed.

