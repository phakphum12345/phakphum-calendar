# Master Execution Roadmap — 2026-11-28

> Repository: `phakphum12345/phakphum-calendar`  
> Base snapshot for this plan: `f7499d76a2d5111a7d37801462a4b837e5791ff9`  
> Status: execution plan; package acceptance is **not** implied by this document.

This roadmap consolidates the remaining work into seven independently verifiable work packages. It is an execution index, not a second implementation specification. Existing domain documents and source code remain canonical; update those documents rather than duplicating their details.

## Product principle — flexible input, precise roster outcomes

The product must adapt to the user's real roster and work practices. It must not force users to reshape their spreadsheets, departments, shift vocabulary, employment rules, or workflows to match a fixed application template.

- **Discover, do not prescribe:** infer structure and semantics from source evidence and user context; do not require fixed sheet names, row/column positions, department names, shift enums, month boundaries, or one canonical workbook layout.
- **Normalize, do not flatten:** translate varied inputs into a stable canonical domain model while retaining source provenance, relationships, revisions, and user-defined metadata.
- **Evidence before inference:** distinguish observed facts, profile hints, inferred mappings, and user-confirmed decisions. Keep confidence and competing interpretations visible.
- **Uncertainty is a first-class result:** ask for clarification or block only the unresolved scope when evidence is insufficient. Never silently guess a date, person, shift, department, status, or transaction.
- **Local correction, full revalidation:** users should correct the smallest ambiguous mapping; rebuild affected semantic records and rerun dependent validation without forcing unrelated re-entry.
- **Preserve meaning across boundaries:** import, persistence, shift transactions, pay, calendar sync, notifications, AI assistance, exports, and audit history must refer to the same canonical roster facts and revisions.
- **Extensible vocabularies and rules:** departments, roles, shift types, status labels, employment arrangements, pay rules, and metadata must be configurable/extendable. Examples are not exhaustive enums or universal policy.
- **No format-specific business logic:** workbook coordinates and reader quirks belong in adapters/provenance, never in core shift, pay, or calendar business rules.
- **Correctness outranks apparent success:** an unresolved or partially imported result is preferable to a plausible but incorrect roster.

The existing [Universal Roster Intelligence master plan](UNIVERSAL_ROSTER_INTELLIGENCE_MASTER_PLAN.md) and [Roster Parser Reliability Specification](ROSTER_PARSER_RELIABILITY_SPEC.md) are the canonical detailed design references. Their flexible-layout discovery, evidence, review, provenance, and parameterized-testing requirements take precedence over examples in this roadmap.

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
- Keep the canonical data model extensible: do not encode one hospital, department, workbook layout, shift vocabulary, employment type, or pay policy as a closed universal enum. Preserve unknown user-defined metadata and versioned domain extensions safely.
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
- Preserve user-managed events, unselected periods, roster overrides, and given/received/canceled state during re-sync.
- Map provider events to stable canonical assignment/transaction identities; provider-specific fields must not become the source of truth for roster semantics.
- Verify Web Push subscription lifecycle, permission/opt-in, VAPID secret handling, outbox/worker, retry/backoff, expired endpoint cleanup, and delivery observability.

Acceptance:
- A live test account can create/update/reconcile the expected event without duplicates.
- A timeout after provider acceptance can be recovered without creating a second event.
- Syncing one month does not delete or rewrite unrelated months or user overrides.
- A shift transaction is not fulfilled merely because a Calendar event was written; each required participant confirmation and fulfillment rule is enforced.
- A real supported browser receives an opted-in test notification; failure/retry/expired-subscription behavior is observable.

Current evidence boundary: Calendar Sync/Web Push foundations and coordination API tests are present in merged work. Do not rebuild those foundations; qualify provider and delivery paths with real integration evidence.

## 4. Universal Roster and workbook import

**Purpose:** understand each user's roster source and work semantics without requiring a fixed spreadsheet template or predefined organization vocabulary.

