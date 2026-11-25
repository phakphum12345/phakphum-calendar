# Backend API Documentation

**API version:** `/api/v1`  
**Implementation source:** `backend/routes/api.php`, controllers and `ShiftTransactionService`.

This document describes the current routes. Request validation and service authorization remain authoritative.

## Authentication and rate limits

- Public health routes: `GET /api/v1/health`, `GET /api/v1/ready`.
- Public client diagnostics: `POST /api/v1/diagnostics/client-errors`, throttled at 30 requests per minute.
- All account, organization, Schedule, import-journal and shift-transaction routes use the `google.account` middleware and are throttled at 120 requests per minute.
- Send a Google **ID token** as `Authorization: Bearer <google-id-token>`. The backend verifies the Google identity token; do not send an OAuth client secret or refresh token.
- The middleware resolves or updates the account by verified Google subject and rejects conflicting email identities.


## Request correlation

- Clients may send `X-Request-ID` using 8–128 ASCII letters, digits, dots, underscores or hyphens.
- The API validates the supplied value; missing or malformed values are replaced with a generated UUID.
- API responses echo the effective value in the `X-Request-ID` response header.
- Health and client-diagnostics responses also include `request_id` in the JSON body; other endpoint bodies retain their existing domain-specific shape.
- The Flutter shift-transaction client generates a distinct opaque ID for each request and sends it in this header.
- Clients must use HTTPS for non-loopback API origins; HTTP is permitted only for loopback local development.
- Browser CORS permits the `X-Request-ID` header and exposes it to clients; membership `PATCH` and `DELETE` preflights are allowed but remain subject to Google bearer authentication.
- Request IDs are diagnostic metadata, not authentication credentials or authorization claims.

## Route inventory

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Liveness |
| GET | `/ready` | Readiness |
| POST | `/diagnostics/client-errors` | Accept bounded client diagnostics |
| GET | `/me` | Current authenticated account |\n| GET / PUT / DELETE | `/schedules/{scheduleId}` | Read / conditional-save / tombstone-delete personal Schedule |\n| GET / POST | `/schedules/{scheduleId}/import-journals` | Discover append-only import journal records / append PREPARED or COMMITTED stage |
| GET / POST | `/organizations` | List memberships / create organization |
| GET | `/organization-join-requests` | Current user's join requests |
| POST | `/organization-join-requests` | Request membership by organization slug |
| GET | `/organizations/{organizationId}/members` | List active members |
| POST | `/organizations/{organizationId}/members` | Add a registered Google account |
| GET | `/organizations/{organizationId}/join-requests` | Owner/admin review queue |
| POST | `/organizations/{organizationId}/join-requests/{requestId}/approve` | Approve join request |
| POST | `/organizations/{organizationId}/join-requests/{requestId}/reject` | Reject join request |
| GET | `/organizations/{organizationId}/shift-policies` | Read organization policies |
| PUT | `/organizations/{organizationId}/shift-policies/{workflowType}` | Update workflow policy |
| GET / POST | `/shift-transactions` | List / create transactions |
| GET | `/shift-transactions/{transactionId}` | Read transaction |
| POST | `/shift-transactions/{transactionId}/confirm` | Recipient confirmation |
| POST | `/shift-transactions/{transactionId}/reject` | Recipient rejection |
| POST | `/shift-transactions/{transactionId}/approve` | Owner/admin organization approval |
| POST | `/shift-transactions/{transactionId}/reject-by-approver` | Owner/admin rejection |
| POST | `/shift-transactions/{transactionId}/cancel` | Cancel transaction |
| POST | `/shift-transactions/{transactionId}/calendar-sync/start` | Start confirmed calendar sync |
| POST | `/shift-transactions/{transactionId}/calendar-sync/complete` | Record completed calendar sync |
| POST | `/shift-transactions/{transactionId}/calendar-sync/fail` | Record failed calendar sync |
| POST | `/shift-transactions/{transactionId}/fulfill` | Fulfill a transfer |

