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

## Current historical revision restore checkpoint — 2026-11-27

PR #204 adds a user-facing revision list in the History utility and routes a selected read-only Drive revision through the shared Grid review and conditional Schedule commit workflow.

- Source fingerprint binds revision ID, modified timestamp, worksheet metadata, rows and background colors.
- The exact `sourceRevisionId` is retained in the versioned import provenance envelope.
- The selected revision is parsed, reviewed and corrected using the existing Grid review path; the target Schedule is written only through the revision-bound conditional commit/journal workflow.
- The Drive source remains read-only; no Drive write scope or remote source mutation is added.
- PR #204 current head: `ba73d30f4e332105c05c95d00f61517da1cd9689`; exact-head CI is pending and the PR remains Draft/unreviewed.

**Still open:** assignment-level before/after diff (current preview includes counts and review rows), original Drive revision export fixture, non-owner account acceptance, and post-commit read-back/recovery under a real backend. This workflow does not restore or mutate the original Drive file.

