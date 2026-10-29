# App-wide UX and navigation redesign

## Goal

Modernize the whole app structure, not just colors or individual screens. Preserve existing workflows, data contracts, Personal Edition and Organization Edition capabilities while making the app easier to learn on phones, tablets, and desktop.

## Findings from the current shell

- The shell already uses Material 3 and adapts between a bottom navigation bar and a navigation rail.
- Navigation destinations are built from the same list for both layouts. In Organization Edition, the destination count grows, which makes mobile navigation crowded.
- A pinned-tools strip, app bar actions, and page navigation all compete for the same top-level attention.
- Dashboard, roster preview, monthly roster, reports, employees, shift exchange, admin, and settings need clearer grouping and task hierarchy.
- AI Support should be discoverable but should not compete with the primary roster/calendar workflow.

## Proposed information architecture

### Primary navigation

1. **ภาพรวม (Dashboard)** — current period, roster/import status, pending review, last sync, and next recommended action.
2. **ปฏิทินเวร (Calendar)** — day/week/month views, shift details, and timeline history.
3. **นำเข้าและตรวจสอบ (Import & Review)** — Google Sheets, Excel/CSV, image/OCR entry points; preview, parser warnings, duplicate/missing-shift review, and explicit confirmation before applying changes.
4. **รายงาน (Reports)** — monthly report and export actions.

### Workspace / More

Group less-frequent and edition-specific destinations into a workspace menu rather than forcing every destination into mobile navigation:
- Staff directory and roster names
- Shift exchange (Organization Edition)
- Shift templates and local defaults
- Notifications and audit/timeline history
- Tools and pinned tools management
- Admin (Organization Edition only)
- Settings, language, and edition selection

### AI Support

- Reachable from the dashboard and workspace menu.
- Chat can explain workflows and help triage ambiguous roster entries.
- AI proposals must be shown as reviewable changes with source context.
- No roster mutation or calendar sync without explicit user confirmation.
- Display clearly when no live AI provider is configured; do not imply a real AI service is connected.

## Visual and interaction principles

- Keep Material 3, strengthen hierarchy through spacing, typography, and consistent section headers rather than decorative gradients.
- Use a clear page title and one primary action per screen.
- Use compact status chips for sync state, parsing warnings, and unsaved review.
- Use responsive layouts: bottom navigation with a small number of primary destinations on phones; navigation rail and wider content constraints on tablets/desktops.
- Avoid placing many unrelated actions in the app bar. Move secondary actions into contextual menus.
- Preserve accessible labels, keyboard navigation, responsive text, and both Thai and English localization.
- Empty, loading, error, offline, and permission states must be designed explicitly.

## Implementation sequence

1. **Baseline and safety**: inventory current destinations and tests; establish navigation behavior and preserve existing actions.
2. **Navigation shell**: separate primary destinations from workspace destinations; add stable route/index mapping and mobile overflow coverage.
3. **Dashboard hierarchy**: prioritize current roster, import/review warnings, sync status, and next actions.
4. **Calendar and review flow**: clarify source selection, preview, discrepancy resolution, and confirmation.
5. **Workspace/settings**: group configuration and Organization-only tools without removing features.
6. **AI Support integration**: expose chat as a helper and later connect the provider-neutral analyzer only after safe provider configuration and tests.
7. **Verification**: run Flutter format/analyze/tests and CI across web, Android, iOS, Windows, and Linux; compare existing workflow coverage before merge.

## Acceptance criteria

- No existing feature becomes inaccessible in either edition.
- Mobile navigation does not overflow or hide labels unpredictably as Organization Edition destinations are added.
- Desktop and mobile navigation select the same logical destination.
- Import and sync actions remain explicit and retain their existing safeguards.
- AI Support never silently edits or syncs schedules.
- Existing tests pass, new navigation/widget tests cover both editions and responsive breakpoints, and all required CI checks are green before merge.
