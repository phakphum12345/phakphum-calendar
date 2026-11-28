# Live Project Status — 2026-11-28 (reconciled)

> Current-main checkpoint only. This is not a production-readiness declaration. Recheck the live repository and exact workflow runs before making release or operational claims.

## Repository baseline

- Repository: \`phakphum12345/phakphum-calendar\`
- Branch: \`main\`
- Baseline SHA when this checkpoint was prepared: \`f7499d76a2d5111a7d37801462a4b837e5791ff9\`
- This checkpoint supersedes the earlier same-date snapshot at \`1f2aba7b50b59cd44a6754a7a5ea8f16ba94cef0\`.

## Integrated delivery

| PR | Result | Integrated scope |
|---|---|---|
| #211 | Merged | Durable roster history / Drive revision restore through reviewed Grid import and conditional Schedule commit; reviewer-selected date-axis orientation |
| #212 | Merged | Calendar Sync coordination and durable operation ledger; ETag/managed Sync ID preconditions and confirmation-gated recovery; browser Web Push subscription/outbox, encrypted payload transport, retry and dead-letter foundations |
| #214 | Merged | Restored missing Laravel Calendar Sync coordination API feature coverage from the prior #196 implementation |
| #215 | Merged | Backend configuration gates: PR builds remain available; main/manual production artifacts and Pages deployment are skipped with explicit evidence when \`ORGANIZATION_API_BASE_URL\` is not a valid HTTPS URL |
| #213 | Merged | Earlier live-status documentation snapshot; superseded by this reconciliation |

PR #191 was closed as superseded after verifying its 35 changed paths were integrated by #212. PR #196 was closed as superseded after verifying the implementation paths were present and restoring its missing Laravel feature test in #214. Their closed branches are historical references, not active delivery branches.

## Current post-merge verification

- PR #214 post-merge main workflows completed successfully: Cross-platform Runtime, Laravel Backend CI, Auto Detect CI and Dependency Security.
- PR #215 exact-head pull-request evidence completed successfully across the observed platform and gate workflows before merge.
- PR #215 merged as \`f7499d76a2d5111a7d37801462a4b837e5791ff9\`.
- Post-merge workflows for \`f7499d76...\` were still running when this checkpoint was prepared. Their final conclusions must be recorded separately; do not infer success from the PR checks.
- The previous #212 post-merge run showed the missing/invalid HTTPS shared-backend configuration caused production artifact/deployment guards to fail. #215 changes those guards to report explicit SKIPPED outcomes while continuing safe non-production CI. This does not configure or deploy the backend.

## Remaining work — highest priority

1. **Verify post-merge #215 behavior:** inspect all workflows on exact main SHA \`f7499d76...\`; confirm build/test evidence remains successful, release artifacts are explicitly skipped when backend config is absent, and Pages deployment is not performed. A skipped artifact is not a production release.
2. **Shared backend operational readiness:** provision/configure the intended self-hosted Laravel backend, HTTPS origin, database/locking, secrets and backup/restore; run migrations and health checks. No deployment or live backend acceptance is claimed here.
3. **Calendar Sync live acceptance:** use a controlled Google test calendar and two clients to test concurrent leases, heartbeat, expiry/reclaim, stale-token fencing, ETag-protected update/delete, ambiguous insert outcomes and restart recovery.
4. **Web Push live acceptance:** configure VAPID keys and scheduler/worker; test permission, subscribe/unsubscribe, delivery, expiration, retries and recovery on a registered supported browser/device. Browser Web Push is not native iOS/Android push.
5. **Universal roster real-file acceptance:** test representative original workbooks with horizontal, vertical and mixed sections, multi-level/merged headers, multiple departments and partial periods. Preserve provenance, reviewer corrections, existing Schedule data and overrides. Synthetic fixtures do not substitute for the original workbooks.
6. **History restore acceptance:** test real Drive revision exports and multiple Schedule contexts, including stale-source guards, preview, confirmation, conditional commit and audit; do not mutate original Drive files.
7. **Shift Pay completion:** finish Personal / Organization / Hybrid rule-source resolution, durable versioned settings, confirmed assignment linkage, immutable calculation snapshots, monthly statements, reconciliation and tenant authorization.
8. **Public Google authentication:** separate basic identity from optional Google API scopes; configure OAuth clients/origins/redirects and verify a normal non-tester account across supported platforms.
9. **AI Assistant readiness:** prove the end-to-end request path; provide offline documentation-grounded help; configure any live provider server-side with authorization, privacy, quotas, safe failures and user-confirmed writes. Do not advertise unavailable live research/provider functions.
10. **Release readiness:** clean install and upgrade on supported platforms, production signing/provisioning where applicable, package dependencies, exact deployed SHA/health, checksums, release notes and rollback/restore evidence.

## Documentation reconciliation

- PR #209 is a stale, divergent documentation branch based on an older repository state. It is not safe to merge wholesale. Its useful requirements are being reconciled selectively into this current-main documentation update.
- Older dated snapshots in the repository remain historical records unless explicitly refreshed. They must not be used as live PR/CI status.

## Merge and evidence policy

- Verify exact base/head SHAs and every required check before merge.
- Pending, missing, skipped, cancelled, unknown, stale or non-terminal checks are not PASS.
- Distinguish source/CI acceptance from provider, device, security, deployment and production acceptance.
- Never add a placeholder backend URL or bypass HTTPS/backend release guards.
- Preserve user data, API contracts, schemas, business rules, overrides and unfinished work.
