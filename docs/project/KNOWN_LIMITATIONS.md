# Known Limitations and External Acceptance Blockers

**Last reconciled:** 2026-11-27  
**Main baseline:** `68ef85361c2d08e2970160a36475592010d908f7`

## Confirmed limitations / unproven behavior

1. **Real workbook acceptance is incomplete.** The Library contains pasted Markdown table extracts for X-OPD November 2569 and the 16 Nov–15 Dec 2569 roster, including rows such as “เวรเช้า14 ชั้น”, but the spreadsheet-file search found no original `.xlsx`/`.xls` workbook. Markdown extracts do not preserve workbook sheet IDs, merged-cell ranges, hidden rows/columns, formulas, raw cell values or original A1 provenance. They now inform a sanitized regression in `test/monthly_roster_section_parser_test.dart` for row 33 `เวรเช้า14 ชั้น`, the 30-date 16 Nov–15 Dec block and source cells B33–AE33, with employee names anonymized. This is a synthetic `NormalizedCell` fixture derived from Markdown, not original-workbook acceptance. PR #192 also records that the original X-OPD November 2569, 16 Nov–15 Dec 2569 and US Clinic ภปร.4 workbook fixtures were unavailable during its execution.
2. **Grid stacked branches require reconciliation.** #205, #207, #206, #208, #204 and #202 are based on earlier heads of the #192 feature branch. Their diffs must be reviewed and CI rerun after alignment.
3. **Employee alias CI is not yet fully complete.** The previous head failed because the widget test assumed one DropdownButtonFormField after opting in, but the production assignment card renders both employee and shift-template selectors. The test now scopes its finder to the employee selector by label in commit `b98a4e7f7911abe7b97d661bf62c121b1e66d716`. Windows, Linux, Android, Web, Dependency Security, Dart Format, Auto Detect, Cross-platform Runtime, Pull Request Gate, macOS Xcode and iOS Advisory now succeed; the iOS build attempt was cancelled and its targeted rerun is queued.
4. **#192 SQLite CAS spike has passing evidence on the previous head, but the newest matrix is still running.** On parent head `fb670c84...` the separate spike workflow failed when macOS was cancelled. On documentation-updated head `87181d550917625659e715b46014ae05fdfab3f3`, it completed successfully across Ubuntu, macOS and Windows. The `fb6a5b84936cba62174b032dbc9f5347618051d2` head failed Auto Detect CI and Pull Request Gate because the new suggestion-text test tapped an off-screen checkbox (y=659 outside a 600px test viewport). The latest head `6663135cff20fab189cdef8996649874ee19a6da` now calls `ensureVisible` before tapping; exact-head CI has not yet returned.
5. **Calendar recovery is implemented in the client but not operationally accepted.** #196 includes explicit `ResumeSyncService.recoverRun` / `recoverHistory` flows that rebuild unfinished operations from the owner-scoped encrypted durable ledger, acquire a new lease, reconcile inserts by stable sync ID and replay updates/deletes with their original ETag and managed identity. The backend exposes the ledger/lease endpoints used by the client rather than a separate recovery endpoint. A 2026-11-27 safety fix now rejects terminal successful runs, empty ledgers and nonterminal runs with no unfinished operations before replay; regression tests prove no lease acquisition/provider insert and no false local success. The latest head still needs exact-head CI; prior unit/API tests do not replace a real Google test-calendar, production database, process-crash or provider-timeout acceptance.
6. **Production backend readiness is unknown.** HTTPS, authentication configuration, database transaction/locking behavior, APP_KEY backup/restore, monitoring and deployed version were not proven by the GitHub workflow evidence.
7. **Shift Pay statement workflow is incomplete.** Mainline backend persists per-calculation snapshots through `/shift-pay/calculations`; #203 adds an immutable monthly statement builder but not a persisted monthly statement repository/API/UI, canonical confirmed-assignment lifecycle, before/after comparison, export or complete authorization acceptance.
8. **Contractor classifications require a product decision.** The current Shift Pay API validates only `salaried` and `dailyPaid`. Rule-source modes (Personal/Organization/Hybrid) and calculation types are not employment classifications. Do not add a third contractor type until the user defines its exact semantics.
9. **Notification delivery is not fully accepted.** #191 CI does not prove actual browser push delivery, expired subscription cleanup under production conditions, worker operations or native iOS/Android push.
10. **Deployment is unverified.** README identifies GitHub Pages as the web app, but this audit did not verify the current deployed commit or production runtime.
11. **Xcode runner scheduling is not accepted.** #208 macOS Xcode and iOS Advisory passed, but the iOS build attempt was cancelled and is queued for a targeted rerun. Other PRs still have Xcode jobs queued/in progress. The workflows use `vars.IOS_RUNNER_LABEL` / `vars.MACOS_RUNNER_LABEL` and fall back to `macos-15`; repository variable values and actual runner allocation were not visible through the connector. Do not count queued/cancelled jobs as platform-build PASS or claim signed/device-ready artifacts.
12. **Branch protection is unknown.** Repository metadata does not expose required status checks/rulesets through the connected audit functions. Confirm in GitHub Settings before merge.
13. **Local working tree is unknown.** The connected GitHub audit does not inspect the user's local Windows checkout or uncommitted changes.

## Data-safety boundaries

- No production Google Calendar was modified.
- No production database migration or reset was performed.
- No production deployment was performed.
- No user workbook fixture was fabricated or represented as an original acceptance artifact.
- No user data, branch history or existing PR was deleted or force-pushed.

## Required external inputs

- Original workbooks listed above.
- Non-production Google account/calendar for provider acceptance.
- Production backend operator evidence and restore procedure.
- Browser/device acceptance for notifications.
- Explicit product semantics for contractor employment classifications.

Until those are supplied and validated, affected features remain partially implemented or operationally unaccepted.

14. **Built-in shift label mappings remain compatibility suggestions, not universal rules.** The legacy adapter contains mappings for labels such as ER, CT, GEN, P1–P4, CTIPD, CTER, IPD and 14ชั้น. The Grid Review page now labels built-in time mappings as suggestions and requires explicit assignment opt-in; reviewers can select a configured Shift Template instead. Real workbook acceptance must verify the suggested times and confirm that no suggestion is silently committed.