The full URL shape is `{APP_URL}/api/v1/{path}`; paths in the table are relative to `/api/v1`.

## Schedule persistence and Grid import journal

All Schedule endpoints require a verified Google ID token and are scoped to the authenticated account. They do not expose another account's records and do not trigger Calendar synchronization.

### Read a Schedule

`GET /api/v1/schedules/{scheduleId}`

Returns the canonical JSON payload, a revision token and state (`live`, `deleted`, or `absent`). An absent Schedule returns HTTP 200 with `data: null` and an account- and Schedule-ID-scoped absent revision token.

### Conditional save

`PUT /api/v1/schedules/{scheduleId}`

Request:

```json
{
  "expected_revision": "absent:<sha256-of-schedule-id>",
  "schedule": {
    "format": "shift-tools.canonical-schedule",
    "version": 1,
    "schedule": {
      "id": "roster-2026-11",
      "name": "November",
      "departments": [],
      "employees": [],
      "shiftTypes": [],
      "months": []
    }
  }
}
```

A first create using the absent token returns HTTP 201 and revision `v1:<sha256>`. A subsequent save must send the exact current revision. The database update matches account, Schedule ID, generation and fingerprint in one conditional statement; stale writers receive HTTP 409 with `schedule_revision_conflict` and the current revision. A revision mismatch never overwrites the current payload.

### Conditional delete

`DELETE /api/v1/schedules/{scheduleId}` with JSON body `{"expected_revision":"vN:<sha256>"}` advances the generation and leaves a tombstone. It does not physically remove the record. A stale revision cannot recreate a tombstoned Schedule. The client must refresh and make an explicit decision before any future restore flow.

### Import journal

- `GET /api/v1/schedules/{scheduleId}/import-journals` lists the authenticated account's append-only journal stages.
- `POST /api/v1/schedules/{scheduleId}/import-journals` appends one `prepared` or `committed` stage, keyed by import run ID and lifecycle.
- A `committed` stage requires a matching prior `prepared` stage with the same Schedule ID, base revision and source fingerprint, and includes the accepted Schedule and fingerprint.
- Replaying the exact same stage is idempotent. Reusing the same import run/lifecycle with different content returns HTTP 409.
- Journal writes do not automatically replay or overwrite the canonical Schedule. Recovery and user-visible conflict resolution remain explicit client responsibilities.

**Current boundary:** this first backend slice stores personal Schedule records per authenticated account. Organization-shared roster ownership/permissions and Flutter client wiring are separate follow-up work; no existing SharedPreferences data is migrated or deleted by these endpoints. Production deployment and live-provider integration are not implied by source changes or CI alone.

## Create a shift transaction

`POST /api/v1/shift-transactions`

Required headers:

```http
Authorization: Bearer <google-id-token>
Content-Type: application/json
Idempotency-Key: <stable-unique-key>
```

The idempotency key is required and must contain 1–128 characters. Repeating the same key and same canonical request returns the existing transaction. Reusing the key for a different request returns a conflict.

Supported values:

- `mode`: `personal` or `organization`.
- `type`: `give_up`, `exchange` or `exchange_and_return`.
- `participants`: exactly two entries, one `requester` and one `recipient`; account and employee identities must be distinct.
- `transfers`: one or two transfer entries, each with a unique transfer ID, shift ID, source/destination employee IDs, shift code, start/end timestamps and purpose. Allowed purposes are `give_up`, `exchange`, `primary` and `return_shift`.
- `organization_id`: required for organization mode and prohibited for personal mode.
- `metadata`: optional object/array restricted to the `note` and `schedule_id` keys. `note` is nullable text up to 1,000 characters; `schedule_id` is a nullable string up to 128 characters. Unknown keys are rejected. Do not send tokens, secrets, full rosters or unnecessary personal data.

Example shape:

