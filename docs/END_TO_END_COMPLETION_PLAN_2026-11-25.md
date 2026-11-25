# Phakphum Calendar — End-to-End Completion Plan

- Audit date: 2026-11-25
- Repository: `phakphum12345/phakphum-calendar`
- Main SHA: `aed2f1177bdfc85f6ff53bb200116812a51bd9e3`
- Status: current engineering plan; not a release-readiness declaration

## Mission

Deliver a dependable calendar and shift-management application with configurable Personal, Organization and Hybrid shift-pay modes, secure organization boundaries, reliable Calendar synchronization, traceable calculations and installable supported clients.

## Verified implementation foundations

- PR #181 merged: Flutter Personal/Organization/Hybrid rule-source resolution with explicit precedence; never adds both source amounts.
- PR #182 merged: backend evolution blueprint.
- PR #183 merged: authenticated Shift Pay profile persistence and organization-owned rules with membership/role authorization.
- PR #186 merged: backend calculation API and immutable/idempotent historical snapshots.
- PR #187 merged: durable Calendar Sync attempts and per-transfer provider event mappings, with legacy payload compatibility.
- Existing roster/calendar engine, organization membership administration, shift transactions, timeline/revision foundations and CI quality workflows remain in place.

## Remaining workstreams

### 1. Shift Pay end-to-end
- Connect confirmed/actual roster assignments to the calculation API.
- Add assignment-level calculation details and monthly statements with reconciliation.
- Resolve Flutter/backend decimal precision and rounding parity explicitly.
- Preserve historical snapshots when rules or organization memberships change.
- Add end-to-end tests for personal, organization, hybrid precedence, no-match, compensatory time, retries and report totals.

### 2. Real Calendar provider integration
- Implement a provider adapter for Google Calendar using the existing authenticated account and least-privilege scopes.
- Preview all external changes and require explicit user confirmation before writes.
- Persist provider event references and use stable idempotency keys.
- Handle timeouts where the provider may have created an event but the response was lost; reconcile before retrying.
- Test with a controlled test account. Do not write to real user calendars during CI.
- PR #187 only records/reconciles attempts and event mappings; it does not call the Google Calendar API or create events.

### 3. Notifications and reminders
- Choose supported platforms and whether delivery must work while the app is closed/offline.
- Implement permission-aware scheduling/cancellation and duplicate prevention.
- Implement Web Push only with configured VAPID secrets, supported encryption and durable retry/worker behavior.
- Keep roster details and credentials out of notification payloads and logs.

### 4. Historical roster recovery
- Provide read-only preview with before/after diff.
- Detect source changes between preview and confirmation.
- Require explicit confirmation immediately before any write.
- Record append-only audit history and recoverable failure state.
- Any Drive write-scope expansion requires separate review and explicit approval.

### 5. Reliability, security and performance
- Review local revision/history persistence, encryption, retention and recovery.
- Maintain tenant-isolation and role-authorization tests.
- Add reproducible large-workbook, event-volume, memory and long-history benchmarks.
- Verify responsive phone/tablet/desktop journeys and accessibility.
- Preserve existing data and backward-compatible contracts.

### 6. Release and operations
- Tie CI and deployment evidence to exact commit SHAs.
- Treat SKIPPED, UNKNOWN, queued, cancelled and missing checks as non-PASS.
- Verify signed/release artifacts separately from unsigned CI outputs.
- Verify Pages deployment metadata and live API health against an explicitly approved main SHA.
- Document rollback, incident response and data recovery before declaring production readiness.

## Safety gates

1. Inspect the full diff, base/head SHA, reviews, mergeability and exact-head checks before each merge.
2. Never directly commit to main or merge a stale/stacked branch without rebuilding it on current main.
3. Never delete existing files/data or perform destructive migrations to make tests pass.
4. No production migration, deployment, real Calendar write, OAuth scope expansion or paid-service adoption without separate explicit approval.
5. Preserve backward compatibility and prove capability expansion with tests.

## Current qualification

The merged PR heads #181, #182, #183, #186 and #187 passed their applicable exact-head checks. The current main SHA recorded above had 5/8 checks completed successfully and 3 still in progress at the time of this snapshot. Production deployment and live Google Calendar provider behavior remain UNKNOWN.
