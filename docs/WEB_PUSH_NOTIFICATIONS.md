# Web Push Notifications


## Delivery implementation — PR #191

The outbox is now connected to a self-hosted Web Push delivery worker.

- `WebPushPayloadEncryptor` implements the RFC 8291 `aes128gcm` payload record using P-256 ECDH, HKDF-SHA256 and AES-128-GCM.
- `VapidTokenGenerator` creates ES256 VAPID JWTs from a deployment-owned P-256 key pair.
- `WebPushSender` sends to validated HTTPS browser push endpoints, disables redirects, classifies 2xx/404/410/429/5xx responses and stores only safe error codes.
- `NotificationOutboxWorker` claims due rows with a database lease and per-row claim token, reclaims stale work, applies exponential backoff, enforces a maximum attempt count and dead-letters permanent/exhausted work.
- `notification_deliveries` records one delivery per outbox item and browser subscription. Successful devices are not resent when another device needs retry.
- Expired subscriptions are marked inactive and retained for delivery audit; explicit unsubscribe removes the subscription.
- `php artisan notifications:deliver` runs a bounded batch. Laravel scheduler invokes it every minute; production must run `php artisan schedule:work` or the platform's scheduler cron.
- `php artisan notifications:vapid-keys` prints a new P-256 VAPID pair. Store the private key only in the backend secret environment.

Environment:
- `WEB_PUSH_VAPID_PUBLIC_KEY`: base64url uncompressed P-256 public point.
- `WEB_PUSH_VAPID_PRIVATE_KEY`: base64url 32-byte P-256 private scalar.
- `WEB_PUSH_VAPID_SUBJECT`: a valid `mailto:` or HTTPS contact URI.
- `WEB_PUSH_MAX_ATTEMPTS`: bounded delivery attempts (default 8).

Automated tests cover payload encryption/decryption, VAPID ES256 signature verification, provider response classification, outbox delivery, per-device retry idempotency, expired subscriptions, no-device outcomes, stale-claim recovery and dead-letter behavior.

## Remaining acceptance gates

- Exact-head backend tests, formatter and security audit must pass after the worker/migration changes.
- Deploy a backend with a configured VAPID key pair and scheduler enabled.
- Register a real browser/device subscription and verify actual delivery, click navigation, permission denied, endpoint expiry and app restart.
- Flutter settings UI and user-visible delivery/failure state are not yet integrated.
- Background delivery on mobile platforms other than supported Web Push browsers remains unverified.
- Provider throttling and multi-worker contention need a live controlled environment test; unit tests do not prove provider acceptance.


## Status

The browser subscription bridge, service worker, authenticated subscription API, and transactional shift-notification outbox are implemented. This does **not** yet send notifications while the browser is closed. Production delivery still requires the VAPID sender, RFC 8291 encryption, durable claim/retry worker, and a user-facing opt-in control.

## Intended flow

1. The user explicitly opts in from the application.
2. The browser asks for notification permission.
3. The app registers `web/push-scope/service-worker.js` in its own `push-scope/` scope, avoiding replacement of Flutter's generated service worker.
4. The browser creates a Push API subscription using the public VAPID key.
5. The Flutter client sends the subscription to the authenticated API.
6. The API validates the push-service host and key encodings, encrypts the endpoint and authentication secret with Laravel's application key, and stores the subscription for the signed-in Google account.
7. Shift transaction events enqueue minimal, user-scoped notification intents transactionally. Payloads contain a same-origin URL and stable notification tag for duplicate display suppression.
8. A future worker will claim outbox intents, encrypt and send each payload using VAPID, retry transient failures, and remove expired subscriptions.

## Configuration boundary

- Flutter Web build: provide `WEB_PUSH_VAPID_PUBLIC_KEY` as a Dart define.
- Backend: the future sender must keep the VAPID private key in the hosting environment. Never place it in Git, Flutter assets, browser JavaScript, or a Dart define.
- Backend `APP_KEY` must be configured and backed up because it encrypts stored subscription endpoints and authentication secrets.
- Push subscription endpoints are accepted only over HTTPS from supported browser push-service hostnames. Arbitrary URLs and IP literals are rejected to reduce SSRF risk.

## Remaining work before claiming background delivery

- Implement and test VAPID authentication and RFC 8291 payload encryption on the backend.
- Add atomic outbox claim/lease semantics, retry policy, expired-subscription cleanup, and a scheduler/worker execution strategy.
- Wire the subscription client into a user-facing notification settings control with explicit permission/connection status.
- Connect shift assignment changes and reminder preferences to scheduled notification intents.
- Configure the backend VAPID private key and Flutter public-key build define without committing secrets.
- Verify browser/OS behavior on supported Chrome, Edge, Firefox, and Safari versions. Closing a browser may prevent delivery on platforms that suspend or disable its push service.

## Privacy and safety

- The server stores a SHA-256 endpoint lookup hash, an encrypted endpoint, the public P-256 key, and an encrypted authentication secret.
- The API requires the existing Google account authentication middleware.
- Users can delete only their own subscription record.
- No Google Drive, Calendar, or other OAuth scopes are added.
- Push delivery is not considered enabled until the sender, scheduler, user controls, and end-to-end tests are complete.
