<?php

namespace Tests\Feature;

use App\Contracts\GoogleIdentityTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Fakes\FakeGoogleIdentityTokenVerifier;
use Tests\TestCase;

class ShiftPayCalculationSnapshotApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->app->instance(GoogleIdentityTokenVerifier::class, new FakeGoogleIdentityTokenVerifier([
            'owner-token' => ['sub' => 'google-owner', 'email' => 'owner@example.com', 'email_verified' => true, 'name' => 'Owner'],
            'outsider-token' => ['sub' => 'google-outsider', 'email' => 'outsider@example.com', 'email_verified' => true, 'name' => 'Outsider'],
        ]));
        foreach (['owner-token', 'outsider-token'] as $token) {
            $this->getJson('/api/v1/me', $this->auth($token))->assertOk();
        }
    }

    public function test_personal_calculation_is_snapshotted_and_remains_unchanged_after_rule_edit(): void
    {
        $this->putJson('/api/v1/shift-pay/profile', [
            'mode' => 'personal',
            'currency_code' => 'THB',
            'decimal_places' => 2,
            'personal_rules' => [$this->rule('night', 700)],
        ], $this->auth('owner-token'))->assertOk();

        $response = $this->postJson('/api/v1/shift-pay/calculations', $this->input(), $this->auth('owner-token') + [
            'Idempotency-Key' => 'personal-snapshot-001',
        ])->assertCreated()
            ->assertJsonPath('data.result.status', 'calculated')
            ->assertJsonPath('data.result.amount', 700)
            ->assertJsonPath('data.result.source', 'personal')
            ->assertJsonPath('data.rule.id', 'night');

        $snapshotId = $response->json('data.id');

        $this->putJson('/api/v1/shift-pay/profile', [
            'mode' => 'personal',
            'personal_rules' => [$this->rule('night', 950)],
        ], $this->auth('owner-token'))->assertOk();

        $stored = DB::table('shift_pay_calculation_snapshots')->where('id', $snapshotId)->first();
        $this->assertSame(700.0, json_decode($stored->result_snapshot, true)['amount']);
        $this->getJson("/api/v1/shift-pay/snapshots/{$snapshotId}", $this->auth('owner-token'))
            ->assertOk()->assertJsonPath('data.result.amount', 700);
        $this->getJson("/api/v1/shift-pay/snapshots/{$snapshotId}", $this->auth('outsider-token'))
            ->assertNotFound();
    }

    public function test_hybrid_require_selection_never_returns_or_adds_candidate_amounts(): void
    {
        $organization = $this->postJson('/api/v1/organizations', [
            'name' => 'Radiology', 'employee_id' => 'EMP-OWNER',
        ], $this->auth('owner-token'))->assertCreated()->json('data');

        $this->putJson('/api/v1/shift-pay/profile', [
            'mode' => 'hybrid',
            'organization_id' => $organization['id'],
            'hybrid_priority' => 'requireSelection',
            'personal_rules' => [$this->rule('personal-night', 700)],
        ], $this->auth('owner-token'))->assertOk();

        $this->putJson("/api/v1/organizations/{$organization['id']}/shift-pay-rules", [
            'rules' => [$this->rule('organization-night', 900)],
        ], $this->auth('owner-token'))->assertOk();

        $this->postJson('/api/v1/shift-pay/calculations', $this->input(), $this->auth('owner-token') + [
            'Idempotency-Key' => 'hybrid-unresolved-001',
        ])->assertCreated()
            ->assertJsonPath('data.result.status', 'source_selection_required')
            ->assertJsonPath('data.result.amount', null)
            ->assertJsonPath('data.result.source', null)
            ->assertJsonPath('data.rule', null);
    }

    public function test_hybrid_priority_selects_one_source_and_does_not_sum_amounts(): void
    {
        $organization = $this->postJson('/api/v1/organizations', [
            'name' => 'Emergency', 'employee_id' => 'EMP-OWNER',
        ], $this->auth('owner-token'))->assertCreated()->json('data');

        $this->putJson('/api/v1/shift-pay/profile', [
            'mode' => 'hybrid',
            'organization_id' => $organization['id'],
            'hybrid_priority' => 'organizationFirst',
            'personal_rules' => [$this->rule('personal-night', 700)],
        ], $this->auth('owner-token'))->assertOk();
        $this->putJson("/api/v1/organizations/{$organization['id']}/shift-pay-rules", [
            'rules' => [$this->rule('organization-night', 900)],
        ], $this->auth('owner-token'))->assertOk();

        $this->postJson('/api/v1/shift-pay/calculations', $this->input(), $this->auth('owner-token') + [
            'Idempotency-Key' => 'hybrid-org-first-001',
        ])->assertCreated()
            ->assertJsonPath('data.result.source', 'organization')
            ->assertJsonPath('data.result.amount', 900)
            ->assertJsonPath('data.rule.id', 'organization-night');
    }

    public function test_missing_rule_is_not_silently_reported_as_zero_and_idempotency_is_enforced(): void
    {
        $this->putJson('/api/v1/shift-pay/profile', [
            'mode' => 'personal',
            'personal_rules' => [],
        ], $this->auth('owner-token'))->assertOk();

        $this->postJson('/api/v1/shift-pay/calculations', $this->input(), $this->auth('owner-token') + [
            'Idempotency-Key' => 'no-rule-001',
        ])->assertCreated()
            ->assertJsonPath('data.result.status', 'no_matching_rule')
            ->assertJsonPath('data.result.amount', null);

        $this->postJson('/api/v1/shift-pay/calculations', $this->input(), $this->auth('owner-token') + [
            'Idempotency-Key' => 'no-rule-001',
        ])->assertOk();

        $changed = $this->input();
        $changed['hours'] = 12;
        $this->postJson('/api/v1/shift-pay/calculations', $changed, $this->auth('owner-token') + [
            'Idempotency-Key' => 'no-rule-001',
        ])->assertConflict();
    }

    private function input(): array
    {
        return [
            'date' => '2026-11-24',
            'employment_type' => 'dailyPaid',
            'shift_type_id' => 'night',
            'hours' => 8,
            'assignment_purpose' => 'regularCoverage',
        ];
    }

    private function rule(string $id, float $amount): array
    {
        return [
            'id' => $id,
            'employment_type' => 'dailyPaid',
            'day_category' => 'regularWeekday',
            'shift_type_id' => 'night',
            'fixed_amount' => $amount,
            'active' => true,
        ];
    }

    private function auth(string $token): array
    {
        return ['Authorization' => 'Bearer '.$token];
    }
}
