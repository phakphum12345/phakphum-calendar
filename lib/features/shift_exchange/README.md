# Shift Exchange and Shift Transaction Timeline

This feature provides server-backed shift release/receive, reciprocal exchange,
exchange-and-return, participant consent, organization approval, Calendar
synchronization safeguards, fulfillment tracking, and immutable transaction
history.

## Supported transaction types

- `give_up`: the requester releases one assigned shift to a recipient. The
  recipient confirms or rejects the request; an organization policy may require
  an authorized manager approval.
- `exchange`: two employees agree to transfer one shift each in opposite
  directions as one transaction.
- `exchange_and_return`: the requester transfers a primary shift to the
  recipient and records a separate return-shift obligation in the opposite
  direction. The two legs remain independently visible and fulfilled.

The existing server lifecycle distinguishes participant agreement, organization
approval, Calendar synchronization, and actual fulfillment. A successful
Calendar write is not treated as proof that the shift was worked.

## Timeline and history

The backend stores append-only events in `shift_transaction_events`. Every
successful state transition records the actor, event type, transaction version,
event payload, and occurrence time. Both participants see the same transaction
timeline, subject to participant or organization membership authorization.

The history panel supports filtering by transaction type and effective shift
month. Each transaction displays participants, transfer legs, fulfillment
state, and chronological audit events. Existing roster ownership timelines are
linked only when exactly one matching roster slot and owner transition can be
identified; ambiguous matches are intentionally not guessed.

## Safety boundaries

- Personal transactions never require organization approval.
- Organization approval follows the organization's configured workflow policy.
- Only transaction participants can respond, cancel as requester, sync, or
  confirm fulfillment as the receiving employee.
- Only authorized organization managers can approve organization requests.
- Calendar writes require an explicit preview confirmation.
- Server transitions use version checks and idempotency on creation.
- Historical events are append-only; cancellation or rejection never erases
  prior events or the original roster assignment.
- The canonical imported roster remains unchanged. Approved transactions are
  projected as an effective view rather than overwriting the import source.

## Related implementation

- `lib/features/shift_exchange/presentation/pages/shift_exchange_page.dart`
- `lib/features/shift_exchange/presentation/widgets/shift_transaction_history_panel.dart`
- `lib/features/shift_exchange/infrastructure/shift_transaction_api_client.dart`
- `backend/app/Services/ShiftTransactions/ShiftTransactionService.php`
- `backend/database/migrations/2026_11_16_000001_create_shift_transactions.php`
- `backend/tests/Feature/ShiftTransactionApiTest.php`

Run the focused Flutter tests with:

```bash
flutter test test/features/shift_transaction_composer_test.dart
flutter test test/features/shift_transaction_history_panel_test.dart
flutter test test/shift_transaction_exchange_test.dart
```

Run the backend feature tests from `backend/` with:

```bash
php artisan test --filter=ShiftTransactionApiTest
```
