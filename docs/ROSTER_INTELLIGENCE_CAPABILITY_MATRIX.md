# Roster Intelligence Capability Matrix

**Status:** Initial planning inventory; rows are not implementation claims.  
**Prepared:** 2026-11-24  
**Baseline:** `main@c847d70b98c2693a11c1063e989c55f2ab825d04`

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
| RI-004 | Section-local period detection | Thai period parser and monthly section parser | UNKNOWN | Competing headings, cross-month periods and section isolation tests |
| RI-005 | Raw source coordinates and merged-cell evidence | Excel reader and normalized cell model | EXISTS — VERIFY | Raw cell provenance retained through preview |
| RI-006 | Thai BE/Gregorian date parsing | Thai roster period parser and date tests | EXISTS — VERIFY | Complete month/year/leap/cross-year matrix |
| RI-007 | Duplicate/missing/out-of-order date diagnostics | Monthly section parser and diagnostics tests | EXISTS — VERIFY | Exact-column anomaly tests |
| RI-008 | Configurable shift definitions | Shift templates and business rules | EXISTS — VERIFY | Multiple profile-specific shift dictionaries |
| RI-009 | Person identity and alias resolution | Roster models, organization members and analyzer | PARTIAL | Explicit alias, collision and wrong-person prevention tests |
| RI-010 | Canonical normalized roster record | Parser adapters and roster models | PARTIAL | All source providers map to one stable domain contract |
| RI-011 | Source fingerprint and revision identity | Import/history/revision services | UNKNOWN | Repeated source import and changed-source reconciliation tests |
| RI-012 | Duplicate and conflict reconciliation | Analyzer, comparison and sync planning modules | PARTIAL | Explainable add/update/remove/conflict change set |
| RI-013 | Partial import by section | Parser diagnostics and conversion adapter | EXISTS — VERIFY | Valid section persists while independent invalid section is blocked |
| RI-014 | Evidence and confidence for inferred values | AI analyzer and raw-cell evidence docs | PARTIAL | Every inference exposes evidence, confidence and resolution state |
| RI-015 | Human review and correction workflow | Import preview, mapping UI and validation UI | PARTIAL | User corrections persist safely and are auditable |
| RI-016 | Profile lifecycle and source-specific configuration | Roster configuration roadmap and template settings | PARTIAL | Create/edit/duplicate/archive/version/restore profile tests |
| RI-017 | Template-driven roster/document generation | Generator and adapter docs | PARTIAL | Deterministic preview/export from approved canonical records |
| RI-018 | Calendar preview and synchronization | Calendar engine, sync reliability and E2E docs | EXISTS — VERIFY | Test-account preview equals actual idempotent provider operations |
| RI-019 | Durable sync resume and ambiguous outcome recovery | Resume/sync services and tests | EXISTS — VERIFY | Failure injection and process-restart tests |
| RI-020 | Timeline and historical restoration | Revision/timeline services | PARTIAL | Previewed, confirmed, non-destructive restore with audit history |
| RI-021 | Notifications with real delivery | Notification interfaces, push docs and backend subscriptions | PARTIAL | Signed/encrypted delivery, durable queue, retries and platform E2E |
| RI-022 | Large-workbook performance | No repository-wide benchmark baseline identified | UNKNOWN | Reproducible time/memory benchmark at documented scales |
| RI-023 | Tenant isolation and privacy | Backend authorization, middleware and security docs | PARTIAL | Cross-tenant negative tests and log/fixture privacy review |
| RI-024 | Responsive workflow | Flutter presentation and widget tests | UNKNOWN | Tested compact/mobile/tablet/desktop widths |
| RI-025 | Audit and provenance across import-to-calendar | Import history, timeline and sync audit | PARTIAL | Trace one assignment from source cell to Calendar event and back |
| RI-026 | PDF/image/OCR and external roster providers | No end-to-end adapter evidence established | PLANNED | Provider contract, consent/privacy review and accuracy benchmark before enabling |
| RI-027 | Offline/local-first import and review | Local readers and local persistence | UNKNOWN | Offline import/preview/restart test with explicit sync state |
| RI-028 | Safe data migration and backup/restore | Backend migrations and local persistence | PARTIAL | Migration rollback/forward and restore drill on disposable data |

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

1. RI-004 section-local period detection and RI-007 date diagnostics.
2. RI-003 multi-section isolation and RI-005 source-coordinate provenance.
3. RI-010 canonical model and RI-014 evidence/confidence.
4. RI-012 reconciliation, RI-013 partial import and RI-015 human review.
5. RI-016 profiles and RI-017 generator.
6. RI-018/019 Calendar synchronization and recovery.
7. RI-020 history restore, RI-021 notification delivery and RI-025 end-to-end provenance.
8. RI-022/023/024/027/028 quality, security, UX and resilience.
9. RI-026 new source providers only after existing formats meet acceptance.

## 5. Maintenance

Update this matrix when source or test evidence changes. Keep detailed behavior in the linked domain documents and the repository-level `REQUIREMENTS_TRACEABILITY.md`; do not copy full implementation narratives into this table.
