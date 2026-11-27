<?php

namespace Tests\Feature;

use App\Contracts\GoogleIdentityTokenVerifier;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
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
        $storedPayload = DB::table('schedule_records')
            ->where('schedule_id', 'roster-2026-11')
            ->value('schedule_payload');
        $this->assertStringStartsWith('enc:v1:', $storedPayload);
        $this->assertStringNotContainsString('November', $storedPayload);

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

    // Keep unexpected storage failures distinct from stale-revision conflicts.
    public function test_legacy_plaintext_schedule_payload_remains_readable(): void
    {
        $this->signIn('alice-token');
        $absent = $this->getJson('/api/v1/schedules/legacy-schedule', $this->auth('alice-token'))
            ->assertOk()->json('revision');
        $this->putJson('/api/v1/schedules/legacy-schedule', [
            'expected_revision' => $absent,
            'schedule' => $this->schedulePayload('legacy-schedule', 'Legacy schedule'),
        ], $this->auth('alice-token'))->assertCreated();

        $legacyPayload = json_encode(
            $this->schedulePayload('legacy-schedule', 'Legacy schedule'),
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR,
        );
        DB::table('schedule_records')
            ->where('schedule_id', 'legacy-schedule')
            ->update(['schedule_payload' => $legacyPayload]);

        $this->getJson('/api/v1/schedules/legacy-schedule', $this->auth('alice-token'))
            ->assertOk()
            ->assertJsonPath('data.schedule.name', 'Legacy schedule');
    }

    public function test_schedule_insert_database_failure_is_not_reported_as_a_revision_conflict(): void
    {
        $this->signIn('alice-token');
        $absent = $this->getJson('/api/v1/schedules/insert-failure', $this->auth('alice-token'))
            ->assertOk()->json('revision');

        DB::unprepared("CREATE TRIGGER fail_schedule_record_insert BEFORE INSERT ON schedule_records
            BEGIN SELECT RAISE(ABORT, 'forced schedule insert failure'); END;");

        try {
            $this->withoutExceptionHandling();
            $this->putJson('/api/v1/schedules/insert-failure', [
                'expected_revision' => $absent,
                'schedule' => $this->schedulePayload('insert-failure', 'Must not be saved'),
            ], $this->auth('alice-token'));
            $this->fail('Expected the original database exception to be rethrown.');
        } catch (QueryException $exception) {
            $this->assertStringContainsString('forced schedule insert failure', $exception->getMessage());
        }

        $this->assertDatabaseMissing('schedule_records', [
            'schedule_id' => 'insert-failure',
        ]);
    }

    public function test_journal_insert_database_failure_is_not_reported_as_an_import_conflict(): void
    {
        $this->signIn('alice-token');

        DB::unprepared("CREATE TRIGGER fail_schedule_journal_insert BEFORE INSERT ON schedule_import_journals
            BEGIN SELECT RAISE(ABORT, 'forced journal insert failure'); END;");

        try {
            $this->withoutExceptionHandling();
            $this->postJson('/api/v1/schedules/journal-failure/import-journals', [
                'import_run_id' => 'grid-journal-failure',
                'lifecycle' => 'prepared',
                'base_revision' => 'absent:test',
                'source_fingerprint' => str_repeat('b', 64),
                'provenance' => ['source' => 'failure-fixture.xlsx'],
            ], $this->auth('alice-token'));
            $this->fail('Expected the original database exception to be rethrown.');
        } catch (QueryException $exception) {
            $this->assertStringContainsString('forced journal insert failure', $exception->getMessage());
        }

        $this->assertDatabaseMissing('schedule_import_journals', [
            'import_run_id' => 'grid-journal-failure',
            'lifecycle' => 'prepared',
        ]);
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

        $this->deleteJson('/api/v1/schedules/delete-me', [
            'expected_revision' => $created['revision'],
        ], $this->auth('alice-token'))->assertOk()
            ->assertJsonPath('revision', $deleted['revision']);
        $this->deleteJson('/api/v1/schedules/delete-me', [
            'expected_revision' => $deleted['revision'],
        ], $this->auth('alice-token'))->assertOk()
            ->assertJsonPath('revision', $deleted['revision']);

        $this->getJson('/api/v1/schedules/delete-me', $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('state', 'deleted')->assertJsonPath('data', null);
    }

    public function test_deleting_an_absent_schedule_creates_an_idempotent_tombstone(): void
    {
        $this->signIn('alice-token');
        $absent = $this->getJson('/api/v1/schedules/never-created', $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('state', 'absent')->json('revision');

        $deleted = $this->deleteJson('/api/v1/schedules/never-created', [
            'expected_revision' => $absent,
        ], $this->auth('alice-token'))->assertCreated()->json();

        $this->assertSame('deleted', $deleted['state']);
        $this->assertStringStartsWith('v1:', $deleted['revision']);
        $this->deleteJson('/api/v1/schedules/never-created', [
            'expected_revision' => $absent,
        ], $this->auth('alice-token'))->assertOk()
            ->assertJsonPath('revision', $deleted['revision']);

        $this->putJson('/api/v1/schedules/never-created', [
            'expected_revision' => $absent,
            'schedule' => $this->schedulePayload('never-created', 'stale create'),
        ], $this->auth('alice-token'))->assertConflict();

        $this->getJson('/api/v1/schedules/never-created', $this->auth('alice-token'))
            ->assertOk()->assertJsonPath('state', 'deleted')
            ->assertJsonPath('revision', $deleted['revision']);
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
        $this->assertSame($payload['provenance'], $created['provenance']);
        $storedPrepared = DB::table('schedule_import_journals')
            ->where('import_run_id', $payload['import_run_id'])
            ->where('lifecycle', 'prepared')
            ->first();
        $preparedEnvelope = json_decode($storedPrepared->provenance, true, 512, JSON_THROW_ON_ERROR);
        $this->assertSame(1, $preparedEnvelope['encryption_version']);
        $this->assertStringNotContainsString('workbook.xlsx', $storedPrepared->provenance);

        $committed = $payload;
        $committed['lifecycle'] = 'committed';
        $committed['schedule'] = $this->schedulePayload('roster', 'Imported roster');
        $committed['accepted_schedule_fingerprint'] = hash('sha256', json_encode($committed['schedule'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION));
        $committed['provenance'] = ['source' => 'workbook.xlsx', 'parser_version' => '1', 'accepted' => true];
        $committedResponse = $this->postJson('/api/v1/schedules/roster/import-journals', $committed, $this->auth('alice-token'))
            ->assertCreated()->assertJsonPath('data.lifecycle', 'committed')
            ->json('data');
        $this->assertSame('Imported roster', $committedResponse['schedule']['schedule']['name']);
        $storedCommitted = DB::table('schedule_import_journals')
            ->where('import_run_id', $payload['import_run_id'])
            ->where('lifecycle', 'committed')
            ->first();
        $this->assertStringStartsWith('enc:v1:', $storedCommitted->schedule_payload);
        $this->assertStringNotContainsString('Imported roster', $storedCommitted->schedule_payload);
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

    public function test_legacy_plaintext_import_journal_remains_readable(): void
    {
        $this->signIn('alice-token');
        $ownerId = DB::table('users')->where('google_subject', 'google-alice')->value('id');
        $now = now();
        DB::table('schedule_import_journals')->insert([
            'owner_user_id' => $ownerId,
            'schedule_id' => 'legacy-journal',
            'import_run_id' => 'legacy-run-1',
            'lifecycle' => 'committed',
            'base_revision' => 'revision-1',
            'source_fingerprint' => str_repeat('c', 64),
            'accepted_schedule_fingerprint' => str_repeat('d', 64),
            'provenance' => json_encode(['source' => 'legacy.xlsx']),
            'schedule_payload' => json_encode($this->schedulePayload('legacy-journal', 'Legacy journal')),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $this->getJson('/api/v1/schedules/legacy-journal/import-journals', $this->auth('alice-token'))
            ->assertOk()
            ->assertJsonPath('data.0.provenance.source', 'legacy.xlsx')
            ->assertJsonPath('data.0.schedule.schedule.name', 'Legacy journal');
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
