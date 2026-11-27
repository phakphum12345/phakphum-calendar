# Implementation Evidence — 2026-11-27

This file separates source presence, test source, executed tests, integration and real-environment acceptance. A higher evidence level must not be inferred from a lower one.

## Roster import — PR #200

| Evidence layer | Current evidence | Result |
|---|---|---|
| Source implementation | `VerticalMonthlyRosterSectionParser`; `MonthlyRosterSectionParser.parse`; `MonthlyRosterWorkbookScanner`; orientation and coordinate fields in `MonthlyRosterSection` | Implemented on PR branch |
| Test source | `test/vertical_monthly_roster_section_parser_test.dart` | Added; includes vertical, mixed, side-by-side, missing-date and no-period cases |
| Executed tests | Exact-head CI for `32cbb1e968c64187d9778bb50118a3e76bb6c167` | Not yet evidenced at this snapshot |
| App integration | Workbook scanner calls the section parser; section parser combines horizontal and vertical reports | Integrated at scanner/parser boundary; downstream review UX not yet verified |
| Real workbook acceptance | Original user workbook files not available in the repository audit context | Blocked — external fixture required |

### Current parser boundaries

- Date-down / assignment-across tables are detected per candidate date-axis column.
- Original date-row and assignment-column coordinates are retained; assignment A1 source cells are preserved.
- Thai month/year headings and explicit Thai date ranges can resolve a period.
- A missing or ambiguous period is not replaced with an invented month.
- Near-complete vertical ranges report missing dates.
- Mixed horizontal/vertical and side-by-side vertical fixtures are present.

Not yet implemented or accepted: user-selected orientation for ambiguous structures, complete merged-header propagation, arbitrary left/right axis arrangements with multiple tables, stacked sections sharing one date column, date-first/employee-first alternate vertical sub-layouts, full XLSX end-to-end flow, preview/correction UI acceptance, and actual workbook validation.

## Existing PR foundations

| Area | Source/PR evidence | What this does not prove |
|---|---|---|
| Schedule CAS | PR #192, exact head `11b4970a17ed17a8a57e7c83b2ae8319b7705229`, 14/14 observed workflows success | Cross-device/local fallback CAS, all writers, conditional delete/tombstone and production backend acceptance |
| Calendar Sync | PR #196, exact head `b9890c2983208b394232f9bc2c2125ec1212e16f`, 13/13 observed workflows success | Live Google Calendar writes, production backend durability, controlled contention and ambiguous-outcome acceptance |
| Notification outbox | PR #191, exact head `6787fe710ceb351581eb42c9b7045c49a93c9cfb`, 10/10 observed workflows success | Actual Web Push delivery, real device registration, worker retries and dead-letter behavior |
| Orientation foundation | PR #199, exact head `5d6906e1b6f938604ba665e2a0963a8d4320bf36`, 11/11 observed workflows success | End-to-end vertical parsing; PR #200 adds the first integrated parser slice |

## Product and release acceptance still required

- Schedule generation: bind preview to exact schedule, employee, catalog and policy revisions; invalidate stale approvals; conditionally commit and recover.
- Shift Pay: integrate confirmed assignments and monthly statement detail; verify decimal parity and historical snapshot immutability.
- History restore: read-only preview, diff, stale-source detection, explicit confirmation, conditional commit and audit.
- Organization/security: endpoint-level tenant-isolation and negative authorization tests; lifecycle and privacy review.
- Quality: accessibility, responsive-device tests, fuzz/property tests and reproducible performance baselines.
- Release: exact deployment SHA, live health/readiness, signed artifacts where advertised, rollback and backup/restore drills.

## Evidence vocabulary

- Source implementation: code exists on the cited branch/SHA.
- Test source: assertion-bearing test code exists.
- Tests executed: a workflow or local run executed the tests on the exact cited SHA.
- Integrated: the feature is connected to the actual application path, not just a standalone class.
- Accepted: required product, security and real-environment criteria passed.
- Merged — post-merge verified: merge SHA and exact post-merge main checks verified.
