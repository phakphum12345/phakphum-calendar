# Product and Engineering Roadmap

This roadmap is evidence-driven. A phase is complete only when implementation, tests, security review, documentation and exact-head CI agree. Roadmap presence is not proof of implementation.

## Current delivery checkpoint — 2026-11-27

Main is `68ef85361c2d08e2970160a36475592010d908f7`. The active work is in Draft PRs #191, #192, #196, #201, #202, #203 and #204. PR #199 was superseded by #192. No open PR has an independent review; branch protection is disabled and production deployment is not verified. See [Implementation Status](IMPLEMENTATION_STATUS.md) and [Requirements Traceability](REQUIREMENTS_TRACEABILITY.md) for exact SHAs and evidence.


## Phase 1 — Core roster and calendar workflows

**Existing foundation**
- Roster import, date-first validation and preview.
- Day, week, month and year schedule modes.
- Guarded Google Calendar synchronization, reconciliation and resume behavior.
- Shift give-up, exchange and exchange-and-return transaction flows.

**Implementation in progress — PR #192**
- The parser path is being extended for per-section horizontal/vertical/mixed orientation, source-coordinate/merged-cell/color provenance and CSV/TSV/TXT input.
- Exact-head CI is pending after the latest source/test changes.

**Remaining acceptance work**
- Verify year overview and week-boundary behavior with focused widget/E2E tests.
- Validate the original X-OPD November 2569, 16 Nov–15 Dec 2569 and US Clinic ภปร.4 workbooks without guessing date headers.
- Verify ambiguous orientation and employee identity decisions with real workbook evidence.

## Phase 2 — Organization administration and audit

**Merged foundation — PR #171**
- Organization membership administration with authenticated membership-audit gateway and UI.
- Cursor pagination, organization-scoped event history, stale-response protection and tenant-isolation regression coverage.

**Post-merge qualification**
- Verify owner/admin boundaries and audit refresh behavior on current main.

**Acceptance criteria**
- Owner/admin-only actions enforced by the backend, not only hidden in the UI.
- Tenant-isolation tests cover cross-organization reads and pagination.
- Audit history refreshes after membership approval, role change and removal, and ignores stale requests (covered by PR #171 tests; retain post-merge verification).
- Exact-head CI passes; merge and post-merge main verification are recorded.

## Phase 3 — Shift Pay and Calendar Sync backend foundations

**Merged foundation**
- PR #181: Personal/Organization/Hybrid source resolution with explicit precedence and no double-counting.
- PR #183: user Shift Pay profile persistence and organization-owned rules with authorization.
- PR #186: backend calculation and immutable, idempotent historical snapshots.
- PR #187: durable Calendar Sync attempt history and per-transfer event reconciliation, preserving the legacy completion payload.

**Remaining acceptance work**
- Connect calculations to confirmed roster assignments and monthly statements.
- Verify Flutter/backend decimal precision behavior and rounding policy.
- Implement actual Google Calendar provider calls, timeout handling and provider-side idempotency. PR #187 records sync outcomes; it does not create external events.

## Phase 4 — Notifications and reminders

**Implementation in progress — PR #191**
- Adds subscription ownership/lifecycle, VAPID Web Push sender, encrypted payload delivery, durable outbox worker, retry/backoff, dead-letter state and a scheduled delivery command.
- Exact-head CI passed 13/13 on the recorded PR head; the PR remains Draft and unreviewed.

**Remaining acceptance**
- Verify delivery to a real registered browser/device, permission denial, expired subscriptions, worker crash/retry and timezone boundaries.
- Verify the scheduler is actually running in the intended self-hosted deployment. Source code and CI do not prove live delivery.

## Phase 5 — Historical roster recovery

**Implementation in progress — PR #204**
- Adds a revision picker in History and routes read-only Drive revision snapshots through the Grid review and revision-bound Schedule commit workflow.
- The source revision ID and snapshot content are bound into import provenance. No Drive write scope or source-file mutation is added.

**Remaining acceptance**
- Add a per-assignment before/after diff, not only counts.
- Verify with original Drive revision exports and a non-owner account.
- Confirm stale target revisions are rejected and recovery is idempotent. No automatic writes.

## Phase 6 — Reliability, security and performance

- Verify Composer audit and backend authorization on current source.
- Add and enforce required branch protection/status checks; current `main` protection is disabled.
- Review local roster/revision persistence, encryption, retention and data deletion semantics.
- Complete mobile/tablet/desktop responsive and accessibility audit.
- Add reproducible benchmarks for large workbooks, event volume, memory and long histories.
- Add property/fuzz coverage for malformed workbooks and API payloads.

## Phase 7 — Release and operational readiness

- Keep CI evidence tied to exact commit SHAs; SKIPPED/UNKNOWN never count as PASS.
- Build all supported targets and verify signed/release artifacts separately from unsigned CI artifacts.
- Deploy GitHub Pages only from the approved main SHA and verify the published `deployment.json` matches it.
- Verify production API health/readiness and OAuth redirect configuration without exposing credentials.
- Record rollback, incident and data-recovery procedures before production readiness is declared.

## Merge and safety gates

1. Reconcile the PR against the latest `main`; inspect the complete diff and changed-file list.
2. Resolve all review findings and verify no unintended file deletions or unrelated changes.
3. Require all applicable exact-head checks to complete successfully.
4. Confirm the PR is not empty, stale, superseded or dependent on an unmerged branch.
5. Merge only after the owner authorizes the merge; verify merge commit and post-merge main evidence.
6. Never directly commit to `main`, reset shared branches, delete user data or expand OAuth scopes without explicit approval.
