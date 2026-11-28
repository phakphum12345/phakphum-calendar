# Live Project Status — 2026-11-28 (reconciled)

> Current-main checkpoint only. This is not a production-readiness declaration. Recheck the live repository and exact workflow runs before making release or operational claims.

## Latest execution checkpoint — current main

- Repository: `phakphum12345/phakphum-calendar`
- Main SHA after PR #227 merged: `5a4e83ac42b1b383768b96828a7a932db9bf3c15`.
- PR #227 merged successfully. It corrects Final Gate's Web evidence mapping to the main-push `deploy-pages.yml` workflow and aligns the iOS advisory path filter with the iOS build trigger.
- Open PRs at this checkpoint: #223 Google function acceptance matrix (new documentation evidence update; fresh CI required), #224 customizable navigation, #226 stale-preview write guard, and #228 this live-status reconciliation.
- #224 exact head `c13e811ae16d05a91f1ae5443623e246e1246713`: all 12 observed exact-head workflows completed successfully.
- #226 exact head `134e067d8870de4aea3ceb66698ef2754a93a4cb`: all 12 observed exact-head workflows completed successfully. Its regression test rejects stale Schedule previews before any provider/archive write; this is not full live Google acceptance.
- #227 exact head `d95e57e5f336eeb6ef300c88c04b0ad14da20b27`: eight applicable exact-head workflows completed successfully (Windows, Linux, Android, Web, Cross-platform Runtime, Dependency Security, Auto Detect CI and Pull Request Gate). iOS/macOS workflows were not triggered by this workflow-only change; the iOS advisory path was deliberately aligned to the iOS build paths.
- #223 previous head `cacea6aeda5aa89851c38f9767bc05979d94ccb5` passed its three documentation-focused workflows; a follow-up evidence correction changed the head, so those earlier runs do not certify the new head.
- Post-merge workflows for main SHA `5a4e83ac42b1b383768b96828a7a932db9bf3c15` were in progress at last inspection: Build Linux and Dependency Security had succeeded; Final Gate, Windows, Android, Web, Cross-platform Runtime and Auto Detect CI were still running. Do not merge dependent feature PRs until the exact mainline Final Gate and required workflows complete successfully.
- The Web build/deploy workflow was still running. No production backend URL, live Google provider acceptance, deployed site, or deployed SHA has been verified. A skipped deployment due to missing HTTPS backend configuration is not a deployment PASS.
- No independent review approval was recorded for the owner-authored PRs at this checkpoint. Repository branch protection was observed disabled; this is recorded as governance context, not as CI evidence.
- Continue to fetch exact-head checks after every commit. Pending, cancelled, skipped, missing and unknown are never PASS.

## Repository baseline (historical checkpoint)

- Repository: `phakphum12345/phakphum-calendar`
- Branch: `main`
- Baseline SHA when this earlier checkpoint was prepared: `f7499d76a2d5111a7d37801462a4b837e5791ff9`
- This checkpoint supersedes the earlier same-date snapshot at `1f2aba7b50b59cd44a6754a7a5ea8f16ba94cef0`.

## Integrated delivery

| PR | Result | Integrated scope |
|---|---|---|
| #211 | Merged | Durable roster history / Drive revision restore through reviewed Grid import and conditional Schedule commit; reviewer-selected date-axis orientation |
| #212 | Merged | Calendar Sync coordination and durable operation ledger; ETag/managed Sync ID preconditions and confirmation-gated recovery; browser Web Push subscription/outbox, encrypted payload transport, retry and dead-letter foundations |
| #214 | Merged | Restored missing Laravel Calendar Sync coordination API feature coverage from the prior #196 implementation |
| #215 | Merged | Backend configuration gates: PR builds remain available; main/manual production artifacts and Pages deployment are skipped with explicit evidence when `ORGANIZATION_API_BASE_URL` is not a valid HTTPS URL |
| #213 | Merged | Earlier live-status documentation snapshot; superseded by this reconciliation |

PR #191 was closed as superseded after verifying its 35 changed paths were integrated by #212. PR #196 was closed as superseded after verifying the implementation paths were present and restoring its missing Laravel feature test in #214. Their closed branches are historical references, not active delivery branches.

## Current post-merge verification

- Exact post-merge main SHA: `f7499d76a2d5111a7d37801462a4b837e5791ff9`.
- All 10 workflows attached to this SHA completed with conclusion SUCCESS: Build macOS (Xcode) run `46104697338`; Build Android `46104697396`; Build Windows `46104697441`; Build iOS `46104697437`; Build Linux `46104697462`; Build and Deploy Web `46104697509`; Cross-platform Runtime `46104697456`; Auto Detect CI `46104697429`; Dependency Security `46104697646`; Final Gate `46104697404`.
- Final Gate confirmed required quality/core evidence succeeded. The non-production web build artifact was created and uploaded; GitHub Pages deployment and published-site verification were SKIPPED because no valid HTTPS backend URL was configured.
- Windows, iOS, macOS, Android and Linux analysis/test/toolchain evidence passed; their production build/package/upload steps were SKIPPED because the shared backend URL was not configured. This is not a platform release.
- PR #214's post-merge Laravel Backend CI, Cross-platform Runtime, Auto Detect CI and Dependency Security workflows all completed successfully. Laravel feature/API tests are included in run `46103367270`.
- PR #215's workflow change is verified on the merged main SHA: missing backend configuration no longer fails the whole CI, while production artifact and Pages deployment remain blocked. No backend was deployed or configured.

## Remaining work — highest priority

1. **Verify post-merge #215 behavior:** inspect all workflows on exact main SHA `f7499d76...`; confirm build/test evidence remains successful, release artifacts are explicitly skipped when backend config is absent, and Pages deployment is not performed. A skipped artifact is not a production release.
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
