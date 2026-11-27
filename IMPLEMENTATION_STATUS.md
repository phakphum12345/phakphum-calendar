# Repository Implementation Status

## Current repository snapshot — 2026-11-27

**Verified main SHA:** `68ef85361c2d08e2970160a36475592010d908f7`

This is the current repository-level status. The historical 2026-11-25 snapshot below is retained as an audit record and must not be treated as current.

| PR | Scope | Exact head SHA | Latest exact-head CI evidence | Review / acceptance |
|---|---|---|---|---|
| [#191](https://github.com/phakphum12345/phakphum-calendar/pull/191) | Web Push delivery/outbox | `cf7eaa22eaf81e04b0b444acfc3aee2a8ca51e5e` | 13/13 workflows passed | Draft; no review; real-device delivery not accepted |
| [#192](https://github.com/phakphum12345/phakphum-calendar/pull/192) | Universal roster import, source provenance, CAS/recovery | `2f6f` (full SHA in PR) | New exact-head runs not yet available | Draft; no review; original workbook acceptance pending |
| [#196](https://github.com/phakphum12345/phakphum-calendar/pull/196) | Calendar Sync ETag/lease/ledger reliability | `8e186790e447f9278eda8612a1bb1b6f7e7b77c9` | 13/13 workflows passed | Draft; no review; controlled Google test calendar pending |
| [#201](https://github.com/phakphum12345/phakphum-calendar/pull/201) | Shift Pay rule conflict/precedence | `d3f228dcdaea4f1a3771c271421226ab71ab00b5` | 12/12 workflows passed | Draft; no review; business-rule acceptance pending |
| [#202](https://github.com/phakphum12345/phakphum-calendar/pull/202) | Schedule generation preview/approval/commit | `ca6ebd095ef6566fcce00e9bc49e9c820470b80d` | 12/12 workflows passed | Draft; no review; dependent on #192 |
| [#203](https://github.com/phakphum12345/phakphum-calendar/pull/203) | Monthly Shift Pay statement calculation core | `9ddcca51de57b71c721f60665f3c9f8cf0e7bbcb` | 11/11 workflows passed; 716 tests passed | Draft; no review; statement persistence/UI not integrated |
| [#204](https://github.com/phakphum12345/phakphum-calendar/pull/204) | Historical Drive revision restore | `ba73` (full SHA in PR) | New exact-head runs not yet available | Draft; no review; real Drive revision acceptance pending |

PR #199 was closed without merge after its orientation foundation was superseded by the parser integration work in #192. All seven currently open PRs remain Draft and have no submitted reviews or review threads.

### Current capability evidence

| Work package | Evidence level | Remaining acceptance |
|---|---|---|
| Universal roster import | IN PROGRESS — implementation in #192; horizontal/vertical/mixed section handling, CSV/TSV/TXT input, merged-cell and color provenance, date correction, source fingerprint and explicit recovery path | Run exact-head CI; validate original X-OPD November 2569, 16 Nov–15 Dec 2569 and US Clinic ภปร.4 workbooks; verify ambiguous orientation/identity review |
| Schedule persistence | IN PROGRESS — revision-bound conditional writer and journal recovery are being consolidated in #192 | Verify every production writer, cross-process/device CAS, backend transaction behavior, tombstone deletion and crash recovery against the deployed backend |
| Calendar Sync | IN PROGRESS — server coordination, ETag-aware provider operations and durable operation history in #196 | Controlled test-calendar insert/update/delete, ambiguous provider timeout recovery and cross-device lease contention |
| Notifications | IN PROGRESS — VAPID/Web Push sender, subscription lifecycle, outbox worker and retry/dead-letter path in #191 | Registered-device delivery, permission-denied/expired-subscription behavior and production scheduler acceptance |
| Schedule generation | IN PROGRESS — immutable preview, revision-bound approval and conditional commit in #202 | Refresh base against current #192, verify UI integration and end-to-end approval/read-back recovery |
| Shift Pay | IN PROGRESS — existing Personal/Organization/Hybrid foundations plus conflict resolution in #201 and monthly statement builder in #203 | Persist statements, connect confirmed assignments, deliver statement UI and verify exact contractor employment/payment modes |
| History restore | IN PROGRESS — Drive revision list, read-only snapshot fingerprint, Grid review and conditional commit in #204 | Exact per-assignment before/after diff, real revision export fixture and external-account acceptance |
| Organization/security | PARTIAL — existing membership and role foundations | Tenant-isolation negative tests, backend authorization coverage, rate-limit and privacy-log acceptance |
| Quality/performance/accessibility | PARTIAL / UNKNOWN | Reproducible large-workbook, event-volume, history, memory, accessibility and device benchmarks |
| Documentation/release | IN PROGRESS | Reconcile feature docs with each PR, verify deployment SHA/health, backup/restore and rollback |

### Main-branch and release gates

- GitHub reports `main.protected = false`; branch-protection enforcement is `off` and required status-check contexts are empty.
- The exact main SHA above returned no workflow runs and no combined-status entries. Do not describe this as a passing main CI run.
- Exact-head PR CI is not post-merge CI. No post-merge verification or production deployment is claimed for the open PRs.
- No open PR is eligible for merge until its latest exact head has all required checks completed, a complete diff review, independent review, and applicable product/external acceptance.
- External dependencies still include original workbooks, a controlled Google Calendar/account, registered notification device/browser permission, production backend availability and release credentials.


## Historical main snapshot — 2026-11-25

**Verified main SHA:** `aed2f1177bdfc85f6ff53bb200116812a51bd9e3`

This snapshot records the completed Shift Pay and Calendar Sync backend sequence. PR-head checks are distinct from post-merge main checks. At audit time, exact-main checks for this SHA were 5 PASS and 3 IN_PROGRESS; no post-merge deployment verification is claimed.

| Item | Current observation | Status |
|---|---|---|
| Default branch | `main` at `aed2f1177bdfc85f6ff53bb200116812a51bd9e3` | PASS |
| PR #181 | Merged; Flutter Personal/Organization/Hybrid source resolution | MERGED |
| PR #182 | Merged; Backend Evolution Blueprint | MERGED |
| PR #183 | Merged; Shift Pay profile and rule persistence | MERGED |
| PR #184 | Closed without merge; stacked history replaced by clean-mainline PR #186 | SUPERSEDED |
| PR #185 | Closed without merge; stale-base Calendar Sync branch replaced by clean-mainline PR #187 | SUPERSEDED |
| PR #186 | Merged; server-side calculation and immutable snapshots | MERGED |
| PR #187 | Merged; Calendar Sync attempt history and transfer event reconciliation | MERGED |
| PR #178 / #180 | Older documentation PRs; content consolidated and refreshed in documentation replacement PR #188 | SUPERSEDED BY DOC UPDATE |
| Main branch protection | GitHub reports `protected: false`; do not assume server-enforced merge gates | NEEDS REVIEW |
| Exact-main CI | 8 of 8 exact-main checks completed successfully | IN_PROGRESS |
| Production deployment | No deployment was performed or verified for this main SHA | UNKNOWN |

### Current capability evidence

| Area | Evidence on current main | Status | Remaining work |
|---|---|---|---|
| Shift Pay modes | Flutter resolver supports Personal, Organization and Hybrid with explicit precedence and no double-counting | IMPLEMENTED FOUNDATION | Verify client/backend decimal precision parity and assignment-level integration |
| Shift Pay persistence | Authenticated user profiles and organization-owned rules with membership/role checks | IMPLEMENTED FOUNDATION | Verify multi-device/offline conflict behavior |
| Shift Pay calculation | Backend calculation service applies selected source and persists immutable, idempotent snapshots | IMPLEMENTED FOUNDATION | Connect confirmed roster assignments and monthly statement UI |
| Calendar Sync reconciliation | Per-transaction attempts and per-transfer provider event mappings; retry history and idempotent completion | IMPLEMENTED FOUNDATION | Real Google Calendar provider adapter and external event creation are not included |
| Calendar provider integration | PR #187 does not call provider APIs or create external events | MISSING / UNKNOWN | Implement provider adapter, OAuth scope checks, timeout recovery and provider-side idempotency separately |
| Notifications / reminders | Web Push subscription storage exists; no confirmed production sender/worker path | PARTIAL | Implement supported delivery with secure VAPID handling, queue/retry and opt-in controls |
| Historical roster restoration | Revision listing and timeline generation are read-only | PARTIAL | Preview, conflict detection, explicit approval, audit and recovery |
| Workbook edge cases | Date-first validation blocks malformed sections | UNKNOWN | Obtain original X-OPD and US Clinic ภปร.4 workbooks; never infer date headers |
| Responsive UI | Responsive components exist | NEEDS REVIEW | Verify phone/tablet/desktop critical journeys |
| Performance | No repository-wide benchmark baseline | UNKNOWN | Add large-workbook, event-volume, memory and history benchmarks |
| Local data protection | Local revision/history persistence exists | NEEDS REVIEW | Review encryption, retention, export and recovery |
| Documentation | Root status docs, API/schema docs and domain documentation tree are maintained | IN PROGRESS | Keep exact SHA and implementation evidence current |

### CI and release qualification

- CI claims are tied to exact SHAs. Queued, in-progress, cancelled, skipped or missing checks are not PASS.
- PR #186 and #187 each completed all 8 exact-head checks successfully before merge.
- PR #181 had 16 successful quality checks and one intentionally skipped Pages deployment check; the skipped deployment was not counted as PASS.
- Current main SHA `aed2f1177bdfc85f6ff53bb200116812a51bd9e3` completed 8/8 exact-main checks successfully.
- No Pages deployment, production API migration, live Google Calendar write, or production configuration change was performed by this PR sequence.
- Main branch protection is disabled; repository-side protection must not be assumed.

### Immediate execution order

1. Finish and record exact-main CI after the merge sequence.
2. Implement real Calendar provider calls only behind explicit user confirmation and verified OAuth scopes.
3. Add provider-side idempotency/reconciliation for ambiguous external timeouts.
4. Connect Shift Pay calculation to confirmed roster assignments and monthly statements without changing existing shift workflows.
5. Review notification delivery, historical restore, local data protection, responsive UI and performance.
6. Verify Pages/API deployment metadata against the exact approved main SHA before any production-readiness claim.

**Snapshot date:** 2026-11-25  
**Snapshot base:** `main` at `aed2f1177bdfc85f6ff53bb200116812a51bd9e3`

> This is an evidence-based engineering snapshot, not a declaration that the repository is production-ready. SKIPPED and UNKNOWN are never PASS.


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
