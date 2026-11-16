# Shift Tools Laravel API

The Laravel service provides authenticated account, organization, and shared shift-transaction boundaries for the Shift Tools application. It does not replace the Flutter roster parser, local schedule persistence, or Google Calendar integration.

## Requirements and setup

- PHP 8.4.1 or later
- Composer 2
- SQLite for local development, or another Laravel-supported database
- A Google OAuth server/web client ID configured for the API

\`\`\`bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate
php artisan serve
\`\`\`

Configure \`GOOGLE_ALLOWED_CLIENT_IDS\` as a comma-separated list of OAuth client IDs accepted by the API. The API verifies Google ID token signatures and claims. Set \`FRONTEND_ALLOWED_ORIGINS\` to exact browser origins.

Existing password-based user records are not silently linked to Google accounts by matching email. Account collisions require an explicit linking workflow.

## Shift transaction API

All routes below require \`Authorization: Bearer <Google ID token>\`.

| Method | Endpoint | Purpose |
| --- | --- | --- |
| GET | \`/api/v1/shift-transactions\` | List transactions visible to the caller |
| POST | \`/api/v1/shift-transactions\` | Create a transaction; requires \`Idempotency-Key\` |
| GET | \`/api/v1/shift-transactions/{id}\` | Read transaction and append-only event timeline |
| POST | \`/{id}/confirm\` | Confirm as a participant |
| POST | \`/{id}/reject\` | Reject as a participant |
| POST | \`/{id}/approve\` | Approve under organization owner/admin authorization |
| POST | \`/{id}/reject-by-approver\` | Reject under organization owner/admin authorization |
| POST | \`/{id}/cancel\` | Cancel as requester before Calendar sync |
| POST | \`/{id}/calendar-sync/start\` | Record start of an explicitly confirmed Calendar write |
| POST | \`/{id}/calendar-sync/complete\` | Record verified Calendar write success |
| POST | \`/{id}/calendar-sync/fail\` | Record recoverable Calendar write failure |
| POST | \`/{id}/fulfill\` | Fulfill one shift obligation after its scheduled end |

List filters: \`mode=personal|organization\`, \`type=give_up|exchange|exchange_and_return\`, \`month=YYYY-MM\`, and \`organization_id=<uuid>\`. Organization history is restricted to active members of that organization. Personal history is restricted to transaction participants.

Transaction creation is idempotent per authenticated requester and key. Reusing a key with a different request payload returns HTTP 409. Each successful lifecycle transition updates the transaction under a database row lock and increments its version; the state change and event append are committed atomically.

## Append-only event history

Every create and lifecycle transition appends a row to \`shift_transaction_events\`. The API has no event update/delete operation. Events capture actor, organization scope, event type, transaction version, timestamp, and event-specific data. Transaction deletion is not exposed; foreign keys restrict deletion while history exists.

Calendar synchronization and shift fulfillment are deliberately separate. Calendar sync start requires `preview_confirmed=true`; completion records the provider event references supplied by the authenticated client (the API records the acknowledgement but does not itself call Google Calendar). A successful Calendar write leaves the transaction in its approved state. An exchange-and-return transaction becomes completed only after every transfer leg has a separate fulfillment event after its scheduled end.

## Existing organization endpoints

See the authenticated organization and membership routes in \`routes/api.php\`. New organizations default to requiring approval for each workflow. Personal transactions never use organization approval.

## Validation

\`\`\`bash
composer validate --strict
vendor/bin/pint --test app config database routes tests
php artisan test
\`\`\`

These checks run in \`.github/workflows/laravel.yml\`.
