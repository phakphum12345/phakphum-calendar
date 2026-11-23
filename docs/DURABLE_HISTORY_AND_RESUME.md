# Durable History and Resume

Sprint 4 stores lightweight synchronization history and failed-operation payloads
through `SharedPreferencesAsync`, using separate versioned keys.

History stores timestamps, status and counts. Failed-operation storage contains only
technical Calendar commands needed for retry. Patient data, OAuth tokens and complete
roster contents must never be stored here.

`ResumeSyncService` retries failed operations and updates the original history entry.
`CalendarSyncCoordinator` joins managed-event lookup, plan building and execution.

Insert retries and resume now reconcile the deterministic managed-event Sync ID
before another insert. A single matching provider event is adopted; duplicate
matches or a failed verification lookup remain failed rather than risking a
second event.

Remaining follow-up: cross-device concurrent-sync coordination, authorization
refresh behavior, and durable cross-device history are separate concerns.
