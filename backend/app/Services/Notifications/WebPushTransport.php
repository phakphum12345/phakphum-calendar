<?php

namespace App\Services\Notifications;

interface WebPushTransport
{
    public function send(object $subscription, array $payload): array;
}