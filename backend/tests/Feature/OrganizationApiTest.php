<?php

namespace Tests\Feature;

use App\Contracts\GoogleIdentityTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Fakes\FakeGoogleIdentityTokenVerifier;
use Tests\TestCase;

class OrganizationApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->app->instance(
            GoogleIdentityTokenVerifier::class,
            new FakeGoogleIdentityTokenVerifier([
                'owner-token' => [
                    'sub' => 'google-owner',
                    'email' => 'owner@example.com',
                    'email_verified' => true,
                    'name' => 'Owner',
                ],
                'member-token' => [
                    'sub' => 'google-member',
                    'email' => 'member@example.com',
                    'email_verified' => true,
                    'name' => 'Member',
                ],
                'outsider-token' => [
                    'sub' => 'google-outsider',
                    'email' => 'outsider@example.com',
                    'email_verified' => true,
                    'name' => 'Outsider',
                ],
            ]),
        );
    }

    public function test_owner_can_create_organization_and_default_to_approval(): void
    {
        $this->getJson('/api/v1/me', $this->auth('owner-token'))->assertOk();

        $response = $this->postJson('/api/v1/organizations', [
            'name' => 'Radiology',
            'slug' => 'radiology',
            'employee_id' => 'EMP-001',
        ], $this->auth('owner-token'));

        $response->assertCreated()
            ->assertJsonPath('data.role', 'owner')
            ->assertJsonPath('data.slug', 'radiology');

        $organizationId = $response->json('data.id');
        $policies = $this->getJson(
            "/api/v1/organizations/{$organizationId}/shift-policies",
            $this->auth('owner-token'),
        );

        $policies->assertOk()
            ->assertJsonPath('data.0.workflow_type', 'give_up')
            ->assertJsonPath('data.0.requires_approval', true)
            ->assertJsonPath('data.1.requires_approval', true)
            ->assertJsonPath('data.2.requires_approval', true);
    }

    public function test_owner_can_add_a_registered_member_and_configure_workflow_policy(): void
    {
        $this->getJson('/api/v1/me', $this->auth('owner-token'))->assertOk();
        $this->getJson('/api/v1/me', $this->auth('member-token'))->assertOk();

        $organization = $this->postJson('/api/v1/organizations', [
            'name' => 'Emergency',
            'employee_id' => 'EMP-OWNER',
        ], $this->auth('owner-token'))->assertCreated()->json('data');

        $organizationId = $organization['id'];

        $this->postJson("/api/v1/organizations/{$organizationId}/members", [
            'email' => 'member@example.com',
            'employee_id' => 'EMP-MEMBER',
            'role' => 'staff',
        ], $this->auth('owner-token'))->assertCreated();

        $this->putJson(
            "/api/v1/organizations/{$organizationId}/shift-policies/give_up",
            ['requires_approval' => false],
            $this->auth('owner-token'),
        )->assertOk()->assertJsonPath('data.requires_approval', false);

        $this->getJson(
            "/api/v1/organizations/{$organizationId}/members",
            $this->auth('owner-token'),
        )->assertOk()->assertJsonCount(2, 'data');
    }

    public function test_non_admin_member_cannot_change_organization_policy(): void
    {
        $this->getJson('/api/v1/me', $this->auth('owner-token'))->assertOk();
        $this->getJson('/api/v1/me', $this->auth('member-token'))->assertOk();

        $organization = $this->postJson('/api/v1/organizations', [
            'name' => 'Outpatient',
            'employee_id' => 'EMP-OWNER',
        ], $this->auth('owner-token'))->assertCreated()->json('data');

        $this->postJson("/api/v1/organizations/{$organization['id']}/members", [
            'email' => 'member@example.com',
            'employee_id' => 'EMP-MEMBER',
            'role' => 'staff',
        ], $this->auth('owner-token'))->assertCreated();

        $this->putJson(
            "/api/v1/organizations/{$organization['id']}/shift-policies/exchange",
            ['requires_approval' => false],
            $this->auth('member-token'),
        )->assertForbidden();
    }

    public function test_accounts_outside_an_organization_cannot_read_its_members(): void
    {
        $this->getJson('/api/v1/me', $this->auth('owner-token'))->assertOk();
        $this->getJson('/api/v1/me', $this->auth('outsider-token'))->assertOk();

        $organization = $this->postJson('/api/v1/organizations', [
            'name' => 'CT',
            'employee_id' => 'EMP-OWNER',
        ], $this->auth('owner-token'))->assertCreated()->json('data');

        $this->getJson(
            "/api/v1/organizations/{$organization['id']}/members",
            $this->auth('outsider-token'),
        )->assertForbidden();
    }

    public function test_owner_cannot_add_an_unregistered_google_account(): void
    {
        $this->getJson('/api/v1/me', $this->auth('owner-token'))->assertOk();
        $organization = $this->postJson('/api/v1/organizations', [
            'name' => 'MRI',
            'employee_id' => 'EMP-OWNER',
        ], $this->auth('owner-token'))->assertCreated()->json('data');

        $this->postJson("/api/v1/organizations/{$organization['id']}/members", [
            'email' => 'not-registered@example.com',
            'employee_id' => 'EMP-UNKNOWN',
            'role' => 'staff',
        ], $this->auth('owner-token'))->assertNotFound()
            ->assertJsonPath('error.code', 'account_not_registered');
    }

    private function auth(string $token): array
    {
        return ['Authorization' => 'Bearer '.$token];
    }
}
