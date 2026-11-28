<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notification_deliveries', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->foreignId('outbox_id')->constrained('notification_outbox')->cascadeOnDelete();
            $table->foreignId('subscription_id')->constrained('web_push_subscriptions')->cascadeOnDelete();
            $table->string('status', 16)->default('pending')->index();
            $table->unsignedInteger('attempts')->default(0);
            $table->timestamp('claimed_at')->nullable();
            $table->uuid('claim_token')->nullable()->index();
            $table->timestamp('sent_at')->nullable();
            $table->timestamp('expired_at')->nullable();
            $table->text('last_error')->nullable();
            $table->timestamps();

            $table->unique(
                ['outbox_id', 'subscription_id'],
                'notification_deliveries_outbox_subscription_unique',
            );
            $table->index(['outbox_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_deliveries');
    }
};