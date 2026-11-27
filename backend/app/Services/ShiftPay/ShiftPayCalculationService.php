<?php

namespace App\\Services\\ShiftPay;

final class ShiftPayCalculationService
{
    /**
     * @param array<string, mixed> $profile
     * @param array<string, mixed> $input
     * @return array<string, mixed>
     */
    public function calculate(array $profile, array $input): array
    {
        $personalMatch = $this->match(
            $profile['personal_rules'] ?? [],
            $input,
            $profile['employment_type'] ?? 'salaried',
            $input['day_category'],
        );
        $organizationMatch = $this->match(
            $profile['organization_rules'] ?? [],
            $input,
            $profile['employment_type'] ?? 'salaried',
            $input['day_category'],
        );
        $personal = $personalMatch['rule'];
        $organization = $organizationMatch['rule'];
        $mode = $profile['mode'] ?? 'personal';
        $priority = $profile['hybrid_priority'] ?? 'require_selection';
        $selectedSource = null;

        if ($mode === 'personal') {
            $selectedSource = 'personal';
        } elseif ($mode === 'organization') {
            $selectedSource = 'organization';
        } elseif (($input['selected_source'] ?? null) !== null) {
            $selectedSource = $input['selected_source'];
        } elseif ($priority === 'personal_first') {
            $selectedSource = $personal !== null ||
                $personalMatch['conflicting_rule_ids'] !== []
                ? 'personal'
                : 'organization';
        } elseif ($priority === 'organization_first') {
            $selectedSource = $organization !== null ||
                $organizationMatch['conflicting_rule_ids'] !== []
                ? 'organization'
                : 'personal';
        } else {
            $allConflicts = array_merge(
                $personalMatch['conflicting_rule_ids'],
                $organizationMatch['conflicting_rule_ids'],
            );
            if ($allConflicts !== []) {
                return $this->invalidRuleResult(
                    $personal,
                    $organization,
                    $personalMatch['conflicting_rule_ids'],
                    $organizationMatch['conflicting_rule_ids'],
                    $allConflicts,
                );
            }
            if ($personal !== null && $organization !== null) {
                return [
                    'status' => 'source_selection_required',
                    'amount' => null,
                    'source' => null,
                    'selected_rule' => null,
                    'candidate_rule_ids' => [
                        'personal' => $personal['id'],
                        'organization' => $organization['id'],
                    ],
                    'source_conflicts' => [
                        'personal' => [],
                        'organization' => [],
                    ],
                    'conflicting_rule_ids' => [],
                ];
            }
            $selectedSource = $personal !== null ? 'personal' : 'organization';
        }

        $selectedMatch = $selectedSource === 'personal'
            ? $personalMatch
            : $organizationMatch;
        $selectedRule = $selectedMatch['rule'];
        $selectedConflicts = $selectedMatch['conflicting_rule_ids'];

        if ($selectedConflicts !== []) {
            return $this->invalidRuleResult(
                $personal,
                $organization,
                $personalMatch['conflicting_rule_ids'],
                $organizationMatch['conflicting_rule_ids'],
                $selectedConflicts,
                $selectedSource,
            );
        }

        if ($selectedRule === null) {
            return [
                'status' => 'no_matching_rule',
                'amount' => null,
                'source' => $selectedSource,
                'selected_rule' => null,
                'candidate_rule_ids' => [
                    'personal' => $personal['id'] ?? null,
                    'organization' => $organization['id'] ?? null,
                ],
                'source_conflicts' => [
                    'personal' => $personalMatch['conflicting_rule_ids'],
                    'organization' => $organizationMatch['conflicting_rule_ids'],
                ],
                'conflicting_rule_ids' => [],
            ];
        }

        $hours = (float) ($input['hours'] ?? 0);
        $baseAmount = (float) ($selectedRule['amount'] ?? 0);
        $amount = ($selectedRule['amount_type'] ?? 'fixed') === 'hourly'
            ? $baseAmount * $hours
            : $baseAmount;
        $precision = $selectedSource === 'organization'
            ? (int) ($profile['organization_decimal_places'] ?? $profile['decimal_places'] ?? 2)
            : (int) ($profile['decimal_places'] ?? 2);

        return [
            'status' => 'payable',
            'amount' => round($amount, $precision),
            'source' => $selectedSource,
            'selected_rule' => $selectedRule['id'],
            'candidate_rule_ids' => [
                'personal' => $personal['id'] ?? null,
                'organization' => $organization['id'] ?? null,
            ],
            'source_conflicts' => [
                'personal' => $personalMatch['conflicting_rule_ids'],
                'organization' => $organizationMatch['conflicting_rule_ids'],
            ],
            'conflicting_rule_ids' => [],
        ];
    }

