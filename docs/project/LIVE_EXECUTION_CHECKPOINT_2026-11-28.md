# Live Execution Checkpoint — 2026-11-28

**Repository:** `phakphum12345/phakphum-calendar`  
**Main:** `6b96b2fa81d7c2a40225067fb6aeaeb03907cb2d`  
**Post-merge verification:** 17/17 main check-runs completed successfully.  
**Latest merged work:** PR #201 — deterministic equal-specificity Shift Pay conflict handling.

This checkpoint is authoritative for the live repository state at the timestamp of this update. PR workflow counts are exact-head snapshots and will change as queued jobs execute. A skipped job is not a pass; optional deployment/advisory evidence is not substituted for required quality gates.

## 1. Active pull requests

| PR | Base | Exact head | CI snapshot | Mergeability / disposition |
|---|---|---|---|---|
| #192 Grid import + persistence | `main` | `b00a98dfcde0d37c4d4f92554090184794798031` | 16 success, 3 in progress, 3 queued, 1 skipped (Pages deployment) | Mergeable; Draft; original workbook acceptance outstanding |
| #205 Reviewer-selected orientation | Grid branch at #192 | `c9f85011f6fcc09c4c9d05db03596d24493ca440` | 4 success, 5 in progress, 6 queued, 1 skipped (Pages deployment) | Mergeable; Draft |
| #207 Merged vertical headers | Grid branch at #192 | `227927c2b24d5f3b81d05e45216d8dc66147fdcc` | 1 success, 2 in progress, 13 queued | Mergeable; Draft |
| #206 Schedule read-back verification | Grid branch at #192 | `022a10b3671d0e1c166d4f2a06705002114fe8cc` | 2 success, 2 in progress, 11 queued | Mergeable; Draft |
| #208 Employee aliases | Grid branch at #192 | `3f482b28aa676d3af6b0f81cde90205e6727a597` | 1 success, 2 in progress, 14 queued | Mergeable; Draft |
| #204 Drive history restore | Grid branch at #192 | `153b7bffb8afc602ffcd3f6eeadbb4eabdb6eb07` | 1 success, 3 in progress, 11 queued | Mergeable; Draft |
| #202 Generation preview/approval | Grid branch at #192 | `a976a21da4acabe32eb5ab5787f4914fcf9eaa86` | 2 success, 1 in progress, 12 queued, 1 skipped (Pages deployment) | Mergeable; Draft |
| #203 Monthly Shift Pay statement calculation | `main` | `490dc0fdddb43eca234718a76142819e71f6208a` | 1 in progress, 13 queued | Mergeable; Draft; calculation-only scope |
| #196 Calendar ETag/lease/recovery | `main` | `6128c97984bbd8bb15e2a0758498f5fc28c792bf` | 16 queued | Mergeable; Draft; live Google acceptance outstanding |
| #191 Notification outbox/Web Push | `main` | `ac4c7e9e4d52673e05743e35b39118e563e4b541` | 16 queued | Mergeable; Draft; real browser/device delivery outstanding |
| #209 Project documentation audit | `main` | `c087c3d0de179637f6b5a6cd0ed2ae9d6d48e592` | 5 queued | Mergeable; Draft; documentation refresh in progress |

No exact-head failure was observed in this snapshot for these updated PR heads. This does not mean their CI is complete: queued and in-progress checks remain unverified. The skipped GitHub Pages deployment jobs on PRs #192, #205 and #202 are not counted as successful checks.

## 2. Dependency and branch reconciliation completed

