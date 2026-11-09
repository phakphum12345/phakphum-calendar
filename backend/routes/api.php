<?php

use App\Http\Controllers\Api\V1\ClientErrorController;
use App\Http\Controllers\Api\V1\GoogleAccountController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\OrganizationController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/health', [HealthController::class, 'live'])
        ->name('api.v1.health');
    Route::get('/ready', [HealthController::class, 'ready'])
        ->name('api.v1.ready');
    Route::post('/diagnostics/client-errors', [ClientErrorController::class, 'store'])
        ->middleware('throttle:30,1')
        ->name('api.v1.diagnostics.client-errors');

    Route::middleware(['throttle:120,1', 'google.account'])->group(function (): void {
        Route::get('/me', [GoogleAccountController::class, 'show'])
            ->name('api.v1.me');
        Route::get('/organizations', [OrganizationController::class, 'index'])
            ->name('api.v1.organizations.index');
        Route::post('/organizations', [OrganizationController::class, 'store'])
            ->name('api.v1.organizations.store');
        Route::get('/organizations/{organizationId}/members', [OrganizationController::class, 'members'])
            ->whereUuid('organizationId')
            ->name('api.v1.organizations.members');
        Route::post('/organizations/{organizationId}/members', [OrganizationController::class, 'addMember'])
            ->whereUuid('organizationId')
            ->name('api.v1.organizations.members.store');
        Route::get('/organizations/{organizationId}/shift-policies', [OrganizationController::class, 'policies'])
            ->whereUuid('organizationId')
            ->name('api.v1.organizations.policies');
        Route::put('/organizations/{organizationId}/shift-policies/{workflowType}', [OrganizationController::class, 'updatePolicy'])
            ->whereUuid('organizationId')
            ->name('api.v1.organizations.policies.update');
    });
});
