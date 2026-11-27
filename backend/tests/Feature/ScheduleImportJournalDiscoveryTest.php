<?php

namespace Tests\Feature;

use App\Contracts\GoogleIdentityTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Fakes\FakeGoogleIdentityTokenVerifier;
use Tests\TestCase;

class ScheduleImportJournalDiscoveryTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->app->instance(GoogleIdentityTokenVerifier::class, new FakeGoogleIdentityTokenVerifier([
            'owner-token' => ['sub' => 'journal-owner', 'email' => 'owner@example.com', 'email_verified' => true, 'name' => 'Owner'],
            'other-token' => ['sub' => 'journal-other', 'email' => 'other@example.com', 'email_verified' => true, 'name' => 'Other'],
        ]));
    }

    public function test_discovery_returns_distinct_schedule_ids_only_for_authenticated_owner(): void
    {
        $this->getJson('/api/v1/me', ['Authorization' => 'Bearer owner-token'])->assertOk();
        $this->getJson('/api/v1/me', ['Authorization' => 'Bearer other-token'])->assertOk();

        $ownerId = DB::table('users')->where('google_subject', 'journal-owner')->value('id');
        $otherId = DB::table('users')->where('google_subject', 'journal-other')->value('id');
        $now = now();

        foreach ([
            [$ownerId, 'owner-schedule-b', 'owner-run-1'],
            [$ownerId, 'owner-schedule-a', 'owner-run-2'],
            [$ownerId, 'owner-schedule-a', 'owner-run-3'],
            [$otherId, 'private-schedule', 'other-run-1'],
        ] as [$userId, $scheduleId, $runId]) {
            DB::table('schedule_import_journals')->insert([
                'owner_user_id' => $userId,
                'schedule_id' => $scheduleId,
                'import_run_id' => $runId,
                'lifecycle' => 'prepared',
                'base_revision' => 'revision-1',
                'source_fingerprint' => str_repeat('a', 64),
                'accepted_schedule_fingerprint' => null,
                'provenance' => json_encode([]),
                'schedule_payload' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $this->getJson('/api/v1/schedules/import-journals', [
            'Authorization' => 'Bearer owner-token',
        ])->assertOk()->assertExactJson([
            'data' => ['owner-schedule-a', 'owner-schedule-b'],
        ]);

        $this->getJson('/api/v1/schedules/import-journals', [
            'Authorization' => 'Bearer other-token',
        ])->assertOk()->assertExactJson([
            'data' => ['private-schedule'],
        ]);

        $this->getJson('/api/v1/schedules/import-journals')
            ->assertUnauthorized();
    }
}
