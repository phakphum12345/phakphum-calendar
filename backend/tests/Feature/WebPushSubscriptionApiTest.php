<?php

namespace Tests\Feature;

use App\Contracts\GoogleIdentityTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Tests\Fakes\FakeGoogleIdentityTokenVerifier;
use Tests\TestCase;

class WebPushSubscriptionApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'app.key' => 'base64:'.base64_encode(str_repeat('a', 32)),
        ]);

        $this->app->instance(
            GoogleIdentityTokenVerifier::class,
            new FakeGoogleIdentityTokenVerifier([
                'owner-token' => [
                    'sub' => 'google-owner',
                    'email' => 'owner@example.com',
                    'email_verified' => true,
                    'name' => 'Owner',
                ],
                'other-token' => [
                    'sub' => 'google-other',
                    'email' => 'other@example.com',
                    'email_verified' => true,
                    'name' => 'Other',
                ],
            ]),
        );
    }

    public function test_authenticated_user_can_register_an_encrypted_web_push_subscription(): void
    {
        $this->getJson('/api/v1/me', $this->auth('owner-token'))->assertOk();

        $endpoint = 'https://fcm.googleapis.com/fcm/send/subscription-token';
        $response = $this->postJson('/api/v1/push-subscriptions', [
            'endpoint' => $endpoint,
            'keys' => [
                'p256dh' => rtrim(strtr(base64_encode("\x04".str_repeat("\x01", 64)), '+/', '-_'), '='),
                'auth' => rtrim(strtr(base64_encode(str_repeat("\x02", 16)), '+/', '-_'), '='),
            ],
            'contentEncoding' => 'aes128gcm',
        ], $this->auth('owner-token'));

        $response->assertCreated()->assertJsonPath('status', 'subscribed');
        $this->assertDatabaseCount('web_push_subscriptions', 1);

        $subscription = DB::table('web_push_subscriptions')->first();
        $this->assertSame(hash('sha256', $endpoint), $subscription->endpoint_hash);
        $this->assertSame($endpoint, Crypt::decryptString($subscription->endpoint_encrypted));
        $this->assertSame(
            rtrim(strtr(base64_encode(str_repeat("\x02", 16)), '+/', '-_'), '='),
            Crypt::decryptString($subscription->auth_token_encrypted),
        );
        $this->assertSame(rtrim(strtr(base64_encode("\x04".str_repeat("\x01", 64)), '+/', '-_'), '='), $subscription->p256dh_key);
        $this->assertSame('aes128gcm', $subscription->content_encoding);
    }

    public function test_registration_is_idempotent_for_the_same_browser_endpoint(): void
    {
        $this->getJson('/api/v1/me', $this->auth('owner-token'))->assertOk();
        $payload = [
            'endpoint' => 'https://fcm.googleapis.com/fcm/send/same-endpoint',
            'keys' => [
                'p256dh' => rtrim(strtr(base64_encode("\x04".str_repeat("\x01", 64)), '+/', '-_'), '='),
                'auth' => rtrim(strtr(base64_encode(str_repeat("\x02", 16)), '+/', '-_'), '='),
            ],
        ];

        $this->postJson('/api/v1/push-subscriptions', $payload, $this->auth('owner-token'))
            ->assertCreated();
        $this->postJson('/api/v1/push-subscriptions', $payload, $this->auth('owner-token'))
            ->assertCreated();

        $this->assertDatabaseCount('web_push_subscriptions', 1);
    }

    public function test_untrusted_or_insecure_push_endpoints_are_rejected(): void
    {
        $this->getJson('/api/v1/me', $this->auth('owner-token'))->assertOk();

        foreach ([
            'http://fcm.googleapis.com/fcm/send/token',
            'https://example.com/push/token',
            'https://127.0.0.1/push/token',
            'https://user:password@fcm.googleapis.com/fcm/send/token',
        ] as $endpoint) {
            $this->postJson('/api/v1/push-subscriptions', [
                'endpoint' => $endpoint,
                'keys' => [
                    'p256dh' => rtrim(strtr(base64_encode("\x04".str_repeat("\x01", 64)), '+/', '-_'), '='),
                    'auth' => rtrim(strtr(base64_encode(str_repeat("\x02", 16)), '+/', '-_'), '='),
                ],
            ], $this->auth('owner-token'))->assertUnprocessable();
        }

        $this->assertDatabaseCount('web_push_subscriptions', 0);
    }

    public function test_subscription_requires_google_authentication(): void
    {
        $this->postJson('/api/v1/push-subscriptions', [
            'endpoint' => 'https://fcm.googleapis.com/fcm/send/token',
            'keys' => [
                'p256dh' => rtrim(strtr(base64_encode("\x04".str_repeat("\x01", 64)), '+/', '-_'), '='),
                'auth' => rtrim(strtr(base64_encode(str_repeat("\x02", 16)), '+/', '-_'), '='),
            ],
        ])->assertUnauthorized();
    }

    public function test_user_can_only_remove_their_own_subscription(): void
    {
        $this->getJson('/api/v1/me', $this->auth('owner-token'))->assertOk();
        $this->getJson('/api/v1/me', $this->auth('other-token'))->assertOk();
        $endpoint = 'https://fcm.googleapis.com/fcm/send/owner-device';

        $this->postJson('/api/v1/push-subscriptions', [
            'endpoint' => $endpoint,
            'keys' => [
                'p256dh' => rtrim(strtr(base64_encode("\x04".str_repeat("\x01", 64)), '+/', '-_'), '='),
                'auth' => rtrim(strtr(base64_encode(str_repeat("\x02", 16)), '+/', '-_'), '='),
            ],
        ], $this->auth('owner-token'))->assertCreated();

        $this->deleteJson('/api/v1/push-subscriptions', [
            'endpoint' => $endpoint,
        ], $this->auth('other-token'))->assertOk();

        $this->assertDatabaseCount('web_push_subscriptions', 1);

        $this->deleteJson('/api/v1/push-subscriptions', [
            'endpoint' => $endpoint,
        ], $this->auth('owner-token'))->assertOk();

        $this->assertDatabaseCount('web_push_subscriptions', 0);
    }

    private function auth(string $token): array
    {
        return ['Authorization' => 'Bearer '.$token];
    }
}
