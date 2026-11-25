<?php

namespace Tests\Feature;

use App\Contracts\GoogleIdentityTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Fakes\FakeGoogleIdentityTokenVerifier;
use Tests\TestCase;

class ScheduleApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->app->instance(GoogleIdentityTokenVerifier::class, new FakeGoogleIdentityTokenVerifier([
            'alice-token' => ['sub' => 'google-alice', 'email' => 'alice@example.com', 'email_verified' => true, 'name' => 'Alice'],
            'bob-token' => ['sub' => 'google-bob', 'email' => 'bob@example.com', 'email_verified' => true, 'name' => 'Bob'],
        ]));
    }

    public function test_schedule_is_created_and_updated_only_with_the_current_revision(): void
    {
        $this->signIn('alice-token');
        $absent = $this->getJson('/api/v1/schedules/roster-2026-11', $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('state', 'absent')->json('revision');

        $first = $this->putJson('/api/v1/schedules/roster-2026-11', [
            'expected_revision' => $absent,
            'schedule' => $this->schedulePayload('roster-2026-11', 'November'),
        ], $this->auth('alice-token'))->assertCreated()->json();

        $this->assertSame('live', $first['state']);
        $this->assertStringStartsWith('v1:', $first['revision']);

        $updated = $this->putJson('/api/v1/schedules/roster-2026-11', [
            'expected_revision' => $first['revision'],
            'schedule' => $this->schedulePayload('roster-2026-11', 'November revised'),
        ], $this->auth('alice-token'))->assertOk()->json();

        $this->assertSame('v2:', substr($updated['revision'], 0, 3));
        $this->assertSame('November revised', $updated['data']['schedule']['name']);

        $this->putJson('/api/v1/schedules/roster-2026-11', [
            'expected_revision' => $first['revision'],
            'schedule' => $this->schedulePayload('roster-2026-11', 'stale overwrite'),
        ], $this->auth('alice-token'))->assertConflict()
            ->assertJsonPath('error.code', 'schedule_revision_conflict');

        $this->getJson('/api/v1/schedules/roster-2026-11', $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('data.schedule.name', 'November revised')
            ->assertJsonPath('revision', $updated['revision']);
    }

    public function test_schedule_records_are_isolated_between_authenticated_accounts(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');

        $aliceAbsent = $this->getJson('/api/v1/schedules/shared-id', $this->auth('alice-token'))
            ->assertOk()->json('revision');
        $this->putJson('/api/v1/schedules/shared-id', [
            'expected_revision' => $aliceAbsent,
            'schedule' => $this->schedulePayload('shared-id', 'Alice private'),
        ], $this->auth('alice-token'))->assertCreated();

        $this->getJson('/api/v1/schedules/shared-id', $this->auth('bob-token'))
            ->assertOk()->assertJsonPath('state', 'absent')->assertJsonPath('data', null);

        $bobAbsent = $this->getJson('/api/v1/schedules/shared-id', $this->auth('bob-token'))->json('revision');
        $this->assertNotSame($aliceAbsent, $bobAbsent, 'Absent revision tokens must be scoped to the authenticated account.');
        $this->putJson('/api/v1/schedules/shared-id', [
            'expected_revision' => $bobAbsent,
            'schedule' => $this->schedulePayload('shared-id', 'Bob private'),
        ], $this->auth('bob-token'))->assertCreated();

        $this->getJson('/api/v1/schedules/shared-id', $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('data.schedule.name', 'Alice private');
    }

    public function test_conditional_delete_keeps_a_tombstone_and_rejects_stale_revision(): void
    {
        $this->signIn('alice-token');
        $absent = $this->getJson('/api/v1/schedules/delete-me', $this->auth('alice-token'))->json('revision');
        $created = $this->putJson('/api/v1/schedules/delete-me', [
            'expected_revision' => $absent,
            'schedule' => $this->schedulePayload('delete-me', 'Keep history'),
        ], $this->auth('alice-token'))->assertCreated()->json();

        $deleted = $this->deleteJson('/api/v1/schedules/delete-me', [
            'expected_revision' => $created['revision'],
        ], $this->auth('alice-token'))->assertOk()->json();

        $this->assertSame('deleted', $deleted['state']);
        $this->assertStringStartsWith('v2:', $deleted['revision']);

        $this->putJson('/api/v1/schedules/delete-me', [
            'expected_revision' => $created['revision'],
            'schedule' => $this->schedulePayload('delete-me', 'stale resurrection'),
        ], $this->auth('alice-token'))->assertConflict();

        $this->getJson('/api/v1/schedules/delete-me', $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('state', 'deleted')->assertJsonPath('data', null);
    }

    public function test_import_journal_is_idempotent_and_account_scoped(): void
    {
        $this->signIn('alice-token');
        $this->signIn('bob-token');
        $payload = [
            'import_run_id' => 'grid-1795520000000000',
            'lifecycle' => 'prepared',
            'base_revision' => 'absent:abc',
            'source_fingerprint' => str_repeat('a', 64),
            'provenance' => ['source' => 'workbook.xlsx', 'parser_version' => '1'],
        ];

        $created = $this->postJson('/api/v1/schedules/roster/import-journals', $payload, $this->auth('alice-token'))
            ->assertCreated()->json('data');
        $replayed = $this->postJson('/api/v1/schedules/roster/import-journals', $payload, $this->auth('alice-token'))
            ->assertOk()->json('data');

        $this->assertSame($created['import_run_id'], $replayed['import_run_id']);

        $committed = $payload;
        $committed['lifecycle'] = 'committed';
        $committed['schedule'] = $this->schedulePayload('roster', 'Imported roster');
        $committed['accepted_schedule_fingerprint'] = hash('sha256', json_encode($committed['schedule'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION));
        $committed['provenance'] = ['source' => 'workbook.xlsx', 'parser_version' => '1', 'accepted' => true];
        $this->postJson('/api/v1/schedules/roster/import-journals', $committed, $this->auth('alice-token'))
            ->assertCreated()->assertJsonPath('data.lifecycle', 'committed');
        $this->postJson('/api/v1/schedules/roster/import-journals', $committed, $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('data.lifecycle', 'committed');

        $this->getJson('/api/v1/schedules/roster/import-journals', $this->auth('bob-token'))
            ->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/schedules/roster/import-journals', $this->auth('alice-token'))
            ->assertOk()->assertJsonCount(2, 'data');

        $different = $payload;
        $different['provenance'] = ['source' => 'different.xlsx'];
        $this->postJson('/api/v1/schedules/roster/import-journals', $different, $this->auth('alice-token'))
            ->assertConflict()->assertJsonPath('error.code', 'import_run_conflict');
    }

    private function schedulePayload(string $id, string $name): array
    {
        return [
            'format' => 'shift-tools.canonical-schedule',
            'version' => 1,
            'schedule' => [
                'id' => $id,
                'name' => $name,
                'departments' => [],
                'employees' => [],
                'shiftTypes' => [],
                'months' => [],
            ],
        ];
    }

    private function signIn(string $token): void
    {
        $this->getJson('/api/v1/me', $this->auth($token))->assertOk();
    }

    private function auth(string $token): array
    {
        return ['Authorization' => 'Bearer '.$token];
    }
}
