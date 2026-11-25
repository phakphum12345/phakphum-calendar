# Notification Outbox Foundation

## Status
This phase adds durable, user-scoped notification intents and idempotent enqueueing. It deliberately does not deliver email, browser push, or native notifications. No worker, scheduler, VAPID sender, or production dispatch is enabled by this change.

## Contract
- A notification intent belongs to one existing user account.
- The idempotency key is unique per user. Replaying the same key and same type/payload returns the original row.
- Reusing a key with different content returns a conflict; existing data is never overwritten.
- New intents start as pending, with zero attempts and an explicit available_at.
- Payloads are structured JSON and must not contain access tokens, push endpoints, authentication secrets, or credentials.
- The outbox is an internal application service, not a public API.

## Delivery boundary
The existing authenticated Web Push subscription API remains registration-only. This outbox does not contact push providers, mark records sent, retry delivery, or remove subscriptions. A later delivery phase must add a vetted VAPID/Web Push implementation, atomic claim/lease semantics, bounded retries with backoff, provider response classification, expired-subscription handling, and worker tests before any real delivery is enabled.

## Integration boundary
Shift transaction lifecycle events are not automatically enqueued in this foundation. A follow-up must define recipient selection for each event and add enqueue calls inside the same database transaction as the corresponding state transition, with tests proving rollback and idempotency. This avoids notifications for rolled-back or unauthorized changes.

## Safety
- No external network calls are made by enqueueing.
- No existing shift transaction, roster, calendar, or subscription records are modified.
- The migration is additive and uses restrictive user foreign keys.
- No secrets or new paid services are introduced.
