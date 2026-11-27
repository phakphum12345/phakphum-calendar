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

## Historical roster restore — PR #204

The new history restore workflow reads an existing Google Drive revision export and routes its snapshots through the same Grid review, provenance journal and conditional Schedule commit path used by live roster imports.

- The source fingerprint binds the Drive revision ID, modified timestamp, worksheet metadata, rows and cell colors.
- The restore path is read-only with respect to Drive and Google Sheets; it does not require or request Drive write scopes.
- The caller must select the target Schedule, provide the employee/template directory, review assignments and supply explicit decisions.
- The final Schedule write uses the existing revision-bound CAS workflow and journal recovery behavior.
- A stale target revision is rejected by the underlying Grid import workflow; no silent overwrite is allowed.

Acceptance remains open:
- The History utility now lists archived revisions and launches the existing Grid review/confirmation workflow for the selected revision.
- The review page shows the current target Schedule assignment count and the selected revision's parsed assignment count before commit.
- The exact Drive revision ID is retained in the versioned import provenance envelope.
- A per-assignment before/after diff is still not available; the current preview is count-based and assignment-level review.
- Real Drive revision export fixtures and a non-owner account acceptance run are not available in this execution.
- The historical revision snapshot is locally read-only; this feature does not restore or mutate the original Drive file.
