# Repository Implementation Status

## Current main snapshot — 2026-11-24

**Verified main SHA:** `dcb51b6ad7db3540eea7152949556465ea67256c`

This is a source-backed snapshot of the current default branch. It supersedes earlier snapshots below; historical sections remain for audit history only.

| Item | Current observation | Status |
|---|---|---|
| Default branch | `main` at `dcb51b6ad7db3540eea7152949556465ea67256c` | PASS |
| Open pull requests | #150, #163, #171 and #172 observed open | IN_PROGRESS |
| Open issue tracker | Repository issue tracking is disabled; an empty issue search is not proof of no work | UNKNOWN |
| Main branch protection | Not re-verified in this reconciliation | UNKNOWN |
| Exact-main-SHA PR workflow evidence | No PR-triggered workflow runs were returned for this merge commit | UNKNOWN |
| Latest verified deployed application-source SHA | `4618ab98b0fc371f32f08d3299365f577fa81674` | Historical evidence only |
| Deployment of current main | Current main is 34 commits ahead of the last verified deployed source; exact published metadata for `dcb51b6` is not verified | UNKNOWN |

### Current pull-request reconciliation

| PR | Current observation | Decision |
|---|---|---|
| #150 | Open; latest diff changes only `DOCUMENTATION_INDEX.md`, `IMPLEMENTATION_STATUS.md` and `REQUIREMENTS_TRACEABILITY.md`, including removal of current status material. API and database guides already exist on main. | Do not merge this stale/reverting documentation diff. |
| #163 | Open; GitHub compare reports zero changed files against current main. The year overview and selector are already present in `ScheduleWorkspacePage` and `ScheduleYearOverview` on main. | No-op PR; do not merge. |
| #171 | Open; membership-audit Flutter gateway/UI and tests are proposed. Main exact-head CI evidence is not complete; Build iOS remains queued in the observed run. | Keep open pending exact-head checks and final review. |
| #172 | This documentation refresh branch. Its earlier snapshot referenced main SHA `9efb98c`, which is superseded by `dcb51b6`. | Refresh this snapshot and validate its exact head. |

PR #162 is already merged. PR #173 is merged as `dcb51b6ad7db3540eea7152949556465ea67256c`; it adds exchange-and-return transaction composition and transaction-history filters. No claim is made here that current main has been deployed.

### Source-level gap register

| Area | Evidence on current main | Status | Required next work |
|---|---|---|---|
| Calendar day/week/month/year views | `ScheduleWorkspacePage` selects day, week, month and year; `ScheduleYearOverview` renders the 12-month view. | IMPLEMENTED FOUNDATION | Verify widget coverage, narrow-width layout, year navigation and month-selection regressions. PR #163 has no diff. |
| Organization membership audit | Backend audit writes/read endpoint exist; Flutter gateway, panel and tests are proposed in #171. | IN_PROGRESS | Complete exact-head CI, permission/tenant-isolation review and post-merge verification. |
| Notifications/reminders | `NotificationService` is an abstract interface; no concrete platform delivery implementation is present in the inspected source. | MISSING | Decide supported platforms/background behavior; add permission-aware implementation, scheduling/cancellation, tests and user controls. |
| Historical roster restoration | `RosterRevisionService` explicitly reads Drive revisions only and never writes to Drive/Sheets. | PARTIAL | Define preview, conflict handling, confirmation, audit and recovery. Any Drive write-scope expansion requires separate explicit approval. |
| Web Push | Subscription/API groundwork exists; VAPID sender, RFC 8291 encryption, durable delivery queue/scheduler, retry and opt-in controls remain unimplemented in the prior source audit. | PARTIAL | Verify current backend source, then implement only with configured secrets and a supported worker/scheduler. |
| Calendar sync live integration | Planner/executor/reconciliation and regression tests exist. | UNKNOWN | Verify authorized Google account behavior, idempotency and recovery without modifying real calendars during tests. |
| Workbook edge cases | Date validation blocks malformed sections; X-OPD November 2569 and US Clinic ภปร.4 issues require original workbooks to confirm intended cell/date layouts. | UNKNOWN | Obtain original source workbooks; never infer or silently repair dates. |
| Responsive UI | Year overview adapts columns at width breakpoints; full screen-by-screen device verification is not established. | NEEDS REVIEW | Test mobile, tablet and desktop layouts across critical workflows. |
| Performance | No repository-wide benchmark baseline is established. | UNKNOWN | Add reproducible large-workbook, event-volume, memory and long-history benchmarks. |
| Local data protection | Timeline/revision snapshots use local persistence; encryption and retention behavior require focused review. | NEEDS REVIEW | Document data classification, retention, encryption and recovery requirements before changing storage. |
| API/database documentation | `backend/API_DOCUMENTATION.md` and `backend/DATABASE_SCHEMA.md` are present on main. Migrations remain authoritative. | IMPLEMENTED FOUNDATION | Keep route, authorization and constraint descriptions synchronized with source/migrations. |
| Roadmap and traceability | Existing roadmap is version-only and does not map phases to acceptance evidence. | NEEDS REVIEW | Use the reconciled, evidence-based roadmap and traceability matrix in this PR. |

