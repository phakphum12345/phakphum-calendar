<?php

namespace Tests\Feature;

use App\Services\Notifications\NotificationOutboxService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Tests\TestCase;

class NotificationOutboxServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_enqueue_persists_pending_intent_without_sending_it(): void
    {
        $userId = $this->createUser('outbox@example.com');

        $result = app(NotificationOutboxService::class)->enqueue(
            $userId,
            'shift.transaction.approved',
            'tx-1:approved:user-'.$userId,
            ['transaction_id' => 'tx-1', 'event' => 'approved'],
        );

        $this->assertTrue($result['created']);
        $this->assertSame('pending', $result['status']);
        $this->assertDatabaseHas('notification_outbox', [
            'id' => $result['id'],
            'user_id' => $userId,
            'notification_type' => 'shift.transaction.approved',
            'status' => 'pending',
            'attempts' => 0,
            'sent_at' => null,
        ]);
    }

    public function test_repeated_enqueue_with_same_content_is_idempotent(): void
    {
        $userId = $this->createUser('outbox-idempotent@example.com');
        $service = app(NotificationOutboxService::class);
        $payload = ['transaction_id' => 'tx-2', 'event' => 'approved'];

        $first = $service->enqueue(
            $userId,
            'shift.transaction.approved',
            'tx-2:approved',
            $payload,
        );
        $second = $service->enqueue(
            $userId,
            'shift.transaction.approved',
            'tx-2:approved',
            $payload,
        );

        $this->assertTrue($first['created']);
        $this->assertFalse($second['created']);
        $this->assertSame($first['id'], $second['id']);
        $this->assertDatabaseCount('notification_outbox', 1);
    }

    public function test_idempotency_key_is_scoped_to_the_user(): void
    {
        $alice = $this->createUser('outbox-alice@example.com');
        $bob = $this->createUser('outbox-bob@example.com');
        $service = app(NotificationOutboxService::class);

        $aliceResult = $service->enqueue(
            $alice,
            'shift.transaction.approved',
            'same-key',
            ['transaction_id' => 'tx-alice'],
        );
        $bobResult = $service->enqueue(
            $bob,
            'shift.transaction.approved',
            'same-key',
            ['transaction_id' => 'tx-bob'],
        );

        $this->assertTrue($aliceResult['created']);
        $this->assertTrue($bobResult['created']);
        $this->assertNotSame($aliceResult['id'], $bobResult['id']);
        $this->assertDatabaseCount('notification_outbox', 2);
    }

    public function test_associative_payload_key_order_does_not_change_idempotency(): void
    {
        $userId = $this->createUser('outbox-canonical@example.com');
        $service = app(NotificationOutboxService::class);

        $first = $service->enqueue(
            $userId,
            'shift.transaction.approved',
            'canonical-key',
            ['transaction_id' => 'tx-4', 'metadata' => ['z' => 2, 'a' => 1]],
        );
        $second = $service->enqueue(
            $userId,
            'shift.transaction.approved',
            'canonical-key',
            ['metadata' => ['a' => 1, 'z' => 2], 'transaction_id' => 'tx-4'],
        );

        $this->assertTrue($first['created']);
        $this->assertFalse($second['created']);
        $this->assertSame($first['id'], $second['id']);
        $this->assertDatabaseCount('notification_outbox', 1);
    }

    public function test_reusing_idempotency_key_for_same_type_and_different_payload_conflicts(): void
    {
        $userId = $this->createUser('outbox-payload-conflict@example.com');
        $service = app(NotificationOutboxService::class);

        $service->enqueue(
            $userId,
            'shift.transaction.approved',
            'tx-5:approved',
            ['transaction_id' => 'tx-5', 'recipient_id' => 'recipient-a'],
        );

        $this->expectException(ConflictHttpException::class);

        $service->enqueue(
            $userId,
            'shift.transaction.approved',
            'tx-5:approved',
            ['transaction_id' => 'tx-5', 'recipient_id' => 'recipient-b'],
        );
    }

    public function test_reusing_idempotency_key_for_different_content_conflicts(): void
    {
        $userId = $this->createUser('outbox-conflict@example.com');
        $service = app(NotificationOutboxService::class);

        $service->enqueue(
            $userId,
            'shift.transaction.approved',
            'tx-3:approved',
            ['transaction_id' => 'tx-3'],
        );

        $this->expectException(ConflictHttpException::class);

        $service->enqueue(
            $userId,
            'shift.transaction.rejected',
            'tx-3:approved',
            ['transaction_id' => 'tx-3'],
        );
    }

    private function createUser(string $email): int
    {
        return DB::table('users')->insertGetId([
            'name' => 'Outbox Test',
            'email' => $email,
            'email_verified_at' => now(),
            'password' => bcrypt('not-a-real-login'),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}