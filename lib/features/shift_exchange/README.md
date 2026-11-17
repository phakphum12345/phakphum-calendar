# Shift Exchange

The existing Phase 1 request workspace remains read-only until its application
and persistence boundaries are connected. The typed transaction foundation
models three distinct operations:

- `giveUp`: one shift moves from the requester to the recipient;
- `exchange`: two reciprocal shift movements are agreed as one transaction;
- `exchangeAndReturn`: a primary movement and a reciprocal return obligation
  are tracked separately.

Transactions distinguish personal agreements from organization-scoped
requests. Personal transactions never require an organization approver.
Organization requests can require an approval decision, which must be checked
through the application authorization boundary.

Participant agreement, organization approval, Calendar synchronization, and
actual shift fulfillment are separate lifecycle stages. Calendar writes remain
previewed and explicitly confirmed by the user. The server-backed read-only history panel now consumes the authenticated Laravel
transaction API and renders transfer details plus append-only audit events. The
Flutter API adapter intentionally uses response DTOs separate from the local
domain aggregate because the server does not expose participant Google subjects.
Mutation endpoints are not exposed by this adapter. Future write integration
must retain idempotency, server authorization, preview confirmation, and
version-checked transitions.

No existing roster, Employee Directory, Calendar event, or historical Timeline
record is changed by this domain foundation.


## Read-only server history

Set `ORGANIZATION_API_BASE_URL` at build time to the Laravel API origin. The app
uses the signed-in Google account's ID token as a Bearer token for
`GET /api/v1/shift-transactions`. No access token or ID token is persisted by
this feature. When the URL is not configured, the history panel explains the
missing configuration and makes no network request. The panel is read-only;
Google Calendar changes remain behind the existing preview and explicit user
confirmation workflow.
