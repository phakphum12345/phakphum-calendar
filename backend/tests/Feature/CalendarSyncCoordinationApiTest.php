<?php

namespace Tests\Feature;

use App\Contracts\GoogleIdentityTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
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

    public function test_operation_ledger_is_idempotent_and_rejects_key_reuse_with_different_payload(): void
    {
        $lease = $this->postJson('/api/v1/calendar-sync/leases', $this->lease('00000000-0000-4000-8000-000000000005', 'alice-device'), $this->auth('alice-token'))
            ->assertCreated()->json('data');
        $payload = [
            'lease_token' => $lease['lease_token'],
            'operation_key' => 'event-sync-1',
            'operation_type' => 'insert',
            'payload_hash' => hash('sha256', 'same-event-payload'),
        ];

        $this->postJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000005/operations', $payload, $this->auth('alice-token'))
            ->assertCreated()->assertJsonPath('data.status', 'prepared');
        $this->postJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000005/operations', $payload, $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('data.status', 'prepared');

        $this->postJson('/api/v1/calendar-sync/leases/00000000-0000-4000-8000-000000000005/operations', [
            ...$payload,
            'payload_hash' => hash('sha256', 'different-event-payload'),
        ], $this->auth('alice-token'))->assertConflict();

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
        $this->getJson('/api/v1/calendar-sync/runs/00000000-0000-4000-8000-000000000005/operations', $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('data.0.provider_event_id', 'provider-event-123');
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
