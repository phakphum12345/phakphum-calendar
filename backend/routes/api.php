<?php

use App\Http\Controllers\Api\V1\ClientErrorController;
use App\Http\Controllers\Api\V1\GoogleAccountController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\OrganizationController;
use App\Http\Controllers\Api\V1\ScheduleController;
use App\Http\Controllers\Api\V1\ScheduleImportJournalController;
use App\Http\Controllers\Api\V1\ShiftPayCalculationController;
use App\Http\Controllers\Api\V1\ShiftPayProfileController;
use App\Http\Controllers\Api\V1\ShiftTransactionController;
use App\Http\Controllers\Api\V1\WebPushSubscriptionController;
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
        Route::get('/schedules/import-journals', [ScheduleImportJournalController::class, 'discover'])
            ->name('api.v1.schedules.import-journals.discover');
        Route::get('/schedules/{scheduleId}', [ScheduleController::class, 'show'])
            ->where('scheduleId', '[A-Za-z0-9._:-]{1,128}')
            ->name('api.v1.schedules.show');
        Route::put('/schedules/{scheduleId}', [ScheduleController::class, 'store'])
            ->where('scheduleId', '[A-Za-z0-9._:-]{1,128}')
            ->name('api.v1.schedules.store');
        Route::delete('/schedules/{scheduleId}', [ScheduleController::class, 'destroy'])
            ->where('scheduleId', '[A-Za-z0-9._:-]{1,128}')
            ->name('api.v1.schedules.destroy');
        Route::get('/schedules/{scheduleId}/import-journals', [ScheduleImportJournalController::class, 'index'])
            ->where('scheduleId', '[A-Za-z0-9._:-]{1,128}')
            ->name('api.v1.schedules.import-journals.index');
        Route::post('/schedules/{scheduleId}/import-journals', [ScheduleImportJournalController::class, 'store'])
            ->where('scheduleId', '[A-Za-z0-9._:-]{1,128}')
            ->name('api.v1.schedules.import-journals.store');
        Route::get('/me', [GoogleAccountController::class, 'show'])
            ->name('api.v1.me');
        Route::post('/shift-pay/calculations', [ShiftPayCalculationController::class, 'store'])
            ->name('api.v1.shift-pay.calculations.store');
        Route::get('/shift-pay/snapshots', [ShiftPayCalculationController::class, 'index'])
            ->name('api.v1.shift-pay.snapshots.index');
        Route::get('/shift-pay/snapshots/{snapshotId}', [ShiftPayCalculationController::class, 'show'])
            ->whereUuid('snapshotId')
            ->name('api.v1.shift-pay.snapshots.show');
        Route::get('/shift-pay/profile', [ShiftPayProfileController::class, 'show'])
            ->name('api.v1.shift-pay.profile.show');
        Route::put('/shift-pay/profile', [ShiftPayProfileController::class, 'update'])
            ->name('api.v1.shift-pay.profile.update');
        Route::get('/organizations/{organizationId}/shift-pay-rules', [ShiftPayProfileController::class, 'organizationRules'])
            ->whereUuid('organizationId')
            ->name('api.v1.organizations.shift-pay-rules.show');
        Route::put('/organizations/{organizationId}/shift-pay-rules', [ShiftPayProfileController::class, 'updateOrganizationRules'])
            ->whereUuid('organizationId')
            ->name('api.v1.organizations.shift-pay-rules.update');
        Route::get('/organizations', [OrganizationController::class, 'index'])
            ->name('api.v1.organizations.index');
        Route::post('/organizations', [OrganizationController::class, 'store'])
            ->name('api.v1.organizations.store');
        Route::get('/organization-join-requests', [OrganizationController::class, 'myJoinRequests'])
            ->name('api.v1.organization-join-requests.index');
        Route::post('/organization-join-requests', [OrganizationController::class, 'requestMembership'])
            ->name('api.v1.organization-join-requests.store');
        Route::get('/organizations/{organizationId}/members', [OrganizationController::class, 'members'])
            ->whereUuid('organizationId')
            ->name('api.v1.organizations.members');
        Route::get('/organizations/{organizationId}/membership-audit', [OrganizationController::class, 'membershipAudit'])
            ->whereUuid('organizationId')
            ->name('api.v1.organizations.membership-audit');
        Route::post('/push-subscriptions', [WebPushSubscriptionController::class, 'store'])
            ->name('api.v1.push-subscriptions.store');
        Route::delete('/push-subscriptions', [WebPushSubscriptionController::class, 'destroy'])
            ->name('api.v1.push-subscriptions.destroy');
        Route::post('/organizations/{organizationId}/members', [OrganizationController::class, 'addMember'])
            ->whereUuid('organizationId')
            ->name('api.v1.organizations.members.store');
        Route::patch('/organizations/{organizationId}/members/{userId}', [OrganizationController::class, 'updateMemberRole'])
            ->whereUuid('organizationId')
            ->whereNumber('userId')
            ->name('api.v1.organizations.members.update');
        Route::delete('/organizations/{organizationId}/members/{userId}', [OrganizationController::class, 'removeMember'])
            ->whereUuid('organizationId')
            ->whereNumber('userId')
            ->name('api.v1.organizations.members.destroy');
        Route::get('/organizations/{organizationId}/join-requests', [OrganizationController::class, 'joinRequests'])
            ->whereUuid('organizationId')
            ->name('api.v1.organizations.join-requests.index');
        Route::post('/organizations/{organizationId}/join-requests/{requestId}/approve', [OrganizationController::class, 'approveJoinRequest'])
            ->whereUuid('organizationId')
            ->whereNumber('requestId')
            ->name('api.v1.organizations.join-requests.approve');
        Route::post('/organizations/{organizationId}/join-requests/{requestId}/reject', [OrganizationController::class, 'rejectJoinRequest'])
            ->whereUuid('organizationId')
            ->whereNumber('requestId')
            ->name('api.v1.organizations.join-requests.reject');
        Route::get('/organizations/{organizationId}/shift-policies', [OrganizationController::class, 'policies'])
            ->whereUuid('organizationId')
            ->name('api.v1.organizations.policies');
        Route::put('/organizations/{organizationId}/shift-policies/{workflowType}', [OrganizationController::class, 'updatePolicy'])
            ->whereUuid('organizationId')
            ->name('api.v1.organizations.policies.update');

        Route::get('/shift-transactions', [ShiftTransactionController::class, 'index'])
            ->name('api.v1.shift-transactions.index');
        Route::post('/shift-transactions', [ShiftTransactionController::class, 'store'])
            ->name('api.v1.shift-transactions.store');
        Route::get('/shift-transactions/{transactionId}', [ShiftTransactionController::class, 'show'])
            ->whereUuid('transactionId')->name('api.v1.shift-transactions.show');
        Route::post('/shift-transactions/{transactionId}/confirm', [ShiftTransactionController::class, 'confirm'])
            ->whereUuid('transactionId')->name('api.v1.shift-transactions.confirm');
        Route::post('/shift-transactions/{transactionId}/reject', [ShiftTransactionController::class, 'reject'])
            ->whereUuid('transactionId')->name('api.v1.shift-transactions.reject');
        Route::post('/shift-transactions/{transactionId}/approve', [ShiftTransactionController::class, 'approve'])
            ->whereUuid('transactionId')->name('api.v1.shift-transactions.approve');
        Route::post('/shift-transactions/{transactionId}/reject-by-approver', [ShiftTransactionController::class, 'rejectByApprover'])
            ->whereUuid('transactionId')->name('api.v1.shift-transactions.reject-by-approver');
        Route::post('/shift-transactions/{transactionId}/cancel', [ShiftTransactionController::class, 'cancel'])
            ->whereUuid('transactionId')->name('api.v1.shift-transactions.cancel');
        Route::post('/shift-transactions/{transactionId}/calendar-sync/start', [ShiftTransactionController::class, 'startSync'])
            ->whereUuid('transactionId')->name('api.v1.shift-transactions.calendar-sync.start');
        Route::post('/shift-transactions/{transactionId}/calendar-sync/complete', [ShiftTransactionController::class, 'completeSync'])
            ->whereUuid('transactionId')->name('api.v1.shift-transactions.calendar-sync.complete');
        Route::post('/shift-transactions/{transactionId}/calendar-sync/fail', [ShiftTransactionController::class, 'failSync'])
            ->whereUuid('transactionId')->name('api.v1.shift-transactions.calendar-sync.fail');
        Route::post('/shift-transactions/{transactionId}/fulfill', [ShiftTransactionController::class, 'fulfill'])
            ->whereUuid('transactionId')->name('api.v1.shift-transactions.fulfill');
    });
});