```json
{
  "mode": "personal",
  "type": "give_up",
  "participants": [
    {"employee_id": "EMP-A", "role": "requester"},
    {"email": "verified-recipient@example.test", "employee_id": "EMP-B", "role": "recipient"}
  ],
  "transfers": [
    {
      "id": "transfer-1",
      "shift_id": "shift-2026-11-20-EMP-A",
      "from_employee_id": "EMP-A",
      "to_employee_id": "EMP-B",
      "shift_code": "MORNING",
      "starts_at": "2026-11-20T08:00:00+07:00",
      "ends_at": "2026-11-20T16:00:00+07:00",
      "purpose": "give_up"
    }
  ]
}
```

The authenticated user is authoritative for the requester. A recipient must resolve to a registered account with verified identity. In organization mode both participants must be active members and their employee IDs must match their membership records. The organization member-add endpoint accepts `staff`, `incharge`, `manager` or `admin` as the new member role. Only an existing organization `owner` or `admin` may add members, review join requests or update shift policies; a member whose role is `manager` does not receive these owner/admin permissions. Transfer shape is type-specific: `give_up` requires one `give_up` transfer; `exchange` requires two reciprocal `exchange` transfers; `exchange_and_return` requires one `primary` and one reciprocal `return_shift` transfer.

A successful create returns HTTP 201 with a `data` transaction snapshot.

## Transaction lifecycle and calendar sync

Calendar writes remain behind a preview-and-confirm flow:

1. Create the transaction.
2. Recipient confirms or rejects.
3. Organization manager approves or rejects when the organization policy requires it.
4. Client displays the calendar preview and obtains explicit confirmation.
5. Call `calendar-sync/start` with `preview_confirmed: true`.
6. On success call `calendar-sync/complete` with either the legacy `calendar_event_ids` array (one distinct ID per transfer leg, mapped in transfer creation order) or the structured `calendar_events` array. Each structured item contains `transfer_id`, `provider`, `event_id`, and optional `calendar_id` and `etag`. Exactly one distinct mapping is required for every transfer leg.
7. On failure call `calendar-sync/fail` with an optional bounded reason. A failed attempt can be retried by starting a new attempt after the previous one has been recorded as failed.
8. Repeating a completed request with the exact same event mappings is idempotent. Repeating completion with different mappings returns HTTP 409.
9. Transaction reads include `calendar_events` (per-transfer provider references) and `sync_attempts` (attempt number, status, actor and timestamps).
10. Fulfill a transfer with `transfer_id` when the workflow conditions are met.

The service uses database transactions, row locking, a transaction version, idempotency keys and append-only event records by service convention. Event records have an auto-incrementing ID and transaction version; the current schema does not define a separate event-sequence column. Do not bypass the service with direct production database writes.

## List filters

`GET /api/v1/shift-transactions` accepts optional:

- `mode`
- `type`
- `month` in `YYYY-MM` format (filtered by effective shift start date)
- `organization_id`
- `staff_id`
- `shift_type`

The service currently returns at most 100 transactions. Cursor pagination is not implemented in this route.

## Error handling

Typical responses:

| HTTP status | Meaning |
|---:|---|
| 201 | Transaction created |
| 202 | Client diagnostic accepted |
| 401 | Missing or invalid Google identity token |
| 403 | Authenticated user lacks required membership/role |
| 404 | Organization, account or transaction not found |
| 409 | Idempotency, membership or state conflict |
| 422 | Request validation or business-rule failure |
| 429 | Rate limit exceeded |
| 503 | Identity verification provider temporarily unavailable |

Validation errors use Laravel's standard JSON validation response. The API may also return an `error` object with a stable `code` and user-safe `message`.

## Privacy and operational notes

