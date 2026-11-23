# Roster Transactions and Historical Timeline

## Scope

This implementation slice completes the user-facing transaction options and
historical filtering on top of the existing canonical roster, transaction API,
organization policy, and append-only event ledger. It does not replace the
repository's roster import engine or rewrite unrelated schedule/calendar files.

## User workflows

### Release a shift (give up)

1. The requester selects one of their canonical roster assignments.
2. The requester identifies a recipient.
3. The server records a `give_up` transaction with one transfer leg.
4. The recipient confirms or rejects.
5. Organization approval is required only when the organization's configured
   workflow policy requires it.
6. The approved transfer appears in the effective schedule projection; the
   imported canonical roster remains unchanged.

### Receive a shift

Receiving is represented by the recipient's authenticated response to a
pending transfer. The recipient can confirm or reject only when their account
is a transaction participant. Fulfillment is a later action, available to the
receiving employee only after approval and verified Calendar synchronization,
and not before the scheduled shift end.

### Exchange shifts

Two employees select one shift each. The transaction records two reciprocal
transfer legs and requires both participants to confirm. The pair is approved
or rejected as one transaction.

### Exchange and return

The requester selects a primary shift and the recipient selects the return
shift. The API stores two distinct legs: `primary` from requester to recipient
and `return_shift` from recipient to requester. The legs have separate
fulfillment records while sharing one participant agreement and approval
lifecycle.

## Historical Timeline

Every successful lifecycle transition is recorded in the append-only
`shift_transaction_events` table with:
- transaction ID and monotonically increasing transaction version;
- event type and structured event data;
- authenticated actor;
- occurrence timestamp.

The history UI shows transaction creation time, participants, transfer
direction, scheduled start/end, fulfillment state, and the ordered event
timeline. The list can be filtered by transaction type and effective shift
month. Month filtering uses the shift date, not the date on which the request
was created. The backend already supports personal-participant and
organization-membership authorization for history reads.

Where an imported roster ownership timeline can be matched to exactly one
transfer by shift code, Bangkok wall-clock slot, and consecutive owner change,
the UI links that source history. Ambiguous matches are intentionally omitted
rather than guessed.

## Existing safeguards preserved

- Personal requests do not require organization approval.
- Organization approval follows the organization's stored shift policy.
- Only authenticated transaction participants can respond.
- Only an authorized organization manager can approve or reject an
  organization request.
- Request creation uses an idempotency key.
- Lifecycle updates use a transaction version compare-and-swap.
- Calendar writes remain behind preview and explicit user confirmation.
- A successful Calendar sync is not treated as actual shift fulfillment.
- The original imported roster is not overwritten; approved transfers are
  represented by the effective schedule projection.
- Rejected and cancelled transactions remain in history; events are not
  deleted.

## Files changed in this slice

- `lib/features/shift_exchange/presentation/pages/shift_exchange_page.dart`
  adds the exchange-and-return composer option and emits the correct two
  transfer purposes.
- `lib/features/shift_exchange/presentation/widgets/shift_transaction_history_panel.dart`
  adds server-backed transaction-type and effective-month filters.
- `test/features/shift_transaction_composer_test.dart` covers reciprocal
  exchange-and-return payload construction.
- `lib/features/shift_exchange/README.md` documents the actual workflow and
  security boundaries.
- This document records the scope and acceptance behavior.

## Validation commands

Flutter:
```bash
flutter test test/features/shift_transaction_composer_test.dart
flutter test test/features/shift_transaction_history_panel_test.dart
flutter test test/shift_transaction_exchange_test.dart
flutter analyze
```

Laravel backend:
```bash
cd backend
php artisan test --filter=ShiftTransactionApiTest
```

The backend transaction API, event migration, and append-only event tests were
reconciled against current `main`; no schema migration or OAuth scope change
was needed for this UI slice.
