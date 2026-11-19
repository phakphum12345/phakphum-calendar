# Shift Transaction Calendar Sync — E2E Contract

## Purpose

Connect an approved shift transaction to the effective roster and the existing Google Calendar synchronization engine. The imported roster remains immutable; transaction projection supplies the effective schedule.

## User flow

1. Import and validate the roster.
2. Create a give-up or exchange transaction.
3. Require participant confirmation and organization approval where policy requires it.
4. Project approved transfers onto the effective schedule.
5. In transaction history, choose Preview & sync Calendar.
6. Show the transfer legs and the complete effective-schedule Calendar diff, including insert, update, delete counts, delete titles, and validation warnings.
7. Do not write to Google Calendar until the user explicitly confirms.
8. Start the server transaction sync state, execute the prepared schedule plan, and read Calendar back.
9. Require exactly one non-empty, distinct provider Event ID for every transfer leg.
10. Only after read-back succeeds, record those IDs through the transaction API and expose fulfillment to the receiving participant.
11. Allow the recipient to confirm fulfillment only after the shift end time. The server remains authoritative and rejects early or wrong-participant fulfillment.
12. Record every lifecycle change in the append-only transaction timeline.

## Safety and recovery

- Preview is read-only. Cancel disposes the prepared plan and causes no Calendar write.
- Confirmation is tied to the transaction ID/version and the canonical source schedule instance. A changed roster or ledger invalidates the preview.
- Calendar sync uses the effective schedule and the existing validation/diff engine. The preview explicitly includes any deletion operations because the plan covers the selected schedule range.
- Provider IDs returned by insert/update operations and IDs for already-managed events are reconciled with a fresh read-only Calendar comparison before the sync_complete transition.
- A provider write failure or failed read-back records sync_fail; a retry starts with a fresh preview and relies on stable sync IDs and managed-event deduplication. A participant can explicitly reset a pending sync after 30 minutes if the original client stopped responding.
- sync_complete requires one distinct provider event reference for every transfer leg.
- The server prevents fulfillment before the transfer's scheduled end, by anyone other than the receiving participant, or before successful Calendar sync.
- No automatic Calendar write, deployment, source-roster mutation, or silent deletion is allowed.

## Automated coverage

- Calendar executor retains provider event IDs for successful insert/update operations.
- Prepared Calendar comparisons expose existing provider IDs by stable sync ID.
- AppController preview maps every approved transfer to exactly one effective-schedule Calendar event.
- History UI exposes Preview & sync only for approved, not-yet-synced transactions and gates writes behind a confirmation dialog.
- Backend feature tests cover explicit preview confirmation, one distinct Event ID per transfer, sync failure/retry, and recipient-only post-shift fulfillment.

## Remaining manual E2E

A real Google account and a real roster are still required to verify OAuth scopes, provider latency, Calendar UI appearance, cross-device history refresh, and the recipient's post-shift fulfillment action. CI success alone does not prove those live-provider steps.
