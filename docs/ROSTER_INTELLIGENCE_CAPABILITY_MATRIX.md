# Roster Intelligence Capability Matrix

**Status:** Updated capability inventory; row states reflect source/test evidence, not product acceptance.  
**Updated:** 2026-11-27  
**Audited main:** `main@68ef85361c2d08e2970160a36475592010d908f7`  
**Execution evidence:** PR #192 head `8d262dc7365a63c279e06affcdedbdbcf1b6fadc`

## 1. Status vocabulary

- **EXISTS — VERIFY:** a related source/test/document exists; end-to-end behavior is not yet certified.
- **PARTIAL:** some parts exist, with a known gap.
- **PLANNED:** target capability not yet established by evidence.
- **UNKNOWN:** current implementation or runtime state has not been inspected sufficiently.
- **PASS / FAIL / SKIPPED:** reserved for a specific executed check and exact commit; SKIPPED is never PASS.

## 2. Capability inventory

| ID | Capability | Existing evidence to inspect | Initial status | Acceptance evidence |
|---|---|---|---|---|
| RI-001 | Local Excel/CSV/TSV/TXT ingestion | `excel_reader_service.dart`, `local_roster_file_service.dart`, import tests | EXISTS — VERIFY | Format-by-format fixture and end-to-end import |
| RI-002 | Google Sheets ingestion | Sheets source adapters and parser foundation docs | EXISTS — VERIFY | Authorized test spreadsheet round-trip |
| RI-003 | Multiple sections per worksheet | `monthly_roster_section_parser.dart`, section parser tests | EXISTS — VERIFY | Distinct section periods/layouts in one workbook |
| RI-004 | Section-local period detection | Monthly section parser, date-first two-phase scanner and vertical section parser | PARTIAL — implemented for detected horizontal/vertical sections; exact-head tests passed | Competing headings, ambiguous orientation and original workbook acceptance |
| RI-005 | Raw source coordinates and merged-cell evidence | Normalized cell model, orientation mapping, row/column indexes and A1 references | PARTIAL — source coordinates integrated; full merged-header propagation remains open | Verify every merged/header transformation through correction and persistence |
| RI-006 | Thai BE/Gregorian date parsing | Thai roster period parser and date tests | EXISTS — VERIFY | Complete month/year/leap/cross-year matrix |
| RI-007 | Duplicate/missing/out-of-order date diagnostics | Monthly section parser and diagnostics tests | PARTIAL — duplicate, missing, unresolved and out-of-order findings implemented; exact-head unit/integration tests passed | Original workbook acceptance and all orientation permutations |
| RI-008 | Configurable shift definitions | Shift templates and business rules | EXISTS — VERIFY | Multiple profile-specific shift dictionaries |
| RI-009 | Person identity and alias resolution | Roster models, organization members and analyzer | PARTIAL | Explicit alias, collision and wrong-person prevention tests |
| RI-010 | Canonical normalized roster record | Parser adapters and roster models | PARTIAL | All source providers map to one stable domain contract |
| RI-011 | Source fingerprint and revision identity | Import/history/revision services | UNKNOWN | Repeated source import and changed-source reconciliation tests |
| RI-012 | Duplicate and conflict reconciliation | Analyzer, comparison and sync planning modules | PARTIAL | Explainable add/update/remove/conflict change set |
| RI-013 | Partial import by section | Grid review workflow, section-local findings and canonical converter | PARTIAL — preview isolates sections; persistence behavior still needs explicit per-section acceptance | Prove valid section commits while unrelated invalid section remains blocked |
| RI-014 | Evidence and confidence for inferred values | AI analyzer and raw-cell evidence docs | PARTIAL | Every inference exposes evidence, confidence and resolution state |
| RI-015 | Human review and correction workflow | Grid review session/page, row-based vertical correction and recovery review UI | PARTIAL — integrated on PR #192; recovery requires exact-preview confirmation | Widget/E2E tests and correction audit persistence |
| RI-016 | Profile lifecycle and source-specific configuration | Roster configuration roadmap and template settings | PARTIAL | Create/edit/duplicate/archive/version/restore profile tests |
| RI-017 | Template-driven roster/document generation | Existing generation engine; PR #202 adds immutable preview/approval/CAS workflow | PARTIAL — preview/commit source added; UI and durable journal remain open | Exact-head CI, review UI, durable approval and recovery |
| RI-018 | Calendar preview and synchronization | Calendar engine and PR #196 lease/ledger/ETag changes | PARTIAL — exact-head CI 13/13; no live provider acceptance | Controlled Google test-calendar insert/update/delete and reconciliation |
| RI-019 | Durable sync resume and ambiguous outcome recovery | PR #196 operation ledger, leases and ETag coordination | PARTIAL — implementation/test foundations; production durability and ambiguous provider acceptance open | Cross-client failure injection, restart and provider outcome recovery |
| RI-020 | Timeline and historical restoration | Revision/timeline services and persistence journal foundations | PARTIAL | Previewed, confirmed, non-destructive restore with audit history and CAS |
| RI-021 | Notifications with real delivery | PR #191 outbox, worker, VAPID/RFC 8291 sender, browser subscription UI and service worker | PARTIAL — source and fake-provider tests; real device not verified | Real registered browser delivery, scheduler deployment and production concurrency |
| RI-022 | Large-workbook performance | No repository-wide benchmark baseline identified | UNKNOWN | Reproducible time/memory benchmark at documented scales |
| RI-023 | Tenant isolation and privacy | Backend authorization, middleware and security docs | PARTIAL | Cross-tenant negative tests and log/fixture privacy review |
| RI-024 | Responsive workflow | Flutter presentation and widget tests | UNKNOWN | Tested compact/mobile/tablet/desktop widths |
| RI-025 | Audit and provenance across import-to-calendar | Source-cell provenance, import journal and Calendar operation ledger | PARTIAL | Trace one assignment from source cell through approved Schedule and provider event, then reconcile back |
| RI-026 | PDF/image/OCR and external roster providers | No end-to-end adapter evidence established | PLANNED | Provider contract, consent/privacy review and accuracy benchmark before enabling |
| RI-027 | Offline/local-first import and review | Local readers and local persistence | UNKNOWN | Offline import/preview/restart test with explicit sync state |
| RI-028 | Safe data migration and backup/restore | Backend migrations and local persistence | PARTIAL | Migration rollback/forward and restore drill on disposable data |
| RI-029 | Immutable generation preview and approval | ScheduleGenerationReviewWorkflow, exact input/candidate fingerprints and CAS commit in PR #202 | PARTIAL — code/test source added; exact-head CI rerun pending | UI approval, persisted approval provenance, durable recovery and cross-device CAS |
| RI-030 | Schedule CAS, startup recovery and conditional delete | PR #192 revision-aware writer, journal assessment, per-Schedule edit gate and tombstones | PARTIAL — unit/integration tests passed on prior exact head; Windows startup failure requires new run | All legacy writers, crash recovery, conflict UI, cross-device backend and delete acceptance |

## 3. Required evidence fields for every row

When a capability is audited, add:
- exact repository commit SHA;
- source paths and relevant symbols;
- test names and exact command;
- observed result and date;
- workflow run/check URL where applicable;
- live test environment details without exposing secrets or personal roster data;
- remaining limitations and next action.

Do not change an initial status to PASS merely because a file exists or a design is documented.

## 4. Priority order

1. RI-004 section-local date detection, RI-007 diagnostics and RI-005 source provenance.
2. RI-003 multi-section isolation, RI-013 partial import and RI-015 review/correction.
3. RI-030 repository-wide CAS, journal recovery and conditional delete.
4. RI-018/019 Calendar sync and ambiguous provider outcome recovery.
5. RI-021 real Web Push delivery and RI-025 end-to-end provenance.
6. RI-017/029 generation review, approval and durable commit.
7. RI-020 history restore and RI-016 profile lifecycle.
8. RI-022/023/024/027/028 performance, security, accessibility, offline and resilience.
9. RI-026 new source providers only after existing formats meet acceptance.

## 5. Maintenance

Update this matrix when source or test evidence changes. Keep detailed behavior in the linked domain documents and the repository-level `REQUIREMENTS_TRACEABILITY.md`; do not copy full implementation narratives into this table.
