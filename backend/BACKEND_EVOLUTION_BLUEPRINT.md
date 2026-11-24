# Backend Evolution Blueprint

**Status:** Draft for review  
**Baseline branch:** `main`  
**Baseline commit:** `c847d70b98c2693a11c1063e989c55f2ab825d04`  
**Scope:** Evolve the existing Laravel backend without replacing or losing existing application data.

## 1. Executive decision

The project already contains a Laravel API under `backend/`. This work is an incremental backend evolution, not a greenfield replacement and not a database reset.

The existing API remains the compatibility baseline. New capabilities must be added behind explicit contracts, additive schema changes, and tests. Existing Flutter behavior, Google Calendar integration, local roster persistence, organization membership, and shift-transaction history must continue to work.

## 2. Verified repository baseline

The inspected `main` tree contains:

- Laravel backend under `backend/`, with PHP requirement `^8.4.1` and Laravel `^13.8`.
- API routes and documentation under `backend/routes/api.php`, `backend/API_DOCUMENTATION.md`, and `backend/README.md`.
- Google ID-token verification and account resolution middleware.
- Organization, membership, join-request, and shift-policy endpoints.
- Shift transaction creation and lifecycle service with idempotency, request hashing, row locking, versioning, participants, transfers, and event history.
- Organization membership audit-event migration.
- Web Push subscription storage migration.
- Laravel feature tests for health/readiness, CORS, Google authentication, organizations, join requests, shift transactions, and Web Push subscriptions.
- A dedicated Laravel CI workflow using PHP 8.4, SQLite in-memory tests, Composer validation/audit, Pint, and Laravel tests.

The repository also has a Flutter client with existing local repositories and Google integrations. The backend must not silently take ownership of local data or external Google writes.

## 3. Non-negotiable data and compatibility guarantees

1. Never run `migrate:fresh`, `db:wipe`, destructive seeding, or production reset commands.
2. Never drop, truncate, rename, or repurpose an existing production table or column as part of routine rollout.
3. Existing `/api/v1` request and response contracts remain supported unless a separately reviewed deprecation plan is approved.
4. Existing user, organization, membership, join-request, shift-transaction, participant, transfer, event, audit, and push-subscription records must be preserved.
5. New migrations are additive by default. Any exceptional data transformation requires a backup, a dry-run report, reconciliation counts, an explicit rollback/forward-repair plan, and approval.
6. No production migration, data backfill, credential rotation, deployment, or external Google write is authorized by this blueprint.
7. No direct commit to `main`; implementation changes go through focused pull requests. No PR is merged without explicit approval.
8. `PASS`, `FAIL`, `SKIPPED`, and `UNKNOWN` remain distinct. Missing or skipped evidence is never a pass.

## 4. Target architecture

Keep Laravel as the server-side API and evolve it through bounded modules. Do not introduce a second backend framework or paid infrastructure without a measured requirement.

Suggested logical boundaries:

- **Identity:** Google token verification, account resolution, explicit account-linking workflow, authenticated principal.
- **Organizations & access:** tenant membership, roles, join requests, policy evaluation, audit history.
- **Roster references:** stable identifiers and metadata needed by server workflows; do not copy complete rosters unless required and approved.
- **Shift transactions:** transaction aggregate, participants, transfers, lifecycle state machine, idempotency, concurrency control, immutable event history.
- **Shift-pay rules:** personal, organization, and hybrid rule-source resolution; explicit precedence and missing-rule states; organization scope enforcement.
- **Calendar coordination:** durable intent and synchronization state only; actual Google Calendar writes remain client-confirmed until a separately reviewed server-side OAuth design exists.
- **Notifications:** subscription management, durable delivery intent, retry/dead-letter handling, and provider adapter. Subscription storage alone is not a delivery system.
- **Diagnostics & operations:** health/readiness, request correlation, bounded client diagnostics, structured redacted logs, metrics and operational audit.

Implementation should use Laravel controllers as thin HTTP adapters, request objects for validation, application services/use cases for orchestration, domain objects/policies for business rules, and infrastructure adapters for persistence/providers. Avoid a large rewrite or speculative abstraction layer.

## 5. API evolution policy

- Preserve `/api/v1` and its established semantics.
- Add endpoints to v1 only when they are strictly backward-compatible.
- Introduce `/api/v2` only when a contract cannot be evolved compatibly; run contract tests against both versions during transition.
- Publish OpenAPI or equivalent machine-readable schemas from the actual route/request/response implementation.
- Standardize error envelopes without changing existing v1 error shapes unexpectedly.
- Keep `X-Request-ID`, HTTPS requirements, exact CORS origin allowlists, and rate limits.
- Never log bearer tokens, OAuth credentials, raw roster contents, or sensitive personal data.

## 6. Data and migration strategy

### 6.1 Inventory before schema changes

Record the actual deployed database engine/version, migration table state, table/column/index/foreign-key inventory, row counts, data volumes, backup/restore process, and retention obligations. Repository migrations and SQLite CI do not prove the production database engine or production schema state.

### 6.2 Expand, migrate, contract

