# Remaining Acceptance — 2026-11-28

This document turns the current project checkpoint into verifiable work packages. It distinguishes code/CI evidence from operational acceptance.\n\n## Latest execution checkpoint — 2026-11-28\n\n- Current main after PR #219 and #225: `4aea651968b5429a2df0e9487bbf200998096561`. Earlier `953e5d00...`, `9aed0905...` and `f7499d76...` checks below remain historical evidence only.\n- Open work: #223 Google function matrix, #224 navigation layout, #226 stale-preview guard, #227 Final Gate Web evidence source, #228 live-status reconciliation. PR #219 roadmap and PR #225 incremental authorization are merged.\n- #224 head moved after a page-state preservation fix; re-run CI on `c13e811ae16d05a91f1ae5443623e246e1246713`. Earlier checks on `8c1ce4f4e631a1b3db4105122a6d54247ff59e17` do not certify it.\n- #225 merged as `953e5d00b85d281566ed8bc98453727cc9112ec3` after all 12 exact-head workflows succeeded, including all platform builds, security, format, runtime, and Pull Request Gate. Its Google provider behavior remains unverified live.\n- #226 exact head `134e067d8870de4aea3ceb66698ef2754a93a4cb`: Linux/Web/security/format passed; remaining platform and PR-gate checks were pending/in progress.\n- #227 exact head `861536cd1528e9016d17a3336111e0352b9c090c`: exact-head checks had just started.\n- PRs #219 and #225 are merged. The other listed PRs remain open; no independent review approval was recorded at this checkpoint. Post-merge main workflows for `953e5d00b85d281566ed8bc98453727cc9112ec3` were queued/in progress at last inspection. No live Google provider, backend, or production deployment acceptance is claimed.\n- Re-fetch all checks by exact head SHA before merge; pending/cancelled/skipped/missing/unknown remain non-passing.\n

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
