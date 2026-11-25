<?php
namespace Tests\Feature;
use App\Services\Notifications\NotificationOutboxService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Tests\TestCase;
class NotificationOutboxServiceTest extends TestCase {
 use RefreshDatabase;
 private function createUser(string $email): int {
  return DB::table('users')->insertGetId(['name'=>'Outbox Test','email'=>$email,'email_verified_at'=>now(),'password'=>bcrypt('not-a-real-login'),'created_at'=>now(),'updated_at'=>now()]);
 }
 public function test_enqueue_persists_pending_intent_without_sending_it(): void {
  $userId=$this->createUser('outbox@example.com');
  $result=app(NotificationOutboxService::class)->enqueue($userId,'shift.transaction.approved','tx-1:approved:user-'.$userId,['transaction_id'=>'tx-1','event'=>'approved']);
  $this->assertTrue($result['created']); $this->assertSame('pending',$result['status']);
  $this->assertDatabaseHas('notification_outbox',['id'=>$result['id'],'user_id'=>$userId,'notification_type'=>'shift.transaction.approved','status'=>'pending','attempts'=>0,'sent_at'=>null]);
 }
 public function test_repeated_enqueue_with_same_content_is_idempotent(): void {
  $userId=$this->createUser('outbox-idempotent@example.com'); $service=app(NotificationOutboxService::class); $payload=['transaction_id'=>'tx-2','event'=>'approved'];
  $first=$service->enqueue($userId,'shift.transaction.approved','tx-2:approved',$payload); $second=$service->enqueue($userId,'shift.transaction.approved','tx-2:approved',$payload);
  $this->assertTrue($first['created']); $this->assertFalse($second['created']); $this->assertSame($first['id'],$second['id']); $this->assertDatabaseCount('notification_outbox',1);
 }
 public function test_reusing_idempotency_key_for_different_content_conflicts(): void {
  $userId=$this->createUser('outbox-conflict@example.com'); $service=app(NotificationOutboxService::class);
  $service->enqueue($userId,'shift.transaction.approved','tx-3:approved',['transaction_id'=>'tx-3']);
  $this->expectException(ConflictHttpException::class);
  $service->enqueue($userId,'shift.transaction.rejected','tx-3:approved',['transaction_id'=>'tx-3']);
 }
}
