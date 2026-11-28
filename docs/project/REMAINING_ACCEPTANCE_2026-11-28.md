# Remaining Acceptance — 2026-11-28

This document turns the current project checkpoint into verifiable work packages. It distinguishes code/CI evidence from operational acceptance.\n\n## Latest execution checkpoint — 2026-11-28

- Current main after PR #223: `4141e2715a15a211cc42dce2525361cd6688990e`; earlier SHA checks remain historical.
- PR #219, #225, #227 and #223 are merged. #227 fixed Final Gate's Web evidence mapping; #223 records Google function acceptance evidence.
- Open PRs: #224, #226 and #228.
- #224 exact head `c13e811ae16d05a91f1ae5443623e246e1246713`: all 12 observed workflows passed; fresh PR metadata reports clean mergeability.
- #226 exact head `134e067d8870de4aea3ceb66698ef2754a93a4cb`: all 12 observed workflows passed; stale Schedule preview regression prevents provider/archive writes. Full Calendar provider acceptance remains open.
- #227 exact head `d95e57e5f336eeb6ef300c88c04b0ad14da20b27`: all eight applicable exact-head workflows passed.
- #223 exact head `6f67b968257a4e7f5867820d4a0159c272733041`: all three documentation-focused workflows passed and PR merged.
- Main post-merge CI on `5a4e83ac42b1b383768b96828a7a932db9bf3c15`: Windows, Linux, Android, Web build, Auto Detect CI, Dependency Security and Cross-platform Runtime passed; Final Gate was still in progress at last inspection. Wait for its terminal result before merging #224/#226.
- Web artifact creation succeeded; GitHub Pages deploy and deployed-SHA verification were skipped by the HTTPS backend guard. No live Google provider, configured HTTPS backend, production deployment or deployed-SHA acceptance is claimed.
- Re-fetch exact-head checks after every update; pending/cancelled/skipped/missing/unknown remain non-passing.


## 1. Post-merge CI after PR #215

**Baseline:** `f7499d76a2d5111a7d37801462a4b837e5791ff9`.

- [x] Fetch all workflow runs attached to this exact SHA: all 10 runs completed.
- [x] Inspect each run and job, including the Final Gate's required and optional classifications.
- [x] Verify build/test jobs pass and that missing backend configuration produces explicit SKIPPED release/deployment evidence.
- [x] Confirm GitHub Pages deployment and published-site verification were skipped without a valid HTTPS backend URL.
- [x] No failing workflow remained on this main SHA; the earlier #212 failures were traced to the missing backend URL and resolved by #215's explicit skip behavior.
- [x] Update the live status with run IDs and final conclusions.

## 2. Shared Laravel backend

- [ ] Decide and provision the self-hosted deployment target and HTTPS origin.
- [ ] Configure database, transaction/locking support, secrets, VAPID key custody, rate limits, backups and health checks.
- [ ] Run migrations in a controlled staging environment; verify rollback and restore.
- [ ] Exercise authenticated owner/tenant authorization and negative cross-tenant tests.
- [ ] Configure `ORGANIZATION_API_BASE_URL` only after health and security acceptance.
- [ ] Confirm production artifacts/deployment are enabled only after the valid backend origin is configured.

## 3. Calendar Sync

- [ ] Use a controlled Google test account/calendar, never a user's production calendar for acceptance.
- [ ] Run concurrent syncs for the same owner/calendar and verify lease isolation and conflict behavior.
- [ ] Verify heartbeat, expiry/reclaim and stale-token fencing.
- [ ] Verify ETag/managed Sync ID preconditions for updates/deletes.
- [ ] Simulate ambiguous insert/update outcomes and ensure reconciliation occurs before retry.
- [ ] Restart the app/backend during a run and verify durable operation-ledger recovery.
- [ ] Confirm recovery remains preview/confirmation gated and cannot overwrite newer user changes.

## 4. Web Push

- [ ] Configure and protect VAPID public/private keys.
- [ ] Deploy the outbox scheduler/worker and verify durable claims, retry/backoff, dead-letter and observability.
- [ ] Test browser permission, subscription creation, renewal, unsubscribe and expiry cleanup.
- [ ] Deliver a real notification to a registered supported browser/device.
- [ ] Verify payload confidentiality and safe logs.
- [ ] Keep browser Web Push distinct from native iOS/Android push; do not claim native push support from browser tests.

## 5. Universal roster and persistence

- [ ] Test original representative XLSX/CSV/Google Sheets inputs, not only synthetic fixtures.
- [ ] Cover horizontal, vertical and mixed table sections, merged/multi-level headers, multiple departments, partial periods and Thai Buddhist Era/Gregorian dates.
- [ ] Detect and report duplicate, missing, conflicting and out-of-order dates with source coordinates; never silently guess.
- [ ] Verify reviewed corrections are rebuilt from original source data and provenance is retained.
- [ ] Verify import, re-sync, restore and every writer preserve user overrides and existing Schedule data.
- [ ] Test two-client CAS contention, stale-client writes, crash recovery and conditional deletion/tombstones.

## 6. History and Drive revision restore

- [ ] Test against controlled Drive revision exports and multiple Schedule contexts.
- [ ] Preview diffs and identify source revision before mutation.
- [ ] Require explicit confirmation and conditional commit.
- [ ] Verify original Drive source is never mutated and audit/recovery evidence is retained.

## 7. Shift Pay

- [ ] Complete Personal, Organization and Hybrid modes, including first-run selection and mode-specific UX.
- [ ] Persist profiles/rules with schema versioning and backward-compatible migration.
- [ ] Resolve rules deterministically and reject ambiguous/equal-specificity conflicts.
- [ ] Calculate only from confirmed/fulfilled assignments; a Google Calendar event alone is not fulfillment.
- [ ] Preserve immutable calculation snapshots and prevent duplicate payments.
- [ ] Deliver monthly statements and assignment-level reconciliation with exact decimal/rounding policy.
- [ ] Verify personal mode without organization membership and organization tenant isolation.

## 8. Google identity and public-user access

- [ ] Separate basic sign-in from optional Calendar/Drive/Sheets scopes.
- [ ] Configure platform OAuth clients, origins, redirect URIs and consent publication.
- [ ] Test with an ordinary non-owner/non-tester account.
- [ ] Verify token refresh, revocation, sign-out and secure storage on each supported platform.

## 9. AI Assistant

- [ ] Trace and test the complete UI-to-backend request path.
- [ ] Provide reliable offline, documentation-grounded help without claiming a live response.
- [ ] If live AI/research is advertised, use server-side providers and retrieval with verifiable citations.
- [ ] Enforce authentication, tenant authorization, consent, data minimization, quotas, timeouts and safe errors.
- [ ] Keep deterministic parsing authoritative and require preview/confirmation for writes.
- [ ] Add privacy, retention/deletion, audit and prompt-injection defenses.

## 10. Release readiness

- [ ] Clean-install and upgrade tests on every claimed supported platform.
- [ ] Production signing/provisioning for Android/iOS distribution.
- [ ] Windows/Linux dependency and package verification on clean machines.
- [ ] Web live health check and exact deployed-SHA verification.
- [ ] Decide macOS support scope and accurately document ad-hoc signing/notarization.
- [ ] Publish versioned release notes, checksums, installation guide and rollback/restore procedure.

## Completion rule

A package is complete only when its implementation, exact-head CI, regression tests, operational acceptance, documentation and platform behavior all have evidence. A successful CI run alone is not production acceptance.
