<?php

namespace Tests\Feature;

use App\Contracts\GoogleIdentityTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\Fakes\FakeGoogleIdentityTokenVerifier;
use Tests\TestCase;

class ShiftTransactionApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->app->instance(GoogleIdentityTokenVerifier::class, new FakeGoogleIdentityTokenVerifier([
            'alice-token' => ['sub' => 'google-alice', 'email' => 'alice@example.com', 'email_verified' => true, 'name' => 'Alice'],
            'bob-token' => ['sub' => 'google-bob', 'email' => 'bob@example.com', 'email_verified' => true, 'name' => 'Bob'],
            'outsider-token' => ['sub' => 'google-outsider', 'email' => 'outsider@example.com', 'email_verified' => true, 'name' => 'Outsider'],
            'manager-token' => ['sub' => 'google-manager', 'email' => 'manager@example.com', 'email_verified' => true, 'name' => 'Manager'],
        ]));
    }

    public function test_personal_give_up_is_persisted_and_has_append_only_events(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');
        $created = $this->postJson('/api/v1/shift-transactions', $this->giveUp(), [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'personal-001',
        ])->assertCreated()->json('data');

        $this->postJson("/api/v1/shift-transactions/{$created['id']}/confirm", [], $this->auth('alice-token'))->assertOk();
        $confirmed = $this->postJson("/api/v1/shift-transactions/{$created['id']}/confirm", [], $this->auth('bob-token'))
            ->assertOk()->json('data');

        $this->assertSame('approved', $confirmed['status']);
        $this->assertTrue(collect($created['participants'])->firstWhere('role', 'requester')['is_current_user']);
        $this->assertFalse(collect($created['participants'])->firstWhere('role', 'recipient')['is_current_user']);
        $this->assertTrue(collect($confirmed['participants'])->firstWhere('role', 'recipient')['is_current_user']);
        $this->assertFalse(collect($confirmed['participants'])->firstWhere('role', 'requester')['is_current_user']);
        $this->assertDatabaseHas('shift_transaction_events', [
            'transaction_id' => $created['id'], 'event_type' => 'created', 'transaction_version' => 1,
        ]);
        $this->assertDatabaseHas('shift_transaction_events', [
            'transaction_id' => $created['id'], 'event_type' => 'confirm', 'transaction_version' => 3,
        ]);
        $this->assertSame(3, DB::table('shift_transaction_events')->where('transaction_id', $created['id'])->count());
        $this->getJson('/api/v1/shift-transactions?month='.now()->format('Y-m').'&staff_id=A&shift_type=morning&type=give_up', $this->auth('alice-token'))
            ->assertOk()->assertJsonCount(1, 'data');
    }

    public function test_timeline_is_consistent_for_both_participants_and_idempotent_replay_adds_no_events(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');
        $payload = $this->giveUp();
        $headers = [
            'Authorization' => 'Bearer alice-token',
            'Idempotency-Key' => 'timeline-both-participants',
        ];

        $created = $this->postJson('/api/v1/shift-transactions', $payload, $headers)
            ->assertCreated()->json('data');

        $this->postJson("/api/v1/shift-transactions/{$created['id']}/confirm", [], $this->auth('alice-token'))
            ->assertOk();
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/confirm", [], $this->auth('bob-token'))
            ->assertOk();

        $aliceHistory = $this->getJson(
            "/api/v1/shift-transactions/{$created['id']}",
            $this->auth('alice-token'),
        )->assertOk()->json('data');
        $bobHistory = $this->getJson(
            "/api/v1/shift-transactions/{$created['id']}",
            $this->auth('bob-token'),
        )->assertOk()->json('data');

        $this->assertSame($aliceHistory['timeline'], $bobHistory['timeline']);
        $this->assertSame(
            ['created', 'confirm', 'confirm'],
            collect($aliceHistory['timeline'])->pluck('event_type')->all(),
        );
        $this->assertSame(
            [1, 2, 3],
            collect($aliceHistory['timeline'])->pluck('transaction_version')->all(),
        );
        $this->assertSame(
            ['Alice', 'Alice', 'Bob'],
            collect($aliceHistory['timeline'])->pluck('actor_name')->all(),
        );
        $this->assertTrue(collect($aliceHistory['participants'])->firstWhere('role', 'requester')['is_current_user']);
        $this->assertFalse(collect($aliceHistory['participants'])->firstWhere('role', 'recipient')['is_current_user']);
        $this->assertFalse(collect($bobHistory['participants'])->firstWhere('role', 'requester')['is_current_user']);
        $this->assertTrue(collect($bobHistory['participants'])->firstWhere('role', 'recipient')['is_current_user']);

        $replayed = $this->postJson('/api/v1/shift-transactions', $payload, $headers)
            ->assertCreated()->json('data');
        $this->assertSame($created['id'], $replayed['id']);
        $this->assertSame($aliceHistory['timeline'], $replayed['timeline']);
        $this->assertSame(
            3,
            DB::table('shift_transaction_events')->where('transaction_id', $created['id'])->count(),
        );
    }

    public function test_month_filter_uses_effective_shift_date_instead_of_request_creation_date(): void
    {
        $this->travelTo(Carbon::parse('2026-11-15 12:00:00'));
        $this->signIn('alice-token');
        $this->signIn('bob-token');

        $payload = $this->giveUp();
        $payload['transfers'][0]['starts_at'] = '2026-12-01T08:00:00+07:00';
        $payload['transfers'][0]['ends_at'] = '2026-12-01T16:00:00+07:00';
        $created = $this->postJson('/api/v1/shift-transactions', $payload, [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'effective-month-filter',
        ])->assertCreated()->json('data');

        $this->assertSame('2026-11', substr($created['created_at'], 0, 7));
        $this->getJson('/api/v1/shift-transactions?month=2026-11', $this->auth('alice-token'))
            ->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/shift-transactions?month=2026-12', $this->auth('alice-token'))
            ->assertOk()->assertJsonCount(1, 'data');
    }

    public function test_personal_transaction_resolves_recipient_by_verified_email(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');
        $payload = $this->giveUp();
        $payload['participants'] = [
            ['employee_id' => 'A', 'role' => 'requester'],
            ['email' => 'bob@example.com', 'employee_id' => 'B', 'role' => 'recipient'],
        ];

        $created = $this->postJson('/api/v1/shift-transactions', $payload, [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'personal-email-recipient',
        ])->assertCreated()->json('data');

        $this->assertDatabaseHas('shift_transaction_participants', [
            'transaction_id' => $created['id'],
            'user_id' => DB::table('users')->where('google_subject', 'google-bob')->value('id'),
            'employee_id' => 'B',
            'role' => 'recipient',
        ]);
    }

    public function test_personal_transaction_rejects_unverified_recipient_email(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');
        DB::table('users')->where('google_subject', 'google-bob')->update(['email_verified_at' => null]);
        $payload = $this->giveUp();
        $payload['participants'] = [
            ['employee_id' => 'A', 'role' => 'requester'],
            ['email' => 'bob@example.com', 'employee_id' => 'B', 'role' => 'recipient'],
        ];

        $this->postJson('/api/v1/shift-transactions', $payload, [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'unverified-recipient',
        ])->assertUnprocessable();
    }

    public function test_transaction_rejects_oversized_unicode_participant_email_before_email_validation(): void
    {
        $this->signIn('alice-token');
        $payload = $this->giveUp();
        $payload['participants'] = [
            ['employee_id' => 'A', 'role' => 'requester'],
            [
                'email' => str_repeat('é', 300).'@example.com',
                'employee_id' => 'B',
                'role' => 'recipient',
            ],
        ];

        $response = $this->postJson('/api/v1/shift-transactions', $payload, [
            'Authorization' => 'Bearer alice-token',
            'Idempotency-Key' => 'oversized-unicode-email',
        ])->assertUnprocessable();

        $errors = $response->json('errors')['participants.1.email'] ?? null;
        $this->assertCount(1, $errors);
        $this->assertStringContainsString('254', $errors[0]);
    }

    public function test_transaction_metadata_accepts_only_bounded_note_and_schedule_id(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');
        $payload = $this->giveUp();
        $payload['metadata'] = [
            'note' => 'Please exchange this shift.',
            'schedule_id' => 'schedule-123',
        ];

        $created = $this->postJson('/api/v1/shift-transactions', $payload, [
            'Authorization' => 'Bearer alice-token',
            'Idempotency-Key' => 'metadata-allowlist',
        ])->assertCreated()->json('data');

        $this->assertSame('Please exchange this shift.', $created['metadata']['note']);
        $this->assertSame('schedule-123', $created['metadata']['schedule_id']);
    }

    public function test_transaction_metadata_rejects_unknown_keys_and_oversized_values(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');

        $payload = $this->giveUp();
        $payload['metadata'] = ['access_token' => 'must-not-be-stored'];
        $this->postJson('/api/v1/shift-transactions', $payload, [
            'Authorization' => 'Bearer alice-token',
            'Idempotency-Key' => 'metadata-unknown-key',
        ])->assertUnprocessable()->assertJsonValidationErrors('metadata');

        $payload = $this->giveUp();
        $payload['metadata'] = ['note' => str_repeat('n', 1001)];
        $this->postJson('/api/v1/shift-transactions', $payload, [
            'Authorization' => 'Bearer alice-token',
            'Idempotency-Key' => 'metadata-note-too-long',
        ])->assertUnprocessable()->assertJsonValidationErrors('metadata.note');

        $payload = $this->giveUp();
        $payload['metadata'] = ['schedule_id' => str_repeat('s', 129)];
        $this->postJson('/api/v1/shift-transactions', $payload, [
            'Authorization' => 'Bearer alice-token',
            'Idempotency-Key' => 'metadata-schedule-id-too-long',
        ])->assertUnprocessable()->assertJsonValidationErrors('metadata.schedule_id');
    }

    public function test_idempotency_replays_same_payload_and_rejects_key_reuse(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');
        $first = $this->postJson('/api/v1/shift-transactions', $this->giveUp(), [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'same-key',
        ])->assertCreated()->json('data');
        $again = $this->postJson('/api/v1/shift-transactions', $this->giveUp(), [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'same-key',
        ])->assertCreated()->json('data');
        $this->assertSame($first['id'], $again['id']);

        $different = $this->giveUp();
        $different['metadata'] = ['note' => 'different'];
        $this->postJson('/api/v1/shift-transactions', $different, [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'same-key',
        ])->assertConflict();
    }

    public function test_calendar_sync_does_not_complete_a_transaction_before_shift_fulfillment(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');
        $payload = $this->giveUp();
        $payload['type'] = 'exchange_and_return';
        $payload['transfers'] = [
            ['id' => 'primary', 'shift_id' => 'shift-a', 'from_employee_id' => 'A', 'to_employee_id' => 'B', 'shift_code' => 'late', 'starts_at' => now()->subDays(2)->toIso8601String(), 'ends_at' => now()->subDay()->toIso8601String(), 'purpose' => 'primary'],
            ['id' => 'return', 'shift_id' => 'shift-b', 'from_employee_id' => 'B', 'to_employee_id' => 'A', 'shift_code' => 'morning', 'starts_at' => now()->subDay()->toIso8601String(), 'ends_at' => now()->subHours(2)->toIso8601String(), 'purpose' => 'return_shift'],
        ];
        $created = $this->postJson('/api/v1/shift-transactions', $payload, [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'return-flow',
        ])->assertCreated()->json('data');
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/confirm", [], $this->auth('alice-token'))->assertOk();
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/confirm", [], $this->auth('bob-token'))->assertOk();
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/calendar-sync/start", ['preview_confirmed' => true], $this->auth('alice-token'))->assertOk();
        $synced = $this->postJson("/api/v1/shift-transactions/{$created['id']}/calendar-sync/complete", ['calendar_event_ids' => ['google-event-1', 'google-event-2']], $this->auth('alice-token'))
            ->assertOk()->json('data');
        $this->assertSame('approved', $synced['status']);
        $this->assertSame('synced', $synced['sync_status']);
        $this->assertCount(2, $synced['calendar_events']);
        $this->assertSame(['legacy', 'legacy'], collect($synced['calendar_events'])->pluck('provider')->all());
        $this->assertSame(['completed'], collect($synced['sync_attempts'])->pluck('status')->all());
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/calendar-sync/complete", ['calendar_event_ids' => ['google-event-1', 'google-event-2']], $this->auth('alice-token'))->assertOk();
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/calendar-sync/complete", ['calendar_event_ids' => ['different-event-1', 'different-event-2']], $this->auth('alice-token'))->assertConflict();
        $this->assertSame(2, DB::table('shift_transaction_calendar_events')->where('transaction_id', $created['id'])->count());
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/fulfill", ['transfer_id' => 'primary'], $this->auth('alice-token'))->assertForbidden();
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/fulfill", ['transfer_id' => 'primary'], $this->auth('bob-token'))->assertOk();
        $partial = $this->getJson("/api/v1/shift-transactions/{$created['id']}", $this->auth('bob-token'))->assertOk()->json('data');
        $this->assertSame('approved', $partial['status']);
        $this->assertSame(1, collect($partial['transfers'])->whereNotNull('fulfilled_at')->count());
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/fulfill", ['transfer_id' => 'return'], $this->auth('alice-token'))->assertOk();
        $complete = $this->getJson("/api/v1/shift-transactions/{$created['id']}", $this->auth('alice-token'))->assertOk()->json('data');
        $this->assertSame('completed', $complete['status']);
    }

    public function test_personal_history_is_not_visible_to_an_unrelated_account(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');
        $this->signIn('outsider-token');
        $created = $this->postJson('/api/v1/shift-transactions', $this->giveUp(), [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'private-history',
        ])->assertCreated()->json('data');
        $this->getJson("/api/v1/shift-transactions/{$created['id']}", $this->auth('outsider-token'))->assertForbidden();
    }

    public function test_calendar_sync_failure_is_recorded_and_retryable(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');
        $created = $this->postJson('/api/v1/shift-transactions', $this->giveUp(), [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'sync-failure',
        ])->assertCreated()->json('data');
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/confirm", [], $this->auth('alice-token'))->assertOk();
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/confirm", [], $this->auth('bob-token'))->assertOk();
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/calendar-sync/start", ['preview_confirmed' => true], $this->auth('alice-token'))->assertOk();
        $failed = $this->postJson("/api/v1/shift-transactions/{$created['id']}/calendar-sync/fail", ['reason' => 'provider timeout'], $this->auth('alice-token'))
            ->assertOk()->json('data');
        $this->assertSame('failed', $failed['sync_status']);
        $this->assertContains('sync_fail', collect($failed['timeline'])->pluck('event_type')->all());
        $this->assertSame(['failed'], collect($failed['sync_attempts'])->pluck('status')->all());

        $this->postJson("/api/v1/shift-transactions/{$created['id']}/calendar-sync/start", ['preview_confirmed' => true], $this->auth('alice-token'))->assertOk();
        $transferId = $created['transfers'][0]['transfer_key'];
        $retried = $this->postJson("/api/v1/shift-transactions/{$created['id']}/calendar-sync/complete", [
            'calendar_events' => [[
                'transfer_id' => $transferId,
                'provider' => 'google',
                'calendar_id' => 'primary',
                'event_id' => 'google-event-retry',
                'etag' => 'etag-123',
            ]],
        ], $this->auth('alice-token'))->assertOk()->json('data');
        $this->assertSame('synced', $retried['sync_status']);
        $this->assertSame(['failed', 'completed'], collect($retried['sync_attempts'])->pluck('status')->all());
        $this->assertSame('google', $retried['calendar_events'][0]['provider']);
        $this->assertSame($transferId, $retried['calendar_events'][0]['transfer_key']);
    }

    public function test_calendar_sync_requires_one_distinct_mapping_for_each_transfer_leg(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');
        $payload = $this->giveUp();
        $payload['type'] = 'exchange_and_return';
        $payload['transfers'] = [
            ['id' => 'primary', 'shift_id' => 'shift-a', 'from_employee_id' => 'A', 'to_employee_id' => 'B', 'shift_code' => 'late', 'starts_at' => now()->subDays(2)->toIso8601String(), 'ends_at' => now()->subDay()->toIso8601String(), 'purpose' => 'primary'],
            ['id' => 'return', 'shift_id' => 'shift-b', 'from_employee_id' => 'B', 'to_employee_id' => 'A', 'shift_code' => 'morning', 'starts_at' => now()->subDay()->toIso8601String(), 'ends_at' => now()->subHours(2)->toIso8601String(), 'purpose' => 'return_shift'],
        ];
        $created = $this->postJson('/api/v1/shift-transactions', $payload, [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'sync-partial-mapping',
        ])->assertCreated()->json('data');
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/confirm", [], $this->auth('alice-token'))->assertOk();
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/confirm", [], $this->auth('bob-token'))->assertOk();
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/calendar-sync/start", ['preview_confirmed' => true], $this->auth('alice-token'))->assertOk();

        $this->postJson("/api/v1/shift-transactions/{$created['id']}/calendar-sync/complete", [
            'calendar_events' => [[
                'transfer_id' => 'primary',
                'provider' => 'google',
                'event_id' => 'only-one-event',
            ]],
        ], $this->auth('alice-token'))->assertUnprocessable();

        $this->postJson("/api/v1/shift-transactions/{$created['id']}/calendar-sync/complete", [
            'calendar_events' => [
                ['transfer_id' => 'primary', 'provider' => 'google', 'event_id' => 'duplicate-event'],
                ['transfer_id' => 'return', 'provider' => 'google', 'event_id' => 'duplicate-event'],
            ],
        ], $this->auth('alice-token'))->assertUnprocessable();

        $pending = $this->getJson("/api/v1/shift-transactions/{$created['id']}", $this->auth('alice-token'))->assertOk()->json('data');
        $this->assertSame('pending', $pending['sync_status']);
        $this->assertSame(['started'], collect($pending['sync_attempts'])->pluck('status')->all());
        $this->assertCount(0, $pending['calendar_events']);
    }

    public function test_organization_transaction_requires_membership_and_approver_role(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');
        $this->signIn('manager-token');
        $organization = $this->postJson('/api/v1/organizations', [
            'name' => 'Radiology', 'employee_id' => 'A',
        ], $this->auth('alice-token'))->assertCreated()->json('data');
        DB::table('organization_memberships')->insert([
            'organization_id' => $organization['id'], 'user_id' => DB::table('users')->where('google_subject', 'google-bob')->value('id'),
            'employee_id' => 'B', 'role' => 'staff', 'status' => 'active', 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('organization_memberships')->insert([
            'organization_id' => $organization['id'], 'user_id' => DB::table('users')->where('google_subject', 'google-manager')->value('id'),
            'employee_id' => 'M', 'role' => 'admin', 'status' => 'active', 'created_at' => now(), 'updated_at' => now(),
        ]);
        $payload = $this->giveUp();
        $payload['participants'] = [
            ['employee_id' => 'A', 'role' => 'requester'],
            [
                'user_id' => DB::table('users')->where('google_subject', 'google-bob')->value('id'),
                'employee_id' => 'B',
                'role' => 'recipient',
            ],
        ];
        $payload['mode'] = 'organization';
        $payload['organization_id'] = $organization['id'];
        $created = $this->postJson('/api/v1/shift-transactions', $payload, [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'org-transaction',
        ])->assertCreated()->json('data');
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/confirm", [], $this->auth('alice-token'))->assertOk();
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/confirm", [], $this->auth('bob-token'))->assertOk();
        $this->assertSame('pending_approval', $this->getJson("/api/v1/shift-transactions/{$created['id']}", $this->auth('alice-token'))->json('data.status'));
        $this->getJson("/api/v1/shift-transactions/{$created['id']}", $this->auth('outsider-token'))->assertForbidden();
        $this->postJson("/api/v1/shift-transactions/{$created['id']}/approve", [], $this->auth('manager-token'))->assertOk();
    }

    public function test_rejection_and_requester_cancellation_are_recorded_in_history(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');

        $rejected = $this->postJson('/api/v1/shift-transactions', $this->giveUp(), [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'reject-flow',
        ])->assertCreated()->json('data');
        $this->postJson("/api/v1/shift-transactions/{$rejected['id']}/reject", ['reason' => 'Cannot cover this shift'], $this->auth('bob-token'))
            ->assertOk();
        $rejectedHistory = $this->getJson("/api/v1/shift-transactions/{$rejected['id']}", $this->auth('alice-token'))
            ->assertOk()->json('data');
        $this->assertSame('rejected', $rejectedHistory['status']);
        $this->assertContains('reject', collect($rejectedHistory['timeline'])->pluck('event_type')->all());

        $cancelled = $this->postJson('/api/v1/shift-transactions', $this->giveUp(), [
            'Authorization' => 'Bearer alice-token', 'Idempotency-Key' => 'cancel-flow',
        ])->assertCreated()->json('data');
        $this->postJson("/api/v1/shift-transactions/{$cancelled['id']}/cancel", [], $this->auth('alice-token'))
            ->assertOk();
        $cancelledHistory = $this->getJson("/api/v1/shift-transactions/{$cancelled['id']}", $this->auth('bob-token'))
            ->assertOk()->json('data');
        $this->assertSame('cancelled', $cancelledHistory['status']);
        $this->assertContains('cancel', collect($cancelledHistory['timeline'])->pluck('event_type')->all());
    }

    public function test_transaction_lifecycle_enqueues_idempotent_notifications_for_other_participants(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');
        $payload = $this->giveUp();

        $created = $this->postJson('/api/v1/shift-transactions', $payload, [
            'Authorization' => 'Bearer alice-token',
            'Idempotency-Key' => 'notification-lifecycle',
        ])->assertCreated()->json('data');

        $aliceId = (int) DB::table('users')->where('google_subject', 'google-alice')->value('id');
        $bobId = (int) DB::table('users')->where('google_subject', 'google-bob')->value('id');
        $this->assertDatabaseHas('notification_outbox', [
            'user_id' => $bobId,
            'notification_type' => 'shift_transaction.created',
            'idempotency_key' => "shift-transaction:{$created['id']}:created:{$bobId}",
            'status' => 'pending',
        ]);
        $this->assertSame(
            1,
            DB::table('notification_outbox')
                ->where('user_id', $bobId)
                ->where('notification_type', 'shift_transaction.created')
                ->count(),
        );

        // Replaying the idempotent create request must not enqueue again.
        $this->postJson('/api/v1/shift-transactions', $payload, [
            'Authorization' => 'Bearer alice-token',
            'Idempotency-Key' => 'notification-lifecycle',
        ])->assertOk();
        $this->assertSame(
            1,
            DB::table('notification_outbox')
                ->where('user_id', $bobId)
                ->where('notification_type', 'shift_transaction.created')
                ->count(),
        );

        $this->postJson(
            "/api/v1/shift-transactions/{$created['id']}/confirm",
            [],
            $this->auth('bob-token'),
        )->assertOk();
        $confirmKey = "shift-transaction:{$created['id']}:v2:confirm:{$aliceId}";
        $this->assertDatabaseHas('notification_outbox', [
            'user_id' => $aliceId,
            'notification_type' => 'shift_transaction.confirm',
            'idempotency_key' => $confirmKey,
            'status' => 'pending',
        ]);

        // Replaying an already-confirmed transition is a no-op.
        $this->postJson(
            "/api/v1/shift-transactions/{$created['id']}/confirm",
            [],
            $this->auth('bob-token'),
        )->assertOk();
        $this->assertSame(
            1,
            DB::table('notification_outbox')
                ->where('user_id', $aliceId)
                ->where('idempotency_key', $confirmKey)
                ->count(),
        );

        $this->postJson(
            "/api/v1/shift-transactions/{$created['id']}/cancel",
            [],
            $this->auth('alice-token'),
        )->assertOk();
        $this->assertDatabaseHas('notification_outbox', [
            'user_id' => $bobId,
            'notification_type' => 'shift_transaction.cancel',
            'idempotency_key' => "shift-transaction:{$created['id']}:v3:cancel:{$bobId}",
            'status' => 'pending',
        ]);
        $this->assertSame(
            0,
            DB::table('notification_outbox')
                ->where('user_id', $aliceId)
                ->where('notification_type', 'shift_transaction.created')
                ->count(),
        );
    }

    private function signIn(string $token): void
    {
        $this->getJson('/api/v1/me', $this->auth($token))->assertOk();
    }

    private function auth(string $token): array
    {
        return ['Authorization' => 'Bearer '.$token];
    }

    private function giveUp(): array
    {
        return [
            'mode' => 'personal', 'type' => 'give_up',
            'participants' => [
                ['account_subject' => 'google-alice', 'employee_id' => 'A', 'role' => 'requester'],
                ['account_subject' => 'google-bob', 'employee_id' => 'B', 'role' => 'recipient'],
            ],
            'transfers' => [[
                'id' => 'transfer-1', 'shift_id' => 'shift-1',
                'from_employee_id' => 'A', 'to_employee_id' => 'B',
                'shift_code' => 'morning', 'starts_at' => now()->subDay()->toIso8601String(),
                'ends_at' => now()->addHour()->toIso8601String(), 'purpose' => 'give_up',
            ]],
        ];
    }
}
