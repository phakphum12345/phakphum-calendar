<?php

namespace App\Services\Notifications;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Throwable;

final class NotificationOutboxWorker
{
    public function __construct(
        private readonly WebPushTransport $transport,
    ) {}

    /**
     * @return array{claimed: int, sent: int, retried: int, dead_lettered: int, no_subscriptions: int}
     */
    public function deliverBatch(int $limit = 50): array
    {
        $limit = max(1, min($limit, 250));
        $rows = $this->claimBatch($limit);
        $stats = [
            'claimed' => count($rows),
            'sent' => 0,
            'retried' => 0,
            'dead_lettered' => 0,
            'no_subscriptions' => 0,
        ];

        foreach ($rows as $row) {
            $outcome = $this->deliverOne($row);
            $stats[$outcome]++;
        }

        return $stats;
    }

    /** @return list<object> */
    private function claimBatch(int $limit): array
    {
        $now = now();
        $leaseExpiredAt = $now->copy()->subMinutes(5);
        $maxAttempts = max(1, (int) config('services.web_push.max_attempts', 8));
        $driver = DB::connection()->getDriverName();

        return DB::transaction(function () use (
            $now,
            $leaseExpiredAt,
            $maxAttempts,
            $driver,
            $limit,
        ): array {
            DB::table('notification_outbox')
                ->where('status', 'processing')
                ->where('claimed_at', '<=', $leaseExpiredAt)
                ->where('attempts', '>=', $maxAttempts)
                ->update([
                    'status' => 'dead_letter',
                    'claim_token' => null,
                    'claimed_at' => null,
                    'dead_lettered_at' => $now,
                    'last_error' => 'delivery_attempt_limit_reached',
                    'updated_at' => $now,
                ]);

            DB::table('notification_outbox')
                ->where('status', 'processing')
                ->where('claimed_at', '<=', $leaseExpiredAt)
                ->where('attempts', '<', $maxAttempts)
                ->update([
                    'status' => 'pending',
                    'claim_token' => null,
                    'claimed_at' => null,
                    'updated_at' => $now,
                ]);

            DB::table('notification_outbox')
                ->where('status', 'pending')
                ->where('attempts', '>=', $maxAttempts)
                ->update([
                    'status' => 'dead_letter',
                    'dead_lettered_at' => $now,
                    'last_error' => 'delivery_attempt_limit_reached',
                    'updated_at' => $now,
                ]);

            $query = DB::table('notification_outbox')
                ->where('status', 'pending')
                ->where('available_at', '<=', $now)
                ->where('attempts', '<', $maxAttempts)
                ->orderBy('id')
                ->limit($limit);
            if ($driver !== 'sqlite') {
                $query->lockForUpdate()->skipLocked();
            }

            $claimed = [];
            foreach ($query->get() as $row) {
                $claimToken = (string) Str::uuid();
                $updated = DB::table('notification_outbox')
                    ->where('id', $row->id)
                    ->where('status', 'pending')
                    ->update([
                        'status' => 'processing',
                        'claimed_at' => $now,
                        'claim_token' => $claimToken,
                        'attempts' => DB::raw('attempts + 1'),
                        'updated_at' => $now,
                    ]);
                if ($updated !== 1) {
                    continue;
                }

                $row->claim_token = $claimToken;
                $row->attempts = (int) $row->attempts + 1;
                $claimed[] = $row;
            }

            return $claimed;
        });
    }

    private function deliverOne(object $outbox): string
    {
        try {
            $subscriptions = DB::table('web_push_subscriptions')
                ->where('user_id', $outbox->user_id)
                ->whereNull('expired_at')
                ->orderBy('id')
                ->get();

            if ($subscriptions->isEmpty()) {
                $this->finishOutbox($outbox, 'no_subscriptions', 'no_active_subscription');

                return 'no_subscriptions';
            }

            $payload = $this->notificationPayload($outbox);
            $retryable = false;
            $permanent = false;

            foreach ($subscriptions as $subscription) {
                $delivery = $this->claimDelivery($outbox, $subscription);
                if ($delivery === null) {
                    $existing = DB::table('notification_deliveries')
                        ->where('outbox_id', $outbox->id)
                        ->where('subscription_id', $subscription->id)
                        ->value('status');
                    if (! in_array($existing, ['sent', 'expired', 'failed'], true)) {
                        $retryable = true;
                    }
                    if ($existing === 'failed') {
                        $permanent = true;
                    }
                    continue;
                }

                $result = $this->transport->send($subscription, $payload);
                $this->finishDelivery($delivery, $outbox, $result);
                if ($result['status'] === 'retryable') {
                    $retryable = true;
                } elseif ($result['status'] === 'permanent') {
                    $permanent = true;
                } elseif ($result['status'] === 'expired') {
                    DB::table('web_push_subscriptions')
                        ->where('id', $subscription->id)
                        ->where('user_id', $outbox->user_id)
                        ->update([
                            'expired_at' => now(),
                            'updated_at' => now(),
                        ]);
                }
            }

            $statuses = DB::table('notification_deliveries')
                ->where('outbox_id', $outbox->id)
                ->pluck('status')
                ->all();
            $sentCount = count(array_filter($statuses, static fn (string $status): bool => $status === 'sent'));
            $unresolved = count(array_filter(
                $statuses,
                static fn (string $status): bool => in_array($status, ['pending', 'processing'], true),
            ));
            $maxAttempts = max(1, (int) config('services.web_push.max_attempts', 8));

            if ($unresolved === 0 && $permanent) {
                $this->finishOutbox($outbox, 'dead_letter', 'push_delivery_permanent_failure');

                return 'dead_lettered';
            }
            if ($unresolved === 0 && $sentCount > 0) {
                $this->finishOutbox($outbox, 'sent', null);

                return 'sent';
            }
            if ($unresolved === 0 && $sentCount === 0) {
                $this->finishOutbox($outbox, 'no_subscriptions', 'no_active_subscription');

                return 'no_subscriptions';
            }
            if ((int) $outbox->attempts >= $maxAttempts) {
                $this->finishOutbox($outbox, 'dead_letter', 'delivery_attempt_limit_reached');

                return 'dead_lettered';
            }

            $this->retryOutbox($outbox, 'push_delivery_retryable_failure');

            return 'retried';
        } catch (Throwable) {
            if ((int) $outbox->attempts >= max(1, (int) config('services.web_push.max_attempts', 8))) {
                $this->finishOutbox($outbox, 'dead_letter', 'delivery_worker_exception');

                return 'dead_lettered';
            }
            $this->retryOutbox($outbox, 'delivery_worker_exception');

            return 'retried';
        }
    }

