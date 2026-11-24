# Phakphum Calendar — End-to-End Completion Plan

- Audit date: 2026-11-24
- Repository: `phakphum12345/phakphum-calendar`
- Audited base branch: `main`
- Audited main SHA: `c847d70b98c2693a11c1063e989c55f2ab825d04`
- Related delivery PRs: #178, #180, #181
- Status: planning baseline; not a release-readiness declaration

## 1. Mission

Deliver a calendar and shift-management application that an ordinary user can install or open, authenticate with their own Google account where Google features are enabled, configure their own shift-pay rates, and review accurate monthly shift-pay totals.

The shift-pay system must support three independent usage models:

1. **Personal** — an independent worker configures and owns their own rates. Organization membership is not required.
2. **Organization** — an organization configures shared rules and authorized members use them.
3. **Hybrid** — a user can use both personal and organization rule sets under an explicit source-selection policy. The system must never silently add both rule sets for the same assignment.

This plan is a scope and evidence ledger. It does not claim that open PRs, unfinished code, skipped workflows, or external console settings are complete.

## 2. Current baseline

### Verified repository observations

- `main` was observed at `c847d70b98c2693a11c1063e989c55f2ab825d04`.
- PR #179 (independent macOS/iOS Xcode workflow work) is merged into main.
- PR #171 membership-audit work is merged.
- PR #178 is open and proposes a post-#171 implementation-status/traceability/roadmap reconciliation. Its base is older than the current main after PR #179 and needs rebasing/reconciliation before it can be treated as current.
- PR #180 is a Draft documentation specification for three-mode shift pay and public-user readiness.
- PR #181 is a Draft implementation slice for typed Personal/Organization/Hybrid rule-source resolution. Its head at the last recorded inspection was `0951187431faf7db5331809b23ec48c84eaf88e6`.
- The current `ShiftPayCalculator` already models configured additional pay by employment type, work-day category, shift type, optional department/location/work-point/purpose, fixed amount/hourly rate/multiplier, salary-included treatment, and compensatory time.
- Shift templates already contain editable shift-type/rate data and local persistence, but this does not prove a complete user-configurable pay-profile workflow.
- Monthly reports currently summarize schedule assignments; a reconciled, auditable shift-pay statement is not yet established.
- Existing Google setup documentation still describes OAuth consent screen Testing mode. This is not public-user launch readiness.
- Platform documentation describes Android debug signing and an unsigned iOS IPA; neither is a production-distributable signed mobile release.
- Google sign-in support differs by platform; Windows/Linux public sign-in is not established.

### Evidence rule

Every status in this plan is scoped to a commit, workflow, test, platform, or external configuration. Do not generalize a successful build into a claim that a platform is installable, authenticated, or production-ready.

## 3. Workstreams and remaining work

### Workstream A — shift-pay domain and rule resolution

- [x] Existing configurable shift-pay calculator is present in the repository.
- [x] Requirements for Personal, Organization, Hybrid, and explicit hybrid precedence are documented in PR #180.
- [x] Initial typed source-resolution implementation and focused tests are proposed in PR #181.
- [ ] Review and validate PR #181 against exact-head CI; fix all static-analysis, formatting, and test findings.
- [ ] Ensure invalid Hybrid source selections cannot be silently accepted.
- [ ] Ensure mode changes and organization changes cannot leak or accidentally reuse another tenant's rules.
- [ ] Add stable rule identity, version, effective dates, active/inactive state, and deterministic specificity/conflict resolution.
- [ ] Define whether each pay rule is a fixed amount per actual shift, hourly rate, multiplier, or a combination, and validate mutually exclusive/allowed combinations.

### Workstream B — persistence and migration

- [ ] Add a versioned ShiftPayProfile repository.
- [ ] Persist Personal profiles independently of organization membership.
- [ ] Persist Organization rules under an organization-owned namespace with server-side authorization.
- [ ] Persist Hybrid mode, organization selection, precedence policy, and any assignment-level explicit source choice.
- [ ] Add schema versioning, safe migration, validation, backup/restore compatibility, and round-trip tests.
- [ ] Preserve all existing shift templates and existing historical schedule data; do not silently rewrite saved values.
- [ ] Define conflict behavior for offline edits and multi-device synchronization.

