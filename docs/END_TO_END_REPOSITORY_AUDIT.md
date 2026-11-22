# End-to-End Repository Audit

**Repository:** `phakphum12345/phakphum-calendar`  
**Audit date:** 2026-11-22  
**Audited main SHA:** `168559498de58a071ac43a81e410227f0f83ec4b`  
**Default branch:** `main`  
**Audit mode:** Read-only baseline plus explicitly recorded integration work

## Executive summary

The repository is an established Flutter application with a Laravel API, Google Workspace integration, calendar synchronization, schedule management, organization administration, reports, and a broad CI/build matrix. It is not yet certified complete or production-ready.

The current main commit includes the successful merge of PR #161. Its GitHub Pages deployment and the post-deployment exact-SHA HTTP smoke test both completed successfully for `168559498de58a071ac43a81e410227f0f83ec4b`. The remaining platform workflows for that same SHA were still queued or in progress at the audit checkpoint, so the complete main CI matrix remains IN_PROGRESS.

The original yearly-view PR #163 is based on a stacked branch and is conflict-blocked. Its week-boundary changes are already present in main from PR #162. A replacement PR #165 was created from current main and contains only the five year-overview-specific files.

## Repository inventory

| Item | Observed evidence | Status |
|---|---|---|
| Repository visibility | Public GitHub repository | PASS |
| Default branch | `main` | PASS |
| Main SHA | `168559498de58a071ac43a81e410227f0f83ec4b` | PASS |
| Repository tree | 1,202 entries; 901 blobs; recursive tree response not truncated | PASS |
| Flutter/Dart test files | 158 files matching `test/**/*_test.dart` | PASS (inventory only) |
| GitHub Actions workflow YAML | 18 files under `.github/workflows/` | PASS (inventory only) |
| Markdown files | 125 files | PASS (inventory only) |
| Feature directories | 32 under `lib/features/` | PASS (inventory only) |
| Backend | Laravel 13.8; PHP constraint `^8.4.1` | PASS (configuration inspected) |
| Flutter SDK constraint | Dart SDK `^3.12.2` in `pubspec.yaml` | PASS (configuration inspected) |
| Open issues | 0 at audit time | PASS |
| Branch protection | GitHub endpoint returned HTTP 403 | UNKNOWN |
| Repository rulesets | Empty list returned | UNKNOWN |
| Local working tree | Not available through this GitHub audit | UNKNOWN |

## Pull request and integration state

| PR | State | Evidence / action | Status |
|---|---|---|---|
| #161 | Merged | Merge commit `168559498de58a071ac43a81e410227f0f83ec4b`; exact-SHA Pages deployment and published metadata smoke test succeeded | PASS |
| #162 | Merged | Merge commit `52d18f53872c35c1b7076c81e4ecb996c36fd17a`; week-boundary implementation is present in main | PASS |
| #164 | Merged | Merge commit `b0a42a291f048f790df430f0d12d7c7d88f07710`; organization member role and soft-removal workflows included | PASS |
| #165 | Open | Replacement year-overview PR created from current main; head `912b1537c4a3286a3c02b5fe1b0907143581e17d`; CI was queued/in progress | IN_PROGRESS |
| #163 | Open, superseded | Original stacked PR; mergeability false. Week-boundary file and weekly page were verified identical to main and were excluded from replacement PR | BLOCKED |
| #160 | Open, stale | Documentation refresh branch is based on old main SHA and contains stale statements about PR #162/#164 and deployment | BLOCKED |

PR #165 contains exactly these five files:
- `lib/features/schedule/presentation/pages/schedule_workspace_page.dart`
- `lib/features/schedule/presentation/widgets/schedule_view_scaffold.dart`
- `lib/features/schedule/presentation/widgets/schedule_view_selector.dart`
- `lib/features/schedule/presentation/widgets/schedule_year_overview.dart`
- `test/schedule_year_overview_test.dart`

The current-main versions of `weekly_schedule_page.dart` and `test/schedule_week_boundary_test.dart` were byte-for-byte identical to the original #163 branch versions and were not overwritten.

## CI and deployment evidence

### Current main SHA

For `168559498de58a071ac43a81e410227f0f83ec4b`, eight main-push workflow runs were observed:
- Build Linux — SUCCESS
- Build and Deploy Web — SUCCESS
- Build iOS — QUEUED at checkpoint
- Build Android — IN_PROGRESS at checkpoint
- Build Windows — IN_PROGRESS at checkpoint
- Cross-platform Runtime — IN_PROGRESS at checkpoint
- Auto Detect CI — IN_PROGRESS at checkpoint
- Final Gate — IN_PROGRESS at checkpoint

The Web workflow's nested jobs:
- Build Flutter web — SUCCESS
- Deploy GitHub Pages — SUCCESS
- Verify published site and deployed commit — SUCCESS

The deployment job receives `github.sha` as its expected SHA and the verification step succeeds only when the published `deployment.json` contains that exact commit SHA. This proves the deployment verification step succeeded for the audited main SHA; it does not certify future deployments.

