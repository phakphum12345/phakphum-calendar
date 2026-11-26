# Shift Tools Laravel API

The Laravel service provides authenticated account and organization boundaries
for the Shift Tools application. It does not replace the Flutter roster parser,
local schedule persistence, or Google Calendar integration.

## Requirements and setup

- PHP 8.4.1 or later
- Composer 2
- SQLite for local development, or another Laravel-supported database
- A Google OAuth server/web client ID configured for the API

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate
php artisan serve
```

The default development URL is `http://127.0.0.1:8000`.

Configure `GOOGLE_ALLOWED_CLIENT_IDS` as a comma-separated list of OAuth client
IDs that may be used to obtain Google ID tokens for this API. The API verifies
the token signature against Google's published certificates and checks issuer,
audience, authorized party, expiry, issued-at time, Google subject, and verified
email. The API fails closed when no accepted audience is configured.

For browser clients, set `FRONTEND_ALLOWED_ORIGINS` to a comma-separated list
of exact frontend origins (scheme and host, without a path). The Flutter web
build reads `ORGANIZATION_API_BASE_URL` at build time; set it to the HTTPS
origin of this API. In GitHub Actions, configure it as the repository variable
of the same name. An empty value deliberately leaves organization membership
controls unavailable in the web app.

Existing password-based user records are not silently linked to Google accounts
by matching email. An account collision returns `409 account_link_required`
and requires an explicit account-linking workflow.

## API

Unauthenticated operational endpoints:

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/health` | Process liveness |
| `GET` | `/api/v1/ready` | Database readiness |
| `POST` | `/api/v1/diagnostics/client-errors` | Rate-limited, validated client error report |

Google ID token required in `Authorization: Bearer <id-token>`:

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/me` | Resolve the authenticated Google account |
| `GET` | `/api/v1/organizations` | List the caller's active organizations |
| `POST` | `/api/v1/organizations` | Create an organization and become its owner |
| `GET` | `/api/v1/organization-join-requests` | List the caller's join requests |
| `POST` | `/api/v1/organization-join-requests` | Request to join by organization slug and employee ID |
| `GET` | `/api/v1/organizations/{id}/members` | List active organization members |
| `POST` | `/api/v1/organizations/{id}/members` | Add an already-registered Google account |
| `GET` | `/api/v1/organizations/{id}/join-requests` | List pending requests for an owner or admin |
| `POST` | `/api/v1/organizations/{id}/join-requests/{request}/approve` | Approve a request and assign its role |
| `POST` | `/api/v1/organizations/{id}/join-requests/{request}/reject` | Reject a pending request |
| `GET` | `/api/v1/organizations/{id}/shift-policies` | Read approval policy by workflow |
| `PUT` | `/api/v1/organizations/{id}/shift-policies/{workflow}` | Configure approval policy |

Organization creation requires the owner's employee ID. A new user signs in
with Google, submits the organization slug supplied by its administrator and
an employee ID, then waits for an owner or admin to review the Google profile
and approve with a role (`staff`, `incharge`, `manager`, or `admin`) or reject.
The applicant cannot choose their own role. Rejected requests may be resubmitted.
The existing direct-add endpoint remains an owner/admin operation and requires
that the target account has signed in at least once with a verified Google
email; invitations for accounts that have never signed in are not supported.
Only organization owners and admins may review requests, add members, or change
policies. New organizations default to requiring approval for give-up,
exchange, and exchange-and-return. Personal-mode requests do not use these
organization policies.

All API responses include `X-Request-ID`. A valid caller-supplied request ID is
preserved; otherwise the API creates a UUID. ID tokens and credentials are never
written to application logs.

This phase does not expose shift-transaction write endpoints and does not write
to rosters or Google Calendar. The next implementation part will add shared
transaction persistence, participant confirmations, organization approval
enforcement, idempotency, and append-only transaction events.

## Validation

```bash
composer validate --strict
vendor/bin/pint --test
php artisan test
```

These checks run in `.github/workflows/laravel.yml`.

## Shift transaction history API

All shift transaction routes require `Authorization: Bearer <Google ID token>`.

| Method | Endpoint | Purpose |
| --- | --- | --- |
| GET | `/api/v1/shift-transactions` | List transactions visible to the caller |
| POST | `/api/v1/shift-transactions` | Create a transaction; requires `Idempotency-Key` |
| GET | `/api/v1/shift-transactions/{id}` | Read transaction and event timeline |
| POST | `/{id}/confirm` | Confirm as a participant |
| POST | `/{id}/reject` | Reject as a participant |
| POST | `/{id}/approve` | Approve under organization owner/admin authorization |
| POST | `/{id}/reject-by-approver` | Reject under organization owner/admin authorization |
| POST | `/{id}/cancel` | Cancel as requester before Calendar sync |
| POST | `/{id}/calendar-sync/start` | Start after explicit preview confirmation |
| POST | `/{id}/calendar-sync/complete` | Record provider event references after client sync succeeds |
| POST | `/{id}/calendar-sync/fail` | Record recoverable Calendar write failure |
| POST | `/{id}/fulfill` | Fulfill one shift obligation after its scheduled end |

List filters: `mode=personal|organization`, `type=give_up|exchange|exchange_and_return`, `month=YYYY-MM`, `staff_id=<employee-id>`, `shift_type=<shift-code>`, and `organization_id=<uuid>`. Personal history is visible only to the two participants. Organization history is visible to active members of that organization.

Creation is idempotent per authenticated requester and key. Reusing a key with a different request payload returns HTTP 409. Each lifecycle update uses a database transaction and row lock, increments the transaction version, and appends an event atomically.

Every create and lifecycle transition appends a row to `shift_transaction_events`. The API exposes no event update/delete route, and restrictive foreign keys prevent deletion of transaction records while event history exists. Events retain the actor, organization scope, event type, transaction version, timestamp, and event-specific data.

Calendar sync start requires `preview_confirmed=true`. Completion records one distinct Google Calendar event reference per transfer supplied by the authenticated client; this API records the client acknowledgement and does not itself call Google Calendar. A successful Calendar write does not complete the shift transaction. Only the employee receiving a transfer may confirm fulfillment, and only after the scheduled shift end. Exchange-and-return remains approved until every transfer leg is fulfilled.

Validation: `composer validate --strict`, `vendor/bin/pint --test app config database routes tests`, and `php artisan test`. These checks run in `.github/workflows/laravel.yml`.


## Continuous integration

The Laravel GitHub Actions workflow creates an empty `.env` file in its isolated test workspace. All test configuration is supplied through the workflow environment; developer and production secrets are not copied into CI. The workflow validates Composer, installs the locked dependencies, runs `composer audit --locked`, checks PHP formatting and bootstrap syntax, and runs the Laravel test suite. A successful Composer audit is evidence for the locked PHP dependency graph on that exact commit; it does not certify Flutter/Dart package advisories or later commits.
