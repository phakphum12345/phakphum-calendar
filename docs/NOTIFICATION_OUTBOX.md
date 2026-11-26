# Notification Outbox

## Current status

The API now creates durable, user-scoped notification intents inside the same database transaction as shift transaction creation and state changes. This guarantees that a committed business event has its notification intent, and a rolled-back/unauthorized change does not produce a notification.

The outbox does **not** yet deliver push notifications or email. No worker or scheduler is enabled.

## Event mapping

- New shift transaction: notify the resolved recipient.
- Confirm/reject: notify the other participant.
- Organization approve/reject: notify the transaction participants.
- Cancel: notify the other participant.
- Calendar sync complete/fail: notify the other participant.
- Fulfillment: notify the other participant.
- Calendar sync start is an internal provider step and is not notified.

Each event uses a per-user idempotency key derived from transaction ID, transaction version, action and recipient ID. Payloads include a minimal transaction reference, status/version, display title/body, stable notification tag and same-origin application URL. They do not include push endpoints, auth secrets, provider event IDs or ETags.

## Outbox contract

- A notification intent belongs to one existing user account.
- Replaying the same user/idempotency key and same type/payload returns the original row.
- Reusing a key with different content returns a conflict; existing data is never overwritten.
- New intents start as pending, with zero attempts and an explicit available_at.
- Payloads are structured JSON and must not contain access tokens, push endpoints, authentication secrets or credentials.
- The outbox is an internal application service, not a public API.

## Remaining delivery work

A follow-up delivery phase must add:
- A vetted RFC 8291 Web Push encryption + VAPID sender.
- Atomic worker claim/lease semantics with stale-claim fencing.
- Bounded retries with exponential backoff, provider response classification and terminal failure status.
- Expired-subscription cleanup and safe handling of multiple browser subscriptions.
- A scheduled worker execution strategy and observable delivery outcomes.
- User-facing opt-in/settings control and end-to-end device tests.

## Safety

- Enqueueing makes no external network calls.
- Enqueueing and transaction state changes share one database transaction.
- The existing authenticated Web Push subscription API remains registration-only.
- No production notifications have been sent.
