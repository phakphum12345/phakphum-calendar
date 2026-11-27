# Web Push Notifications

## Current status — 2026-11-27

The original subscription-only status below is superseded by the implementation in [PR #191](https://github.com/phakphum12345/phakphum-calendar/pull/191).

- PR #191 adds the backend VAPID sender, RFC 8291 payload encryption, durable notification outbox, worker claim/lease handling, retry/backoff, dead-letter state, delivery-attempt history, subscription expiry handling and a scheduled `notifications:deliver` command.
- The Flutter web path includes a scoped service worker/browser bridge, authenticated subscription lifecycle and user opt-in/settings integration.
- Exact-head CI passed 13/13 on PR head `cf7eaa22eaf81e04b0b444acfc3aee2a8ca51e5e`.
- PR #191 remains Draft and has no independent review.
- **Real-device delivery and deployed scheduler behavior are not accepted yet.** No production notification delivery is claimed.

## Intended flow

1. The user explicitly opts in from the application.
2. The browser requests notification permission.
3. The app registers `web/push-scope/service-worker.js` in its own `push-scope/` scope, avoiding replacement of Flutter's generated service worker.
4. The browser creates a Push API subscription using the public VAPID key.
5. The Flutter client sends the subscription to the authenticated API.
6. The API validates HTTPS and supported push-service hostnames, encrypts the endpoint and authentication secret with Laravel's application key, and stores the subscription for the signed-in account.
7. A durable outbox worker claims due deliveries, records attempts and sends encrypted payloads using VAPID authentication.
8. Retryable failures use bounded backoff; terminal/expired subscriptions are marked or cleaned according to worker policy; exhausted deliveries enter dead-letter state.
9. Unsubscribe removes the browser subscription and its account-scoped server record.

## Configuration boundary

- Flutter Web build: provide `WEB_PUSH_VAPID_PUBLIC_KEY` as a Dart define.
- Backend: keep the VAPID private key in the hosting environment. Never place it in Git, Flutter assets, browser JavaScript or a Dart define.
- Backend `APP_KEY` must be configured and backed up because it encrypts stored subscription endpoints and authentication secrets.
- Push subscription endpoints are accepted only over HTTPS from supported browser push-service hostnames. Arbitrary URLs and IP literals are rejected to reduce SSRF risk.
- The scheduler/worker must actually run in the self-hosted deployment; a scheduled command in source code does not prove a running production worker.

## Remaining acceptance before background delivery is accepted

- Register a real browser/device and verify a successful delivery end to end.
- Verify permission denied, opt-out, expired/replaced subscription, worker crash, concurrent workers, retry/backoff and dead-letter behavior.
- Verify timezone boundaries and schedule change/cancellation navigation.
- Verify payload privacy and ensure logs never expose endpoint secrets, VAPID secrets or roster details.
- Verify deployed scheduler execution and delivery-attempt observability.
- Confirm supported Chrome, Edge, Firefox and Safari versions. Closing a browser may prevent delivery on platforms that suspend or disable its push service.

## Privacy and safety

- The server stores an endpoint lookup hash, encrypted endpoint, public P-256 key and encrypted authentication secret.
- The API requires the existing account authentication middleware.
- Users can delete only their own subscription record.
- No Google Drive, Calendar or other OAuth scopes are added.
- Delivery is accepted only after real-device and deployed-worker tests. CI success alone is not live-delivery evidence.
