# Repository Implementation Status

**Snapshot date:** 2026-11-22  
**Snapshot base:** `main` at `168559498de58a071ac43a81e410227f0f83ec4b`  
**Scope:** Whole repository, Flutter client, Laravel API, persistence, synchronization, CI/CD, security and documentation.

> This is a point-in-time engineering inventory, not a declaration that the repository is complete or production-ready. Source code, migrations, exact-head CI and observed runtime behavior take precedence over this document. `SKIPPED` and `UNKNOWN` are never treated as `PASS`.

## Repository evidence

| Item | Observed state |
|---|---|
| Default branch | `main` |
| Main SHA | `168559498de58a071ac43a81e410227f0f83ec4b` |
| Open issues | 0 (verified 2026-11-22) |
| Open PRs | 3 — #160 (stale docs), #163 (superseded stacked year-view PR), and #165 (replacement year-view PR) |
| Test files | 158 Dart test files (`test/**/*_test.dart`) |
| GitHub workflow YAML files | 18 (plus `README.md` in the directory) |
| Markdown files | 125 |
| Main Flutter shell | `lib/ui/app_shell.dart` — 5,717 lines |
| Main application controller | `lib/controller/app_controller.dart` — 3,162 lines |
| Main branch protection | UNKNOWN — branch-protection endpoint returned HTTP 403; repository rulesets endpoint returned an empty list |
| Current main CI | IN_PROGRESS on `168559498de58a071ac43a81e410227f0f83ec4b`: 8 workflow runs observed; Linux and Web workflows completed successfully, 6 other workflows were queued or in progress at audit time. Pages deploy job and exact-SHA published metadata smoke test both succeeded. |

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
| #154 | MERGED | Updates vulnerable Composer dependency graph and adds `composer audit --locked` CI gate | Merge commit `e3c248480ebc55aa4b552cafb2291be9d00c0ecc`; exact-head checks passed; Pages deployment skipped on that historical SHA |
| #161 | MERGED | Enables Pages deployment on main pushes, writes deployment metadata, verifies published SHA, and makes Final Gate require successful deployment | Merge commit `168559498de58a071ac43a81e410227f0f83ec4b`; Pages deployment and published-SHA smoke test succeeded on that exact SHA |
| #162 | MERGED | Complete seven-day week view across month boundaries | Merge commit `52d18f53872c35c1b7076c81e4ecb996c36fd17a`; current-main source retains the week-boundary implementation |
| #164 | MERGED | Organization member role changes and safe soft removal with owner protection and reactivation | Merge commit `b0a42a291f048f790df430f0d12d7c7d88f07710`; backend feature tests and Flutter gateway/widget tests included |
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
| Day / week / month / year calendar views | IN_PROGRESS | Day, week and month pages exist; PR #162 is merged. PR #165 adds the responsive 12-month year overview from current main; its exact-head CI is pending. Original stacked PR #163 is superseded and conflict-blocked. |
| Organization membership administration | MERGED FOUNDATION | Create, member listing, join-request, approval, role-change and soft-removal API/UI flows exist; PR #164 is merged with owner protection, reactivation and access-revocation coverage. Dedicated append-only membership audit history remains unimplemented. |
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
7. Verify PR #162's merged seven-day week behavior on current main and retain cross-month regression coverage.
8. Complete PR #165's exact-head CI for the year overview, resolve any failures, and verify year/month navigation after merge.
9. Add dedicated append-only membership audit history if required by the product's governance model.
9. Add performance baselines for large workbooks, large event sets and long sync histories.
10. Verify post-merge behavior for client diagnostic log redaction from PR #152.
10. PR #161 is merged; its main-push Pages deployment and exact-SHA HTTP smoke test passed on merge commit `168559498de58a071ac43a81e410227f0f83ec4b`.
11. Refresh this inventory after PR #165 and subsequent end-to-end work.
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
