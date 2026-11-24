# Product and Engineering Roadmap

This roadmap is evidence-driven. A phase is complete only when implementation, tests, security review, documentation and exact-head CI agree. Roadmap presence is not proof of implementation.

## Phase 1 — Core roster and calendar workflows

**Existing foundation**
- Roster import, date-first validation and preview.
- Day, week, month and year schedule modes.
- Guarded Google Calendar synchronization, reconciliation and resume behavior.
- Shift give-up, exchange and exchange-and-return transaction flows.

**Remaining acceptance work**
- Verify year overview and week-boundary behavior with focused widget/E2E tests.
- Validate the original X-OPD November 2569 and US Clinic ภปร.4 workbooks without guessing date headers.
- Verify authorized Google Calendar behavior and ambiguous network recovery in a controlled test account.

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

## Phase 3 — Notifications and reminders

**Missing implementation**
- `NotificationService` currently defines an interface but no concrete delivery implementation was found.

**Decisions required before implementation**
- Supported platforms and minimum OS versions.
- Whether reminders must fire while the app is closed or device is offline.
- Timezone and daylight-saving policy.
- Permission denial, rescheduling, cancellation and duplicate-delivery behavior.

**Acceptance criteria**
- Permission-aware local notification adapter and/or backend push delivery.
- Stable notification IDs and idempotent schedule/cancel operations.
- Tests for timezone boundaries, changed/cancelled shifts, denied permissions and app restart.
- No secrets or roster data exposed in notification payloads or logs.

## Phase 4 — Historical roster recovery

**Existing foundation**
- Read-only Google Drive revision listing/export and timeline generation.

**Missing capability**
- A safe restore workflow that writes a selected historical state back to the source.

**Acceptance criteria**
- Read-only preview with before/after diff and date/assignment validation.
- Explicit user confirmation immediately before any write.
- Conflict detection if the source changed after preview.
- Append-only audit record and recoverable failure handling.
- Any OAuth Drive write-scope expansion must be separately reviewed and explicitly approved. No automatic writes.

## Phase 5 — Reliability, security and performance

- Verify Composer audit and backend authorization on current source.
- Review local roster/revision persistence, encryption, retention and data deletion semantics.
- Complete mobile/tablet/desktop responsive and accessibility audit.
- Add reproducible benchmarks for large workbooks, event volume, memory and long histories.
- Add property/fuzz coverage for malformed workbooks and API payloads.

## Phase 6 — Release and operational readiness

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
