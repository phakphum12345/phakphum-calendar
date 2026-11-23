# Repository Audit — 2026-11-22

Repository: `phakphum12345/phakphum-calendar`
Default branch: `main`
Audited main SHA: `e9ed13fb2f0ed82571ce7f2b39b57503d04e5ce5`

## Executive result

Observed main-branch CI runs are successful, but Production deployment is not verified. The Web build and Pages artifact upload succeeded for the audited main SHA; the nested `Deploy GitHub Pages` job was skipped. The current deployment workflow condition explains why a normal push to main does not deploy.

The README declares the production URL as [Phakphum Calendar on GitHub Pages](https://phakphum12345.github.io/phakphum-calendar/). The Pages settings endpoint was not accessible through the connected GitHub integration, and the URL could not be independently opened with the available browser fetch. Therefore, accessibility and the deployed SHA remain UNKNOWN; do not claim the live site is healthy or deployed at the audited SHA.

## Repository state

| Item | Evidence |
|---|---|
| Repository | Public; default branch `main` |
| README-declared production URL | `https://phakphum12345.github.io/phakphum-calendar/` (accessibility and deployed SHA UNKNOWN) |
| Main SHA | `e9ed13fb2f0ed82571ce7f2b39b57503d04e5ce5` |
| Open PRs | 5 — [#160](https://github.com/phakphum12345/phakphum-calendar/pull/160), [#161](https://github.com/phakphum12345/phakphum-calendar/pull/161), [#162](https://github.com/phakphum12345/phakphum-calendar/pull/162), [#163](https://github.com/phakphum12345/phakphum-calendar/pull/163), [#164](https://github.com/phakphum12345/phakphum-calendar/pull/164) |
| Open issues | 0 |
| Workflow inventory | 18 YAML workflow files plus `README.md` under `.github/workflows/` |
| Repository rulesets | Empty list returned |
| Branch protection | UNKNOWN — branch-protection API returned HTTP 403 (resource not accessible by integration) |

## Main-branch workflow evidence

The following 10 workflow runs completed with conclusion `success` for exact main SHA `e9ed13fb2f0ed82571ce7f2b39b57503d04e5ce5`:

- [Build Windows](https://github.com/phakphum12345/phakphum-calendar/actions/runs/44921688541)
- [Final Gate](https://github.com/phakphum12345/phakphum-calendar/actions/runs/44921688606)
- [Build and Deploy Web](https://github.com/phakphum12345/phakphum-calendar/actions/runs/44921688542)
- [Build Linux](https://github.com/phakphum12345/phakphum-calendar/actions/runs/44921688501)
- [Auto Detect CI](https://github.com/phakphum12345/phakphum-calendar/actions/runs/44921688516)
- [Build Android](https://github.com/phakphum12345/phakphum-calendar/actions/runs/44921688508)
- [Cross-platform Runtime](https://github.com/phakphum12345/phakphum-calendar/actions/runs/44921688579)
- [Build iOS](https://github.com/phakphum12345/phakphum-calendar/actions/runs/44921688544)
- [DISKPATH Manifest Validation](https://github.com/phakphum12345/phakphum-calendar/actions/runs/44921688495)
- [Dart Format Baseline Audit](https://github.com/phakphum12345/phakphum-calendar/actions/runs/44921688538)

The Web workflow's [Build Flutter web job](https://github.com/phakphum12345/phakphum-calendar/actions/runs/44921688542/job/136898907601) succeeded and uploaded the Pages artifact. Its [Deploy GitHub Pages job](https://github.com/phakphum12345/phakphum-calendar/actions/runs/44921688542/job/136899340229) was `skipped`.

The [Final Gate run](https://github.com/phakphum12345/phakphum-calendar/actions/runs/44921688606) succeeded. Its collector currently treats the overall Web workflow conclusion as required evidence. A successful build job can make the parent workflow successful while the nested deployment job is skipped. Final Gate success is therefore not proof of production publication.

## Root cause in `.github/workflows/web.yml`

The workflow triggers on both `push` to `main` and `workflow_dispatch`. The deploy job currently has:

```yaml
if: github.ref == 'refs/heads/main' && github.event_name == 'workflow_dispatch'
```

Consequences:
1. A push to `main` starts the Web build.
2. The build and Pages artifact upload can succeed.
3. Deployment is skipped because the event is `push`, not `workflow_dispatch`.
4. The overall Web workflow can still conclude `success`.
5. Final Gate can pass without production publication.

## PR #160 evidence

[PR #160 — docs: refresh repository status after PRs 157-159](https://github.com/phakphum12345/phakphum-calendar/pull/160)

- Base SHA: `e9ed13fb2f0ed82571ce7f2b39b57503d04e5ce5`
- Head branch: `docs/post-merge-status-20261122`
- Initial audited head SHA: `a79af5dab3a5a619fd37138b1764811ba8118626`; later documentation updates advanced the branch further, so the live PR #160 page is the source of truth for its current exact head SHA.
- State: OPEN; mergeable: true
- Reviews and review threads: none returned
- Exact-head workflow runs: Auto Detect CI and Cross-platform Runtime succeeded; 7 individual check runs succeeded.
- The PR is documentation-only. The core PR evidence gate has path filters for application/platform/workflow paths and does not run for these documentation-only changes.
- The two status documents contain no inline Markdown links; no dedicated Markdown-link validation workflow was observed.

Do not merge until the updated head is rechecked and required approval policy is satisfied.

## Functional source observations

These are source-level observations, not end-to-end behavior claims:

- `lib/domain/services/notification_service.dart` declares an abstract `NotificationService` interface with schedule/cancel methods; the inspected app controller does not wire it to a concrete scheduled delivery implementation. `ShiftAlertService` provides in-app shift/conflict alerts, which are not equivalent to scheduled platform notifications. Supported delivery platforms and whether reminders must fire while the app is closed remain product decisions.
- `lib/services/roster_revision_service.dart` reads Google Drive revisions and XLSX exports. Its documentation describes read-only Drive access; the inspected service exposes history reading, not a restore/write operation. `GoogleAuthService.readAccessScopes` includes Drive metadata/read-only scopes only, so restoring back to Drive requires explicit approval for additional write scope and user consent.
- `lib/services/roster_timeline_generator.dart` converts revision documents into assignment timelines. Timeline generation alone does not establish a user-facing restore workflow.
- The schedule feature has dedicated daily, weekly and monthly pages. The weekly pages currently derive days from the selected month, so weeks crossing month boundaries can be incomplete; PR #162 adds canonical cross-month day lookup and regression tests. A 12-month year overview is proposed in PR #163.

Existing implementation and traceability documents identify outstanding work in scheduled notifications, historical restore, the year overview (PR #163), organization member role changes/removal (PR #164), responsive UI, performance baselines, and production integration verification.

## Active follow-up PRs

- [PR #161](https://github.com/phakphum12345/phakphum-calendar/pull/161) — automatic Pages deployment on main pushes, deployed-SHA metadata, HTTP smoke tests, and deployment-aware Final Gate. OPEN; not merged.
- [PR #162](https://github.com/phakphum12345/phakphum-calendar/pull/162) — complete seven-day weekly views across month boundaries. OPEN; not merged.
- [PR #163](https://github.com/phakphum12345/phakphum-calendar/pull/163) — responsive 12-month year overview, stacked on PR #162. OPEN; not merged.
- [PR #164](https://github.com/phakphum12345/phakphum-calendar/pull/164) — owner/admin member role changes, soft removal, and reactivation. OPEN; not merged.

## Required remediation

1. Change the Pages deployment condition so a successful `push` to `main` deploys automatically, while retaining safe manual dispatch.
2. Make the release gate require the `Deploy GitHub Pages` job itself to conclude `success`, not merely the overall Web workflow.
3. Add post-deployment HTTP smoke tests for the published site and deployment metadata containing the exact source SHA.
4. Verify the deployed SHA equals the intended `main` SHA.
5. Re-run the workflow on a controlled PR head and after an approved merge.
6. Verify the live Pages URL and runtime behavior.

## Limitations

- Branch-protection settings could not be read because the connected integration returned HTTP 403.
- GitHub Pages settings could not be retrieved through the available integration endpoint.
- The public site could not be independently opened with the available browser fetch.
- No source code, workflow, deployment setting, or production data was changed during the initial read-only audit; all subsequent implementation changes are isolated in separate open PRs.
- No files were deleted.
