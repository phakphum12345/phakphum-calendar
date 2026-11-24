<?php

use Illuminate\\Database\\Migrations\\Migration;
use Illuminate\\Database\\Schema\\Blueprint;
use Illuminate\\Support\\Facades\\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_shift_pay_profiles', function (Blueprint $table): void {
            $table->foreignId('user_id')->primary()->constrained('users')->restrictOnDelete();
            $table->string('mode', 16)->default('personal');
            $table->foreignUuid('organization_id')->nullable()->constrained('organizations')->restrictOnDelete();
            $table->string('hybrid_priority', 24)->default('require_selection');
            $table->char('currency_code', 3)->default('THB');
            $table->unsignedTinyInteger('decimal_places')->default(2);
            $table->json('personal_rules')->nullable();
            $table->unsignedInteger('version')->default(1);
            $table->timestamps();
            $table->index(['organization_id', 'mode']);
        });

        Schema::create('organization_shift_pay_profiles', function (Blueprint $table): void {
            $table->id();
            $table->foreignUuid('organization_id')->unique()->constrained('organizations')->restrictOnDelete();
            $table->char('currency_code', 3)->default('THB');
            $table->unsignedTinyInteger('decimal_places')->default(2);
            $table->json('rules')->nullable();
            $table->unsignedInteger('version')->default(1);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('organization_shift_pay_profiles');
        Schema::dropIfExists('user_shift_pay_profiles');
    }
};
