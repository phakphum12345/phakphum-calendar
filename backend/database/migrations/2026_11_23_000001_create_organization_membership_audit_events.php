<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('organization_membership_audit_events', function (Blueprint $table): void {
            $table->id();
            $table->foreignUuid('organization_id')
                ->constrained('organizations')
                ->restrictOnDelete();
            $table->foreignId('actor_user_id')
                ->constrained('users')
                ->restrictOnDelete();
            $table->foreignId('subject_user_id')
                ->constrained('users')
                ->restrictOnDelete();
            $table->string('action', 32);
            $table->json('before_state')->nullable();
            $table->json('after_state')->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->index(['organization_id', 'id']);
            $table->index(['subject_user_id', 'id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('organization_membership_audit_events');
    }
};
