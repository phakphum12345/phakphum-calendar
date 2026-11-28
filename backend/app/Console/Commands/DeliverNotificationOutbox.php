<?php

namespace App\Console\Commands;

use App\Services\Notifications\NotificationOutboxWorker;
use Illuminate\Console\Command;

final class DeliverNotificationOutbox extends Command
{
    protected $signature = 'notifications:deliver {--limit=50}';

    protected $description = 'Deliver pending notifications to registered Web Push subscriptions';

    public function handle(NotificationOutboxWorker $worker): int
    {
        $stats = $worker->deliverBatch((int) $this->option('limit'));
        foreach ($stats as $name => $count) {
            $this->line($name.': '.$count);
        }

        return self::SUCCESS;
    }
}