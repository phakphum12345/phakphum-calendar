# Master Execution Roadmap — 2026-11-28

> Repository: `phakphum12345/phakphum-calendar`  
> Base snapshot for this plan: `f7499d76a2d5111a7d37801462a4b837e5791ff9`  
> Status: execution plan; package acceptance is **not** implied by this document.

This roadmap consolidates the remaining work into seven independently verifiable work packages. It is an execution index, not a second implementation specification. Existing domain documents and source code remain canonical; update those documents rather than duplicating their details.

## 1. Evidence, CI/CD, repository health, and documentation

**Purpose:** ensure every engineering and release claim is tied to the exact commit and actual executed steps.

Scope:
- Reconcile open PRs #216 and #217 against current `main`; inspect base/head SHAs, changed files, reviews, check runs, and mergeability before acting.
- Ensure Final Gate distinguishes workflow/job success from the actual build, package, upload, Pages deploy, and deployed-SHA verification steps.
- Keep `PASS`, `FAIL`, `PENDING`, `SKIPPED`, and `UNKNOWN` distinct. A skipped release artifact or deployment cannot qualify as a release.
- Refresh the live checkpoint, implementation inventory, requirements traceability, delivery status, and documentation index without overwriting historical snapshots.
- Check dependency/security gates and formatting/test baselines without mass-formatting unrelated files.

Acceptance:
- Every merged PR has successful exact-head required checks and a recorded merge SHA.
- Post-merge checks are fetched for that merge SHA; pending, skipped, missing, and unknown checks remain explicit.
- Documentation identifies its baseline SHA and does not label historical observations as current.
- No merge occurs while required checks are failing, pending, skipped, or unverifiable.

Current evidence boundary: main was observed at the base SHA above. The open PR descriptions #216 and #217 are known, but their latest exact-head checks must be fetched again before merge.

## 2. Shared backend, persistence, and data integrity

**Purpose:** make organization-scoped state reliable across clients while retaining the local-first experience.

Scope:
- Verify Laravel API, migrations, authentication/authorization, request correlation, and error contracts against Flutter and any Python integration boundary.
- Inventory every schedule writer and ensure the intended compare-and-swap (CAS), revision, and conflict policy is consistently applied; do not infer global atomicity from one protected writer.
- Verify global sync serialization, durable operation ledger, idempotency, retry/recovery, and audit history for operations that span multiple records or providers.
- Verify schema migration ordering, rollback/recovery, backup/restore, and behavior during interrupted writes.
- Preserve local-only use when no organization backend is configured; never bypass production HTTPS guards or embed secrets.

Acceptance:
- Concurrent writes cannot silently overwrite a newer revision; conflicts are visible and recoverable.
- Retries do not duplicate logical operations.
- Cross-device organization data is consistent after acknowledged writes.
- Offline/local workflows remain usable and do not falsely claim server synchronization.
- Migration and restore tests demonstrate no loss of accepted user data.

Dependency/blocker: production release artifacts and Pages deployment require an owner-controlled, valid HTTPS `ORGANIZATION_API_BASE_URL` and corresponding operational backend. A placeholder URL or bypassed guard is not acceptable.

## 3. Google Calendar Sync and Web Push operations

**Purpose:** prove that the existing synchronization foundations work against real provider behavior and recover safely.

Scope:
- Trace the full roster/transaction lifecycle through preview, explicit confirmation, provider write, provider acknowledgement, reconciliation, and fulfillment.
- Verify OAuth scopes, token expiry/revocation, create/update/delete behavior, event identity, ETag/version handling, duplicate prevention, and ambiguous-timeout recovery.
- Verify sync lease/serialization, heartbeat/expiry, durable attempts, retry/resume, and history.
- Preserve user-managed events, unselected months, roster overrides, and given/received/canceled state during re-sync.
- Verify Web Push subscription lifecycle, permission/opt-in, VAPID secret handling, outbox/worker, retry/backoff, expired endpoint cleanup, and delivery observability.

Acceptance:
- A live test account can create/update/reconcile the expected event without duplicates.
- A timeout after provider acceptance can be recovered without creating a second event.
- Syncing one month does not delete or rewrite unrelated months or user overrides.
- A shift transaction is not fulfilled merely because a Calendar event was written; each required participant confirmation and fulfillment rule is enforced.
- A real supported browser receives an opted-in test notification; failure/retry/expired-subscription behavior is observable.

