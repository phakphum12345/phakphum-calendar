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

When an insert fails after submission, the executor looks up managed events in
the target interval and reconciles by the deterministic `sceSyncId` before
another insert attempt. Exactly one match is treated as success and its provider
event ID is retained. Multiple matches or a failed verification lookup remain
failed; the executor does not blindly issue another insert when the provider
outcome is unknown.

Resume performs the same lookup before inserting and again after an ambiguous
insert failure. This protects retry and resume from duplicate creation when the
provider accepted a write but the client lost the response. It is not a
distributed lock for simultaneous independent clients; cross-device concurrent
sync coordination remains a separate concern.

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

Retry is appropriate because inserts use deterministic Sync IDs, but production
code must re-check for existing managed events before retrying ambiguous network
failures to avoid duplicate events.