### CI and release qualification

- CI states must be tied to the exact head SHA. Queued, in-progress, cancelled, skipped or missing checks are not PASS.
- The current PR checks for #150, #163 and #172 are still queued/in progress in the latest observed run set; #171 has successful core checks but its iOS build was still queued.
- The latest observed successful Web deployment was on application-source SHA `4618ab98b0fc371f32f08d3299365f577fa81674`. Current main `dcb51b6` includes later application changes, so the deployed site must not be represented as current-main verified.
- The Web workflow is configured to build on main pushes and deploy Pages only on `refs/heads/main`; this configuration does not itself prove a successful deployment for the current SHA.
- Composer dependency remediation and the `composer audit --locked` CI gate were merged previously in PR #154; re-run the audit on the current relevant head before release claims.

### Immediate execution order

1. Finish exact-head CI and review for PR #171; merge only if every required gate passes.
2. Close or supersede no-op/stale documentation PRs only after preserving any unique, still-valid material; do not merge #150 or #163 as they currently stand.
3. Complete concrete notification delivery as a separately scoped implementation with platform and background-delivery requirements.
4. Design safe historical restore as a separate reviewed workflow; do not expand OAuth scopes or write to user calendars without explicit approval.
5. Add responsive, performance, data-protection and critical E2E evidence.
6. Verify the Pages deployment metadata against the exact current main SHA before claiming production readiness.

**Snapshot date:** 2026-11-24  
**Snapshot base:** `main` at `dcb51b6ad7db3540eea7152949556465ea67256c`

> This inventory is not a declaration that the repository is complete or production-ready. Source code, tests, exact-head CI and observed runtime behavior take precedence. `SKIPPED` and `UNKNOWN` are never treated as `PASS`.

## Repository evidence

| Item | Observed state |
|---|---|
| Default branch | `main` |
| Main SHA | `e9ed13fb2f0ed82571ce7f2b39b57503d04e5ce5` |
| Open issues | 0 (verified 2026-11-22) |
| Open PRs | 5 — PRs #160–#164 are open and not merged; #163 is stacked on #162 |
| Test files | 157 Dart test files |
| GitHub workflow YAML files | 18 (plus `README.md` in the directory) |
| Markdown files | 118 |
| Main Flutter shell | `lib/ui/app_shell.dart` — 5,717 lines |
| Main application controller | `lib/controller/app_controller.dart` — 3,162 lines |
| Main branch protection | UNKNOWN — branch-protection endpoint returned HTTP 403; repository rulesets endpoint returned an empty list |
| Current main CI | PASS for 10 observed workflow runs on `e9ed13f`; Web build succeeded but its nested GitHub Pages deployment job was SKIPPED |

The branch-protection state remains UNKNOWN because the connected integration could not read that endpoint. Repository settings and security rules were not changed.

## Recent merged work

