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

PR #192 includes a backend CAS/revision contract, revision-aware repository/writer migration, durable journal/recovery foundations and conditional deletion/tombstone behavior. The 2026-11-27 follow-up adds:

- Read-only recovery assessment states: no committed bundle, ready, already applied and conflict.
- AppShell startup discovery of local and remote journal IDs; remote discovery failure is surfaced without discarding local findings.
- A review list and explicit per-Schedule confirmation; no automatic replay.
- A review-bound recovery commit that rechecks the exact journal run ID, target revision, accepted fingerprint and candidate payload before CAS and read-back.
- Same-Schedule edit/re-import guards while a committed recovery is ready or conflicting.

Test source in test/grid_roster_recovery_assessment_test.dart covers empty, ready, conflict, already-applied, remote failure, journal replacement after preview and re-import blocking. On exact head 8d262dc7365a63c279e06affcdedbdbcf1b6fadc, Dart format, static analysis, unit tests and Linux integration tests passed; Windows PowerShell quality and macOS build passed. Windows build had startup_failure and caused PR Gate failure; Linux POSIX and iOS evidence remained in progress. This is not a full pass. Remaining: every legacy writer/edit route, global conflict resolution UI, cross-device database transactions, process-crash recovery and local fallback guarantees.

## C. Calendar Sync — PR #196

PR #196 contains scoped lease/ledger/ETag and recovery foundations. Exact-head e4e09e3c74856c64306030679a9701ec51a3b18b has 13/13 observed workflows successful. Live insert/update/delete on a controlled Google test calendar, production backend durability, multi-client contention and ambiguous provider outcome recovery remain external acceptance.

## D. Notifications — PR #191

PR #191 now contains a transactional user-scoped outbox, worker claim tokens, per-device delivery records, retry/backoff/dead-letter handling, expired subscription cleanup, VAPID authorization, RFC 8291 aes128gcm payload encryption, authenticated browser subscription registration/removal, Flutter Web opt-in/settings UI and a dedicated service-worker scope. Laravel Backend CI and 11 other observed workflows passed on exact head cf7eaa22eaf81e04b0b444acfc3aee2a8ca51e5e; Cross-platform Runtime remained in progress and macOS queued. Fake HTTP/provider tests do not prove a real registered device received a notification. Scheduler deployment, real browser delivery, production concurrency, alerting and native mobile push remain unaccepted.

## E–K. Other work packages

- Generation: PR #202 adds immutable preview, source/input/candidate fingerprints, employee/catalog/policy revision binding, exact-preview approval, deterministic candidate re-run, conditional CAS and read-back. Its first exact-head Auto Detect run found one unused-import analyzer issue; that import was removed on head ca6ebd095ef6566fcce00e9bc49e9c820470b80d and CI is rerunning. UI, durable approval/provenance journal, crash recovery and cross-device acceptance remain open.
- Shift Pay: three rule-source modes and profile persistence/calculation APIs exist. PR #201 adds Dart/backend equal-specificity conflict rejection with non-payable snapshots; exact head d3f228dcdaea4f1a3771c271421226ab71ab00b5 has 12/12 observed workflows successful. Confirmed assignment linkage, client/UI, monthly statements and immutable historical calculation acceptance remain open.
- History restore: read-only history exists; safe preview/diff/conditional restore and audit acceptance remain open.
- Organization/security: authorization and tenant foundations exist; full negative endpoint tests and privacy/security review remain open.
- Quality: CI foundations exist; reproducible benchmarks, fuzz/property tests, accessibility and real responsive acceptance remain open.
- Documentation: completion status, implementation evidence, Grid recovery/concurrency and generation approval documents are being reconciled against current source. The repository-wide Markdown/source audit remains in progress.
- Release: no production deployment SHA, live health, rollback or backup/restore evidence is claimed.

## Evidence vocabulary

- Source implementation: code exists on the cited branch/SHA.
- Test source: assertion-bearing tests exist.
- Tests executed: exact-head workflow or local run executed them.
- Integrated: connected to the application path.
- Accepted: required product/security/real-environment criteria passed.
- Merged — post-merge verified: merge SHA and exact post-merge main checks verified.
