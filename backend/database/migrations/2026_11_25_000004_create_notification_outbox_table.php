<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notification_outbox', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->string('notification_type', 96);
            $table->string('idempotency_key', 128);
            $table->json('payload');
            $table->string('status', 16)->default('pending')->index();
            $table->unsignedInteger('attempts')->default(0);
            $table->timestamp('available_at')->index();
            $table->timestamp('claimed_at')->nullable();
            $table->uuid('claim_token')->nullable()->index();
            $table->timestamp('sent_at')->nullable();
            $table->timestamp('dead_lettered_at')->nullable();
            $table->text('last_error')->nullable();
            $table->timestamps();

            $table->unique(
                ['user_id', 'idempotency_key'],
                'notification_outbox_idempotency_unique',
            );
            $table->index(['status', 'available_at', 'id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_outbox');
    }
};
