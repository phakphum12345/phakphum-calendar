<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shift_transaction_sync_attempts', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('transaction_id')->constrained('shift_transactions')->restrictOnDelete();
            $table->unsignedSmallInteger('attempt_number');
            $table->string('status', 16);
            $table->foreignId('initiated_by_user_id')->constrained('users')->restrictOnDelete();
            $table->text('failure_reason')->nullable();
            $table->timestamp('started_at');
            $table->timestamp('finished_at')->nullable();
            $table->timestamps();
            $table->unique(['transaction_id', 'attempt_number'], 'shift_tx_sync_attempt_number_unique');
            $table->index(['transaction_id', 'status']);
        });

        Schema::create('shift_transaction_calendar_events', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->foreignUuid('transaction_id')->constrained('shift_transactions')->restrictOnDelete();
            $table->string('transfer_key', 64);
            $table->string('provider', 32)->default('legacy');
            $table->string('calendar_id', 512)->nullable();
            $table->string('event_id', 512);
            $table->string('etag', 512)->nullable();
            $table->timestamp('synced_at');
            $table->timestamps();
            $table->unique(['transaction_id', 'transfer_key'], 'shift_tx_calendar_transfer_unique');
            $table->index(['provider', 'calendar_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shift_transaction_calendar_events');
        Schema::dropIfExists('shift_transaction_sync_attempts');
    }
};
