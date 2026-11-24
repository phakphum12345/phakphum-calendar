<?php

namespace App\Services\ShiftPay;

class ShiftPayCalculationService
{
    public function calculate(array $input, array $personalRules, array $organizationRules, array $profile): array
    {
        $dayCategory = $this->classifyDay($input);
        $personal = $this->match($input, $dayCategory, $personalRules);
        $organization = $this->match($input, $dayCategory, $organizationRules);
        $mode = $profile['mode'] ?? 'personal';
        $priority = $profile['hybrid_priority'] ?? 'requireSelection';
        $selectedSource = null;
        $selected = null;
        $selectionRequired = false;

        if ($mode === 'personal') {
            $selectedSource = $personal === null ? null : 'personal';
            $selected = $personal;
        } elseif ($mode === 'organization') {
            $selectedSource = $organization === null ? null : 'organization';
            $selected = $organization;
        } elseif (! empty($input['selected_source'])) {
            $selectedSource = $input['selected_source'];
            $selected = $selectedSource === 'personal' ? $personal : $organization;
        } elseif ($personal !== null && $organization !== null && $priority === 'requireSelection') {
            $selectionRequired = true;
        } elseif ($priority === 'personalFirst') {
            $selectedSource = $personal !== null ? 'personal' : ($organization !== null ? 'organization' : null);
            $selected = $personal ?? $organization;
        } else {
            $selectedSource = $organization !== null ? 'organization' : ($personal !== null ? 'personal' : null);
            $selected = $organization ?? $personal;
        }

        $decimalPlaces = (int) ($selectedSource === 'organization'
            ? ($profile['organization_decimal_places'] ?? $profile['decimal_places'] ?? 2)
            : ($profile['decimal_places'] ?? 2));
        $currency = $selectedSource === 'organization'
            ? ($profile['organization_currency_code'] ?? $profile['currency_code'] ?? 'THB')
            : ($profile['currency_code'] ?? 'THB');

        if ($selectionRequired || $selected === null) {
            $result = [
                'status' => $selectionRequired ? 'source_selection_required' : 'no_matching_rule',
                'day_category' => $dayCategory,
                'source' => null,
                'rule_id' => null,
                'treatment' => null,
                'amount' => null,
                'currency_code' => $currency,
                'decimal_places' => $decimalPlaces,
                'is_covered_by_salary' => false,
                'is_compensatory_time' => false,
                'compensates_shift_type_id' => null,
            ];
        } else {
            $rule = $selected;
            $treatment = $rule['treatment'] ?? 'additionalPay';
            $salaryIncluded = (bool) ($rule['salary_included'] ?? false);
            $isCompensatory = $treatment === 'compensatoryTime';
            $covered = $salaryIncluded || $treatment === 'includedInSalary';
            if ($isCompensatory) {
                $amount = 0.0;
            } elseif ($covered) {
                $amount = 0.0;
            } else {
                $base = isset($rule['fixed_amount'])
                    ? (float) $rule['fixed_amount']
                    : ((float) $input['hours'] * (float) $rule['hourly_rate']);
                $amount = round($base * (float) ($rule['multiplier'] ?? 1), $decimalPlaces, PHP_ROUND_HALF_UP);
            }
            $result = [
                'status' => 'calculated',
                'day_category' => $dayCategory,
                'source' => $selectedSource,
                'rule_id' => $rule['id'],
                'treatment' => $treatment,
                'amount' => $amount,
                'currency_code' => $currency,
                'decimal_places' => $decimalPlaces,
                'is_covered_by_salary' => $covered,
                'is_compensatory_time' => $isCompensatory,
                'compensates_shift_type_id' => $isCompensatory ? ($rule['compensates_shift_type_id'] ?? null) : null,
            ];
        }

        return [
            'result' => $result,
            'selected_rule' => $selected,
            'candidate_rule_ids' => [
                'personal' => $personal['id'] ?? null,
                'organization' => $organization['id'] ?? null,
            ],
            'source_versions' => [
                'personal' => (int) ($profile['version'] ?? 0),
                'organization' => (int) ($profile['organization_version'] ?? 0),
            ],
        ];
    }

    private function classifyDay(array $input): string
    {
        $date = $input['date'];
        $overrides = $input['date_overrides'] ?? [];
        if (isset($overrides[$date])) {
            return $overrides[$date];
        }
        $weekday = (int) date('N', strtotime($date));
        if (in_array($weekday, $input['weekly_days_off'] ?? [], true)) {
            return 'weeklyDayOff';
        }

        return 'regularWeekday';
    }

    private function match(array $input, string $dayCategory, array $rules): ?array
    {
        $candidates = [];
        foreach ($rules as $index => $rule) {
            if (($rule['active'] ?? true) !== true ||
                ($rule['employment_type'] ?? null) !== $input['employment_type'] ||
                ($rule['day_category'] ?? null) !== $dayCategory ||
                ($rule['shift_type_id'] ?? null) !== $input['shift_type_id'] ||
                ($rule['assignment_purpose'] ?? 'regularCoverage') !== ($input['assignment_purpose'] ?? 'regularCoverage')) {
                continue;
            }
            if (($rule['treatment'] ?? 'additionalPay') === 'compensatoryTime' &&
                ! in_array((int) date('N', strtotime($input['date'])), $rule['compensatory_weekdays'] ?? [], true)) {
                continue;
            }
            if (! $this->matchesOptional($rule['department'] ?? null, $input['department'] ?? null) ||
                ! $this->matchesOptional($rule['location'] ?? null, $input['location'] ?? null) ||
                ! $this->matchesOptional($rule['work_point'] ?? null, $input['work_point'] ?? null)) {
                continue;
            }
            $specificity = (($rule['department'] ?? null) !== null ? 4 : 0)
                + (($rule['location'] ?? null) !== null ? 2 : 0)
                + (($rule['work_point'] ?? null) !== null ? 1 : 0);
            $candidates[] = ['rule' => $rule, 'specificity' => $specificity, 'index' => $index];
        }
        usort($candidates, static function (array $a, array $b): int {
            $specificity = $b['specificity'] <=> $a['specificity'];

            return $specificity !== 0 ? $specificity : ($a['index'] <=> $b['index']);
        });

        return $candidates[0]['rule'] ?? null;
    }

    private function matchesOptional(?string $configured, ?string $actual): bool
    {
        if ($configured === null) {
            return true;
        }

        return $this->normalize($configured) === $this->normalize($actual);
    }

    private function normalize(?string $value): ?string
    {
        $normalized = strtolower(trim((string) $value));

        return $normalized === '' ? null : $normalized;
    }
}
