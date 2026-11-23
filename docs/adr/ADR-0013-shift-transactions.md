# ADR-0013: Shift transaction lifecycle and approval boundaries

- Status: Accepted for domain foundation; persistence and server integration pending
- Date: 2026-11-09

## Context

The existing Shift Exchange page is a read-only request workspace. The legacy
swap-request store is device-global and truncates its history. The application
also has no authenticated shared transaction API yet; the Laravel backend
currently exposes health/readiness and client-diagnostic endpoints only.

A shift transfer needs a shared, auditable lifecycle. Personal agreements must
not be routed through organization approval, while organization approval must
be checked by an authorization boundary rather than a UI visibility flag.

## Decision

Represent give-up, exchange, and exchange-and-return as distinct transaction
types with explicit shift-transfer legs and stable employee/account identities.

Keep these stages separate:

1. participant confirmation;
2. organization approval, only when the organization policy requires it;
3. preview and explicit user confirmation before Calendar synchronization;
4. verified Calendar synchronization;
5. actual fulfillment of every shift obligation.

Personal transactions cannot require organization approval. Organization
transactions carry an organization ID and are eligible for an approval decision
only after all participants confirm. Approval must be authorized against the
organization membership boundary.

Exchange-and-return contains one primary and one return transfer. The
transaction cannot become completed until both transfer obligations are marked
fulfilled. Calendar synchronization success alone is not fulfillment.

Repository implementations must provide idempotent creation and atomic
compare-and-swap updates using the transaction version. The current PR adds the
domain/application contracts only; it does not claim production persistence,
cross-account delivery, server authorization, or Calendar Timeline integration.

## Consequences

- Existing ShiftExchangeRequest and SwapRequest records remain readable and
  untouched during this foundation change.
- The next implementation parts must add authenticated shared persistence,
  account/organization isolation, migration, UI wiring, and append-only Calendar
  Timeline integration.
- No new Calendar write occurs as a side effect of constructing or confirming a
  domain transaction.