- Do not log or transmit Google ID tokens, access tokens, refresh tokens, OAuth secrets or full roster files.
- Client diagnostic messages are accepted but are not included in server log context; the backend records only the message character length. Never place secrets or personal roster data in diagnostic messages.
- The optional `metadata` field is restricted to bounded `note` and `schedule_id` values. Keep both minimal and non-sensitive.
- Organization membership and transaction reads are authorized server-side; client-side role visibility is not an authorization boundary.
- The route list is not a promise that every workflow is production-enabled. Verify exact-head CI and live integration configuration before release.


## Shift Pay profiles and rule sources

The additive Shift Pay API persists user mode/preferences separately from organization-owned rules. It does not change existing shift-transaction request/response contracts or retroactively calculate historical payments.

- `GET /shift-pay/profile`: returns the authenticated user's mode, selected organization, hybrid precedence, currency precision, personal rules and (when an active membership exists) the selected organization's rules.
- `PUT /shift-pay/profile`: updates the user's `personal`, `organization` or `hybrid` mode, selected organization, precedence and personal rule set. Organization and hybrid modes require an organization ID; organization access is checked server-side.
- `GET /organizations/{organizationId}/shift-pay-rules`: reads organization-owned rules for an active member.
- `PUT /organizations/{organizationId}/shift-pay-rules`: replaces the organization's rule set and is restricted to active owners/admins.

Rule definitions use the existing Flutter calculator vocabulary: employment type, day category, shift type, optional department/location/work point, assignment purpose, pay component, treatment, fixed amount/hourly rate, multiplier, active state and compensatory-time metadata. IDs must be unique within a source. Additional-pay rules require a fixed amount or hourly rate unless salary-included; compensatory-time rules require a compensated shift type.

The profile response keeps personal and organization rules in separate arrays. Consumers must apply the selected mode and hybrid precedence and must never add both source amounts. An unresolved hybrid conflict remains a source-selection requirement, not a payable amount. This API persists configuration only; server-side calculation snapshots and payroll posting are separate future work.

All endpoints use the existing Google account middleware and rate limit. No production migration or deployment is implied by adding this migration to source control.


## Shift Pay calculation and immutable snapshots

POST /api/v1/shift-pay/calculations calculates one assignment using the authenticated user's saved profile and persists the exact calculation as an immutable historical snapshot. Send Idempotency-Key (1–128 characters) with every calculation request.

Input fields: date (YYYY-MM-DD), employment_type (salaried or dailyPaid), shift_type_id, and hours; optional department, location, work_point, assignment_purpose, date_overrides keyed by ISO date, weekly_days_off (Monday=1 through Sunday=7), and selected_source (personal or organization) for explicit hybrid selection.

The engine follows the Flutter rule-matching contract: active state, employment type, day category, shift type, assignment purpose, optional department/location/work point matching, and specificity weights (department 4, location 2, work point 1). Fixed amount takes precedence over hourly rate; hourly rate is multiplied by hours, then the configured multiplier is applied. Compensatory-time and salary-included treatments return zero cash pay with treatment metadata. Amounts use the selected profile's decimal precision and half-up rounding.

Personal, organization and hybrid modes select at most one source. Hybrid precedence is organizationFirst, personalFirst, or requireSelection; when both sources match under requireSelection, the response is source_selection_required with a null amount. The service never adds personal and organization amounts together. Missing matches return no_matching_rule with a null amount, not an invented zero.

The snapshot stores exact input, selected rule (when any), result, source, calculation engine version and profile configuration versions. Later rule edits do not recalculate or rewrite earlier snapshots. Reusing an idempotency key with the same request and same profile versions returns the original snapshot; reusing it for a different calculation returns HTTP 409.

GET /api/v1/shift-pay/snapshots lists the authenticated user's snapshots using cursor pagination (limit 1–100; default 50). GET /api/v1/shift-pay/snapshots/{snapshotId} retrieves one snapshot only for the authenticated user who created it. Snapshots are audit records, not payroll postings, statutory wage determinations or payment instructions. No existing shift transaction or historical record is modified.
