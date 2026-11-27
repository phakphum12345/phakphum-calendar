# Integration Status

## Current integration checkpoint — 2026-11-27

The Sprint 6 foundations listed below remain part of the repository, but they do not mean all advertised product workflows are complete. Current end-to-end extensions are still in Draft PRs:

- #192: universal roster import/orientation, CSV/TSV/TXT, source provenance and CAS/recovery.
- #196: durable Calendar Sync coordination and provider outcome recovery.
- #191: actual Web Push sender/outbox worker path.
- #202: generation preview/approval/conditional commit.
- #201/#203: Shift Pay rule conflict resolution and monthly statement calculation core.
- #204: historical Drive revision restore through Grid review and conditional Schedule commit.

All seven PRs are Draft and have no submitted reviews. Exact-head CI, live external acceptance and post-merge verification are separate gates. See [Implementation Status](../IMPLEMENTATION_STATUS.md) and [Requirements Traceability](../REQUIREMENTS_TRACEABILITY.md).

## Included

Sprint 6 production architecture has been merged into the existing `phakphum_calendar` Flutter application without replacing its working entry point.

- `lib/core/`
- `lib/features/authentication/`
- `lib/features/google_drive/`
- `lib/features/google_sheets/`
- `lib/features/shift_parser/`
- `lib/features/relationship_engine/`
- `lib/features/diff_engine/`
- `lib/features/simulation/`
- `lib/features/calendar_engine/`
- `lib/features/history/`
- `lib/features/workflow/`
- Sprint 6 unit tests under `test/sce_*`
- Architecture documentation and ADRs
- AI workspace under `.ai/`

## Active application

The current `lib/main.dart`, `lib/app.dart`, `lib/controller/app_controller.dart`, and existing UI remain active. This avoids breaking the Google authentication, roster screen, and Google Sheets picker already present in the application.

## Current Calendar workflow integration

The active app shell compares the Calendar, prepares a
`ShiftCalendarWorkflowController`, shows the confirmation dialog, and only
then calls `AppController.syncCalendar(userConfirmed: true)`. The controller
rejects execution without an explicitly prepared workflow and confirmation.
The adapter keeps the legacy `Shift` model separate from the workflow domain
model. Further workflow capabilities and feature migrations remain tracked in
the relevant roadmaps; this integration does not mean every Sprint 6 feature
is complete.
