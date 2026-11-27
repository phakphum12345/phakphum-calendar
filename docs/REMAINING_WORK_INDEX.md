## Live execution checkpoint — 2026-11-27

- Audited `main`: `68ef85361c2d08e2970160a36475592010d908f7`.
- Existing Draft PRs: #191, #192, #196 and #199; new vertical-parser integration PR #200.
- Exact-head workflow results for #191 (10/10), #192 (14/14), #196 (13/13) and #199 (11/11) were observed successful. These are CI results only; product/backend/provider acceptance remains open.
- PR #200 adds a first vertical date-axis parser slice. Its initial exact-head CI exposed a missing orientation import; that was fixed in a later commit. Do not reuse the earlier failed result as the current head's status.
- No PR is accepted or merged by this checkpoint. Re-fetch the exact latest PR head and all associated workflow runs before changing status.
- Original X-OPD November 2569, 16 Nov–15 Dec 2569 and US Clinic ภปร.4 workbooks have not been validated from the actual source files in this execution.
- New evidence ledgers: [Completion Status](COMPLETION_STATUS.md) and [Implementation Evidence](IMPLEMENTATION_EVIDENCE.md).

# Remaining Work Index — 2026-11-27

This is the concise execution checklist. The detailed design and test criteria are in the linked documents.

## P0 — Required for the requested feature

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
