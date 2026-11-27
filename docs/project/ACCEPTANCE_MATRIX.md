# End-to-End Acceptance Matrix — 2026-11-27

**Baseline:** `main@68ef85361c2d08e2970160a36475592010d908f7`  
**Legend:** PASS requires inspectable evidence. UNKNOWN is not PASS. CI green does not equal operational acceptance.

| ID | Acceptance requirement | Current evidence | State | Required proof |
|---|---|---|---|---|
| A-01 | Horizontal date axis import | Existing parser + #192 | PARTIAL | Real workbook regression matrix |
| A-02 | Vertical date axis import | #192 + #205 | PARTIAL | Mixed-axis and ambiguity acceptance |
| A-03 | Multiple sections/sheets and 6+ months | #192 and existing regression work | PARTIAL | Original multi-department workbook and source-cell audit |
| A-04 | Thai BE/Gregorian/Excel/ISO dates | #192 tests | TESTED (automated) | Real workbook validation and edge-case acceptance |
| A-05 | Merged multi-level headers | #207 | CI VERIFIED (PR head) | Original merged workbook and reviewer semantics |
| B-01 | Preview is read-only | #192 workflow | PARTIAL | Verify no Schedule/Calendar mutation before explicit commit |
| B-02 | Ambiguous employee is never preselected | #208 implementation and test correction | CI PENDING on new head | New exact-head CI and reviewer acceptance |
| B-03 | Alias collision shows all candidates | #208 resolver tests | TESTED (automated) | UI collision review and save/reload |
| B-04 | Date/orientation corrections revalidate source | #192/#205 | PARTIAL | Fingerprint/revision invalidation and real workbook tests |
| B-05 | Built-in shift label/time mapping is presented as a suggestion and requires explicit reviewer opt-in; configured templates can override it | #192 Grid Review wording + widget regression | CI PENDING on latest #192 head | Verify all built-in labels against real workbooks and prove ambiguous labels never auto-resolve |
| C-01 | Every Schedule writer uses caller-bound CAS | #192 backend work | PARTIAL | Full writer inventory and concurrent multi-client proof |
| C-02 | Read-back before success | #206 | CI VERIFIED (PR head) | Backend integration and crash/recovery proof |
| C-03 | Durable operation ledger and recovery | #192/#204 foundations | PARTIAL | Transaction durability and process crash injection |
| D-01 | Give-up / receive / exchange lifecycle | Existing transaction API and UI foundations | PARTIAL | End-to-end actor/permission/rollback/idempotency acceptance |
| D-02 | Calendar sync is distinct from transaction fulfillment | Existing API contract / #187/#190 | PARTIAL | Verify no sync-only path marks transaction fulfilled |
| E-01 | ETag-protected provider update/delete | #196 | CI VERIFIED (PR head) | Controlled Google test calendar with stale ETag |
| E-02 | Owner/calendar scoped lease and fencing | #196 | CI VERIFIED (PR head) | Multi-client lease expiry/reclaim and stale worker tests |
| E-03 | Ambiguous insert reconciliation | #196 design | PARTIAL | Real provider timeout and read-back test |
| E-04 | Production backend HTTPS/auth/durable DB/APP_KEY recovery | Not proven by PR CI | UNKNOWN | Deployment config and restore evidence |
| E-05 | Explicit Calendar crash-resume/recovery after worker/process restart | #196 `ResumeSyncService.recoverRun` / `recoverHistory`, encrypted durable ledger replay, lease reacquisition, original ETag/sync-ID preconditions; new guard blocks terminal-success replay | PARTIAL — prior head CI VERIFIED; latest safety fix CI PENDING | Controlled Google test-calendar crash/timeout/restart acceptance and production database contention |
| E-06 | Reconcile ambiguous update/delete that provider applied before response loss | #196 `updateConditionally` re-reads and recognizes already-applied command state; `deleteConditionally` treats missing/410 as success; tests cover retry and stale-ETag refusal | CI VERIFIED (PR head) — OPERATIONAL ACCEPTANCE PENDING | Controlled Google test-calendar timeout-after-commit tests for update and delete with production backend/ledger |
| F-01 | Personal/Organization/Hybrid rule-source resolution | Existing mainline foundations + #201 | PARTIAL | Cross-client/API parity |
| F-02 | Immutable monthly statement calculation | #203 | CI VERIFIED (PR head) | Canonical confirmed assignment lifecycle |
| F-03 | Persisted statements/API/UI/export/authorization | Not in #203 current scope | NOT IMPLEMENTED / UNKNOWN | Implement and test end-to-end |
| F-04 | Contractor employment classification semantics | Requirements not sufficiently defined | BLOCKED ON PRODUCT DECISION | User specifies exact classification meanings |
| G-01 | Immutable generation preview and input fingerprint | #202 | CI VERIFIED (PR head) | UI and real persisted revision validation |
| G-02 | Explicit approval-bound CAS commit | #202 | PARTIAL | Durable approval, crash recovery and read-back |
| H-01 | Durable notification outbox | #191 | CI VERIFIED (PR head) | Transactional intent and worker lifecycle |
| H-02 | Real browser Web Push delivery | #191 foundations | UNKNOWN | Permission granted/denied, delivery, expiration and retry in real browser |
| H-03 | Native iOS/Android push | No accepted implementation evidence | NOT ESTABLISHED | Do not claim until implemented and device-tested |
| I-01 | Responsive/accessibility and status colors | Existing UI | PARTIAL | Screen-by-screen desktop/tablet/mobile review |
| J-01 | Shared backend contract and request correlation | Existing backend foundations | PARTIAL | Offline/online parity and runtime diagnostics |
| K-01 | Flutter/Laravel/platform CI | Workflows exist; PR-specific results vary | PARTIAL | Required checks policy + exact-head complete green |
| K-02 | Security/dependency review | Dependency Security workflow succeeds on most listed heads | PARTIAL | Alert/advisory inventory and remediation evidence |
| L-01 | Docs agree with current source and main SHA | 182 Markdown files enumerated; stale status snapshots marked historical and linked to live project status | PARTIAL | Complete relative-link/command validation and paragraph-level reconciliation across all 182 files |
| Z-01 | Post-merge main verification | No new PR merged in this audit | NOT DONE | Exact post-merge SHA and required CI |
| Z-02 | Deployment SHA verified | No deployment evidence in this audit | UNKNOWN | Runtime reports exact deployed SHA |

## External acceptance evidence required

- Original X-OPD November 2569 workbook.
- Original 16 November–15 December 2569 workbook.
- Original US Clinic ภปร.4 workbook.
- Controlled Google test calendar and non-production account.
- Real backend deployment endpoint/configuration and backup/restore evidence.
- Real browser and, if claimed, real iOS/Android device notification acceptance.
- Product decision for contractor classifications.

A requirement may be marked accepted only when evidence links, exact SHA, test environment, result and reviewer/owner are recorded.
