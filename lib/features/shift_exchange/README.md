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
previewed and explicitly confirmed by the user. The repository contract must
provide idempotent creation and atomic version-checked updates before this
foundation is wired to production persistence or cross-account UI.

No existing roster, Employee Directory, Calendar event, or historical Timeline
record is changed by this domain foundation.