Current evidence boundary: Calendar Sync/Web Push foundations and coordination API tests are present in merged work. Do not rebuild those foundations; qualify provider and delivery paths with real integration evidence.

## 4. Universal Roster and workbook import

**Purpose:** accept real-world roster layouts without locking the product to one spreadsheet template.

Scope:
- Exercise vertical, horizontal, multi-section, multi-sheet, multi-department, and long-range (six months or more) layouts.
- Resolve all date headers/rows and calendar systems (including Thai Buddhist Era) before assigning people or interpreting shift cells.
- Detect duplicate, missing, out-of-order, merged, ambiguous, and conflicting dates; report exact source coordinates and provenance.
- Support editable column/row/section mapping and staged corrections before commit.
- Preserve source provenance and reconcile re-imports without overwriting user-confirmed edits, overrides, given/received/canceled transactions, or unrelated schedule ranges.
- Verify employee alias matching never silently preselects an uncertain person.

Acceptance:
- No fixed workbook template or hardcoded row/column layout is required.
- Ambiguous mappings are presented for user review; no unsafe auto-commit occurs.
- A real workbook is imported with a reproducible preview, correction trail, and read-back verification.
- Re-importing the same source is idempotent and does not erase accepted user changes.
- Original acceptance workbooks are used when available; synthetic fixtures are supplementary, not substitutes.

External test data needed: original X-OPD November 2569, 16 Nov–15 Dec 2569 sample, and US Clinic ภปร.4 workbooks. Until those files are supplied and tested, their specific acceptance remains **BLOCKED / NOT VERIFIED**.

## 5. Shift Pay and workforce rules

**Purpose:** calculate pay transparently from confirmed work and effective policy.

Scope:
- Verify Personal, Organization, and Hybrid rule-source resolution and explicit precedence.
- Cover fixed-per-shift, hourly, multiplier, salary-included, and compensatory-time conditions where supported by the product requirements.
- Verify organization policy authorization, effective dates, rule revisions, decimal precision, rounding, and conflict behavior.
- Connect calculation only to confirmed/fulfilled roster assignments; distinguish estimated, pending, approved, and payable amounts.
- Provide auditable monthly statements and immutable historical snapshots.

Acceptance:
- No assignment is paid twice and unconfirmed work is not represented as payable.
- Ambiguous or conflicting policy sources require explicit resolution.
- Recalculation does not mutate an already-issued historical statement; corrections create traceable revisions.
- Flutter and backend calculations agree on precision and rounding for representative edge cases.

Current evidence boundary: Shift Pay profile/rule persistence and backend calculation snapshot foundations are already merged. Remaining work is assignment-level integration and end-to-end acceptance, not a second rule engine.

## 6. Authentication, organization access, and AI assistant

**Purpose:** make account access dependable and AI assistance safe, useful, and bounded by permissions.

Scope:
- Test public Google sign-in for supported platforms, token refresh/expiry, logout/revocation, account linking, first-login onboarding, and recovery from OAuth misconfiguration.
- Verify organization membership, owner/admin/staff roles, join requests, approval/rejection, role changes, and removal/reactivation with server-side authorization.
- Verify no privileged action relies solely on client/local-storage role flags.
- Define AI assistant capabilities against actual available data: schedule lookup, roster/person search, summaries, anomaly detection, shift-pay explanation, and history questions.
- Require preview and explicit confirmation for every mutating action; record actor, intent, affected records, and result.

Acceptance:
- Ordinary users can complete supported sign-in without developer-only setup steps beyond documented OAuth configuration.
- Unauthorized users cannot read or mutate another organization's data.
- AI responses cite the underlying schedule facts available to the caller and clearly state uncertainty.
- AI cannot silently change roster, pay, Calendar, membership, or notification settings.

Dependency: live public OAuth acceptance requires valid owner-controlled OAuth configuration and tester accounts. AI production acceptance requires a verified permission-aware data interface; mock responses do not count.

## 7. End-to-end, security, and production acceptance

**Purpose:** make a release decision from complete evidence rather than a green workflow wrapper.

Scope:
- Run critical journeys across Web and supported Windows/Android/iOS/Linux/macOS targets, distinguishing build support from signed/distributable release support.
- Run integration tests with the configured backend, real Google Calendar test account, real browser push endpoint, and representative real roster workbooks.
- Test concurrency, retries, offline recovery, data migration, backup/restore, access control, secret handling, and dependency security.
- Verify production API health/readiness, frontend deployment URL, artifact checksums/signatures where applicable, and deployed SHA.
- Publish a release matrix that marks each platform and capability as accepted, blocked, skipped, or unsupported.

