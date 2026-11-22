# Repository Audit — 2026-11-22

Repository: `phakphum12345/phakphum-calendar`
Default branch: `main`
Audited main SHA: `e9ed13fb2f0ed82571ce7f2b39b57503d04e5ce5`

## Executive result

Observed main-branch CI runs are successful, but Production deployment is not verified. The Web build and Pages artifact upload succeeded for the audited main SHA; the nested `Deploy GitHub Pages` job was skipped. The current deployment workflow condition explains why a normal push to main does not deploy.

The Pages settings endpoint was not accessible through the connected GitHub integration, and the public URL could not be verified with the available browser fetch. Therefore, do not claim the live Pages site is healthy or deployed at the audited SHA.

## Repository state

| Item | Evidence |
|---|---|
| Repository | Public; default branch `main` |
| Main SHA | `e9ed13fb2f0ed82571ce7f2b39b57503d04e5ce5` |
| Open PRs | 1 — [PR #160](https://github.com/phakphum12345/phakphum-calendar/pull/160) |
| Open issues | 0 |
| Workflow files | 19 under `.github/workflows/` |
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
- Audited head SHA: `a79af5dab3a5a619fd37138b1764811ba8118626`
- State: OPEN; mergeable: true
- Reviews and review threads: none returned
- Exact-head workflow runs: Auto Detect CI and Cross-platform Runtime succeeded; 7 individual check runs succeeded.
- The PR is documentation-only. The core PR evidence gate has path filters for application/platform/workflow paths and does not run for these documentation-only changes.
- The two status documents contain no inline Markdown links; no dedicated Markdown-link validation workflow was observed.

Do not merge until the updated head is rechecked and required approval policy is satisfied.

## Functional source observations

These are source-level observations, not end-to-end behavior claims:

- `lib/domain/services/notification_service.dart` declares an abstract `NotificationService` interface with schedule/cancel methods; it does not itself provide a concrete platform delivery implementation.
- `lib/services/roster_revision_service.dart` reads Google Drive revisions and XLSX exports. Its documentation describes read-only Drive access; the inspected service exposes history reading, not a restore/write operation.
- `lib/services/roster_timeline_generator.dart` converts revision documents into assignment timelines. Timeline generation alone does not establish a user-facing restore workflow.
- `lib/ui/app_shell.dart` exposes dashboard, schedule, monthly roster, roster names, employees, shift exchange, reports, admin, and settings navigation. Dedicated day/week/year calendar views require further targeted source and UI verification.

Existing implementation and traceability documents also identify outstanding work in notifications, historical restore, daily/weekly/yearly views, organization member role changes/removal, responsive UI, performance baselines, and production integration verification.

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
- No source code, workflow, deployment setting, or production data was changed during this audit.
- No files were deleted.
