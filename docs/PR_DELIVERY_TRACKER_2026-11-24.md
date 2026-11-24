# PR and Delivery Tracker — 2026-11-24

This is a point-in-time snapshot. Always refresh live PR metadata and exact-head workflow runs before taking a merge or release action.

## Repository baseline

- Repository: `phakphum12345/phakphum-calendar`
- Default branch: `main`
- Main SHA observed: `c847d70b98c2693a11c1063e989c55f2ab825d04`
- Main branch endpoint reported `protected: false`; server-enforced branch protection must not be assumed.
- No direct main commits or deployments are authorized by this plan.

## Related PRs

| PR | Title / scope | Snapshot state | Next action |
|---|---|---|---|
| #171 | Organization membership audit history | MERGED | Retain as completed work; post-merge evidence is historical |
| #179 | Independent macOS/iOS Xcode workflows | MERGED into main | Use current main as base for new work |
| #178 | Reconcile implementation status after PR #171 | OPEN, non-Draft; base SHA is older than current main | Reconcile/rebase against current main; inspect its three documentation files and current evidence |
| #180 | Three-mode shift pay and public-user readiness specification | OPEN, Draft; head `637c7e71f61d69823c6404462709570ffc068655` before this documentation batch | Keep as documentation delivery package; validate all added docs and update its head after one batch commit |
| #181 | Three-mode rule-source resolution | OPEN, Draft; last recorded head `0951187431faf7db5331809b23ec48c84eaf88e6` | Finish exact-head checks and review before converting from Draft |

## PR #181 workflow snapshot

At the latest recorded inspection, these runs were observed:
- Dart Format Baseline Audit — completed SUCCESS.
- Build and Deploy Web — completed SUCCESS at workflow level; this is PR-branch build evidence, not proof of production deployment.
- Build Linux — completed SUCCESS.
- Auto Detect CI, Android, Pull Request Gate, Cross-platform Runtime, iOS Advisory Evidence, Windows, macOS and iOS — still in progress at the last poll.
- Reviews and review threads returned no entries at that inspection.

The workflow state may have changed since this snapshot. Re-query the exact head before deciding.

## Merge policy

A PR is not ready merely because it is mergeable or because some checks passed.

Before merge:
1. Refresh base and head SHA.
2. Inspect diff, file deletions, generated files, and secrets.
3. Inspect reviews and all review threads.
4. Confirm required checks completed successfully on the exact head.
5. Do not count skipped/missing/cancelled/unknown checks as pass.
6. Confirm PR is not Draft and mergeability is true.
7. Reconcile any base movement and rerun required checks.
8. Merge only under the user's standing approval and the repository's applicable policy.

No PR in this tracker is being merged by this documentation batch.
