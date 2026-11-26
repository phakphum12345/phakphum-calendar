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
Calendar update/delete plans now carry the provider ETag and the provider-side
managed Sync ID observed during preview. The Google gateway re-reads the exact
event, verifies its identity, and sends the mutation with `If-Match`. A stale
ETag or changed managed identity fails closed. An ambiguous update is reconciled
by reading the event and comparing its managed identity and desired content; an
ambiguous delete is reconciled by checking whether the event still exists.

This protects individual provider mutations from stale concurrent writes; it
does not serialize whole sync runs or provide a shared cross-device operation
ledger. Sync history and failed-operation records remain local SharedPreferences
storage in the current production dependency graph.

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