### PR #165

Ten workflow runs were created for exact head SHA `912b1537c4a3286a3c02b5fe1b0907143581e17d`. At the checkpoint, nine were queued and one (Linux build) was in progress. No PR #165 check is counted as PASS until it completes.

### Historical main SHA

The previous main SHA `b0a42a291f048f790df430f0d12d7c7d88f07710` had ten workflow runs conclude SUCCESS, but its nested Pages deployment job was SKIPPED. That historical skipped deployment is not counted as a pass. PR #161 corrected this behavior for the new merge commit.

## Source-level observations

### Frontend

- Flutter application with 32 feature directories.
- Main shell and controller are documented as large files and require a measured, incremental modularization review.
- Daily, weekly and monthly schedule views exist; cross-month week behavior is merged.
- Year overview is under PR #165 and awaits exact-head CI.
- Existing test inventory is broad, but file count does not prove end-to-end requirement coverage.
- Responsive behavior needs a dedicated compact-width, tablet and desktop audit.

### Backend and API

- Laravel backend is under `backend/`.
- API routes include health and readiness endpoints, client diagnostics, Google-account identity, organization/member/join-request/shift-policy endpoints, and shift-transaction lifecycle endpoints.
- Authenticated API routes use the Google-account middleware and throttling.
- Organization member role changes and soft removal are merged; owner membership is protected and membership rows are retained.
- Database migration safety, backup/restore behavior and organization-isolation tests need continued review.

### Integrations and data

- Flutter dependencies include Google Sign-In, Google APIs, HTTP, Excel parsing, PDF/printing and file handling.
- Source-level presence of a Google integration does not prove a live OAuth/Drive/Sheets/Calendar workflow.
- Live integration verification requires an authorized test account and explicit consent; no production data should be changed during tests.
- Historical roster restore to Google Drive requires write scopes. The current documented read-only scope must not be expanded without explicit approval.
- Notification scheduling is not established by the existence of a notification interface or in-app alerts.

## Remaining work inventory

| ID | Area | Missing or unverified work | Priority | Status |
|---|---|---|---|---|
| AUD-01 | CI | Complete exact-SHA main CI matrix for `168559498de58a071ac43a81e410227f0f83ec4b` and verify Final Gate result | P0 | IN_PROGRESS |
| AUD-02 | Schedule | Complete PR #165 CI; verify year navigation, 12-month rendering, counts and month selection | P1 | IN_PROGRESS |
| AUD-03 | PR hygiene | Close/supersede original #163 only after #165 is validated; refresh or replace stale #160 docs | P1 | BLOCKED |
| AUD-04 | History | Define restore semantics, preview/confirmation and safe Drive write-scope approval | P1 | NOT_IMPLEMENTED |
| AUD-05 | Notifications | Decide supported platforms and background-delivery requirement; implement scheduling/cancellation if required | P1 | PARTIAL |
| AUD-06 | UX | Run compact-width, tablet and desktop screen-by-screen audit with widget tests | P1 | NEEDS REVIEW |
| AUD-07 | Architecture | Incrementally reduce oversized app shell/controller with behavior-preserving tests | P2 | NEEDS REVIEW |
| AUD-08 | Performance | Establish large-workbook, large-event-set, sync-history and memory baselines | P2 | UNKNOWN |
| AUD-09 | Security | Complete targeted authorization, tenant-isolation, token-storage, local-data and dependency review | P1 | UNKNOWN |
| AUD-10 | E2E | Map critical user journeys to end-to-end tests and test failure/recovery paths | P1 | PARTIAL |
| AUD-11 | Operations | Verify production Google integration and user-facing deployment behavior without modifying user data | P1 | UNKNOWN |
| AUD-12 | Governance | Determine whether append-only membership audit history is required and implement if in scope | P2 | NOT_IMPLEMENTED |

## Explicit scope exclusions and safety

- Do not implement or enforce DISKPATH. Existing DISKPATH files and workflows are left untouched; this audit does not add, modify or validate that subsystem.
- Do not delete files or data.
- Do not reset databases or run destructive migrations.
- Do not expand Google OAuth scopes without explicit approval.
- Do not create paid infrastructure or external services without necessity and approval.
- Do not claim SKIPPED, QUEUED, IN_PROGRESS, MISSING or UNKNOWN checks as PASS.
- Do not claim production integration is verified from source code or build output alone.

## Audit conclusion

**Repository completion: IN_PROGRESS.**

Verified: current main identity, repository inventory, historical PR merges, PR #161 deployment and exact-SHA published metadata smoke test, and creation of a clean year-overview replacement PR.

Not yet verified: complete current-main CI, PR #165 CI and merge, full product journey coverage, live Google integration, notification delivery, historical restore, full security review, performance baselines and the complete responsive UI audit.

Re-run this audit after each major merge and update the exact SHA and evidence.