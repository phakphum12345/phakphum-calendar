<?php
namespace App\Services\Notifications;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
class NotificationOutboxService {
 /** @return array{id:int, created:bool, status:string} */
 public function enqueue(int $userId, string $type, string $idempotencyKey, array $payload, ?\DateTimeInterface $availableAt = null): array {
  if ($type === '' || strlen($type) > 96 || $idempotencyKey === '' || strlen($idempotencyKey) > 128) {
   throw new \InvalidArgumentException('Notification type and idempotency key must be non-empty and within their limits.');
  }
  $encodedPayload = json_encode($payload, JSON_THROW_ON_ERROR);
  $now = now();
  $scheduledAt = $availableAt ?? $now;
  return DB::transaction(function () use ($userId, $type, $idempotencyKey, $encodedPayload, $now, $scheduledAt): array {
   $existing = DB::table('notification_outbox')->where('user_id', $userId)->where('idempotency_key', $idempotencyKey)->lockForUpdate()->first();
   if ($existing !== null) {
    $existingPayload = json_encode(json_decode($existing->payload, true, 512, JSON_THROW_ON_ERROR), JSON_THROW_ON_ERROR);
    if ($existing->notification_type !== $type || $existingPayload !== $encodedPayload) {
     throw new ConflictHttpException('Notification idempotency key was already used for different content.');
    }
    return ['id' => (int) $existing->id, 'created' => false, 'status' => $existing->status];
   }
   $id = DB::table('notification_outbox')->insertGetId([
    'user_id' => $userId, 'notification_type' => $type, 'idempotency_key' => $idempotencyKey,
    'payload' => $encodedPayload, 'status' => 'pending', 'attempts' => 0, 'available_at' => $scheduledAt,
    'created_at' => $now, 'updated_at' => $now,
   ]);
   return ['id' => $id, 'created' => true, 'status' => 'pending'];
  });
 }
}
