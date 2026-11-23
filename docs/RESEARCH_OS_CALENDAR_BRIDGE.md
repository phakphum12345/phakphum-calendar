# Research OS ↔ Shift Tools Calendar Bridge

This contract connects Research OS Friend to the existing Shift Tools calendar
sync engine without moving Google OAuth credentials into Research OS.

## Boundary

```text
Research OS Friend
      │ loopback HTTP
      ▼
Shift Tools Research OS Bridge
      │ in-process
      ▼
CalendarSyncCoordinator
      │ bounded provider requests
      ▼
Google Calendar
```

Google OAuth credentials remain owned by Shift Tools. Research OS only sends a
sync command and receives a job identifier/result metadata.

## Endpoints

The bridge is intentionally loopback-only:

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/v1/research-os/health` | Bridge/provider reachability |
| POST | `/v1/research-os/sync` | Execute one guarded synchronization request |

The sync endpoint should return a JSON object such as:

```json
{
  "status": "completed",
  "sync_id": "...",
  "created": 3,
  "updated": 1,
  "deleted": 0,
  "failed": 0
}
```

For a long operation, the bridge must execute it asynchronously and expose
progress through the Research OS bridge layer rather than keeping the Friend
request open.

## Security requirements

- Bind the bridge to `127.0.0.1` only.
- Never accept Google OAuth access/refresh tokens from Research OS.
- Never log roster contents or credentials.
- Require an explicit sync command; no implicit calendar writes from chat.
- Preserve the existing preview/confirmation semantics for schedule writes.
- Keep provider requests bounded by the calendar gateway timeout and existing
  retry policy.

## Reliability goal

The bridge exists specifically to remove the dependency on the Friend HTTP
request lifetime. A Google Calendar request that stalls must become a bounded
failure/retry in the calendar engine, while Research OS observes the job state
instead of receiving a 5-second `TimeoutException`.