### Workstream C — configuration UI and user experience

- [ ] Add a first-run choice: Personal, Organization, or Hybrid.
- [ ] Allow Personal users to finish setup without creating or joining an organization.
- [ ] Provide editable shift types (name, code, start/end, overnight, paid hours, active state).
- [ ] Provide rule editor fields for employment type, work-day category, shift type, department, location, work point, assignment purpose, rate method, amount/rate, multiplier, currency, rounding, effective dates, salary-included treatment, and compensatory time.
- [ ] Provide explicit missing-rule, no-additional-pay, included-in-salary, and compensatory-time states.
- [ ] For Hybrid, show both matching sources and the chosen precedence; require user selection when configured to require selection.
- [ ] Show a preview calculation before saving a rule.
- [ ] Add accessibility, Thai/English localization, validation, and responsive layout.

### Workstream D — organization authorization and governance

- [ ] Define organization owner/admin/payroll-manager/member permissions for viewing, creating, editing, approving, and exporting pay rules.
- [ ] Enforce permissions at the API/data boundary, not only by hiding UI controls.
- [ ] Enforce tenant isolation for organization IDs and rule reads/writes.
- [ ] Record who changed a rule, when, old/new values, effective date, and approval context.
- [ ] Decide whether member-specific overrides are allowed and who can approve them.
- [ ] Prevent organization rules from being edited by ordinary members unless an explicit role permits it.

### Workstream E — actual roster calculation and monthly reports

- [ ] Identify the authoritative confirmed/actual assignment lifecycle state.
- [ ] Calculate pay from actual confirmed assignments; planned shifts must be labelled forecast and excluded from actual totals.
- [ ] Map every assignment to one and only one rule source and one resolved rule.
- [ ] Support overnight shifts, actual hours, breaks, work-day overrides, holidays, work point, location, department, and assignment purpose.
- [ ] Add idempotency keys to prevent duplicate calculations during import, sync, retry, or reprocessing.
- [ ] Store immutable calculation snapshots: assignment ID, rule ID/version, source, inputs, currency, rounding, formula, result, and calculation timestamp.
- [ ] Recalculate only through an explicit controlled action when rules or assignment facts change; preserve prior versions for audit.
- [ ] Add monthly pay statement rows that reconcile exactly to assignment-level detail.
- [ ] Export/print a report with totals by shift type, day category, department, employee, and rule source where permitted.
- [ ] Clearly distinguish zero pay, included-in-salary, compensatory time, missing rule, and not-yet-confirmed assignment.
- [ ] Do not present the feature as statutory payroll, tax, or legal overtime advice.

### Workstream F — Google authentication for ordinary public users

- [ ] Consolidate the two current Google authentication entry points behind one application-facing auth/session contract.
- [ ] Separate identity sign-in from authorization to Google APIs.
- [ ] Keep basic sign-in independent from optional Calendar, Drive, Sheets, and Contacts scopes.
- [ ] Request additional scopes incrementally at the point of use.
- [ ] Replace placeholder client IDs with real platform-specific public client configuration supplied through secure deployment configuration.
- [ ] Configure authorized JavaScript origins and exact redirect URIs for the deployed web origin and each native platform.
- [ ] Publish the OAuth consent application for the intended user population; resolve Google verification requirements for sensitive/restricted scopes where applicable.
- [ ] Test with a normal Google account that is not the project owner and not an OAuth test user.
- [ ] Verify cancellation, denied scopes, revoked grants, expired tokens, refresh/re-consent, sign-out, and provider outage.
- [ ] Implement and verify the supported OAuth flow and secure token storage separately for each claimed platform.
- [ ] Do not embed client secrets or service-account private keys in Flutter binaries or the public repository.

External owner actions are tracked separately in `PUBLIC_GOOGLE_AUTH_READINESS.md`; source-code changes alone cannot publish an OAuth consent app or complete Google verification.

### Workstream G — genuine installability and release

