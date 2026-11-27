# Implementation Evidence — 2026-11-27

Evidence levels are separate: source implementation, test source, tests executed, application integration, real-environment acceptance and post-merge verification. Do not infer a stronger level from a weaker one.

## A. Universal roster import — PR #192

| Layer | Evidence | State |
|---|---|---|
| Source | `VerticalMonthlyRosterSectionParser`; orientation/coordinate model; integration in `MonthlyRosterSectionParser.generateDateStructure` and `populateAssignments` | Implemented on PR branch |
| Application path | `GridRosterWorkbookScanner` calls the section parser; Grid review session and review page consume normalized assignments; row-based date correction rebuilds from retained source cells | Integrated on PR branch |
| XLSX path | `ExcelReaderService` feeds `GridRosterWorkbookScanner`; test creates an actual XLSX byte stream with a vertical date axis | Test source added |
| UI | Monthly roster card renders date-down sections as date rows and assignment columns; Grid review correction action is row-aware | Implemented on PR branch |
| Tests | `monthly_roster_section_parser_test.dart`, `grid_roster_workbook_scanner_test.dart`, `grid_roster_review_page_test.dart`, `roster_grid_axis_mapping_test.dart` | Test source added; exact-head execution pending |
| Real workbook | Original X-OPD November 2569, 16 Nov–15 Dec 2569 and US Clinic ภปร.4 files | BLOCKED — original source fixtures unavailable |

### Implemented parser behavior

- Per-section date-down axis detection; horizontal and vertical sections can coexist in one worksheet.
- Side-by-side vertical sections use separate date-axis columns.
- Date structure is resolved before assignment population.
- Original zero-based row/column positions, date-row index, assignment-column index and A1 source cell are retained.
- Explicit Thai Buddhist Era/Gregorian dates, Excel DateTime cells, Thai month headings and date ranges are supported.
- Duplicate, out-of-order, unresolved and near-complete missing dates are blocking diagnostics with source coordinates.
- Grid review supports correction of a vertical date row and rebuilds assignments from retained source cells.
- No Schedule write or Calendar sync occurs during parser preview.

### Remaining A acceptance gaps

- Reviewer-selected orientation for ambiguous structures.
- Complete multi-level and merged-header propagation across all local XLSX/Google Sheets inputs.
- All assignment-axis permutations, including employee columns whose cells contain shift labels.
- Consistent profile hints on vertical structures.
- Actual user workbook validation and full re-import reconciliation acceptance.

## B. Persistence — PR #192

PR #192 includes a backend CAS/revision contract, revision-aware repository/writer migration, durable journal/recovery foundations and conditional deletion/tombstone behavior in the backend. Exact-head CI success on earlier SHA does not prove all production writers or cross-device runtime behavior. Current PR head is under test; verify writer inventory, startup journal discovery, local fallback, two-client contention, crash recovery and tombstone recreation prevention.

## C. Calendar Sync — PR #196

PR #196 contains scoped lease/ledger/ETag and recovery foundations. Live insert/update/delete, controlled Google test-calendar acceptance, production backend durability and ambiguous provider outcome recovery remain external acceptance.

## D. Notifications — PR #191

PR #191 contains a transactional user-scoped outbox foundation. It does not prove actual Web Push transport or device delivery. VAPID sender, RFC 8291 encryption, worker claim/retry/dead-letter, subscription lifecycle and real device acceptance remain open.

## E–K. Other work packages

- Generation: exact input revision snapshots, immutable preview, approval invalidation and conditional commit/recovery are not yet accepted.
- Shift Pay: three rule-source modes and profile persistence/calculation APIs exist. PR #201 adds Dart/backend equal-specificity conflict rejection with non-payable snapshots; exact-head CI is pending. Confirmed assignment linkage, client/UI, monthly statements and immutable historical calculation acceptance remain open.
- History restore: read-only history exists; safe preview/diff/conditional restore and audit acceptance remain open.
- Organization/security: authorization and tenant foundations exist; full negative endpoint tests and privacy/security review remain open.
- Quality: CI foundations exist; reproducible benchmarks, fuzz/property tests, accessibility and real responsive acceptance remain open.
- Documentation: current status overlays are being reconciled; complete 176-file Markdown/source audit remains in progress.
- Release: no production deployment SHA, live health, rollback or backup/restore evidence is claimed.

## Evidence vocabulary

- Source implementation: code exists on the cited branch/SHA.
- Test source: assertion-bearing tests exist.
- Tests executed: exact-head workflow or local run executed them.
- Integrated: connected to the application path.
- Accepted: required product/security/real-environment criteria passed.
- Merged — post-merge verified: merge SHA and exact post-merge main checks verified.
