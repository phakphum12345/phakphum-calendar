<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('schedule_records', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('owner_user_id')->constrained('users')->restrictOnDelete();
            $table->string('schedule_id', 128);
            $table->unsignedBigInteger('generation')->default(0);
            $table->string('state', 16)->default('live');
            $table->longText('schedule_payload')->nullable();
            $table->char('fingerprint', 64)->nullable();
            $table->timestamps();
            $table->unique(['owner_user_id', 'schedule_id'], 'schedule_owner_identity_unique');
            $table->index(['owner_user_id', 'state']);
        });

        Schema::create('schedule_import_journals', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('owner_user_id')->constrained('users')->restrictOnDelete();
            $table->string('schedule_id', 128);
            $table->uuid('import_run_id');
            $table->string('lifecycle', 16);
            $table->string('base_revision', 160);
            $table->char('source_fingerprint', 64);
            $table->char('accepted_schedule_fingerprint', 64)->nullable();
            $table->json('provenance');
            $table->longText('schedule_payload')->nullable();
            $table->timestamps();
            $table->unique(['owner_user_id', 'import_run_id', 'lifecycle'], 'schedule_import_run_lifecycle_unique');
            $table->index(['owner_user_id', 'schedule_id', 'created_at'], 'schedule_journal_lookup');
            $table->index(['owner_user_id', 'lifecycle']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('schedule_import_journals');
        Schema::dropIfExists('schedule_records');
    }
};