| PR | Result | Scope | Remaining qualification |
|---|---|---|---|
| #145 | MERGED | Dependabot version-update configuration | Does not itself remediate Composer advisories |
| #148 | MERGED | Deterministic Calendar event IDs and reconciliation after ambiguous insert outcomes | Post-merge CI must remain green |
| #149 | MERGED | Bounds user-supplied email before Laravel email validation | PHP/Laravel suite: 42 tests, 278 assertions; defense-in-depth only |
| #151 | MERGED | Restricts shift transaction metadata to bounded `note` and `schedule_id` keys | Merge commit `9397693422b28fdd29bb395cbe5cc61635609dc5`; exact-head Laravel CI passed |
| #152 | MERGED | Removes untrusted client diagnostic message text from server log context | Merge commit `f275518b3dec97c77e525b036bd1c8c1eca55426`; exact-head Laravel and Flutter quality CI passed |
| #153 | MERGED | Adds repository completion index, requirements traceability and API/database guides | Merge commit `8ef620213ef8629d64bf0d916ee0688e298bfd3b`; exact-head CI passed and 35 documentation links verified |
| #154 | MERGED | Updates vulnerable Composer dependency graph and adds `composer audit --locked` CI gate | Merge commit `e3c248480ebc55aa4b552cafb2291be9d00c0ecc`; exact-head Laravel, Flutter, Windows, Android, iOS, Linux, Web and PR Gate checks passed; Pages deployment skipped |
| #157 | MERGED | Adds exact-SHA DISKPATH manifest regeneration and validation workflow | Merge commit `a88e69cd167ea4a8d565dd55ee64fc7a38b78d73`; PR review and inline threads returned empty; exact PR-head workflow evidence not rechecked in this snapshot |
| #158 | MERGED | Enforces Flutter lockfile and adds informational Dart formatting baseline audit | Merge commit `df7dfe694d23695e62cc1798589323e8d4f4e65f`; maintenance-branch PR; exact-head evidence was promoted and revalidated by #159 |
| #159 | MERGED | Promotes lockfile enforcement, formatting baseline and DISKPATH manifests to `main` | Merge commit `e9ed13fb2f0ed82571ce7f2b39b57503d04e5ce5`; exact PR head `df7dfe694d23695e62cc1798589323e8d4f4e65f`; 11 workflows completed successfully; nested Pages deployment job was SKIPPED; post-merge main checks remain UNKNOWN |
| #147 | Previously merged | Google ID-token verification hardening | Retain regression coverage |
| #144 | MERGED | Preserve managed events outside selected roster months; November/December E2E regression | Exact-head CI: 10 PASS, 1 SKIPPED (Pages); post-merge main CI evidence remains UNKNOWN |

## Current work

| Area | Status | Evidence / next gate |
|---|---|---|
| November/December selected-month synchronization | MERGED, POST-MERGE VERIFICATION | PR #144 merged as `5a8f2a6f…`; exact-head CI passed and regression verifies that December sync preserves November events |
| Calendar insert idempotency | IMPLEMENTED, POST-MERGE VERIFICATION | PR #148 is merged; monitor main CI and provider reconciliation |
| Backend email validation guard | MERGED | PR #149 PHP/Laravel suite: 42 tests, 278 assertions |
| Shift transaction metadata bounds | MERGED | PR #151; metadata is restricted to bounded `note` and `schedule_id`; exact-head Laravel CI passed |
| Composer dependency remediation | MERGED, POST-MERGE VERIFICATION | PR #154 merged; updated lockfile audit returned zero advisories and exact-head CI passed; #158/#159 enforce the committed Flutter lockfile; main post-merge CI status remains UNKNOWN |
| Flutter dependency reproducibility / formatting baseline | MERGED, POST-MERGE VERIFICATION | PR #159 merged; exact-head Auto Detect CI, static analysis, unit and integration tests passed; 124 of 524 Dart files remain in the informational formatting backlog; Pages deployment job was SKIPPED |
| Historical roster timeline | PARTIAL | Revision archive and ownership-history display exist; a complete restore workflow was not found |
| Notifications and reminders | PARTIAL | In-app shift/conflict alerts exist; `NotificationService` is an interface and is not wired to a concrete scheduled platform-delivery implementation |
| Day / week / month / year calendar views | IN_PROGRESS | Day, week and month pages exist; a week-crossing-month defect is addressed in PR #162; the responsive 12-month year overview is proposed in stacked PR #163 |
| Organization membership administration | IN_PROGRESS | Create, member listing, join-request and approval flows exist; role-change and soft-removal API/UI work is proposed in PR #164 with owner protection and reactivation tests |
| Responsive UI | NEEDS REVIEW | Large app shell; mobile/tablet/desktop behavior needs a dedicated screen-by-screen audit |
| Performance | UNKNOWN | No repository-wide performance baseline or benchmark suite was identified |
| Documentation | MERGED, ONGOING MAINTENANCE | Central index, implementation status, requirements traceability and API/database guides are merged; continue keeping them synchronized |

