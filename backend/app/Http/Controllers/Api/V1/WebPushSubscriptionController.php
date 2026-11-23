<?php

namespace App\Http\Controllers\Api\V1;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
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

        $endpointHash = hash('sha256', $endpoint);
        $now = now();

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
                'created_at' => $now,
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

    private function assertAllowedEndpoint(string $endpoint): void
    {
        $parts = parse_url($endpoint);
        $host = strtolower((string) ($parts['host'] ?? ''));

        $isAllowedHost = in_array($host, self::ALLOWED_HOSTS, true)
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
