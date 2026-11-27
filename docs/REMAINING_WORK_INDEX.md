# Remaining Work Index — 2026-11-27

## Current checkpoint — 2026-11-27

The checklist below is a historical backlog baseline. Use this checkpoint for current execution order and status.

| Priority | Work | Current implementation | Still missing |
|---|---|---|---|
| P0 | Universal roster import | #192: orientation-aware section parsing, CSV/TSV/TXT path, XLSX merged/color provenance, source fingerprint and review workflow | Exact-head CI, original workbook acceptance, reviewer-selected ambiguity path and identity collision acceptance |
| P0 | Schedule persistence | #192: snapshot-bound CAS and journal recovery consolidation | Cross-device/backend transaction proof, all-writer audit, conditional tombstone delete and recovery drill |
| P0 | Calendar Sync | #196: ETag, durable operation coordination and retry/recovery foundation | Controlled real test calendar, provider ambiguous-timeout acceptance and cross-device contention |
| P0 | Notifications | #191: VAPID sender, subscription ownership, outbox worker, retry/dead-letter and scheduler command | Registered device delivery and deployed scheduler acceptance |
| P0 | Shift Pay | #181/#183/#186 merged foundations; #201 conflict/precedence and #203 statement calculation core | Durable statement persistence/UI, confirmed-assignment source, exact contractor employment/payment rules and historical acceptance |
| P0 | Generation | #202 immutable preview/approval/conditional commit foundation | Revalidate against latest #192 base, UI integration and end-to-end read-back/recovery |
| P1 | History restore | #204 Drive revision picker, read-only source fingerprint, Grid review and CAS commit | Per-assignment diff and original revision/external-account acceptance |
| P1 | Organization/security | Existing membership/role foundations | Tenant-isolation negative tests, backend authorization audit, rate-limit and privacy-log review |
| P1 | Quality/accessibility/performance | Existing CI and responsive components | Reproducible large-workbook/event/history benchmarks, memory, keyboard and screen-reader tests |
| P1 | Public Google access | Existing auth foundation | Non-owner account verification, OAuth client/consent publication and platform lifecycle acceptance |
| P1 | Production release | Existing build workflows and self-hosted runner | Exact deployed SHA, API health, signing, backup/restore, rollback and release evidence |
| P2 | AI Assistant / Research | Documentation and provider foundations | Complete request path, provider readiness, safe tools, citations, quotas, privacy and deployed-runtime acceptance |

### Current PR and merge policy

- Open Draft PRs: #191, #192, #196, #201, #202, #203 and #204.
- #199 was closed without merge after orientation work was superseded by #192.
- No open PR has a submitted review or review thread.
- #191 CI: 13/13; #196: 13/13; #201: 12/12; #202: 12/12; #203: 11/11 (716 tests). #192 and #204 have new commits whose exact-head CI is pending.
- #202 and #204 are stacked on #192; #203 is stacked on #201. Reconcile their base/head relationships after the dependency PR is accepted.
- `main` is `68ef85361c2d08e2970160a36475592010d908f7`; branch protection is disabled and required checks are not enforced. No exact-main workflow/status evidence was returned for this SHA.
- No merge or production-ready claim is allowed until exact-head checks, complete diff review, independent review and applicable external acceptance are complete.


This is the concise execution checklist. The detailed design and test criteria are in the linked documents.

## Historical backlog baseline — shift-pay scope (2026-11-24)

- [ ] Validate and complete PR #181: typed Personal / Organization / Hybrid rule-source resolution.
- [ ] Add versioned persistence for profiles and rules.
- [ ] Add first-run mode selection and complete rate/shift-type editor.
- [ ] Ensure Personal mode works without an organization.
- [ ] Add organization role checks and tenant isolation.
- [ ] Connect actual/confirmed roster assignments to one resolved rule source.
- [ ] Add immutable calculation snapshots and duplicate prevention.
- [ ] Add monthly pay statement and assignment-level reconciliation.
- [ ] Add full end-to-end tests for all three modes.

## P0 — Required for a genuinely usable AI Assistant

- [ ] Re-audit current AI Support wiring and prove the complete request path.
- [ ] Implement reliable local/offline help grounded in versioned app documentation.
- [ ] Add real server-side provider readiness and at least one owner-approved live provider integration if live AI is advertised.
- [ ] Add authenticated backend execution, organization/roster authorization, tenant isolation, quotas, timeouts, and safe errors.
- [ ] Connect only user-selected roster context with explicit consent and data minimization.
- [ ] Keep deterministic parsing authoritative; AI suggestions require source evidence and user review.
- [ ] Implement real external research retrieval and verifiable citations before advertising AI Research.
- [ ] Add bounded read-only tools, then preview/confirmation for any write action; never bypass calendar sync confirmation.
- [ ] Define conversation/report retention, deletion, privacy, audit, and prompt-injection defenses.
- [ ] Pass normal-user, offline, provider-failure, security, no-write, and deployed-runtime tests.

Detailed plan: [AI Assistant end-to-end completion](AI_ASSISTANT_END_TO_END_COMPLETION.md).

## P0 — Required for public-user access

- [ ] Consolidate duplicate Google authentication services.
- [ ] Separate basic identity login from optional Google API scopes.
- [ ] Configure real OAuth client IDs, origins, and redirect URIs.
- [ ] Complete Google consent publication/verification steps as required.
- [ ] Verify login with a non-owner, non-tester Google account.
- [ ] Verify each platform's OAuth, refresh, sign-out, and secure-storage lifecycle.

## P0 — Required before claiming installable production releases

- [ ] Android production signing and clean-install verification.
- [ ] iOS signing/provisioning and real-device installation verification.
- [ ] Windows/Linux package and dependency verification.
- [ ] Web Pages deployment and exact deployed-SHA verification.
- [ ] Decide whether macOS is in supported release scope; document actual signing/notarization state.
- [ ] Publish versioned release notes, checksums, and install guide.

## P1 — Repository reconciliation and release hardening

- [ ] Rebase/reconcile PR #178 against current main after PR #179.
- [ ] Review PR #180 docs package and PR #181 implementation independently.
- [ ] Verify main branch protection/rulesets and required status-check policy.
- [ ] Ensure deployment gate verifies the Deploy job and published exact SHA, not only parent workflow success.
- [ ] Refresh README/docs index and current implementation/traceability/roadmap snapshots after each merged delivery unit.

## Existing backlog outside the immediate shift-pay/public-auth release scope

These items were previously identified in repository audit documentation and should remain separately prioritized; they are not prerequisites to falsely mark shift-pay or Google Auth complete:

- [ ] Scheduled platform notifications with verified background delivery behavior.
- [ ] Drive revision restore workflow (distinct from read-only history/timeline viewing).
- [ ] Complete cross-month weekly schedule behavior and the year overview.
- [ ] Organization member role changes, soft removal, and reactivation.
- [ ] Responsive UI/performance baselines and production runtime verification.
- [ ] Reconcile automatic GitHub Pages deployment and Final Gate behavior.

## Rules

- A skipped, absent, cancelled, or unknown CI check is not PASS.
- All CI results must match the exact PR head SHA under review.
- No direct push to main and no file deletion.
- Do not deploy or change external OAuth settings without explicit authorization.
- Do not add paid dependencies unnecessarily.