1. **Expand:** add nullable columns, new tables, or compatible indexes without changing existing reads/writes.
2. **Backfill:** use resumable, idempotent batches with checkpoints and before/after counts. Never infer missing business data.
3. **Verify:** compare source/target counts, uniqueness, referential integrity, and domain invariants.
4. **Switch:** enable new reads/writes behind a feature flag after verification.
5. **Observe:** monitor errors, latency, queue lag, and reconciliation.
6. **Contract:** remove obsolete schema only in a separately approved future change after all clients and rollback windows are proven safe. No contract step is part of the initial rollout.

For event history, preserve existing rows and IDs. Any future stronger append-only guarantee must be introduced without rewriting historical events and must be tested against the production database engine.

## 7. Reliability and consistency

- Keep idempotency scoped to the authenticated actor and operation. Reuse with a different canonical payload must conflict.
- Keep state transitions atomic and concurrency-safe.
- Use a transactional outbox for future asynchronous side effects so a committed domain transition cannot silently lose its notification/delivery intent.
- Make workers idempotent; use bounded retries, exponential backoff, dead-letter visibility, and replay controls.
- Do not report a calendar operation as complete until the provider outcome is reconciled.
- Treat external provider timeouts as ambiguous outcomes; reconcile before retrying writes.
- Add pagination and stable ordering to growing history/audit endpoints.

## 8. Security and tenant isolation

- Verify Google ID tokens server-side; do not trust client-supplied user IDs, roles, employee IDs, or organization IDs.
- Resolve tenant access on every organization-scoped operation.
- Enforce least privilege and explicit account linking; do not merge accounts by email alone.
- Encrypt provider endpoints/secrets at rest where applicable and keep encryption keys outside source control.
- Validate and bound all metadata and diagnostics.
- Add authorization tests for cross-tenant reads/writes, role escalation, inactive memberships, and account conflicts.
- Review retention and deletion semantics before changing foreign-key behavior.

## 9. Phased delivery plan

| Phase | Deliverable | Exit evidence |
|---|---|---|
| 0. Baseline audit | Production configuration/schema inventory, API contract inventory, data classification, backup/restore proof | Signed-off inventory; unknowns explicitly listed |
| 1. Backend foundation | Module boundaries, consistent validation/error handling, API contract tests, health/readiness hardening | Existing v1 tests pass; new contract tests pass |
| 2. Identity & tenancy | Explicit account linking, tenant-scoped authorization matrix, membership audit API integration | Positive and negative authorization tests |
| 3. Shift-pay backend | Persisted personal/organization/hybrid rule profiles and deterministic source resolution | Mode isolation, precedence, missing-rule, tenant-scope tests |
| 4. Transaction reliability | Outbox, replay-safe workers, stronger event integrity and pagination | Concurrency, retry, duplicate delivery, and history tests |
| 5. Calendar coordination | Durable sync intents and reconciliation without implicit external writes | Provider-fake E2E and explicit-confirmation tests |
| 6. Notifications | Complete Web Push sender, encryption, queue, retry and opt-in lifecycle | Browser/provider integration tests and delivery telemetry |
| 7. Controlled rollout | Staging migration rehearsal, backup restore drill, canary, monitoring, rollback rehearsal | Reconciled data and explicit production approval |

Phases may be split into smaller PRs. Do not mark a phase complete based only on documentation or a successful SQLite test.

## 10. Immediate implementation sequence

1. Finish the read-only audit of every existing migration, route, controller, service, model, and feature test.
2. Determine the real production database and deployment topology from verified deployment configuration; do not infer it from repository defaults.
3. Publish a route-by-route v1 contract inventory and authorization matrix.
4. Add missing characterization tests before changing existing behavior.
5. Implement the first small, additive backend slice selected from confirmed product requirements. The current candidate is Shift Pay profile persistence and rule-source resolution, aligned with the open Shift Pay work, but its API and data contract must be reviewed first.
6. Keep CI on hosted runners for backend validation; the Windows self-hosted runner initialization error is a separate runner concern and must not block or be “fixed” by rewriting application backend code.

## 11. Risks and unresolved facts

- Production database engine, version, schema drift, row counts, and backup restore evidence are not established by this source audit.
- Deployment host, worker/scheduler topology, queue driver, and secret-management configuration require verification.
- Existing Web Push subscription storage is present, but full delivery infrastructure is not established.
- The current membership audit migration exists; end-user API/UI exposure requires separate verification.
- The current shift-transaction service and schema need a focused concurrency and authorization review before extending their lifecycle.
- Existing documentation snapshots may lag the current `main` SHA; source and exact-SHA CI evidence take precedence.

## 12. Definition of done

A backend evolution slice is complete only when:

- It preserves all existing data and v1 behavior.
- It adds a focused migration or explicitly documents why no schema change is needed.
- It includes positive, negative, authorization, concurrency, and regression tests appropriate to the change.
- Composer validation, dependency audit, Pint, and the full Laravel test suite pass on the exact PR head.
- API documentation and traceability are updated.
- The PR records changed files, migration safety, deployment prerequisites, evidence, and known unknowns.
- It remains unmerged until explicit approval.
