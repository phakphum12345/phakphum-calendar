<?php

namespace App\Services\Notifications;

interface WebPushTransport
{
    /**
     * @param object $subscription
     * @param array<string, mixed> $payload
     * @return array{status: 'sent'|'expired'|'retryable'|'permanent', error_code: ?string}
     */
    public function send(object $subscription, array $payload): array;
}