- [ ] Keep the currently documented Web, Windows, Android, iOS, and Linux build targets separate from the claim that they are installable production releases.
- [ ] Android: configure production release signing securely; verify package ID, version, permissions, checksum, and clean install.
- [ ] iOS: configure Apple signing/provisioning/distribution; verify install on a real supported device. An unsigned IPA is not installable evidence.
- [ ] Windows: package runtime dependencies, version metadata, checksum, and first-run guide; verify Google auth support before claiming Google-connected feature parity.
- [ ] Linux: package required runtime dependencies and a clean install/uninstall path; verify auth support before claiming parity.
- [ ] Web/PWA: verify GitHub Pages deployment, base path, OAuth origins/redirects, HTTPS, cache update behavior, and exact deployed source SHA.
- [ ] macOS: decide whether it is a supported product target. A workflow build or ad-hoc artifact does not imply a notarized, broadly installable application.
- [ ] Add release notes, checksums, version provenance, rollback/previous-version policy, and support matrix.
- [ ] Never commit signing keys, provisioning profiles, client secrets, or long-lived tokens.

### Workstream H — repository delivery and operational quality

- [ ] Reconcile PR #178 with current main after #179; update implementation status, traceability, and roadmap from the current base.
- [ ] Keep PR #180 as the documentation specification package and PR #181 as the first domain implementation slice until their scopes are independently reviewed.
- [ ] Verify exact-head workflows, check runs, review decisions, review threads, mergeability, and changed-file scope before every merge.
- [ ] Ensure Web deployment evidence identifies the exact deployed SHA; a successful Web build alone is not a deployment proof.
- [ ] Recheck branch protection/rulesets because the observed GitHub branch endpoint reported main as unprotected.
- [ ] Preserve no-delete policy and do not push directly to main.
- [ ] No production deployment or external OAuth configuration change without explicit authorization and required credentials.

## 4. Recommended delivery sequence

| Order | Delivery unit | Depends on | Exit condition |
|---:|---|---|---|
| 0 | Documentation baseline (this package) | Current repository audit | All requirements, owners, blockers, and acceptance tests are documented together |
| 1 | PR #181 domain resolution | Existing calculator | Exact-head checks pass; domain review and edge cases resolved |
| 2 | Shift-pay persistence and migration | Domain model | Round-trip, migration, and historical-preservation tests pass |
| 3 | Shift-pay configuration UI | Persistence | Personal setup works without organization; Organization and Hybrid flows are explicit |
| 4 | Organization authorization | Organization model/API | Cross-tenant and role tests pass |
| 5 | Assignment integration and snapshots | Domain + persistence | Each actual assignment resolves exactly one source and is idempotent |
| 6 | Monthly report and export | Assignment snapshots | Report totals reconcile to detail rows |
| 7 | Unified Google auth and public OAuth | Platform configuration | Non-tester account succeeds on each claimed platform |
| 8 | Signed installation packages | Platform signing credentials | Clean installation and first-run tests pass |
| 9 | End-to-end release verification | All prior workstreams | Full acceptance matrix passes; blockers are closed or explicitly excluded from release scope |

Do not merge a documentation PR as evidence that implementation work is finished. Keep implementation PRs small enough to review and test independently.

## 5. Scope boundaries and non-goals

- Avoid new paid backend or SaaS dependencies unless a concrete requirement cannot be met with existing infrastructure.
- Do not introduce a paid service as a prerequisite for Personal mode.
- Do not silently add personal and organization pay amounts together.
- Do not invent rates, holiday calendars, legal entitlements, or payroll deductions.
- Do not rewrite historical templates, assignments, or pay calculations silently.
- Do not claim production installability from unsigned/debug artifacts.
- Do not claim public Google sign-in from a test-user-only OAuth configuration.
- Do not commit secrets or signing credentials.
- Do not delete existing files as part of this delivery plan.

## 6. Release definition

The requested user journey is complete only when an ordinary user can:

1. install/open a supported release;
2. create or sign in to an account with a normal Google account where Google sign-in is advertised;
3. choose Personal without organization membership, or join/use Organization, or configure Hybrid;
4. define shift types and rates;
5. enter/import a roster and distinguish planned from actual/confirmed work;
6. calculate shift pay with an inspectable source and rule snapshot;
7. reconcile assignment-level details to a monthly report;
8. retain data across restart, update, and supported backup/restore paths.

A platform or capability that has not passed its acceptance tests must be labelled unsupported, blocked, or unknown rather than complete.
