<?php

namespace App\Http\Controllers\Api\V1;

use App\Services\ShiftPay\ShiftPayCalculationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Database\QueryException;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class ShiftPayCalculationController
{
    public function __construct(private readonly ShiftPayCalculationService $calculator) {}

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'date' => ['required', 'date_format:Y-m-d'],
            'employment_type' => ['required', Rule::in(['salaried', 'dailyPaid'])],
            'shift_type_id' => ['required', 'string', 'max:128'],
            'hours' => ['required', 'numeric', 'min:0', 'max:168'],
            'department' => ['nullable', 'string', 'max:120'],
            'location' => ['nullable', 'string', 'max:120'],
            'work_point' => ['nullable', 'string', 'max:120'],
            'assignment_purpose' => ['sometimes', Rule::in(['regularCoverage', 'breakRelief', 'premiumDuty', 'replacement', 'other'])],
            'selected_source' => ['nullable', Rule::in(['personal', 'organization'])],
            'date_overrides' => ['sometimes', 'array', 'max:366'],
            'date_overrides.*' => [Rule::in(['regularWeekday', 'officialHoliday', 'weeklyDayOff', 'festival'])],
            'weekly_days_off' => ['sometimes', 'array', 'max:7'],
            'weekly_days_off.*' => ['integer', 'between:1,7'],
        ]);
        $idempotencyKey = (string) $request->header('Idempotency-Key', '');
        if ($idempotencyKey === '' || strlen($idempotencyKey) > 128) {
            return response()->json(['error' => [
                'code' => 'idempotency_key_required',
                'message' => 'Idempotency-Key must contain 1–128 characters.',
            ]], 422);
        }

        $userId = $request->user()->id;
        $profile = DB::table('user_shift_pay_profiles')->where('user_id', $userId)->first();
        $mode = $profile->mode ?? 'personal';
        $organizationId = $profile->organization_id ?? null;
        if (in_array($mode, ['organization', 'hybrid'], true) && $organizationId === null) {
            return response()->json(['error' => [
                'code' => 'organization_required',
                'message' => 'The selected Shift Pay mode requires an organization.',
            ]], 422);
        }

        $organizationProfile = null;
        if ($organizationId !== null) {
            $membership = DB::table('organization_memberships')
                ->where('organization_id', $organizationId)
                ->where('user_id', $userId)
                ->where('status', 'active')->first();
            abort_unless($membership !== null, 403, 'Active organization membership is required.');
            $organizationProfile = DB::table('organization_shift_pay_profiles')
                ->where('organization_id', $organizationId)->first();
        }

        $rules = [
            'mode' => $mode,
            'hybrid_priority' => $profile->hybrid_priority ?? 'requireSelection',
            'currency_code' => $profile->currency_code ?? 'THB',
            'decimal_places' => (int) ($profile->decimal_places ?? 2),
            'version' => (int) ($profile->version ?? 0),
            'organization_version' => (int) ($organizationProfile->version ?? 0),
            'organization_currency_code' => $organizationProfile->currency_code ?? ($profile->currency_code ?? 'THB'),
            'organization_decimal_places' => (int) ($organizationProfile->decimal_places ?? $profile->decimal_places ?? 2),
        ];
        $personalRules = $profile?->personal_rules
            ? json_decode($profile->personal_rules, true, 512, JSON_THROW_ON_ERROR) : [];
        $organizationRules = $organizationProfile?->rules
            ? json_decode($organizationProfile->rules, true, 512, JSON_THROW_ON_ERROR) : [];
        $calculation = $this->calculator->calculate($validated, $personalRules, $organizationRules, $rules);
        $result = $calculation['result'];
        $requestHash = hash('sha256', json_encode([
            'input' => $validated,
            'mode' => $mode,
            'organization_id' => $organizationId,
            'profile_version' => $rules['version'],
            'organization_version' => $rules['organization_version'],
        ], JSON_THROW_ON_ERROR));

        $existing = DB::table('shift_pay_calculation_snapshots')
            ->where('user_id', $userId)->where('idempotency_key', $idempotencyKey)->first();
        if ($existing !== null) {
            if (! hash_equals($existing->request_hash, $requestHash)) {
                throw new ConflictHttpException('Idempotency key was already used for a different calculation request.');
            }

            return response()->json(['data' => $this->snapshotResponse($existing)]);
        }

        $snapshotId = (string) Str::uuid();
        $now = now();
        try {
            DB::table('shift_pay_calculation_snapshots')->insert([
                'id' => $snapshotId,
                'user_id' => $userId,
                'organization_id' => $organizationId,
                'idempotency_key' => $idempotencyKey,
                'request_hash' => $requestHash,
                'mode' => $mode,
                'source' => $result['source'],
                'personal_profile_version' => $rules['version'],
                'organization_profile_version' => $rules['organization_version'],
                'input_snapshot' => json_encode($validated, JSON_THROW_ON_ERROR),
                'rule_snapshot' => $calculation['selected_rule'] === null
                    ? null : json_encode($calculation['selected_rule'], JSON_THROW_ON_ERROR),
                'result_snapshot' => json_encode($result, JSON_THROW_ON_ERROR),
                'calculated_at' => $now,
            ]);
        } catch (QueryException $exception) {
            $existing = DB::table('shift_pay_calculation_snapshots')
                ->where('user_id', $userId)->where('idempotency_key', $idempotencyKey)->first();
            if ($existing !== null && hash_equals($existing->request_hash, $requestHash)) {
                return response()->json(['data' => $this->snapshotResponse($existing)]);
            }
            throw $exception;
        }

        $snapshot = DB::table('shift_pay_calculation_snapshots')->where('id', $snapshotId)->first();

        return response()->json(['data' => $this->snapshotResponse($snapshot)], 201);
    }

    public function show(Request $request, string $snapshotId): JsonResponse
    {
        $snapshot = DB::table('shift_pay_calculation_snapshots')
            ->where('id', $snapshotId)
            ->where('user_id', $request->user()->id)
            ->first();
        abort_unless($snapshot !== null, 404, 'Shift Pay snapshot not found.');

        return response()->json(['data' => $this->snapshotResponse($snapshot)]);
    }

    private function snapshotResponse(object $snapshot): array
    {
        return [
            'id' => $snapshot->id,
            'mode' => $snapshot->mode,
            'source' => $snapshot->source,
            'personal_profile_version' => (int) $snapshot->personal_profile_version,
            'organization_profile_version' => (int) $snapshot->organization_profile_version,
            'input' => json_decode($snapshot->input_snapshot, true, 512, JSON_THROW_ON_ERROR),
            'rule' => $snapshot->rule_snapshot === null
                ? null : json_decode($snapshot->rule_snapshot, true, 512, JSON_THROW_ON_ERROR),
            'result' => json_decode($snapshot->result_snapshot, true, 512, JSON_THROW_ON_ERROR),
            'calculated_at' => $snapshot->calculated_at,
        ];
    }
}