Acceptance:
- All required exact-head checks pass and post-merge main checks are terminal and successful.
- Each production deployment is verified against the approved main SHA.
- Required integrations have evidence from real controlled services, not only mocks.
- No known data-loss, duplicate-write, authorization, or secret-exposure blocker remains.
- Release notes state unsupported platforms and unsigned artifacts accurately.

## Execution order and dependency rules

1. **Package 1:** refresh evidence and safely resolve #216/#217.
2. **Package 2:** verify shared persistence contracts and close data-integrity gaps.
3. **Packages 3 and 4:** proceed in parallel where interfaces are stable; Calendar provider tests depend on backend/operation contracts, while workbook acceptance depends on source fixtures.
4. **Package 5:** integrate Shift Pay with confirmed roster assignments and backend snapshots.
5. **Package 6:** complete OAuth/organization authorization and permission-aware AI workflows.
6. **Package 7:** run full acceptance only after the required foundations and owner-controlled service configuration exist.

A package may be marked **DONE** only when its acceptance criteria have linked source/test/CI or controlled integration evidence. Otherwise use **IN PROGRESS**, **BLOCKED**, **SKIPPED**, or **NOT VERIFIED**, with the blocker and next action recorded.

## Change and merge safety

- Inspect the live default branch, PR base/head SHAs, reviews, checks, and mergeability before each merge.
- Never force-push, reset, rewrite history, or discard user work.
- Do not merge failing, pending, skipped-required, or unverifiable checks.
- Do not duplicate an implementation already merged; extend its canonical source and tests.
- Do not weaken tests, remove business rules, hardcode one roster template, or replace real integration evidence with mocks.
- Preserve user data, API contracts, schema compatibility, and existing workflows.
- Prefer zero-cost/local-first solutions; add hosted services only with explicit owner-controlled configuration and operational justification.

## Live progress log

Update this table only with evidence observed for the specific SHA or controlled test run.

| Package | Status | Evidence / blocker | Next action |
|---|---|---|---|
| 1. Evidence, CI/CD, docs | IN PROGRESS | Main base SHA recorded above; PR #216 and #217 require fresh exact-head inspection | Inspect PR heads/checks, reconcile docs, merge only when all required checks pass |
| 2. Shared backend/data integrity | NOT VERIFIED | Existing Laravel/API foundations; full writer/CAS/ledger/restore acceptance not established by this plan | Audit canonical implementation and tests |
| 3. Calendar Sync/Web Push | PARTIAL / NOT VERIFIED | Foundations merged; real provider and browser delivery acceptance not established | Run controlled provider and push integration tests |
| 4. Universal Roster | PARTIAL / BLOCKED | Parser/review foundations exist; named original workbooks unavailable in this execution context | Audit parser coverage and request/locate source fixtures |
| 5. Shift Pay | PARTIAL / NOT VERIFIED | Rule and calculation snapshot foundations merged; assignment-level end-to-end acceptance open | Trace confirmed roster assignment to immutable statement |
| 6. Auth and AI | PARTIAL / NOT VERIFIED | Google/organization foundations exist; public OAuth and permission-aware AI acceptance open | Audit current flows and controlled credentials/configuration |
| 7. E2E and production | BLOCKED | Valid HTTPS shared backend configuration and real integration evidence required | Configure owner-controlled services, then run release matrix |

## Related canonical documents

- [Documentation index](../DOCUMENTATION_INDEX.md)
- [Implementation status](../IMPLEMENTATION_STATUS.md)
- [Requirements traceability](../REQUIREMENTS_TRACEABILITY.md)
- [Delivery status](DELIVERY_STATUS.md)
- [Integration status](INTEGRATION_STATUS.md)
- [Calendar preview and sync](CALENDAR_PREVIEW_AND_SYNC.md)
- [Synchronization reliability](SYNC_RELIABILITY.md)
- [Shift pay rules](SHIFT_PAY_RULES.md)
- [Universal Roster Intelligence master plan](UNIVERSAL_ROSTER_INTELLIGENCE_MASTER_PLAN.md)
- [Roster parser reliability specification](ROSTER_PARSER_RELIABILITY_SPEC.md)
- [Backend API guide](../backend/README.md)
