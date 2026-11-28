<?php

namespace App\Services\Notifications;

use RuntimeException;

final class WebPushConfigurationException extends RuntimeException
{
    public function __construct(string $message)
    {
        parent::__construct($message);
    }
}
