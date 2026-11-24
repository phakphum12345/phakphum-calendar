<?php

namespace Tests\Feature;

use App\Contracts\GoogleIdentityTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Fakes\FakeGoogleIdentityTokenVerifier;
use Tests\TestCase;

class ShiftPayProfileApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->app->instance(GoogleIdentityTokenVerifier::class, new FakeGoogleIdentityTokenVerifier([
            'owner-token' => ['sub' => 'google-owner', 'email' => 'owner@example.com', 'email_verified' => true, 'name' => 'Owner'],
            'member-token' => ['sub' => 'google-member', 'email' => 'member@example.com', 'email_verified' => true, 'name' => 'Member'],
            'outsider-token' => ['sub' => 'google-outsider', 'email' => 'outsider@example.com', 'email_verified' => true, 'name' => 'Outsider'],
        ]));
        foreach (['owner-token', 'member-token', 'outsider-token'] as $token) {
            $this->getJson('/api/v1/me', $this->auth($token))->assertOk();
        }
    }

    public function test_personal_profile_is_persisted_and_defaults_to_explicit_personal_mode(): void
    {
        $this->getJson('/api/v1/shift-pay/profile', $this->auth('owner-token'))
            ->assertOk()->assertJsonPath('data.mode', 'personal')
            ->assertJsonPath('data.personal_rules', []);

        $rule = $this->rule('personal-night', 700);
        $this->putJson('/api/v1/shift-pay/profile', [
            'mode' => 'personal', 'currency_code' => 'THB',
            'personal_rules' => [$rule],
        ], $this->auth('owner-token'))->assertOk()
            ->assertJsonPath('data.mode', 'personal')
            ->assertJsonPath('data.personal_rules.0.id', 'personal-night');

        $this->assertDatabaseHas('user_shift_pay_profiles', [
            'user_id' => DB::table('users')->where('email', 'owner@example.com')->value('id'),
            'mode' => 'personal', 'currency_code' => 'THB',
        ]);
    }

    public function test_hybrid_profile_resolves_organization_scope_and_returns_separate_sources(): void
    {
        $organization = $this->organization();
        $this->putJson('/api/v1/shift-pay/profile', [
            'mode' => 'hybrid', 'organization_id' => $organization['id'],
            'hybrid_priority' => 'requireSelection',
            'personal_rules' => [$this->rule('personal-night', 700)],
        ], $this->auth('owner-token'))->assertOk()
            ->assertJsonPath('data.mode', 'hybrid')
            ->assertJsonPath('data.organization_id', $organization['id'])
            ->assertJsonPath('data.personal_rules.0.id', 'personal-night');

        $this->putJson("/api/v1/organizations/{$organization['id']}/shift-pay-rules", [
            'currency_code' => 'THB', 'rules' => [$this->rule('org-night', 900)],
        ], $this->auth('owner-token'))->assertOk()
            ->assertJsonPath('data.rules.0.id', 'org-night');

        $this->getJson('/api/v1/shift-pay/profile', $this->auth('owner-token'))
            ->assertOk()->assertJsonPath('data.organization_rules.0.id', 'org-night');
    }

    public function test_only_owner_or_admin_can_change_organization_shift_pay_rules(): void
    {
        $organization = $this->organization();
        DB::table('organization_memberships')->insert([
            'organization_id' => $organization['id'],
            'user_id' => DB::table('users')->where('email', 'member@example.com')->value('id'),
            'employee_id' => 'EMP-MEMBER', 'role' => 'staff', 'status' => 'active',
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $this->putJson("/api/v1/organizations/{$organization['id']}/shift-pay-rules", [
            'rules' => [$this->rule('org-night', 900)],
        ], $this->auth('member-token'))->assertForbidden();
        $this->getJson("/api/v1/organizations/{$organization['id']}/shift-pay-rules", $this->auth('outsider-token'))
            ->assertForbidden();
    }

    public function test_personal_rules_reject_duplicate_ids_and_missing_amounts(): void
    {
        $rule = $this->rule('duplicate', 100);
        $this->putJson('/api/v1/shift-pay/profile', [
            'mode' => 'personal', 'personal_rules' => [$rule, $rule],
        ], $this->auth('owner-token'))->assertUnprocessable();

        unset($rule['fixed_amount']);
        $this->putJson('/api/v1/shift-pay/profile', [
            'mode' => 'personal', 'personal_rules' => [$rule],
        ], $this->auth('owner-token'))->assertUnprocessable();
    }

    public function test_profile_cannot_select_an_organization_without_active_membership(): void
    {
        $organization = $this->organization();
        $this->putJson('/api/v1/shift-pay/profile', [
            'mode' => 'organization', 'organization_id' => $organization['id'],
        ], $this->auth('outsider-token'))->assertForbidden();
    }

    private function organization(): array
    {
        return $this->postJson('/api/v1/organizations', [
            'name' => 'Radiology', 'employee_id' => 'EMP-OWNER',
        ], $this->auth('owner-token'))->assertCreated()->json('data');
    }

    private function rule(string $id, float $amount): array
    {
        return [
            'id' => $id, 'employment_type' => 'dailyPaid',
            'day_category' => 'regularWeekday', 'shift_type_id' => 'night',
            'fixed_amount' => $amount, 'active' => true,
        ];
    }

    private function auth(string $token): array
    {
        return ['Authorization' => 'Bearer '.$token];
    }
}
