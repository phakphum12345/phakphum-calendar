<?php

namespace Tests\Feature;

use App\Contracts\GoogleIdentityTokenVerifier;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Fakes\FakeGoogleIdentityTokenVerifier;
use Tests\TestCase;

class GoogleAuthenticationTest extends TestCase
{
    use RefreshDatabase;

    public function test_google_identity_token_creates_a_verified_account(): void
    {
        $this->app->instance(
            GoogleIdentityTokenVerifier::class,
            new FakeGoogleIdentityTokenVerifier([
                'owner-token' => [
                    'sub' => 'google-subject-1',
                    'email' => 'owner@example.com',
                    'email_verified' => true,
                    'name' => 'Owner',
                ],
            ]),
        );

        $this->getJson('/api/v1/me', [
            'Authorization' => 'Bearer owner-token',
        ])
            ->assertOk()
            ->assertJsonPath('data.email', 'owner@example.com')
            ->assertJsonPath('data.name', 'Owner');

        $this->assertDatabaseHas('users', [
            'google_subject' => 'google-subject-1',
            'email' => 'owner@example.com',
        ]);
        $this->assertNotNull(
            User::query()->where('google_subject', 'google-subject-1')->firstOrFail()->email_verified_at,
        );
    }

    public function test_google_authentication_requires_a_bearer_token(): void
    {
        $this->getJson('/api/v1/me')->assertUnauthorized();
    }

    public function test_invalid_google_token_is_rejected(): void
    {
        $this->app->instance(
            GoogleIdentityTokenVerifier::class,
            new FakeGoogleIdentityTokenVerifier([]),
        );

        $this->getJson('/api/v1/me', [
            'Authorization' => 'Bearer invalid-token',
        ])->assertUnauthorized();
    }

    public function test_google_certificate_provider_outage_returns_service_unavailable(): void
    {
        $this->app->instance(
            GoogleIdentityTokenVerifier::class,
            new class implements GoogleIdentityTokenVerifier
            {
                public function verify(string $token): array
                {
                    throw new \RuntimeException('Google certificate endpoint unavailable.');
                }
            },
        );

        $this->getJson('/api/v1/me', [
            'Authorization' => 'Bearer owner-token',
        ])->assertServiceUnavailable()
            ->assertJsonPath('error.code', 'authentication_provider_unavailable');
    }

    public function test_google_sign_in_does_not_auto_link_an_existing_email_account(): void
    {
        User::query()->create([
            'name' => 'Existing account',
            'email' => 'owner@example.com',
            'password' => 'test-password',
        ]);

        $this->app->instance(
            GoogleIdentityTokenVerifier::class,
            new FakeGoogleIdentityTokenVerifier([
                'owner-token' => [
                    'sub' => 'new-google-subject',
                    'email' => 'owner@example.com',
                    'email_verified' => true,
                    'name' => 'Owner',
                ],
            ]),
        );

        $this->getJson('/api/v1/me', [
            'Authorization' => 'Bearer owner-token',
        ])->assertStatus(409)->assertJsonPath('error.code', 'account_link_required');

        $this->assertDatabaseHas('users', [
            'email' => 'owner@example.com',
            'google_subject' => null,
        ]);
    }
}
