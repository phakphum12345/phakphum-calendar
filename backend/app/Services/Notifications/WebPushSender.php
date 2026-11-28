<?php

namespace App\Services\Notifications;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Http;
use Throwable;

final class WebPushSender implements WebPushTransport
{
    private readonly WebPushPayloadEncryptor $encryptor;
    private readonly VapidTokenGenerator $vapid;

    private const ALLOWED_HOSTS = [
        'fcm.googleapis.com',
        'push.services.mozilla.com',
        'web.push.apple.com',
    ];

    public function __construct(
        WebPushPayloadEncryptor $encryptor,
        VapidTokenGenerator $vapid,
    )
    {
        $this->encryptor = $encryptor;
        $this->vapid = $vapid;
    }

    public function send(object $subscription, array $payload): array
    {
        try {
            $endpoint = Crypt::decryptString((string) $subscription->endpoint_encrypted);
            $authSecret = Crypt::decryptString((string) $subscription->auth_token_encrypted);
            $this->assertAllowedEndpoint($endpoint);
            $encrypted = $this->encryptor->encrypt(
                json_encode($payload, JSON_THROW_ON_ERROR),
                (string) $subscription->p256dh_key,
                $authSecret,
            );
            $publicKey = trim((string) config('services.web_push.vapid_public_key'));
            $token = $this->vapid->generate($endpoint);

            $response = Http::withOptions([
                'allow_redirects' => false,
            ])->withHeaders([
                'Authorization' => 'vapid t='.$token.', k='.$publicKey,
                'Content-Encoding' => 'aes128gcm',
                'Content-Type' => 'application/octet-stream',
                'TTL' => '86400',
                'Urgency' => 'normal',
            ])->timeout(15)->withBody(
                $encrypted['body'],
                'application/octet-stream',
            )->post($endpoint);

            $status = $response->status();
            if ($status >= 200 && $status < 300) {
                return ['status' => 'sent', 'error_code' => null];
            }
            if (in_array($status, [404, 410], true)) {
                return ['status' => 'expired', 'error_code' => 'subscription_expired'];
            }
            if ($status === 408 || $status === 425 || $status === 429 || $status >= 500) {
                return ['status' => 'retryable', 'error_code' => 'push_provider_temporary_failure'];
            }

            return ['status' => 'permanent', 'error_code' => 'push_provider_rejected_request'];
        } catch (ConnectionException) {
            return ['status' => 'retryable', 'error_code' => 'push_provider_unreachable'];
        } catch (WebPushConfigurationException) {
            return ['status' => 'retryable', 'error_code' => 'push_configuration_unavailable'];
        } catch (Throwable) {
            // Never persist provider endpoints, payloads, tokens or exception text.
            return ['status' => 'permanent', 'error_code' => 'push_payload_or_configuration_invalid'];
        }
    }

    private function assertAllowedEndpoint(string $endpoint): void
    {
        $parts = parse_url($endpoint);
        $host = strtolower((string) ($parts['host'] ?? ''));
        $allowed = in_array($host, self::ALLOWED_HOSTS, true)
            || str_ends_with($host, '.push.services.mozilla.com')
            || str_ends_with($host, '.notify.windows.com');

        if (
            ($parts['scheme'] ?? null) !== 'https'
            || $host === ''
            || isset($parts['user'])
            || isset($parts['pass'])
            || (isset($parts['port']) && (int) $parts['port'] !== 443)
            || filter_var($host, FILTER_VALIDATE_IP) !== false
            || $allowed === false
        ) {
            throw new \RuntimeException('Unsupported Web Push endpoint.');
        }
    }
}
