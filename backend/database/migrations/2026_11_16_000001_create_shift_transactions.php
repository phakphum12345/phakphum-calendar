<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shift_transactions', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('mode', 16);
            $table->string('type', 32);
            $table->foreignUuid('organization_id')->nullable()->constrained('organizations')->restrictOnDelete();
            $table->foreignId('created_by_user_id')->constrained('users')->restrictOnDelete();
            $table->string('status', 32)->index();
            $table->string('sync_status', 24)->default('not_started');
            $table->unsignedInteger('version')->default(1);
            $table->string('idempotency_key', 128);
            $table->char('request_hash', 64);
            $table->json('metadata')->nullable();
            $table->timestamps();
            $table->unique(['created_by_user_id', 'idempotency_key'], 'shift_tx_idempotency_unique');
            $table->index(['organization_id', 'created_at']);
            $table->index(['mode', 'created_at']);
        });

        Schema::create('shift_transaction_participants', function (Blueprint $table): void {
            $table->id();
            $table->foreignUuid('transaction_id')->constrained('shift_transactions')->restrictOnDelete();
            $table->foreignId('user_id')->constrained('users')->restrictOnDelete();
            $table->string('employee_id', 128);
            $table->string('role', 16);
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamps();
            $table->unique(['transaction_id', 'user_id']);
            $table->index(['user_id', 'confirmed_at']);
        });

        Schema::create('shift_transaction_transfers', function (Blueprint $table): void {
            $table->id();
            $table->foreignUuid('transaction_id')->constrained('shift_transactions')->restrictOnDelete();
            $table->string('transfer_key', 64);
            $table->string('shift_id', 128);
            $table->string('from_employee_id', 128);
            $table->string('to_employee_id', 128);
            $table->string('shift_code', 64);
            $table->timestamp('starts_at');
            $table->timestamp('ends_at');
            $table->string('purpose', 24);
            $table->timestamp('fulfilled_at')->nullable();
            $table->timestamps();
            $table->unique(['transaction_id', 'transfer_key']);
            $table->unique(['transaction_id', 'shift_id']);
            $table->index(['from_employee_id', 'starts_at']);
            $table->index(['to_employee_id', 'starts_at']);
        });

        Schema::create('shift_transaction_events', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->foreignUuid('transaction_id')->constrained('shift_transactions')->restrictOnDelete();
            $table->foreignUuid('organization_id')->nullable()->constrained('organizations')->restrictOnDelete();
            $table->foreignId('actor_user_id')->nullable()->constrained('users')->restrictOnDelete();
            $table->string('event_type', 48);
            $table->unsignedInteger('transaction_version');
            $table->json('event_data')->nullable();
            $table->timestamp('occurred_at');
            $table->index(['transaction_id', 'id']);
            $table->index(['organization_id', 'occurred_at']);
            $table->index(['actor_user_id', 'occurred_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shift_transaction_events');
        Schema::dropIfExists('shift_transaction_transfers');
        Schema::dropIfExists('shift_transaction_participants');
        Schema::dropIfExists('shift_transactions');
    }
};
