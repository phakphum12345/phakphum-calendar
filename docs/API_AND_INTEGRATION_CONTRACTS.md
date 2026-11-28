# API and Integration Contracts

**Status:** Architecture contract and audit checklist; current endpoints are documented in [Backend API Documentation](../backend/API_DOCUMENTATION.md).  
**Prepared:** 2026-11-24  
**Related:** [API Foundation](API_FOUNDATION.md), [Architecture](../ARCHITECTURE.md), [Database Schema](../backend/DATABASE_SCHEMA.md), [Security](../SECURITY.md)

## 1. Purpose

Define integration boundaries between Flutter features, domain services, local persistence, Laravel API, Google providers and future source/generator adapters. This document supplements the route-level API reference; it does not invent new endpoints or assert that future contracts are implemented.

## 2. Current source-of-truth files

- API routes: `backend/routes/api.php`.
- Request validation and controller behavior: `backend/app/Http/Controllers/Api/V1/`.
- Authentication: `backend/app/Http/Middleware/AuthenticateGoogleAccount.php` and identity-token verifier.
- Domain operations: `backend/app/Services/`.
- Schema: `backend/database/migrations/`; `backend/DATABASE_SCHEMA.md` is a summary only.
- Flutter dependency composition: `lib/core/di/app_dependencies.dart`.
- Flutter feature boundaries: `lib/features/`.
- Google authorization/provider gateways: existing Google client factory and Calendar/Drive/Sheets adapters.

When this document conflicts with code or migrations, implementation is authoritative until an approved ADR changes the contract.

## 3. Dependency direction

```text
Flutter Presentation
  -> Feature Application Use Cases
  -> Domain Models + Repository / Gateway Interfaces
  -> Infrastructure Adapters
       -> Local Storage
       -> Laravel API Client
       -> Google Drive / Sheets / Calendar
```

Laravel request handling follows:

```text
Route + Middleware
  -> Request Validation
  -> Controller (transport mapping)
  -> Application / Domain Service
  -> Scoped Repository / Database
  -> Resource / Response
```

Rules:
- Widgets do not call Google APIs or raw HTTP endpoints directly.
- Controllers do not contain business policy that belongs in domain services.
- Domain models do not depend on Flutter widgets or provider SDK response types.
- External provider payloads are mapped at adapter boundaries.
- A source provider cannot bypass the canonical import/validation workflow.
- Do not create parallel clients, repositories or sync coordinators without an ADR and migration plan.

## 4. API contract requirements

For each endpoint, maintain a contract entry with:
- HTTP method and versioned path;
- authentication and authorization policy;
- organization/account scope;
- request schema and validation rules;
- response schema and stable error codes;
- idempotency behavior for writes;
- rate limit and retry policy;
- request correlation behavior;
- privacy classification and logging policy;
- compatibility/deprecation policy;
- unit, feature and client contract tests.

The existing backend documentation states that account, organization and shift-transaction routes use the `google.account` middleware; clients send a verified Google ID token as a Bearer token, not an OAuth client secret or refresh token. Confirm each route's current middleware and policy before changing it.

## 5. Authentication and authorization

Authentication establishes the account identity; authorization determines whether that account can perform an operation on a resource. Never treat a valid Google identity token as proof of organization ownership or permission to modify a roster.

Every organization-scoped read/write must verify active membership and the required role in the service/controller boundary. Avoid trusting organization IDs, employee IDs, owner flags or role names supplied by the client. Re-check permission at the time of mutation.

Token rules:
- Do not persist or log raw ID/access/refresh tokens in application logs.
- Never put client secrets in Flutter assets or source control.
- Use least-privilege scopes and request write scopes only for an explicitly selected operation.
- Do not broaden scopes automatically after a 403 response.
- Distinguish unauthenticated, forbidden, expired, invalid and transient provider errors.

## 6. Request and response behavior

- Validate content type, payload size, required fields, identifiers, date/time formats and enum/configuration values.
- Return stable machine-readable error codes; localized UI text is a client concern.
- Include request correlation IDs where supported and propagate them to safe structured logs.
- Do not expose stack traces, SQL, secrets, provider tokens or personal roster payloads in public errors.
- Paginate unbounded collections and define maximum batch sizes.
- Use explicit UTC or offset-aware timestamps for instants; use date-only fields for roster work dates.
- Preserve backward compatibility for existing clients through versioning or additive changes where safe.

## 7. Idempotency and concurrency

For write endpoints and external sync operations:
- define an idempotency key and its scope;
- bind the key to an authenticated principal and operation payload fingerprint;
- reject reuse with a materially different payload;
- define retention and replay response semantics;
- use optimistic concurrency or provider revision checks where relevant;
- persist operation outcomes before acknowledging completion when durability is required;
- reconcile timeout/unknown outcomes before retrying.

Do not assume that HTTP retry is safe merely because a request is a PUT/POST or the client timed out.

## 8. Error taxonomy

| Class | Example | Client behavior |
|---|---|---|
| Validation | Invalid date, missing required field | Show field-level error; no retry |
| Authentication | Missing/expired identity token | Re-authenticate through supported flow |
| Authorization | User lacks organization role | Stop; do not broaden scopes |
| Conflict | Stale revision or duplicate idempotency key | Refresh and request review |
| Not found | Resource outside accessible scope or absent | Respect privacy; avoid leaking existence |
| Rate limit | Provider/API throttle | Bounded backoff using server guidance |
| Transient | Network/service unavailable | Retry only if operation is safe/idempotent |
| Ambiguous outcome | Timeout after possible external write | Reconcile by stable operation ID before retry |
| Internal | Unexpected server failure | Correlation ID, redacted diagnostics, no sensitive payload |

## 9. Provider integration contracts

Each provider adapter should expose capabilities, authorization requirements, source identity, acquisition/snapshot semantics, cancellation, typed errors and limits. Google Drive, Sheets and Calendar remain separate capabilities; having access to one does not imply access to the others.

A future provider must pass the same normalized model, provenance, validation, preview and review boundaries. Unsupported platform/provider combinations should be disabled with a clear explanation, not silently routed to a different provider.

## 10. Contract testing

- Backend route tests verify authentication, authorization, validation and response shape.
- Flutter client tests verify request/response mapping and typed errors.
- Contract tests verify stable field names and backward compatibility.
- Tenant-isolation tests use two synthetic accounts/organizations.
- Idempotency tests replay the same operation and conflicting payload.
- Failure tests cover timeouts, rate limits and ambiguous provider outcomes.
- Integration tests use fakes or dedicated test accounts; never production staff data.
- API docs and schema docs are updated in the same PR as contract/migration changes.

## 11. Change process

Any API/database contract change must include:
1. current route/controller/service/migration audit;
2. backward compatibility and client version impact;
3. authorization and privacy review;
4. migration forward/rollback or recovery plan;
5. contract tests and integration tests;
6. updates to `backend/API_DOCUMENTATION.md`, `backend/DATABASE_SCHEMA.md`, and this index where relevant;
7. exact-head CI evidence.

No API route, OAuth scope, production environment, database data or external account is changed by this document.
