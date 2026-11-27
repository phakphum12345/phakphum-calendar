> **Historical snapshot notice:** This file's original status table predates the merge of PR #201. The authoritative live repository baseline and exact-head PR status are maintained in [LIVE_EXECUTION_CHECKPOINT_2026-11-28.md](LIVE_EXECUTION_CHECKPOINT_2026-11-28.md). Treat older SHA and CI observations below as historical unless revalidated.

# Work Package Status — 2026-11-27

**Baseline:** `main@68ef85361c2d08e2970160a36475592010d908f7`  
**Overall:** INCOMPLETE

Status vocabulary:
- **IMPLEMENTED** — source code exists for the described slice.
- **TESTED** — focused automated tests passed.
- **CI VERIFIED** — applicable exact-head workflows completed successfully.
- **REVIEWED** — independent review completed with no unresolved blockers.
- **MERGED** — accepted change is on main.
- **OPERATIONALLY ACCEPTED** — real environment/product acceptance evidence exists.
- **DEPLOYED** — deployment and deployed SHA are verified.

These statuses are independent; do not infer one from another.

| Package | Current evidence | Status | Remaining work |
|---|---|---|---|
| A. Universal roster import | Existing parser plus #192 horizontal/vertical/mixed section work; anonymized row-33 16 Nov–15 Dec regression; #205 orientation and #207 merged vertical header follow-ups; Grid Review labels built-in row-label/time rules as suggestions and requires explicit assignment opt-in | IMPLEMENTED (partial), TESTED (fixtures), CI PARTIAL (12 #192 workflows passed including CAS spike and iOS Advisory; Build iOS rerun queued after cancellation) | Real workbooks, multi-section permutations, hidden/formula metadata, profile evidence and user acceptance |
| B. Grid review / employee resolution | Preview/review workflow in #192; user-managed aliases in #208; assignments excluded by default | IMPLEMENTED (partial), TESTED (partial) | New #208 exact-head CI, directory edit/save/reload, collision acceptance, source fingerprint/revision revalidation and product review |
| C. Data integrity / persistence | Backend CAS work and journal foundations in #192; read-back verification in #206 | IMPLEMENTED (partial), CI VERIFIED (PR heads) | Prove every writer uses caller-bound CAS; transaction/ledger durability; crash recovery and multi-client concurrency |
| D. Shift transactions | Existing transaction domain and backend flows; #187/#190 merged structured sync mapping and history reconciliation | IMPLEMENTED (existing foundation) | End-to-end give-up/receive/exchange lifecycle and prove Calendar sync is not transaction fulfillment |
| E. Google Calendar sync | Existing planner/executor; #196 adds ETag guards, owner/calendar leases, encrypted operation ledger, explicit `ResumeSyncService` recovery and guards against terminal/empty-ledger false success | IMPLEMENTED (partial), TESTED (unit/API), CI PARTIAL (11 workflows passed including iOS Advisory; Build iOS/macOS pending) | Controlled real Google test calendar, provider ambiguous insert, process-crash/restart/reclaim, production backend and live recovery acceptance |
| F. Shift Pay | #181/#183/#186 mainline foundations; #201 rule-conflict handling; #203 immutable statement calculation core | IMPLEMENTED (partial), CI VERIFIED (#201/#203 heads) | Persisted statement repository/API/UI, canonical confirmed assignment lifecycle, export/authorization and payroll acceptance |
| G. Schedule generation | #202 immutable preview/approval/CAS slice | IMPLEMENTED (partial), CI VERIFIED (#202 head) | Review approval UI, durable approval/read-back/crash recovery and policy acceptance |
| H. Notifications | #191 durable outbox foundation and web subscription foundations | IMPLEMENTED (partial), CI VERIFIED (#191 head) | Worker lifecycle, retries/dead letter/monitoring and real browser delivery; native push not established |
| I. User experience | Existing responsive screens and Grid review UI | IMPLEMENTED (partial) | Full workflow audit on desktop/tablet/mobile, accessibility and consistent status semantics |
| J. Backend / architecture | Existing Flutter client and Laravel API; #192/#196/#191 backend integration | IMPLEMENTED (partial) | Shared contract, runtime config, authorization, offline/online recovery, diagnostics and production operations |
| K. Testing / security | Flutter, Laravel, platform and dependency workflows exist | CI VERIFIED (varies by PR head) | Full security review, required-check policy verification, live integration and concurrency/recovery acceptance |
| L. Documentation | Domain documentation tree and dated plans exist | IMPLEMENTED (partial) | Reconcile stale baseline claims, duplicate trackers and feature claims against source/main; keep current docs updated |

## Current blockers

1. #208 prior exact-head failure: the alias widget test used a global Dropdown finder, but an opted-in assignment intentionally renders both employee and shift-template dropdowns. The test now targets the employee field by its semantic label in commit `b98a4e7f7911abe7b97d661bf62c121b1e66d716`. Its prior head passed core CI, but after the safe base merge to `17524ec63d93149c4a5dafb22186e765f4aa979e` the new exact-head Auto Detect, Linux, Android, Web, Cross-platform Runtime, Windows and Dart Format checks passed; Dependency Security, Build iOS, Pull Request Gate and iOS Advisory are in progress, and macOS is queued. Prior iOS/macOS results do not apply to the new head.
2. #192 has a separate SQLite CAS spike workflow with a cancelled macOS job; determine whether this is advisory or required. Do not count cancelled as pass.
3. Stacked Grid PRs are not yet reconciled against the latest #192 base.
4. No review submissions or review threads were returned for any of the 12 currently open PRs (#191, #192, #196, #201–#209) at the latest audit. All remain Draft; CI success is not independent review.
5. Real workbook, live provider, production backend and real-device acceptance remain external gates.

Update this file only from new source, CI, review and acceptance evidence. Do not copy status from stale PR body text.
