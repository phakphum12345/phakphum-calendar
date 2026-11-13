# Integration Status

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