    /**
     * @param array<string, mixed>|null $personal
     * @param array<string, mixed>|null $organization
     * @param list<string> $personalConflicts
     * @param list<string> $organizationConflicts
     * @param list<string> $conflicts
     * @return array<string, mixed>
     */
    private function invalidRuleResult(
        ?array $personal,
        ?array $organization,
        array $personalConflicts,
        array $organizationConflicts,
        array $conflicts,
        ?string $selectedSource = null,
    ): array {
        return [
            'status' => 'invalid_rule',
            'error_code' => 'ambiguous_rule',
            'amount' => null,
            'source' => $selectedSource,
            'selected_rule' => null,
            'candidate_rule_ids' => [
                'personal' => $personal['id'] ?? null,
                'organization' => $organization['id'] ?? null,
            ],
            'source_conflicts' => [
                'personal' => $personalConflicts,
                'organization' => $organizationConflicts,
            ],
            'conflicting_rule_ids' => array_values(array_unique($conflicts)),
        ];
    }

    /**
     * @param list<array<string, mixed>> $rules
     * @param array<string, mixed> $input
     * @return array{rule: array<string, mixed>|null, conflicting_rule_ids: list<string>}
     */
    private function match(
        array $rules,
        array $input,
        string $employmentType,
        string $dayCategory,
    ): array {
        $candidates = array_values(array_filter(
            $rules,
            function (array $rule) use ($input, $employmentType, $dayCategory): bool {
                if (($rule['active'] ?? true) !== true) {
                    return false;
                }
                foreach ([
                    'employment_type' => $employmentType,
                    'day_category' => $dayCategory,
                    'shift_type_id' => $input['shift_type_id'],
                    'assignment_purpose' => $input['assignment_purpose'] ?? 'regular_coverage',
                ] as $key => $value) {
                    if (($rule[$key] ?? null) !== $value) {
                        return false;
                    }
                }
                foreach (['department', 'location', 'work_point'] as $key) {
                    if (($rule[$key] ?? null) !== null &&
                        mb_strtolower(trim((string) $rule[$key])) !== mb_strtolower(trim((string) ($input[$key] ?? '')))) {
                        return false;
                    }
                }
                return true;
            },
        ));

        if ($candidates === []) {
            return ['rule' => null, 'conflicting_rule_ids' => []];
        }

        usort(
            $candidates,
            fn (array $left, array $right): int => $this->specificity($right) <=> $this->specificity($left),
        );
        $highestSpecificity = $this->specificity($candidates[0]);
        $equallySpecific = array_values(array_filter(
            $candidates,
            fn (array $candidate): bool => $this->specificity($candidate) === $highestSpecific,
        ));
        if (count($equallySpecific) > 1) {
            return [
                'rule' => null,
                'conflicting_rule_ids' => array_values(array_map(
                    static fn (array $rule): string => (string) $rule['id'],
                    $equallySpecific,
                )),
            ];
        }

        return ['rule' => $candidates[0], 'conflicting_rule_ids' => []];
    }

    /** @param array<string, mixed> $rule */
    private function specificity(array $rule): int
    {
        return (int) (($rule['department'] ?? null) !== null)
            + (int) (($rule['location'] ?? null) !== null)
            + (int) (($rule['work_point'] ?? null) !== null);
    }
}