    private function claimDelivery(object $outbox, object $subscription): ?object
    {
        $now = now();
        $leaseExpiredAt = $now->copy()->subMinutes(5);

        return DB::transaction(function () use (
            $outbox,
            $subscription,
            $now,
            $leaseExpiredAt,
        ): ?object {
            DB::table('notification_deliveries')->insertOrIgnore([
                'outbox_id' => $outbox->id,
                'subscription_id' => $subscription->id,
                'status' => 'pending',
                'attempts' => 0,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $delivery = DB::table('notification_deliveries')
                ->where('outbox_id', $outbox->id)
                ->where('subscription_id', $subscription->id)
                ->lockForUpdate()
                ->first();
            if ($delivery === null || in_array($delivery->status, ['sent', 'expired', 'failed'], true)) {
                return null;
            }
            if (
                $delivery->status === 'processing'
                && $delivery->claimed_at !== null
                && $delivery->claimed_at > $leaseExpiredAt
            ) {
                return null;
            }

            $updated = DB::table('notification_deliveries')
                ->where('id', $delivery->id)
                ->whereIn('status', ['pending', 'processing'])
                ->update([
                    'status' => 'processing',
                    'claimed_at' => $now,
                    'claim_token' => $outbox->claim_token,
                    'attempts' => DB::raw('attempts + 1'),
                    'updated_at' => $now,
                ]);
            if ($updated !== 1) {
                return null;
            }

            $delivery->status = 'processing';
            $delivery->claimed_at = $now;
            $delivery->claim_token = $outbox->claim_token;
            $delivery->attempts = (int) $delivery->attempts + 1;

            return $delivery;
        });
    }

    private function finishDelivery(object $delivery, object $outbox, array $result): void
    {
        $now = now();
        $status = $result['status'];
        $errorCode = $result['error_code'] ?? null;
        $values = [
            'status' => $status === 'sent' ? 'sent'
                : ($status === 'expired' ? 'expired'
                    : ($status === 'permanent' ? 'failed' : 'pending')),
            'claim_token' => null,
            'claimed_at' => null,
            'last_error' => $errorCode,
            'sent_at' => $status === 'sent' ? $now : null,
            'expired_at' => $status === 'expired' ? $now : null,
            'updated_at' => $now,
        ];

        DB::table('notification_deliveries')
            ->where('id', $delivery->id)
            ->where('claim_token', $outbox->claim_token)
            ->update($values);
    }

    private function notificationPayload(object $outbox): array
    {
        $source = json_decode($outbox->payload, true, 512, JSON_THROW_ON_ERROR);
        $title = trim((string) ($source['title'] ?? 'Shift Tools'));
        $body = trim((string) ($source['body'] ?? 'Your shift schedule has an update.'));
        $url = trim((string) ($source['url'] ?? '../'));

        return [
            'title' => mb_substr($title !== '' ? $title : 'Shift Tools', 0, 120),
            'body' => mb_substr($body, 0, 512),
            'tag' => 'shift-'.substr(hash('sha256', (string) $outbox->idempotency_key), 0, 40),
            'url' => $url !== '' ? $url : '../',
        ];
    }

    private function finishOutbox(object $outbox, string $status, ?string $errorCode): void
    {
        $now = now();
        DB::table('notification_outbox')
            ->where('id', $outbox->id)
            ->where('claim_token', $outbox->claim_token)
            ->update([
                'status' => $status,
                'claim_token' => null,
                'claimed_at' => null,
                'sent_at' => $status === 'sent' ? $now : null,
                'dead_lettered_at' => $status === 'dead_letter' ? $now : null,
                'last_error' => $errorCode,
                'updated_at' => $now,
            ]);
    }

    private function retryOutbox(object $outbox, string $errorCode): void
    {
        $attempt = max(1, (int) $outbox->attempts);
        $delaySeconds = min(3600, 30 * (2 ** min(7, $attempt - 1)));
        $now = now();

        DB::table('notification_outbox')
            ->where('id', $outbox->id)
            ->where('claim_token', $outbox->claim_token)
            ->update([
                'status' => 'pending',
                'claim_token' => null,
                'claimed_at' => null,
                'available_at' => $now->copy()->addSeconds($delaySeconds),
                'last_error' => $errorCode,
                'updated_at' => $now,
            ]);
    }
}