- PR #201 was squash-merged to main. Main SHA is `6b96b2fa81d7c2a40225067fb6aeaeb03907cb2d`.
- All 17 post-merge main checks passed.
- PR #192 branch was updated with a non-force-pushed merge commit `b00a98dfcde0d37c4d4f92554090184794798031`; its base is current main and GitHub reports mergeable.
- PRs #205, #207, #206, #208, #204 and #202 received non-force-pushed merge commits incorporating the updated Grid base and main Shift Pay conflict changes. Each is based on the current Grid branch and GitHub reports mergeable.
- PR #203 was reconciled onto main with merge commit `490dc0fdddb43eca234718a76142819e71f6208a`. Its comparison against main contains only `docs/SHIFT_PAY_THREE_MODES_IMPLEMENTATION.md`, `lib/domain/services/shift_pay_statement_builder.dart` and `test/shift_pay_statement_builder_test.dart`.
- PRs #196 and #191 were reconciled with main using non-force-pushed merge commits; each is based on current main and GitHub reports mergeable.
- PR #209 was reconciled with main. Its current comparison contains only documentation files.

## 3. Work-package state

| Work package | Current evidence | State | Remaining acceptance |
|---|---|---|---|
| Universal Grid roster import | #192 foundation, #205 orientation, #207 merged headers | IN PROGRESS | Exact-head CI; original workbook tests; reviewer acceptance |
| Schedule persistence/recovery | #192 CAS/journal foundations; #206 read-back; #204 Drive restore | IN PROGRESS | Full production writer inventory, crash recovery, multi-client concurrency and real Drive revision acceptance |
| Employee identity | #208 alias resolver and review UI | IN PROGRESS | Exact-head CI; directory edit/save/reload; collision UX and real roster acceptance |
| Shift Pay conflict handling | #201 merged to main | MERGED — POST-MERGE VERIFIED | Product-level end-to-end review remains separate |
| Monthly Shift Pay statement | #203 immutable calculation builder | IN PROGRESS — CI PENDING | Persisted repository/API/UI, confirmed assignment lifecycle, authorization, export and reconciliation |
| Calendar synchronization | #196 ETag/lease/durable ledger/recovery | IN PROGRESS | Exact-head CI and controlled Google test-calendar timeout/restart acceptance |
| Notifications | #191 durable outbox/Web Push foundation | IN PROGRESS | Exact-head CI, worker operations, real browser subscription/delivery/retry; native push not established |
| Schedule generation | #202 immutable preview/approval/CAS slice | IN PROGRESS | Exact-head CI, durable approval, read-back and crash recovery |
| Documentation | #209 live audit refresh | IN PROGRESS | Validate current claims and update status after each merge |

## 4. External acceptance blockers

1. **Original workbooks are not available in the Library.** A search for `.xlsx` and `.xls` returned no files. The Library contains pasted Markdown table extracts, which cannot preserve original worksheet IDs, merged-cell ranges, hidden rows/columns, formulas, raw values or A1 provenance. Required original files remain:
   - X-OPD November 2569
   - 16 November–15 December 2569
   - US Clinic ภปร.4
2. **Google Calendar:** no controlled non-production Google test calendar was used for provider-side timeout-after-commit, ETag conflict, lease expiry/reclaim and restart acceptance.
3. **Backend operations:** production HTTPS/auth configuration, durable database transaction behavior, backup/restore and deployed SHA remain unverified.
4. **Notifications:** no real browser/device delivery acceptance has been recorded. Native iOS/Android push is not established.
5. **Contractor classification:** current Shift Pay employment types are `salaried` and `dailyPaid`. The third contractor mode's exact semantics are undefined and must not be guessed.
6. **Deployment:** no production deployment or deployed-SHA verification was performed in this work.

## 5. Merge and safety rules

- Merge only after all required checks on the exact candidate SHA complete successfully, blocking reviews are resolved, the diff is understood and scope-specific acceptance is recorded.
- CI green is not product acceptance or production acceptance.
- Never count skipped, cancelled, queued, in-progress, missing or unknown checks as PASS.
- Do not use a production Google Calendar for tests; no production data mutation is authorized by this checkpoint.
- After each merge, refresh main SHA, inspect post-merge checks, and reconcile every stacked branch.
- The user's local Windows working tree is not visible to this GitHub audit.
