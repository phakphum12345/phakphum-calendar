<?php

namespace Tests\Feature;

use App\Contracts\GoogleIdentityTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Tests\Fakes\FakeGoogleIdentityTokenVerifier;
use Tests\TestCase;

class CalendarSyncCoordinationApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->app->instance(GoogleIdentityTokenVerifier::class, new FakeGoogleIdentityTokenVerifier([
            'alice-token' => ['sub' => 'google-alice', 'email' => 'alice@example.com', 'email_verified' => true, 'name' => 'Alice'],
            'bob-token' => ['sub' => 'google-bob', 'email' => 'bob@example.com', 'email_verified' => true, 'name' => 'Bob'],
        ]));
        $this->getJson('/api/v1/me', $this->auth('alice-token'))->assertOk();
        $this->getJson('/api/v1/me', $this->auth('bob-token'))->assertOk();
    }

    public function test_one_owner_cannot_start_two_sync_runs_for_the_same_calendar(): void
    {
        $first = $this->postJson('/api/v1/calendar-sync/leases', $this->lease('00000000-0000-4000-8000-000000000001', 'device-a'), $this->auth('alice-token'))
            ->assertCreated()->json('data');

        $this->postJson('/api/v1/calendar-sync/leases', $this->lease('00000000-0000-4000-8000-000000000002', 'device-b'), $this->auth('alice-token'))
            ->assertConflict()
            ->assertJsonPath('error.code', 'calendar_sync_already_running');

        $this->putJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000001', [
            'lease_token' => $first['lease_token'], 'ttl_seconds' => 90,
        ], $this->auth('alice-token'))->assertOk();

        $this->deleteJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000001', [
            'lease_token' => $first['lease_token'], 'status' => 'success',
        ], $this->auth('alice-token'))->assertOk();

        $this->postJson('/api/v1/calendar-sync/leases', $this->lease('00000000-0000-4000-8000-000000000002', 'device-b'), $this->auth('alice-token'))
            ->assertCreated();
    }

    public function test_leases_are_scoped_to_the_authenticated_owner(): void
    {
        $this->postJson('/api/v1/calendar-sync/leases', $this->lease('00000000-0000-4000-8000-000000000003', 'alice-device'), $this->auth('alice-token'))
            ->assertCreated();

        $this->postJson('/api/v1/calendar-sync/leases', $this->lease('00000000-0000-4000-8000-000000000004', 'bob-device'), $this->auth('bob-token'))
            ->assertCreated();
    }

    public function test_expired_lease_can_be_reclaimed_and_old_token_is_rejected(): void
    {
        $first = $this->postJson('/api/v1/calendar-sync/leases', $this->lease('00000000-0000-4000-8000-000000000006', 'device-a'), $this->auth('alice-token'))
            ->assertCreated()->json('data');

        $this->travel(61)->seconds();

        $second = $this->postJson('/api/v1/calendar-sync/leases', $this->lease('00000000-0000-4000-8000-000000000007', 'device-b'), $this->auth('alice-token'))
            ->assertCreated()->json('data');

        $this->putJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000006', [
            'lease_token' => $first['lease_token'],
        ], $this->auth('alice-token'))->assertConflict();

        $this->putJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000007', [
            'lease_token' => $second['lease_token'],
        ], $this->auth('alice-token'))->assertOk();
    }

    public function test_sync_history_is_not_visible_to_another_authenticated_owner(): void
    {
        $lease = $this->postJson('/api/v1/calendar-sync/leases', $this->lease('00000000-0000-4000-8000-000000000008', 'alice-device'), $this->auth('alice-token'))
            ->assertCreated()->json('data');

        $this->postJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000008/operations', [
            'lease_token' => $lease['lease_token'],
            'operation_key' => 'owner-private-op',
            'operation_type' => 'insert',
            'operation_payload' => ['sync_id' => 'owner-private-op', 'title' => 'Private shift'],
            'payload_hash' => hash('sha256', json_encode(['sync_id' => 'owner-private-op', 'title' => 'Private shift'])),
        ], $this->auth('alice-token'))->assertCreated();

        $ciphertext = DB::table('calendar_sync_operations')
            ->where('operation_key', 'owner-private-op')
            ->value('payload_ciphertext');
        $this->assertIsString($ciphertext);
        $this->assertStringNotContainsString('Private shift', $ciphertext);
        $this->assertSame(
            ['sync_id' => 'owner-private-op', 'title' => 'Private shift'],
            json_decode(Crypt::decryptString($ciphertext), true),
        );

        $this->getJson('/api/v1/calendar-sync/runs/00000000-0000-4000-8000-000000000008/operations', $this->auth('alice-token'))
            ->assertOk()
            ->assertJsonPath('data.0.operation_payload.sync_id', 'owner-private-op')
            ->assertJsonPath('data.0.operation_payload.title', 'Private shift');
        $this->getJson('/api/v1/calendar-sync/runs/00000000-0000-4000-8000-000000000008/operations', $this->auth('bob-token'))
            ->assertNotFound();
    }

    public function test_operation_ledger_is_idempotent_and_rejects_key_reuse_with_different_payload(): void
    {
        $lease = $this->postJson('/api/v1/calendar-sync/leases', $this->lease('00000000-0000-4000-8000-000000000005', 'alice-device'), $this->auth('alice-token'))
            ->assertCreated()->json('data');
        $payload = [
            'lease_token' => $lease['lease_token'],
            'operation_key' => 'event-sync-1',
            'operation_type' => 'insert',
            'operation_payload' => ['sync_id' => 'same-event-payload'],
            'payload_hash' => hash('sha256', json_encode(['sync_id' => 'same-event-payload'])),
        ];

        $this->postJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000005/operations', $payload, $this->auth('alice-token'))
            ->assertCreated()->assertJsonPath('data.status', 'prepared');
        $this->postJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000005/operations', $payload, $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('data.status', 'prepared');

        $this->postJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000005/operations', [
            ...$payload,
            'operation_payload' => ['sync_id' => 'different-event-payload'],
            'payload_hash' => hash('sha256', json_encode(['sync_id' => 'different-event-payload'])),
        ], $this->auth('alice-token'))->assertConflict();

        $this->postJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000005/operations', [
            ...$payload,
            'payload_hash' => hash('sha256', 'not-the-payload-hash'),
        ], $this->auth('alice-token'))
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'calendar_sync_payload_hash_mismatch');

        $this->patchJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000005/operations/event-sync-1', [
            'lease_token' => $lease['lease_token'],
            'status' => 'running',
            'attempt_count' => 1,
        ], $this->auth('alice-token'))->assertOk()->assertJsonPath('data.status', 'running');
        $this->patchJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000005/operations/event-sync-1', [
            'lease_token' => $lease['lease_token'],
            'status' => 'succeeded',
            'attempt_count' => 1,
            'provider_event_id' => 'provider-event-123',
        ], $this->auth('alice-token'))->assertOk()->assertJsonPath('data.status', 'succeeded');
        $this->getJson('/api/v1/calendar-sync/runs', $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('data.0.operation_count', 1);
        $this->getJson('/api/v1/calendar-sync/runs/00000000-0000-4000-8000-000000000005', $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('data.schedule_id', 'schedule-1');
        $this->getJson('/api/v1/calendar-sync/runs/00000000-0000-4000-8000-000000000005', $this->auth('bob-token'))
            ->assertNotFound();
        $this->getJson('/api/v1/calendar-sync/runs/00000000-0000-4000-8000-000000000005/operations', $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('data.0.provider_event_id', 'provider-event-123');
    }

    public function test_reclaimed_lease_cannot_append_or_update_the_previous_run_ledger(): void
    {
        $firstRunId = '00000000-0000-4000-8000-000000000009';
        $first = $this->postJson(
            '/api/v1/calendar-sync/leases',
            $this->lease($firstRunId, 'device-a'),
            $this->auth('alice-token'),
        )->assertCreated()->json('data');

        $this->postJson('/api/v1/calendar-sync/leases/'.$firstRunId.'/operations', [
            'lease_token' => $first['lease_token'],
            'operation_key' => 'prepared-before-expiry',
            'operation_type' => 'insert',
            'operation_payload' => ['sync_id' => 'original-payload'],
            'payload_hash' => hash('sha256', json_encode(['sync_id' => 'original-payload'])),
        ], $this->auth('alice-token'))->assertCreated();

        $this->travel(61)->seconds();

        $secondRunId = '00000000-0000-4000-8000-000000000010';
        $this->postJson(
            '/api/v1/calendar-sync/leases',
            $this->lease($secondRunId, 'device-b'),
            $this->auth('alice-token'),
        )->assertCreated();

        $this->postJson('/api/v1/calendar-sync/leases/'.$firstRunId.'/operations', [
            'lease_token' => $first['lease_token'],
            'operation_key' => 'late-write-after-reclaim',
            'operation_type' => 'insert',
            'operation_payload' => ['sync_id' => 'late-payload'],
            'payload_hash' => hash('sha256', json_encode(['sync_id' => 'late-payload'])),
        ], $this->auth('alice-token'))
            ->assertConflict()
            ->assertJsonPath('error.code', 'calendar_sync_lease_lost');

        $this->patchJson('/api/v1/calendar-sync/leases/'.$firstRunId.'/operations/prepared-before-expiry', [
            'lease_token' => $first['lease_token'],
            'status' => 'running',
            'attempt_count' => 1,
        ], $this->auth('alice-token'))
            ->assertConflict()
            ->assertJsonPath('error.code', 'calendar_sync_lease_lost');

        $this->getJson('/api/v1/calendar-sync/runs/'.$firstRunId.'/operations', $this->auth('alice-token'))
            ->assertOk()
            ->assertJsonPath('data.0.status', 'prepared')
            ->assertJsonCount(1, 'data');
    }

    private function lease(string $runId, string $client): array
    {
        return [
            'run_id' => $runId,
            'calendar_id' => 'primary',
            'schedule_id' => 'schedule-1',
            'client_instance_id' => $client,
            'ttl_seconds' => 60,
        ];
    }

    private function auth(string $token): array
    {
        return ['Authorization' => 'Bearer '.$token];
    }
}