Scope:
- Discover candidate regions, section boundaries, orientations, headers, date axes, people, shifts, statuses, and optional metadata from evidence; do not require fixed row/column positions or known sheet names.
- Resolve date systems and periods independently for each section before assigning people or interpreting shift cells; accommodate localized calendars and source-specific date representations through reader adapters.
- Support new and evolving structures through reusable discovery/interpreter components and optional, versioned user profiles. Profiles are hints, never format locks; current source evidence takes precedence.
- Detect incomplete, duplicate, out-of-order, ambiguous, and conflicting facts; report source coordinates, evidence, alternatives, and affected scope.
- Allow user-defined departments, roles, people identifiers, shift vocabularies, statuses, and metadata without requiring code changes for each new value.
- Support focused corrections and staged review; every correction rebuilds affected canonical records and reruns dependent validations before commit.
- Preserve source provenance and reconcile revisions without overwriting user-confirmed edits, overrides, given/received/canceled transactions, or unrelated schedule ranges.
- Verify identity matching never silently assigns an uncertain person; unknown values remain visible and reviewable.

Acceptance:
- A previously unseen layout or renamed/reordered organizational vocabulary can be discovered and reviewed without adding a format-specific branch to core business logic.
- Ambiguous mappings are presented with evidence and alternatives; only the affected unresolved scope is blocked when it can be isolated safely.
- A real source is imported with a reproducible preview, focused correction trail, provenance, and read-back verification.
- Re-importing the same source is idempotent; changed source revisions produce a reconciled change set and never erase accepted user changes.
- Parameterized and metamorphic tests demonstrate that harmless layout changes do not alter semantic assignments; negative tests prove uncertainty is not silently accepted.
- Representative user workbooks, including X-OPD November 2569, 16 Nov–15 Dec 2569, and US Clinic ภปร.4 when available, are valuable regression evidence but are examples—not required templates or the complete universe of formats.

External workbooks are useful for validating real-world behavior. Their absence blocks acceptance of those particular examples, not the architectural goal of flexible roster discovery. The detailed test dimensions and safety rules are defined in the canonical parser reliability specification.

## 5. Shift Pay and workforce rules

**Purpose:** calculate pay transparently from confirmed work and effective policy.

Scope:
- Verify Personal, Organization, and Hybrid rule-source resolution and explicit, configurable precedence.
- Model pay arrangements and compensation rules as extensible, versioned policy data; fixed-per-shift, hourly, multiplier, salary-included, compensatory-time, and future user-defined conditions are examples, not a closed list.
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
- Define AI assistant capabilities against actual available data and permissions: schedule lookup, roster/person search, summaries, anomaly detection, shift-pay explanation, and history questions are examples, not a fixed capability ceiling.
- AI may suggest new mappings or explain unfamiliar roster vocabulary, but must cite source evidence, expose uncertainty, and request confirmation before any domain mutation.
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
- Run critical journeys across platforms and environments actually supported by the current product, distinguishing source availability, buildability, runtime support, and signed/distributable release support without treating a fixed platform list as a product boundary.
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
- Do not turn representative examples, current departments, shift labels, pay modes, platform targets, or test fixtures into exhaustive product constraints.
- Keep adapters and profiles extensible; put roster semantics in the canonical domain model and preserve unknown-but-valid source data for review.
- Preserve user data, API contracts, schema compatibility, and existing workflows.
- Prefer zero-cost/local-first solutions; add hosted services only with explicit owner-controlled configuration and operational justification.

## Live progress log

Update this table only with evidence observed for the specific SHA or controlled test run.

| Package | Status | Evidence / blocker | Next action |
|---|---|---|---|
| 1. Evidence, CI/CD, docs | IN PROGRESS | Main base SHA recorded above; PR #216 and #217 require fresh exact-head inspection | Inspect PR heads/checks, reconcile docs, merge only when all required checks pass |
| 2. Shared backend/data integrity | NOT VERIFIED | Existing Laravel/API foundations; full writer/CAS/ledger/restore acceptance not established by this plan | Audit canonical implementation and tests |
| 3. Calendar Sync/Web Push | PARTIAL / NOT VERIFIED | Foundations merged; real provider and browser delivery acceptance not established | Run controlled provider and push integration tests |
| 4. Universal Roster | PARTIAL / NOT VERIFIED | Flexible discovery/review foundations and canonical design exist; exact-head implementation coverage still needs audit | Audit implementation against the canonical flexible-layout spec; expand semantic/metamorphic tests and use real workbooks as examples, not templates |
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
