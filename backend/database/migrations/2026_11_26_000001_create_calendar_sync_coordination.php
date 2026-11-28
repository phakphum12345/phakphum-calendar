<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('calendar_sync_runs', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('owner_user_id')->constrained('users')->restrictOnDelete();
            $table->string('calendar_id', 512);
            $table->string('schedule_id', 128);
            $table->string('client_instance_id', 128);
            $table->string('status', 16)->default('running');
            $table->timestamp('started_at');
            $table->timestamp('heartbeat_at');
            $table->timestamp('finished_at')->nullable();
            $table->timestamps();
            $table->index(['owner_user_id', 'calendar_id', 'started_at']);
        });

        Schema::create('calendar_sync_leases', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->foreignId('owner_user_id')->constrained('users')->restrictOnDelete();
            $table->string('calendar_id', 512);
            $table->string('schedule_id', 128);
            $table->foreignUuid('run_id')->constrained('calendar_sync_runs')->restrictOnDelete();
            $table->string('client_instance_id', 128);
            $table->char('lease_token', 64);
            $table->timestamp('expires_at');
            $table->timestamp('heartbeat_at');
            $table->timestamps();
            $table->unique(['owner_user_id', 'calendar_id'], 'calendar_sync_lease_owner_calendar_unique');
            $table->unique('run_id');
            $table->index('expires_at');
        });

        Schema::create('calendar_sync_operations', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->foreignUuid('run_id')->constrained('calendar_sync_runs')->restrictOnDelete();
            $table->foreignId('owner_user_id')->constrained('users')->restrictOnDelete();
            $table->string('operation_key', 128);
            $table->string('operation_type', 16);
            $table->string('status', 16)->default('prepared');
            $table->char('payload_hash', 64);
            $table->text('payload_ciphertext');
            $table->unsignedSmallInteger('attempt_count')->default(0);
            $table->string('provider_event_id', 512)->nullable();
            $table->text('last_error')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('finished_at')->nullable();
            $table->timestamps();
            $table->unique(['run_id', 'operation_key'], 'calendar_sync_operation_run_key_unique');
            $table->index(['owner_user_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('calendar_sync_operations');
        Schema::dropIfExists('calendar_sync_leases');
        Schema::dropIfExists('calendar_sync_runs');
    }
};

