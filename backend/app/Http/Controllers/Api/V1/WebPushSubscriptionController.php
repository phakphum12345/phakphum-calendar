<?php

namespace App\Http\Controllers\Api\V1;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class WebPushSubscriptionController
{
    private const ALLOWED_HOSTS = [
        'fcm.googleapis.com',
        'push.services.mozilla.com',
        'web.push.apple.com',
    ];

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'endpoint' => ['required', 'string', 'max:4096', 'url'],
            'keys' => ['required', 'array:p256dh,auth'],
            'keys.p256dh' => ['required', 'string', 'max:128', 'regex:/^[A-Za-z0-9_-]+$/'],
            'keys.auth' => ['required', 'string', 'max:128', 'regex:/^[A-Za-z0-9_-]+$/'],
            'contentEncoding' => ['sometimes', 'string', 'in:aes128gcm'],
        ]);

        $endpoint = $validated['endpoint'];
        $this->assertAllowedEndpoint($endpoint);
        $this->assertValidSubscriptionKeys(
            $validated['keys']['p256dh'],
            $validated['keys']['auth'],
        );

        $endpointHash = hash('sha256', $endpoint);
        $now = now();
        $createdAt = DB::table('web_push_subscriptions')
            ->where('endpoint_hash', $endpointHash)
            ->value('created_at') ?? $now;

        DB::table('web_push_subscriptions')->updateOrInsert(
            ['endpoint_hash' => $endpointHash],
            [
                'user_id' => $request->user()->id,
                'endpoint_encrypted' => Crypt::encryptString($endpoint),
                'p256dh_key' => $validated['keys']['p256dh'],
                'auth_token_encrypted' => Crypt::encryptString($validated['keys']['auth']),
                'content_encoding' => $validated['contentEncoding'] ?? 'aes128gcm',
                'user_agent' => mb_substr((string) $request->userAgent(), 0, 512),
                'updated_at' => $now,
                'created_at' => $createdAt,
            ],
        );

        return response()->json([
            'status' => 'subscribed',
        ], 201);
    }

    public function destroy(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'endpoint' => ['required', 'string', 'max:4096', 'url'],
        ]);

        $endpoint = $validated['endpoint'];
        $this->assertAllowedEndpoint($endpoint);

        DB::table('web_push_subscriptions')
            ->where('user_id', $request->user()->id)
            ->where('endpoint_hash', hash('sha256', $endpoint))
            ->delete();

        return response()->json([
            'status' => 'unsubscribed',
        ]);
    }

    private function assertValidSubscriptionKeys(string $publicKey, string $authToken): void
    {
        $decodedPublicKey = $this->decodeBase64Url($publicKey);
        $decodedAuthToken = $this->decodeBase64Url($authToken);

        if (
            $decodedPublicKey === false
            || strlen($decodedPublicKey) !== 65
            || $decodedPublicKey[0] !== "\x04"
            || $decodedAuthToken === false
            || strlen($decodedAuthToken) !== 16
        ) {
            throw ValidationException::withMessages([
                'keys' => ['The browser push subscription keys are invalid.'],
            ]);
        }
    }

    private function decodeBase64Url(string $value): string|false
    {
        $base64 = strtr($value, '-_', '+/');
        $base64 .= str_repeat('=', (4 - strlen($base64) % 4) % 4);

        return base64_decode($base64, true);
    }

    private function assertAllowedEndpoint(string $endpoint): void
    {
        $parts = parse_url($endpoint);
        $host = strtolower((string) ($parts['host'] ?? ''));

        $isAllowedHost = in_array($host, self::ALLOWED_HOSTS, true)
            || str_ends_with($host, '.push.services.mozilla.com')
            || str_ends_with($host, '.notify.windows.com');

        if (
            ($parts['scheme'] ?? null) !== 'https'
            || $host === ''
            || isset($parts['user'])
            || isset($parts['pass'])
            || (isset($parts['port']) && $parts['port'] !== 443)
            || filter_var($host, FILTER_VALIDATE_IP) !== false
            || ! $isAllowedHost
        ) {
            throw ValidationException::withMessages([
                'endpoint' => ['The push endpoint is not supported.'],
            ]);
        }
    }
}