## Security findings

### Composer dependencies

The pre-remediation backend lockfile was reported by Composer audit as having **27 advisories across 8 packages**. PR #154 updated the dependency graph; exact-head `composer audit --locked` returned exit code 0 with an empty advisory list, and Laravel CI now runs this audit on every relevant change. The following were the pre-remediation locked versions:

| Locked package | Locked version | Patched version identified |
|---|---:|---:|
| `laravel/framework` | 13.22.0 | 13.43.0 or later |
| `league/commonmark` | 2.8.3 | 2.10.2 or later |
| `guzzlehttp/guzzle` | 7.15.1 | 7.15.2 or later |
| `symfony/http-foundation` | 8.1.1 | 8.1.11 or later |
| `symfony/routing` | 8.1.0 | 8.1.11 or later |

The vulnerable lockfile has been remediated and the CI audit gate is merged. Keep post-merge verification UNKNOWN until a completed `main` workflow is observed; continue reviewing local data protection and other security findings separately.

PR #149 hardened email validation. PR #154 separately upgraded the framework and transitive dependency graph and added the CI audit gate.

### Logging and local persistence

- `ClientErrorController` previously logged the client-provided `message` field. PR #152 is merged; the controller removes the free-form message from log context and retains only its character length. Post-merge runtime verification remains pending.
- `ShiftTransactionController` now restricts metadata to `note` (maximum 1,000 characters) and `schedule_id` (maximum 128 characters) through merged PR #151.
- Timeline/revision snapshots are cached locally through SharedPreferences. Review the privacy implications and evaluate encrypted local persistence for sensitive roster content.
- Google ID tokens are verified by the backend middleware; keep tokens and credentials out of logs and source control.

## Functional gaps requiring follow-up

1. Verify post-merge main CI for PR #144 and retain the November/December regression proving that syncing one selected month never deletes another unselected month.
2. Verify post-merge `main` CI for PR #154 and retain the Composer audit gate.
3. Decide supported notification platforms and whether reminders must fire while the app is closed, then implement and wire concrete delivery with permission handling; current in-app shift alerts are not scheduled delivery.
4. Define and implement historical restoration semantics. `GoogleAuthService.readAccessScopes` currently requests Drive read-only scopes; restoring to Drive requires an explicitly approved OAuth write-scope expansion and a safe preview/confirmation flow.
5. Review timeline generation for blank/unassigned cells and removed roster positions.
6. Complete a dedicated mobile/tablet/desktop UI audit and reduce the oversized app shell through incremental, tested extraction.
7. Verify PR #162's complete seven-day week behavior and PR #163's 12-month year overview; both remain unmerged.
8. Verify PR #164's owner/admin role-change and soft-removal workflows, reactivation path, and access revocation tests.
9. Add performance baselines for large workbooks, large event sets and long sync histories.
10. Verify post-merge behavior for client diagnostic log redaction from PR #152.
11. PR #161 proposes automatic Pages deployment on `main` pushes, exact-SHA deployment metadata, HTTP smoke tests, and a Final Gate that requires the deploy job itself to succeed. The fix remains unmerged.
12. Keep API and database documentation synchronized with implementation and update this status after each meaningful merge.

## Completion rules

A module is complete only when its source implementation, relevant tests, integration behavior, security implications, documentation and post-merge evidence agree. A passing build alone is insufficient. Any destructive data operation, database reset, destructive migration, repository-setting change or deployment must follow the repository's approval policy.

## Status vocabulary

- **PASS** — verified on the exact current commit with the required evidence.
- **FAIL** — a required behavior or check failed.
- **SKIPPED** — not executed; never a pass.
- **UNKNOWN** — evidence is missing or inconclusive.
- **IN_PROGRESS** — active implementation or CI work.
- **MISSING** — no implementation was found.
- **PARTIAL** — some implementation exists, but the full requirement is not met.
- **NEEDS REVIEW** — implementation exists but has not received sufficient targeted verification.
