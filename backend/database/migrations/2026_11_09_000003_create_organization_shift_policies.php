<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('organization_shift_policies', function (Blueprint $table): void {
            $table->id();
            $table->foreignUuid('organization_id')->constrained('organizations')->cascadeOnDelete();
            $table->string('workflow_type', 32);
            $table->boolean('requires_approval')->default(true);
            $table->timestamps();
            $table->unique(['organization_id', 'workflow_type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('organization_shift_policies');
    }
};
