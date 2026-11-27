# Known Limitations and External Acceptance Blockers

**Last reconciled:** 2026-11-27  
**Main baseline:** `68ef85361c2d08e2970160a36475592010d908f7`

## Confirmed limitations / unproven behavior

1. **Real workbook acceptance is incomplete.** The Library contains pasted Markdown table extracts for X-OPD November 2569 and the 16 Nov–15 Dec 2569 roster, including rows such as “เวรเช้า14 ชั้น”, but the spreadsheet-file search found no original `.xlsx`/`.xls` workbook. Markdown extracts do not preserve workbook sheet IDs, merged-cell ranges, hidden rows/columns, formulas, raw cell values or original A1 provenance. They may inform sanitized text-level regression fixtures, but they are not original-workbook acceptance. PR #192 also records that the original X-OPD November 2569, 16 Nov–15 Dec 2569 and US Clinic ภปร.4 workbook fixtures were unavailable during its execution.
2. **Grid stacked branches require reconciliation.** #205, #207, #206, #208, #204 and #202 are based on earlier heads of the #192 feature branch. Their diffs must be reviewed and CI rerun after alignment.
3. **Employee alias CI is not yet fully complete.** The previous head failed because the widget test assumed one DropdownButtonFormField after opting in, but the production assignment card renders both employee and shift-template selectors. The test now scopes its finder to the employee selector by label in commit `b98a4e7f7911abe7b97d661bf62c121b1e66d716`. Windows, Linux, Android, Web, Dependency Security, Dart Format, Auto Detect and Cross-platform Runtime now succeed; iOS/macOS remain queued and the final PR Gate/iOS advisory remain in progress.
4. **#192 SQLite CAS spike disposition is unresolved.** Windows and Linux native contract jobs passed; the macOS job was cancelled. The separate spike workflow concluded failure. Confirm whether it is advisory or required; never call cancelled a pass.
5. **Calendar provider behavior is not live-accepted.** #196 CI passing does not prove real Google Calendar ETag, ambiguous insert, quota, token refresh, lease reclaim or crash recovery behavior.
6. **Production backend readiness is unknown.** HTTPS, authentication configuration, database transaction/locking behavior, APP_KEY backup/restore, monitoring and deployed version were not proven by the GitHub workflow evidence.
7. **Shift Pay statement workflow is incomplete.** #203 provides immutable calculation core but not persisted statement repository/API/monthly UI, canonical confirmed-assignment lifecycle, export or complete authorization acceptance.
8. **Contractor classifications require a product decision.** Rule-source modes (Personal/Organization/Hybrid) and calculation types are not employment classifications. Do not invent a third contractor type.
9. **Notification delivery is not fully accepted.** #191 CI does not prove actual browser push delivery, expired subscription cleanup under production conditions, worker operations or native iOS/Android push.
10. **Deployment is unverified.** README identifies GitHub Pages as the web app, but this audit did not verify the current deployed commit or production runtime.
11. **Branch protection is unknown.** Repository metadata does not expose required status checks/rulesets through the connected audit functions. Confirm in GitHub Settings before merge.
12. **Local working tree is unknown.** The connected GitHub audit does not inspect the user's local Windows checkout or uncommitted changes.

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
