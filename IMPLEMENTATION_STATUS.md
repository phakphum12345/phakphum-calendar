# Repository Implementation Status

## Current main snapshot — 2026-11-23

**Verified main SHA:** `9efb98c9d6e5ae5f60f919d5e1a24fac4c2bd35b`

This section supersedes earlier historical snapshots below. Older entries are retained for audit history and must not be used as current PR or release status.

| Item | Current observation | Status |
|---|---|---|
| Default branch | `main` | PASS |
| Open PRs | 1 — PR #171 (Organization Membership Audit UI) | IN_PROGRESS |
| PR #170 | Closed as superseded by #171; not merged | SKIPPED |
| Issue tracker | Disabled (`has_issues: false`); no issue list is available | UNKNOWN |
| Main branch protection | GitHub reports `protected: false` | FAIL |
| Local working tree | Not available through GitHub API | UNKNOWN |
| Current-SHA workflow runs | Auto Detect CI and Cross-platform Runtime both completed successfully | PASS |
| Current-SHA check runs | 7 of 7 completed with conclusion `success` | PASS |
| Current-SHA Web deployment | No deployment run for this documentation-only SHA | UNKNOWN |
| Latest verified deployed application-source SHA | `4618ab98b0fc371f32f08d3299365f577fa81674` | PASS (historical deployment evidence) |
| Exact current-main published metadata | Not verified against `9efb98c9d6e5ae5f60f919d5e1a24fac4c2bd35b` | UNKNOWN |

### Exact-SHA CI evidence

Current main `9efb98c9d6e5ae5f60f919d5e1a24fac4c2bd35b`:
- Auto Detect CI run [45155822259](https://github.com/phakphum12345/phakphum-calendar/actions/runs/45155822259): SUCCESS.
- Cross-platform Runtime run [45155822214](https://github.com/phakphum12345/phakphum-calendar/actions/runs/45155822214): SUCCESS.
- Seven check runs completed successfully: Dart/Flutter quality, platform activation summary, Linux PowerShell launcher smoke test, Linux POSIX full quality suite, capability detection, Windows CMD launcher smoke test, and Windows PowerShell full quality suite.

These results do not imply that every platform release build, Laravel workflow, Pages deployment, or PR Final Gate ran on this exact SHA.

### Deployment relationship

The latest observed successful Web deployment and Final Gate are run [45129035935](https://github.com/phakphum12345/phakphum-calendar/actions/runs/45129035935) and [45129036049](https://github.com/phakphum12345/phakphum-calendar/actions/runs/45129036049), respectively, on application-source SHA `4618ab98b0fc371f32f08d3299365f577fa81674`.

A GitHub compare from that deployed source SHA to current main `9efb98c9d6e5ae5f60f919d5e1a24fac4c2bd35b` reports only documentation changes:
- `IMPLEMENTATION_STATUS.md`
- `REQUIREMENTS_TRACEABILITY.md`
- `docs/END_TO_END_COMPLETION_AUDIT_2026-11-23.md`
- `docs/REPOSITORY_AUDIT.md`

Therefore the application source tree is unchanged from the last verified deployed application-source SHA. However, the published deployment metadata has not been verified against current main `9efb98c9d6e5ae5f60f919d5e1a24fac4c2bd35b`; strict exact-main-SHA deployment status remains UNKNOWN. PR #171 is not merged and is not part of the deployed application.

### Current source-level findings

| Area | Current evidence | Status |
|---|---|---|
| Roster date validation | Parser detects duplicate days, missing dates, out-of-order dates and date-sequence mismatches; conversion skips sections with blocking date anomalies | PASS (guard exists; source-specific workbook outcomes remain unverified) |
| X-OPD November 2569 | Reported malformed header requires original workbook/cell layout to confirm intended dates | UNKNOWN |
| US Clinic ภปร.4 | Markdown header alone does not reproduce the reported offset; original workbook is required | UNKNOWN |
| Calendar sync | Planner/executor/reconciliation and regression tests exist; live authorized Google account behavior is not verified | UNKNOWN |
| Historical roster restore | Revision/timeline support exists, but a complete safe restore workflow was not found | PARTIAL |
| Web Push | Browser subscription and authenticated API storage exist; VAPID sender, RFC 8291 encryption, durable queue/scheduler, retries and user-facing opt-in controls are not implemented | PARTIAL |
| Membership audit | Backend audit writes and manager-protected paginated read endpoint exist. Flutter integration is proposed in PR #171 and has not merged | IN_PROGRESS |
| Responsive UI | Requires screen-by-screen device-width verification | UNKNOWN |
| Performance | No repository-wide baseline verified | UNKNOWN |
| Security / tenant isolation | Existing authorization and backend tests exist; further focused review remains | UNKNOWN |

### Immediate next work

1. Complete exact-head CI for PR #171. Merge only when all required checks pass; then verify merge SHA and post-merge main CI.
2. Obtain the original X-OPD and US Clinic ภปร.4 workbook/export. Do not infer or silently repair date headers.
3. Complete Web Push delivery only after VAPID configuration and a supported scheduler/worker strategy are defined; do not invent credentials.
4. Define and implement safe historical restore preview/confirmation. Any Drive write-scope expansion requires separate explicit approval.
5. Complete targeted security/tenant-isolation, responsive UI, performance and critical E2E audits.
6. Verify a production deployment whose published metadata exactly matches the main SHA before claiming strict release readiness.

**Snapshot date:** 2026-11-23
**Snapshot base:** `main` at `9efb98c9d6e5ae5f60f919d5e1a24fac4c2bd35b`
**Scope:** Whole repository, Flutter client, Laravel API, persistence, synchronization, CI/CD, security and documentation.

> This is a point-in-time engineering inventory, not a declaration that the repository is complete or production-ready. Source code, migrations, exact-head CI and observed runtime behavior take precedence over this document. `SKIPPED` and `UNKNOWN` are never treated as `PASS`.

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
