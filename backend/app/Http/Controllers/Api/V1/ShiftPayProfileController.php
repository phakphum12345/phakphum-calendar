<?php

namespace App\Http\Controllers\Api\V1;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class ShiftPayProfileController
{
    private const MODES = ['personal', 'organization', 'hybrid'];
    private const PRIORITIES = ['organizationFirst', 'personalFirst', 'requireSelection'];

    public function show(Request $request): JsonResponse
    {
        $userId = $request->user()->id;
        $profile = DB::table('user_shift_pay_profiles')->where('user_id', $userId)->first();
        $mode = $profile->mode ?? 'personal';
        $organizationId = $profile->organization_id ?? null;

        $organizationRules = [];
        $organizationCurrency = $profile->currency_code ?? 'THB';
        $organizationDecimalPlaces = (int) ($profile->decimal_places ?? 2);
        if ($organizationId !== null) {
            $this->requireMembership($userId, $organizationId);
            $organizationProfile = DB::table('organization_shift_pay_profiles')
                ->where('organization_id', $organizationId)->first();
            if ($organizationProfile !== null) {
                $organizationRules = $this->decodeRules($organizationProfile->rules);
                $organizationCurrency = $organizationProfile->currency_code;
                $organizationDecimalPlaces = (int) $organizationProfile->decimal_places;
            }
        }

        return response()->json(['data' => [
            'mode' => $mode,
            'organization_id' => $organizationId,
            'hybrid_priority' => $profile->hybrid_priority ?? 'requireSelection',
            'currency_code' => $profile->currency_code ?? 'THB',
            'decimal_places' => (int) ($profile->decimal_places ?? 2),
            'version' => (int) ($profile->version ?? 0),
            'personal_rules' => $this->decodeRules($profile->personal_rules ?? null),
            'organization_rules' => $organizationRules,
            'organization_currency_code' => $organizationCurrency,
            'organization_decimal_places' => $organizationDecimalPlaces,
        ]]);
    }

    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'mode' => ['required', 'string', Rule::in(self::MODES)],
            'organization_id' => ['nullable', 'uuid', 'exists:organizations,id'],
            'hybrid_priority' => ['sometimes', 'string', Rule::in(self::PRIORITIES)],
            'currency_code' => ['sometimes', 'regex:/^[A-Z]{3}$/'],
            'decimal_places' => ['sometimes', 'integer', 'min:0', 'max:4'],
            'personal_rules' => ['sometimes', 'array', 'max:200'],
            'personal_rules.*' => ['array:id,employment_type,day_category,shift_type_id,department,location,work_point,assignment_purpose,pay_component,salary_included,treatment,compensates_shift_type_id,compensatory_weekdays,fixed_amount,hourly_rate,multiplier,active'],
            'personal_rules.*.id' => ['required_with:personal_rules', 'string', 'max:128'],
            'personal_rules.*.employment_type' => ['required_with:personal_rules', Rule::in(['salaried', 'dailyPaid'])],
            'personal_rules.*.day_category' => ['required_with:personal_rules', Rule::in(['regularWeekday', 'officialHoliday', 'weeklyDayOff', 'festival'])],
            'personal_rules.*.shift_type_id' => ['required_with:personal_rules', 'string', 'max:128'],
            'personal_rules.*.department' => ['nullable', 'string', 'max:120'],
            'personal_rules.*.location' => ['nullable', 'string', 'max:120'],
            'personal_rules.*.work_point' => ['nullable', 'string', 'max:120'],
            'personal_rules.*.assignment_purpose' => ['sometimes', Rule::in(['regularCoverage', 'breakRelief', 'premiumDuty', 'replacement', 'other'])],
            'personal_rules.*.pay_component' => ['sometimes', Rule::in(['shiftAllowance', 'premium', 'differential', 'breakRelief', 'other'])],
            'personal_rules.*.salary_included' => ['sometimes', 'boolean'],
            'personal_rules.*.treatment' => ['sometimes', Rule::in(['additionalPay', 'includedInSalary', 'compensatoryTime'])],
            'personal_rules.*.compensates_shift_type_id' => ['nullable', 'string', 'max:128'],
            'personal_rules.*.compensatory_weekdays' => ['sometimes', 'array', 'max:7'],
            'personal_rules.*.compensatory_weekdays.*' => ['integer', 'between:1,7'],
            'personal_rules.*.fixed_amount' => ['nullable', 'numeric', 'min:0'],
            'personal_rules.*.hourly_rate' => ['nullable', 'numeric', 'min:0'],
            'personal_rules.*.multiplier' => ['sometimes', 'numeric', 'min:0', 'max:1000'],
            'personal_rules.*.active' => ['sometimes', 'boolean'],
        ]);

        $organizationId = $validated['organization_id'] ?? null;
        if (in_array($validated['mode'], ['organization', 'hybrid'], true) && $organizationId === null) {
            return response()->json(['error' => [
                'code' => 'organization_required',
                'message' => 'Organization and hybrid modes require an organization_id.',
            ]], 422);
        }
        if ($organizationId !== null) {
            $this->requireMembership($request->user()->id, $organizationId);
        }

        $rules = $validated['personal_rules'] ?? null;
        if ($rules !== null) {
            $this->assertUniqueRuleIds($rules);
            $this->assertPayRuleAmounts($rules);
        }

        $now = now();
        DB::transaction(function () use ($request, $validated, $organizationId, $rules, $now): void {
            $existing = DB::table('user_shift_pay_profiles')
                ->where('user_id', $request->user()->id)->lockForUpdate()->first();
            $values = [
                'mode' => $validated['mode'],
                'organization_id' => $organizationId,
                'hybrid_priority' => $validated['hybrid_priority'] ?? ($existing->hybrid_priority ?? 'requireSelection'),
                'currency_code' => $validated['currency_code'] ?? ($existing->currency_code ?? 'THB'),
                'decimal_places' => $validated['decimal_places'] ?? ($existing->decimal_places ?? 2),
                'version' => (int) ($existing->version ?? 0) + 1,
                'updated_at' => $now,
            ];
            if ($rules !== null) {
                $values['personal_rules'] = json_encode($rules, JSON_THROW_ON_ERROR);
            } elseif ($existing === null) {
                $values['personal_rules'] = json_encode([], JSON_THROW_ON_ERROR);
            }
            if ($existing === null) {
                $values['user_id'] = $request->user()->id;
                $values['created_at'] = $now;
                DB::table('user_shift_pay_profiles')->insert($values);
            } else {
                DB::table('user_shift_pay_profiles')->where('user_id', $request->user()->id)->update($values);
            }
        });

        return $this->show($request);
    }

    public function organizationRules(Request $request, string $organizationId): JsonResponse
    {
        $this->requireMembership($request->user()->id, $organizationId);
        $profile = DB::table('organization_shift_pay_profiles')
            ->where('organization_id', $organizationId)->first();

        return response()->json(['data' => [
            'organization_id' => $organizationId,
            'currency_code' => $profile->currency_code ?? 'THB',
            'decimal_places' => (int) ($profile->decimal_places ?? 2),
            'version' => (int) ($profile->version ?? 0),
            'rules' => $this->decodeRules($profile->rules ?? null),
        ]]);
    }

    public function updateOrganizationRules(Request $request, string $organizationId): JsonResponse
    {
        $this->requireManager($request->user()->id, $organizationId);
        $validated = $request->validate([
            'currency_code' => ['sometimes', 'regex:/^[A-Z]{3}$/'],
            'decimal_places' => ['sometimes', 'integer', 'min:0', 'max:4'],
            'rules' => ['required', 'array', 'max:200'],
            'rules.*' => ['array:id,employment_type,day_category,shift_type_id,department,location,work_point,assignment_purpose,pay_component,salary_included,treatment,compensates_shift_type_id,compensatory_weekdays,fixed_amount,hourly_rate,multiplier,active'],
            'rules.*.id' => ['required', 'string', 'max:128'],
            'rules.*.employment_type' => ['required', Rule::in(['salaried', 'dailyPaid'])],
            'rules.*.day_category' => ['required', Rule::in(['regularWeekday', 'officialHoliday', 'weeklyDayOff', 'festival'])],
            'rules.*.shift_type_id' => ['required', 'string', 'max:128'],
            'rules.*.department' => ['nullable', 'string', 'max:120'],
            'rules.*.location' => ['nullable', 'string', 'max:120'],
            'rules.*.work_point' => ['nullable', 'string', 'max:120'],
            'rules.*.assignment_purpose' => ['sometimes', Rule::in(['regularCoverage', 'breakRelief', 'premiumDuty', 'replacement', 'other'])],
            'rules.*.pay_component' => ['sometimes', Rule::in(['shiftAllowance', 'premium', 'differential', 'breakRelief', 'other'])],
            'rules.*.salary_included' => ['sometimes', 'boolean'],
            'rules.*.treatment' => ['sometimes', Rule::in(['additionalPay', 'includedInSalary', 'compensatoryTime'])],
            'rules.*.compensates_shift_type_id' => ['nullable', 'string', 'max:128'],
            'rules.*.compensatory_weekdays' => ['sometimes', 'array', 'max:7'],
            'rules.*.compensatory_weekdays.*' => ['integer', 'between:1,7'],
            'rules.*.fixed_amount' => ['nullable', 'numeric', 'min:0'],
            'rules.*.hourly_rate' => ['nullable', 'numeric', 'min:0'],
            'rules.*.multiplier' => ['sometimes', 'numeric', 'min:0', 'max:1000'],
            'rules.*.active' => ['sometimes', 'boolean'],
        ]);
        $this->assertUniqueRuleIds($validated['rules']);
        $this->assertPayRuleAmounts($validated['rules']);

        $existing = DB::table('organization_shift_pay_profiles')
            ->where('organization_id', $organizationId)->first();
        $now = now();
        $values = [
            'currency_code' => $validated['currency_code'] ?? ($existing->currency_code ?? 'THB'),
            'decimal_places' => $validated['decimal_places'] ?? ($existing->decimal_places ?? 2),
            'rules' => json_encode($validated['rules'], JSON_THROW_ON_ERROR),
            'version' => (int) ($existing->version ?? 0) + 1,
            'updated_at' => $now,
        ];
        if ($existing === null) {
            $values['organization_id'] = $organizationId;
            $values['created_at'] = $now;
            DB::table('organization_shift_pay_profiles')->insert($values);
        } else {
            DB::table('organization_shift_pay_profiles')->where('organization_id', $organizationId)->update($values);
        }

        return $this->organizationRules($request, $organizationId);
    }

    private function requireMembership(int|string $userId, string $organizationId): object
    {
        $membership = DB::table('organization_memberships')
            ->where('organization_id', $organizationId)
            ->where('user_id', $userId)
            ->where('status', 'active')->first();
        abort_unless($membership !== null, 403, 'Active organization membership is required.');

        return $membership;
    }

    private function requireManager(int|string $userId, string $organizationId): object
    {
        $membership = $this->requireMembership($userId, $organizationId);
        abort_unless(in_array($membership->role, ['owner', 'admin'], true), 403, 'Organization owner or admin role is required.');

        return $membership;
    }

    private function decodeRules(?string $json): array
    {
        return $json === null ? [] : json_decode($json, true, 512, JSON_THROW_ON_ERROR);
    }

    private function assertUniqueRuleIds(array $rules): void
    {
        $ids = array_map(static fn (array $rule): string => $rule['id'], $rules);
        if (count($ids) !== count(array_unique($ids))) {
            abort(422, 'Shift-pay rule IDs must be unique within their source profile.');
        }
    }

    private function assertPayRuleAmounts(array $rules): void
    {
        foreach ($rules as $index => $rule) {
            $treatment = $rule['treatment'] ?? 'additionalPay';
            $salaryIncluded = (bool) ($rule['salary_included'] ?? false);
            if ($treatment === 'additionalPay' && ! $salaryIncluded &&
                ! isset($rule['fixed_amount']) && ! isset($rule['hourly_rate'])) {
                abort(422, "Rule {$index} requires fixed_amount or hourly_rate for additionalPay.");
            }
            if ($treatment === 'compensatoryTime' &&
                empty($rule['compensates_shift_type_id'])) {
                abort(422, "Rule {$index} requires compensates_shift_type_id for compensatoryTime.");
            }
        }
    }
}
