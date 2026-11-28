# Remaining Work Index

**Current baseline:** 2026-11-28 — \`main\` checkpoint \`f7499d76a2d5111a7d37801462a4b837e5791ff9\`.

> The dated PR lists and execution notes retained below are historical snapshots, not current repository state. Use [Live Project Status](project/LIVE_PROJECT_STATUS_2026-11-28.md), [Completion Status](COMPLETION_STATUS.md), and [Remaining Acceptance](project/REMAINING_ACCEPTANCE_2026-11-28.md) as the current source of truth.

## Immediate P0 — verify the latest merged CI

- [ ] Inspect every post-merge workflow for exact main SHA \`f7499d76...\`.
- [ ] Verify Windows, Web, Android, iOS, macOS, Linux, Auto Detect CI, Cross-platform Runtime, Dependency Security and Final Gate terminal outcomes.
- [ ] Confirm absent/invalid \`ORGANIZATION_API_BASE_URL\` results in explicit SKIPPED production artifacts and no Pages deployment, without hiding test/build failures.
- [ ] Record the resulting exact SHA and run IDs in the live status checkpoint.

## P0 — shared backend and live integrations

- [ ] Provision/configure the intended self-hosted Laravel API with HTTPS, database, transaction/locking support, secrets, health checks, backups and restore procedure.
- [ ] Run migrations and validate tenant/owner authorization and idempotency.
- [ ] Perform controlled Google Calendar multi-client concurrency, ETag, ambiguous-outcome and restart-recovery acceptance.
- [ ] Configure VAPID and scheduled outbox worker; verify real browser subscription and delivery lifecycle.
- [ ] Record operational evidence; do not infer it from CI mocks.

## P0 — universal roster and data integrity

- [ ] Validate original representative workbooks with horizontal, vertical and mixed table sections, merged/multi-level headers, multiple departments and partial/cross-month periods.
- [ ] Preserve source coordinates, provenance, corrections, review decisions, given/received/cancelled overrides and existing Schedule data through import, re-sync and restore.
- [ ] Verify every production Schedule writer uses the intended atomic conditional commit and stale-client protection.
- [ ] Test crash recovery, duplicate prevention, conflict UI and cross-device behavior.

## P0 — Shift Pay

- [ ] Complete Personal / Organization / Hybrid rule-source resolution and first-run mode selection.
- [ ] Persist profiles/rules with schema versioning and safe migration.
- [ ] Link only confirmed/fulfilled assignments to calculations; distinguish forecasts and unfulfilled Google events.
- [ ] Add immutable calculation snapshots, duplicate prevention, exact decimal/rounding rules, monthly statements and assignment-level reconciliation.
- [ ] Verify personal mode without an organization and tenant isolation for organization mode.

## P0 — public identity and AI Assistant

- [ ] Separate basic Google identity from optional Calendar/Drive/Sheets scopes; configure OAuth clients, origins and redirects; verify a normal non-tester account.
- [ ] Prove the complete AI Assistant request path; add offline documentation-grounded help.
- [ ] If live AI/research is advertised, configure server-side providers, retrieval/citations, authorization, privacy, quotas, safe failure behavior and audit.
- [ ] Require explicit preview/confirmation for write actions and retain deterministic parsing as authoritative.

## P1 — release readiness

- [ ] Configure production backend before enabling release artifact and Pages deployment gates.
- [ ] Android signing and clean-device install; iOS signing/provisioning and real-device install.
- [ ] Windows/Linux dependency and clean-machine install checks.
- [ ] Web deployment, health smoke test and exact deployed-SHA verification.
- [ ] Decide macOS support scope and document ad-hoc signing/notarization accurately.
- [ ] Publish versioned release notes, checksums, installation guide and rollback/restore procedure.

## P1 — docs and governance

- [ ] Reconcile every Markdown file against current implementation and mark dated snapshots as historical.
- [ ] Maintain requirement-to-source-to-test traceability for each workstream.
- [ ] Verify branch protection/rulesets and exact required status-check names through repository settings.
- [ ] Keep PR/CI status current; do not merge stale branches or use historical green checks as current evidence.

## Rules

- A skipped, absent, cancelled, pending, unknown or stale check is not PASS.
- Never push directly to \`main\` or force-update a shared branch without explicit reconciliation.
- Do not mutate production data, external Calendar, OAuth or deployment settings without the required authorization.
- Preserve existing user data, API/schema compatibility, business logic, overrides and unfinished work.
