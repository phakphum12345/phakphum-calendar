<?php

namespace Tests\Feature;

use App\Contracts\GoogleIdentityTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Fakes\FakeGoogleIdentityTokenVerifier;
use Tests\TestCase;

class OrganizationJoinRequestApiTest extends TestCase
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
                    'name' => 'Organization Owner',
                ],
                'applicant-token' => [
                    'sub' => 'google-applicant',
                    'email' => 'applicant@example.com',
                    'email_verified' => true,
                    'name' => 'New Applicant',
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

    public function test_applicant_can_submit_and_track_a_pending_profile_request(): void
    {
        $organization = $this->createOrganization();

        $this->postJson('/api/v1/organization-join-requests', [
            'organization_slug' => $organization['slug'],
            'employee_id' => 'EMP-NEW',
        ], $this->auth('applicant-token'))
            ->assertCreated()
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.employee_id', 'EMP-NEW');

        $this->assertDatabaseMissing('organization_memberships', [
            'organization_id' => $organization['id'],
            'user_id' => $this->userId('applicant@example.com'),
        ]);

        $this->getJson(
            '/api/v1/organization-join-requests',
            $this->auth('applicant-token'),
        )->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.organization_slug', 'radiology')
            ->assertJsonPath('data.0.status', 'pending');

        $this->postJson('/api/v1/organization-join-requests', [
            'organization_slug' => $organization['slug'],
            'employee_id' => 'EMP-NEW',
        ], $this->auth('applicant-token'))
            ->assertConflict()
            ->assertJsonPath('error.code', 'join_request_pending');
    }

    public function test_owner_can_review_profile_and_choose_role_when_approving(): void
    {
        $organization = $this->createOrganization();
        $this->postJson('/api/v1/organization-join-requests', [
            'organization_slug' => $organization['slug'],
            'employee_id' => 'EMP-NEW',
        ], $this->auth('applicant-token'))->assertCreated();

        $request = $this->getJson(
            "/api/v1/organizations/{$organization['id']}/join-requests",
            $this->auth('owner-token'),
        )->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'New Applicant')
            ->assertJsonPath('data.0.email', 'applicant@example.com')
            ->assertJsonPath('data.0.employee_id', 'EMP-NEW')
            ->json('data.0');

        $this->postJson(
            "/api/v1/organizations/{$organization['id']}/join-requests/{$request['id']}/approve",
            ['role' => 'incharge'],
            $this->auth('owner-token'),
        )->assertOk()
            ->assertJsonPath('data.role', 'incharge')
            ->assertJsonPath('data.status', 'active');

        $this->assertDatabaseHas('organization_memberships', [
            'organization_id' => $organization['id'],
            'user_id' => $this->userId('applicant@example.com'),
            'employee_id' => 'EMP-NEW',
            'role' => 'incharge',
            'status' => 'active',
        ]);
        $this->assertDatabaseHas('organization_join_requests', [
            'id' => $request['id'],
            'status' => 'approved',
            'approved_role' => 'incharge',
        ]);

        $this->postJson('/api/v1/organization-join-requests', [
            'organization_slug' => $organization['slug'],
            'employee_id' => 'EMP-NEW',
        ], $this->auth('applicant-token'))
            ->assertConflict()
            ->assertJsonPath('error.code', 'already_a_member');
    }

    public function test_rejected_request_does_not_grant_membership_and_can_be_resubmitted(): void
    {
        $organization = $this->createOrganization();
        $this->postJson('/api/v1/organization-join-requests', [
            'organization_slug' => $organization['slug'],
            'employee_id' => 'EMP-NEW',
        ], $this->auth('applicant-token'))->assertCreated();
        $request = $this->getJson(
            "/api/v1/organizations/{$organization['id']}/join-requests",
            $this->auth('owner-token'),
        )->json('data.0');

        $this->postJson(
            "/api/v1/organizations/{$organization['id']}/join-requests/{$request['id']}/reject",
            [],
            $this->auth('owner-token'),
        )->assertOk()->assertJsonPath('data.status', 'rejected');

        $this->assertDatabaseMissing('organization_memberships', [
            'organization_id' => $organization['id'],
            'user_id' => $this->userId('applicant@example.com'),
        ]);

        $this->postJson('/api/v1/organization-join-requests', [
            'organization_slug' => $organization['slug'],
            'employee_id' => 'EMP-UPDATED',
        ], $this->auth('applicant-token'))
            ->assertOk()
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.employee_id', 'EMP-UPDATED');
    }

    public function test_non_admin_cannot_review_an_organization_request(): void
    {
        $organization = $this->createOrganization();
        $this->postJson('/api/v1/organization-join-requests', [
            'organization_slug' => $organization['slug'],
            'employee_id' => 'EMP-NEW',
        ], $this->auth('applicant-token'))->assertCreated();
        $request = $this->getJson(
            "/api/v1/organizations/{$organization['id']}/join-requests",
            $this->auth('owner-token'),
        )->json('data.0');

        $this->getJson(
            "/api/v1/organizations/{$organization['id']}/join-requests",
            $this->auth('outsider-token'),
        )->assertForbidden();

        $this->postJson(
            "/api/v1/organizations/{$organization['id']}/join-requests/{$request['id']}/approve",
            ['role' => 'admin'],
            $this->auth('outsider-token'),
        )->assertForbidden();

        $this->assertDatabaseMissing('organization_memberships', [
            'organization_id' => $organization['id'],
            'user_id' => $this->userId('applicant@example.com'),
        ]);
    }

    public function test_applicant_cannot_choose_an_admin_role_before_review(): void
    {
        $organization = $this->createOrganization();

        $this->postJson('/api/v1/organization-join-requests', [
            'organization_slug' => $organization['slug'],
            'employee_id' => 'EMP-NEW',
            'role' => 'admin',
        ], $this->auth('applicant-token'))
            ->assertCreated()
            ->assertJsonPath('data.status', 'pending');

        $this->assertDatabaseMissing('organization_memberships', [
            'organization_id' => $organization['id'],
            'user_id' => $this->userId('applicant@example.com'),
        ]);
    }

    private function createOrganization(): array
    {
        $this->getJson('/api/v1/me', $this->auth('owner-token'))->assertOk();

        return $this->postJson('/api/v1/organizations', [
            'name' => 'Radiology',
            'slug' => 'radiology',
            'employee_id' => 'EMP-OWNER',
        ], $this->auth('owner-token'))->assertCreated()->json('data');
    }

    private function userId(string $email): int
    {
        return (int) DB::table('users')
            ->where('email', $email)
            ->value('id');
    }

    private function auth(string $token): array
    {
        return ['Authorization' => 'Bearer '.$token];
    }
}
