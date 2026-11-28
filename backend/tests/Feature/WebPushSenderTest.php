<?php

namespace Tests\Feature;

use App\Services\Notifications\WebPushSender;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class WebPushSenderTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        config([
            'app.key' => 'base64:'.base64_encode(str_repeat('a', 32)),
        ]);
    }

    public function test_sender_posts_encrypted_payload_with_vapid_headers(): void
    {
        $subscription = $this->subscription();
        Http::fake([
            'https://fcm.googleapis.com/*' => Http::response('', 201),
        ]);

        $result = app(WebPushSender::class)->send($subscription, [
            'title' => 'Shift request approved',
            'body' => 'A participant approved the request.',
            'url' => '../',
        ]);

        $this->assertSame(['status' => 'sent', 'error_code' => null], $result);
        Http::assertSent(function ($request): bool {
            return str_starts_with($request->url(), 'https://fcm.googleapis.com/')
                && str_starts_with((string) $request->header('Authorization')[0], 'vapid t=')
                && $request->header('Content-Encoding') === ['aes128gcm']
                && $request->header('Content-Type') === ['application/octet-stream']
                && $request->body() !== '';
        });
    }

    public function test_expired_and_temporary_provider_responses_are_classified(): void
    {
        $subscription = $this->subscription();
        Http::fakeSequence()
            ->push('', 410)
            ->push('', 429);

        $sender = app(WebPushSender::class);
        $this->assertSame(
            ['status' => 'expired', 'error_code' => 'subscription_expired'],
            $sender->send($subscription, ['title' => 'Test']),
        );
        $this->assertSame(
            ['status' => 'retryable', 'error_code' => 'push_provider_temporary_failure'],
            $sender->send($subscription, ['title' => 'Test']),
        );
    }

    private function subscription(): object
    {
        $clientPrivateKey = openssl_pkey_new([
            'private_key_type' => OPENSSL_KEYTYPE_EC,
            'curve_name' => 'prime256v1',
        ]);
        $client = openssl_pkey_get_details($clientPrivateKey);
        $ec = $client['ec'];
        $publicKey = "\x04".$ec['x'].$ec['y'];
        $authSecret = random_bytes(16);

        $vapidPrivateKey = openssl_pkey_new([
            'private_key_type' => OPENSSL_KEYTYPE_EC,
            'curve_name' => 'prime256v1',
        ]);
        $vapid = openssl_pkey_get_details($vapidPrivateKey);
        $vapidEc = $vapid['ec'];
        $encode = static fn (string $value): string => rtrim(
            strtr(base64_encode($value), '+/', '-_'),
            '=',
        );
        config([
            'services.web_push.vapid_public_key' => $encode("\x04".$vapidEc['x'].$vapidEc['y']),
            'services.web_push.vapid_private_key' => $encode($vapidEc['d']),
            'services.web_push.vapid_subject' => 'mailto:push@example.test',
        ]);

        return (object) [
            'endpoint_encrypted' => Crypt::encryptString('https://fcm.googleapis.com/fcm/send/test-endpoint'),
            'auth_token_encrypted' => Crypt::encryptString($encode($authSecret)),
            'p256dh_key' => $encode($publicKey),
        ];
    }
}
