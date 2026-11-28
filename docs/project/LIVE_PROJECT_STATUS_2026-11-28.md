# Live Project Status — 2026-11-28

> This is a dated execution checkpoint, not a declaration that the product is complete. Verify live GitHub state before treating any branch, PR, CI result, or deployment as current.

## Repository baseline

- Repository: `phakphum12345/phakphum-calendar`
- Target branch: `main`
- Main baseline at checkpoint: `1f2aba7b50b59cd44a6754a7a5ea8f16ba94cef0`
- PR #211 merged as `1f2aba7b50b59cd44a6754a7a5ea8f16ba94cef0`.

## Integrated work

- PR #211 integrated durable roster history/Drive revision restore through the reviewed Grid import and conditional Schedule commit workflow, together with reviewer-selected date-axis orientation.
- PRs #204 and #205 are closed as superseded by #211. Their former branches are not the active integration path.

## Active integration work

### PR #212 — Calendar Sync coordination + Web Push outbox

- Branch: `integration/calendar-sync-notifications-on-main-20261128`
- Head at checkpoint: `0d086809cdcc7335a69a29ed469a79ebbd3d1e6a`
- Base at checkpoint: `2e30ca4237f6191cf23a2c005c6157523bf4558a`
- GitHub compare against current main reported 83 commits ahead and 19 commits behind; mergeability was false.
- Three files overlap with the merged #211 change set: `lib/controller/app_controller.dart`, `lib/ui/app_shell.dart`, and `test/widget_test.dart`.
- No PR-triggered workflow runs were returned for this exact head; CI status is UNKNOWN, not PASS.
- Keep Draft. Reconcile the branch with current main while preserving both feature sets, inspect the three overlapping files, then run formatting, backend tests, Flutter tests and all required CI on the resulting exact head.

Intended feature scope includes owner+Calendar-scoped durable sync leases, run history and operation ledger, ETag/managed Sync ID preconditions, stable Sync IDs for ambiguous inserts, confirmation-gated recovery, and transactional/idempotent browser Web Push outbox delivery with encrypted payload transport, retries and dead-letter handling.

### PR #209 — broad documentation reconciliation

- Branch: `docs/project-completion-audit-20261127`
- Head at checkpoint: `2eddbe0060aa42c8f39ff18506c904ed0b164964`
- Its merge base with current main was `6b96b2fa81d7c2a40225067fb6aeaeb03907cb2d`; compare reported 120 commits ahead and 532 behind.
- Keep Draft. Do not force-update or overwrite newer documentation. Reconcile only after inspecting each document against current main and the actual implementation.

## Superseded source PRs

- #191 contains the earlier Web Push outbox implementation.
- #196 contains the earlier Calendar Sync coordination implementation.
- Their work is being consolidated through #212. Keep their branches as reference until #212 has been reconciled and its full feature coverage verified; do not treat their older CI results as validation of #212.

## Operational acceptance still required

1. Deploy/migrate the self-hosted Laravel backend in a controlled environment and verify configuration, durable database transactions/locking, key backup and recovery.
2. Test concurrent Calendar sync runs, lease expiry/reclaim, stale-token fencing, ETag-protected updates/deletes, ambiguous provider outcomes and restart recovery against a controlled Google test calendar.
3. Verify real browser Web Push permission, subscription lifecycle, delivery, expiry and worker recovery on an actual supported browser/device. Browser Web Push is not native iOS/Android push.
4. Validate roster imports using representative real workbooks with mixed layouts, departments, merged headers and varying date axes; preserve review decisions, provenance and existing Schedule data.
5. Verify history restore against real Drive revision exports and multiple Schedule contexts, without mutating the original Drive source.
6. Record deployment and acceptance evidence before declaring production readiness.

## Merge policy

- Merge only after the exact current PR head has all required CI checks terminal and successful, conflicts resolved, review requirements satisfied, and the intended base/head SHAs verified.
- Pending, skipped, missing, unknown or stale checks are not passing.
- Never claim operational acceptance from mocked tests or CI alone.
- Preserve user data, API contracts, schema compatibility, existing overrides and unrelated main-branch changes.
