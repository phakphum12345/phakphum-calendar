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

A short incremental delay is applied between attempts.

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
