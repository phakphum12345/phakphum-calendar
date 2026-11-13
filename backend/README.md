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
