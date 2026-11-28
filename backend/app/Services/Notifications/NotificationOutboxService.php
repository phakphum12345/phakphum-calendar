<?php

namespace App\Services\Notifications;

use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class NotificationOutboxService
{
    /**
     * Persist an intent without delivering it.
     *
     * @return array{id: int, created: bool, status: string}
     */
    public function enqueue(
        int $userId,
        string $type,
        string $idempotencyKey,
        array $payload,
        ?\DateTimeInterface $availableAt = null,
    ): array {
        if (
            $type === ''
            || strlen($type) > 96
            || $idempotencyKey === ''
            || strlen($idempotencyKey) > 128
        ) {
            throw new \InvalidArgumentException(
                'Notification type and idempotency key must be non-empty and within their limits.',
            );
        }

        $encodedPayload = json_encode($this->canonicalize($payload), JSON_THROW_ON_ERROR);
        $now = now();

        return DB::transaction(function () use (
            $userId,
            $type,
            $idempotencyKey,
            $encodedPayload,
            $availableAt,
            $now,
        ): array {
            $inserted = DB::table('notification_outbox')->insertOrIgnore([
                'user_id' => $userId,
                'notification_type' => $type,
                'idempotency_key' => $idempotencyKey,
                'payload' => $encodedPayload,
                'status' => 'pending',
                'attempts' => 0,
                'available_at' => $availableAt ?? $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $record = DB::table('notification_outbox')
                ->where('user_id', $userId)
                ->where('idempotency_key', $idempotencyKey)
                ->lockForUpdate()
                ->first();

            if ($record === null) {
                throw new \RuntimeException('Notification outbox insert could not be read back.');
            }

            $storedPayload = json_encode(
                $this->canonicalize(json_decode($record->payload, true, 512, JSON_THROW_ON_ERROR)),
                JSON_THROW_ON_ERROR,
            );

            if (
                $record->notification_type !== $type
                || $storedPayload !== $encodedPayload
            ) {
                throw new ConflictHttpException(
                    'Notification idempotency key was already used for different content.',
                );
            }

            return [
                'id' => (int) $record->id,
                'created' => $inserted === 1,
                'status' => $record->status,
            ];
        });
    }

    private function canonicalize(array $value): array
    {
        foreach ($value as $key => $item) {
            if (is_array($item)) {
                $value[$key] = $this->canonicalize($item);
            }
        }

        if (! array_is_list($value)) {
            ksort($value);
        }

        return $value;
    }
}

