<?php

namespace Tests\Feature;

use App\Services\Notifications\NotificationOutboxService;
use App\Services\Notifications\NotificationOutboxWorker;
use App\Services\Notifications\WebPushTransport;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class NotificationOutboxWorkerTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        config([
            'app.key' => 'base64:'.base64_encode(str_repeat('a', 32)),
        ]);
    }

    use RefreshDatabase;

    public function test_worker_delivers_pending_intent_and_records_per_device_success(): void
    {
        $userId = $this->createUser();
        $subscriptionId = $this->createSubscription($userId, 'device-one');
        $outbox = $this->enqueue($userId);
        $transport = new FakeWebPushTransport([
            ['status' => 'sent', 'error_code' => null],
        ]);

        $stats = (new NotificationOutboxWorker($transport))->deliverBatch();

        $this->assertSame(1, $stats['claimed']);
        $this->assertSame(1, $stats['sent']);
        $this->assertDatabaseHas('notification_outbox', [
            'id' => $outbox['id'],
            'status' => 'sent',
            'claim_token' => null,
        ]);
        $this->assertNotNull(
            DB::table('notification_outbox')->where('id', $outbox['id'])->value('sent_at'),
        );
        $this->assertDatabaseHas('notification_deliveries', [
            'outbox_id' => $outbox['id'],
            'subscription_id' => $subscriptionId,
            'status' => 'sent',
            'attempts' => 1,
        ]);
        $this->assertCount(1, $transport->calls);
    }

    public function test_retry_does_not_resend_to_a_device_that_already_received_the_notification(): void
    {
        $userId = $this->createUser();
        $firstSubscription = $this->createSubscription($userId, 'device-one');
        $secondSubscription = $this->createSubscription($userId, 'device-two');
        $outbox = $this->enqueue($userId);
        $transport = new FakeWebPushTransport([
            ['status' => 'sent', 'error_code' => null],
            ['status' => 'retryable', 'error_code' => 'push_provider_unreachable'],
            ['status' => 'sent', 'error_code' => null],
        ]);
        $worker = new NotificationOutboxWorker($transport);

        $first = $worker->deliverBatch();
        $this->assertSame(1, $first['retried']);
        $this->assertDatabaseHas('notification_deliveries', [
            'outbox_id' => $outbox['id'],
            'subscription_id' => $firstSubscription,
            'status' => 'sent',
        ]);
        $this->assertDatabaseHas('notification_deliveries', [
            'outbox_id' => $outbox['id'],
            'subscription_id' => $secondSubscription,
            'status' => 'pending',
        ]);

        $this->travel(31)->seconds();
        $second = $worker->deliverBatch();

        $this->assertSame(1, $second['sent']);
        $this->assertCount(3, $transport->calls);
        $this->assertSame(
            [
                hash('sha256', 'https://fcm.googleapis.com/fcm/send/device-one'),
                hash('sha256', 'https://fcm.googleapis.com/fcm/send/device-two'),
                hash('sha256', 'https://fcm.googleapis.com/fcm/send/device-two'),
            ],
            $transport->calls,
        );
        $this->assertDatabaseHas('notification_outbox', [
            'id' => $outbox['id'],
            'status' => 'sent',
        ]);
    }

    public function test_expired_subscription_is_deactivated_and_delivery_is_recorded(): void
    {
        $userId = $this->createUser();
        $subscriptionId = $this->createSubscription($userId, 'expired-device');
        $outbox = $this->enqueue($userId);
        $transport = new FakeWebPushTransport([
            ['status' => 'expired', 'error_code' => 'subscription_expired'],
        ]);

        $stats = (new NotificationOutboxWorker($transport))->deliverBatch();

        $this->assertSame(1, $stats['no_subscriptions']);
        $this->assertDatabaseHas('web_push_subscriptions', [
            'id' => $subscriptionId,
        ]);
        $this->assertNotNull(
            DB::table('web_push_subscriptions')->where('id', $subscriptionId)->value('expired_at'),
        );
        $this->assertDatabaseHas('notification_deliveries', [
            'outbox_id' => $outbox['id'],
            'subscription_id' => $subscriptionId,
            'status' => 'expired',
        ]);
        $this->assertDatabaseHas('notification_outbox', [
            'id' => $outbox['id'],
            'status' => 'no_subscriptions',
        ]);
    }

    public function test_outbox_without_registered_devices_is_not_reported_as_sent(): void
    {
        $userId = $this->createUser();
        $outbox = $this->enqueue($userId);
        $transport = new FakeWebPushTransport([]);

        $stats = (new NotificationOutboxWorker($transport))->deliverBatch();

        $this->assertSame(1, $stats['no_subscriptions']);
        $this->assertSame([], $transport->calls);
        $this->assertDatabaseHas('notification_outbox', [
            'id' => $outbox['id'],
            'status' => 'no_subscriptions',
            'sent_at' => null,
            'last_error' => 'no_active_subscription',
        ]);
    }

    public function test_attempt_limit_moves_retryable_delivery_to_dead_letter(): void
    {
        config(['services.web_push.max_attempts' => 1]);
        $userId = $this->createUser();
        $subscriptionId = $this->createSubscription($userId, 'unreachable-device');
        $outbox = $this->enqueue($userId);
        $transport = new FakeWebPushTransport([
            ['status' => 'retryable', 'error_code' => 'push_provider_unreachable'],
        ]);

        $stats = (new NotificationOutboxWorker($transport))->deliverBatch();

        $this->assertSame(1, $stats['dead_lettered']);
        $this->assertDatabaseHas('notification_outbox', [
            'id' => $outbox['id'],
            'status' => 'dead_letter',
            'last_error' => 'delivery_attempt_limit_reached',
        ]);
        $this->assertDatabaseHas('notification_deliveries', [
            'outbox_id' => $outbox['id'],
            'subscription_id' => $subscriptionId,
            'status' => 'failed',
        ]);
    }

    public function test_stale_outbox_claim_is_recovered_after_worker_restart(): void
    {
        $userId = $this->createUser();
        $subscriptionId = $this->createSubscription($userId, 'recovered-device');
        $now = now();
        $outboxId = DB::table('notification_outbox')->insertGetId([
            'user_id' => $userId,
            'notification_type' => 'shift.transaction.approved',
            'idempotency_key' => 'recovery-key',
            'payload' => json_encode(['title' => 'Recovered'], JSON_THROW_ON_ERROR),
            'status' => 'processing',
            'attempts' => 1,
            'available_at' => $now->copy()->subMinutes(10),
            'claimed_at' => $now->copy()->subMinutes(6),
            'claim_token' => (string) Str::uuid(),
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $transport = new FakeWebPushTransport([
            ['status' => 'sent', 'error_code' => null],
        ]);

        $stats = (new NotificationOutboxWorker($transport))->deliverBatch();

        $this->assertSame(1, $stats['sent']);
        $this->assertDatabaseHas('notification_outbox', [
            'id' => $outboxId,
            'status' => 'sent',
            'attempts' => 2,
        ]);
        $this->assertDatabaseHas('notification_deliveries', [
            'outbox_id' => $outboxId,
            'subscription_id' => $subscriptionId,
            'status' => 'sent',
        ]);
    }

    private function createUser(): int
    {
        return DB::table('users')->insertGetId([
            'name' => 'Notification User',
            'email' => Str::uuid().'@example.test',
            'email_verified_at' => now(),
            'password' => bcrypt('not-a-real-login'),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function createSubscription(int $userId, string $endpointSuffix): int
    {
        $endpoint = 'https://fcm.googleapis.com/fcm/send/'.$endpointSuffix;

        return DB::table('web_push_subscriptions')->insertGetId([
            'user_id' => $userId,
            'endpoint_hash' => hash('sha256', $endpoint),
            'endpoint_encrypted' => Crypt::encryptString($endpoint),
            'p256dh_key' => 'test-public-key',
            'auth_token_encrypted' => Crypt::encryptString('test-auth-secret'),
            'content_encoding' => 'aes128gcm',
            'user_agent' => 'Test Browser',
            'last_used_at' => null,
            'expired_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function enqueue(int $userId): array
    {
        return app(NotificationOutboxService::class)->enqueue(
            $userId,
            'shift.transaction.approved',
            'notification-'.Str::uuid(),
            [
                'title' => 'Shift request approved',
                'body' => 'A participant approved the request.',
                'url' => '../',
            ],
        );
    }
}

final class FakeWebPushTransport implements WebPushTransport
{
    /** @var list<array{status: string, error_code: ?string}> */
    private array $results;

    /** @var list<string> */
    public array $calls = [];

    public function __construct(array $results)
    {
        $this->results = $results;
    }

    public function send(object $subscription, array $payload): array
    {
        $this->calls[] = (string) $subscription->endpoint_hash;

        return array_shift($this->results) ?? [
            'status' => 'sent',
            'error_code' => null,
        ];
    }
}

