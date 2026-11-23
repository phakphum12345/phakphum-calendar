<?php

namespace Tests\Feature;

use App\Contracts\GoogleIdentityTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
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

    public function test_add_member_rejects_oversized_unicode_email_before_email_validation(): void
    {
        $this->getJson('/api/v1/me', $this->auth('owner-token'))->assertOk();
        $organization = $this->postJson('/api/v1/organizations', [
            'name' => 'Radiology',
            'employee_id' => 'EMP-OWNER',
        ], $this->auth('owner-token'))->assertCreated()->json('data');

        $response = $this->postJson(
            "/api/v1/organizations/{$organization['id']}/members",
            [
                'email' => str_repeat('é', 300).'@example.com',
                'employee_id' => 'EMP-LONG-EMAIL',
                'role' => 'staff',
            ],
            $this->auth('owner-token'),
        )->assertUnprocessable();

        $errors = $response->json('errors.email');
        $this->assertCount(1, $errors);
        $this->assertStringContainsString('254', $errors[0]);
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

    public function test_owner_can_change_member_role_remove_and_reactivate_without_deleting_membership(): void
    {
        $this->getJson('/api/v1/me', $this->auth('owner-token'))->assertOk();
        $this->getJson('/api/v1/me', $this->auth('member-token'))->assertOk();
        $this->getJson('/api/v1/me', $this->auth('outsider-token'))->assertOk();

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

        $memberId = (string) DB::table('users')
            ->where('email', 'member@example.com')
            ->value('id');

        $this->patchJson(
            "/api/v1/organizations/{$organizationId}/members/{$memberId}",
            ['role' => 'manager'],
            $this->auth('owner-token'),
        )->assertOk()
            ->assertJsonPath('data.user_id', $memberId)
            ->assertJsonPath('data.role', 'manager');

        $this->assertDatabaseHas('organization_memberships', [
            'organization_id' => $organizationId,
            'user_id' => $memberId,
            'role' => 'manager',
            'status' => 'active',
        ]);

        $this->deleteJson(
            "/api/v1/organizations/{$organizationId}/members/{$memberId}",
            [],
            $this->auth('owner-token'),
        )->assertOk()->assertJsonPath('data.status', 'inactive');

        $this->assertDatabaseHas('organization_memberships', [
            'organization_id' => $organizationId,
            'user_id' => $memberId,
            'role' => 'manager',
            'status' => 'inactive',
        ]);

        $this->getJson(
            "/api/v1/organizations/{$organizationId}/members",
            $this->auth('owner-token'),
        )->assertOk()->assertJsonCount(1, 'data');
        $this->getJson(
            "/api/v1/organizations/{$organizationId}/members",
            $this->auth('member-token'),
        )->assertForbidden();

        $this->postJson("/api/v1/organizations/{$organizationId}/members", [
            'email' => 'member@example.com',
            'employee_id' => 'EMP-MEMBER-2',
            'role' => 'admin',
        ], $this->auth('owner-token'))->assertOk();

        $this->assertDatabaseHas('organization_memberships', [
            'organization_id' => $organizationId,
            'user_id' => $memberId,
            'employee_id' => 'EMP-MEMBER-2',
            'role' => 'admin',
            'status' => 'active',
        ]);
        $this->getJson(
            "/api/v1/organizations/{$organizationId}/members",
            $this->auth('member-token'),
        )->assertOk()->assertJsonCount(2, 'data');
    }

    public function test_only_owner_or_admin_can_manage_members_and_owner_membership_is_protected(): void
    {
        $this->getJson('/api/v1/me', $this->auth('owner-token'))->assertOk();
        $this->getJson('/api/v1/me', $this->auth('member-token'))->assertOk();

        $organization = $this->postJson('/api/v1/organizations', [
            'name' => 'Outpatient',
            'employee_id' => 'EMP-OWNER',
        ], $this->auth('owner-token'))->assertCreated()->json('data');
        $organizationId = $organization['id'];

        $this->postJson("/api/v1/organizations/{$organizationId}/members", [
            'email' => 'member@example.com',
            'employee_id' => 'EMP-MEMBER',
            'role' => 'staff',
        ], $this->auth('owner-token'))->assertCreated();

        $memberId = (string) DB::table('users')
            ->where('email', 'member@example.com')
            ->value('id');
        $ownerId = (string) DB::table('users')
            ->where('email', 'owner@example.com')
            ->value('id');

        $this->patchJson(
            "/api/v1/organizations/{$organizationId}/members/{$memberId}",
            ['role' => 'manager'],
            $this->auth('member-token'),
        )->assertForbidden();

        $this->deleteJson(
            "/api/v1/organizations/{$organizationId}/members/{$memberId}",
            [],
            $this->auth('member-token'),
        )->assertForbidden();

        $this->patchJson(
            "/api/v1/organizations/{$organizationId}/members/{$ownerId}",
            ['role' => 'admin'],
            $this->auth('owner-token'),
        )->assertConflict()
            ->assertJsonPath('error.code', 'owner_membership_protected');

        $this->deleteJson(
            "/api/v1/organizations/{$organizationId}/members/{$ownerId}",
            [],
            $this->auth('owner-token'),
        )->assertConflict()
            ->assertJsonPath('error.code', 'owner_membership_protected');

        $this->assertDatabaseHas('organization_memberships', [
            'organization_id' => $organizationId,
            'user_id' => $ownerId,
            'role' => 'owner',
            'status' => 'active',
        ]);
    }

    public function test_membership_audit_records_lifecycle_events_and_is_manager_only(): void
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

        $memberId = (string) DB::table('users')
            ->where('email', 'member@example.com')
            ->value('id');

        $this->patchJson(
            "/api/v1/organizations/{$organizationId}/members/{$memberId}",
            ['role' => 'manager'],
            $this->auth('owner-token'),
        )->assertOk();

        $this->deleteJson(
            "/api/v1/organizations/{$organizationId}/members/{$memberId}",
            [],
            $this->auth('owner-token'),
        )->assertOk();

        $this->postJson("/api/v1/organizations/{$organizationId}/members", [
            'email' => 'member@example.com',
            'employee_id' => 'EMP-MEMBER-2',
            'role' => 'staff',
        ], $this->auth('owner-token'))->assertOk();

        $auditUrl = "/api/v1/organizations/{$organizationId}/membership-audit";
        $this->getJson($auditUrl, $this->auth('member-token'))->assertForbidden();
        $this->getJson($auditUrl, $this->auth('outsider-token'))->assertForbidden();

        $this->getJson("{$auditUrl}?limit=1", $this->auth('owner-token'))
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.action', 'reactivated')
            ->assertJsonPath('meta.limit', 1);

        $this->getJson($auditUrl, $this->auth('owner-token'))
            ->assertOk()
            ->assertJsonCount(5, 'data')
            ->assertJsonPath('data.0.action', 'reactivated')
            ->assertJsonPath('data.0.before.status', 'inactive')
            ->assertJsonPath('data.0.after.status', 'active')
            ->assertJsonPath('data.1.action', 'removed')
            ->assertJsonPath('data.1.before.status', 'active')
            ->assertJsonPath('data.1.after.status', 'inactive')
            ->assertJsonPath('data.2.action', 'role_changed')
            ->assertJsonPath('data.2.before.role', 'staff')
            ->assertJsonPath('data.2.after.role', 'manager')
            ->assertJsonPath('data.3.action', 'added')
            ->assertJsonPath('data.4.action', 'created');

        $this->assertDatabaseCount('organization_membership_audit_events', 5);
    }

    private function auth(string $token): array
    {
        return ['Authorization' => 'Bearer '.$token];
    }
}
