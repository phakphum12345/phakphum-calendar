<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shift_pay_calculation_snapshots', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained('users')->restrictOnDelete();
            $table->foreignUuid('organization_id')->nullable()->constrained('organizations')->restrictOnDelete();
            $table->string('idempotency_key', 128);
            $table->char('request_hash', 64);
            $table->string('mode', 16);
            $table->string('source', 16)->nullable();
            $table->string('engine_version', 24)->default('1.0.0');
            $table->unsignedInteger('personal_profile_version')->default(0);
            $table->unsignedInteger('organization_profile_version')->default(0);
            $table->json('input_snapshot');
            $table->json('rule_snapshot')->nullable();
            $table->json('result_snapshot');
            $table->timestamp('calculated_at');
            $table->unique(['user_id', 'idempotency_key'], 'shift_pay_snapshot_user_idempotency_unique');
            $table->index(['organization_id', 'calculated_at'], 'shift_pay_snapshot_org_calculated_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shift_pay_calculation_snapshots');
    }
};
