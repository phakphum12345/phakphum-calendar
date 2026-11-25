import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/services/shift_pay_calculator.dart';
import 'package:phakphum_calendar/domain/services/shift_pay_profile.dart';

void main() {
  const calculator = ShiftPayCalculator();
  final input = ShiftPayInput(
    date: DateTime(2026, 11, 24),
    employmentType: EmploymentType.dailyPaid,
    shiftTypeId: 'night',
    hours: 8,
  );

  ShiftPayRule rule(String id, double amount) => ShiftPayRule(
    id: id,
    employmentType: EmploymentType.dailyPaid,
    dayCategory: WorkDayCategory.regularWeekday,
    shiftTypeId: 'night',
    fixedAmount: amount,
  );

  test('personal mode resolves personal rules without organization access', () {
    final profile = ShiftPayProfile(
      id: 'profile-1',
      mode: ShiftPayMode.personal,
      rules: [
        ShiftPayRuleEntry(
          source: ShiftPayRuleSource.personal,
          rule: rule('personal-night', 700),
        ),
        ShiftPayRuleEntry(
          source: ShiftPayRuleSource.organization,
          organizationId: 'org-a',
          rule: rule('org-night', 900),
        ),
      ],
    );

    final result = profile.resolve(calculator: calculator, input: input);

    expect(result.source, ShiftPayRuleSource.personal);
    expect(result.calculation.amount, 700);
  });

  test('organization mode only resolves rules for the selected organization', () {
    final profile = ShiftPayProfile(
      id: 'profile-2',
      mode: ShiftPayMode.organization,
      organizationId: 'org-a',
      rules: [
        ShiftPayRuleEntry(
          source: ShiftPayRuleSource.organization,
          organizationId: 'org-b',
          rule: rule('other-org', 1200),
        ),
        ShiftPayRuleEntry(
          source: ShiftPayRuleSource.organization,
          organizationId: 'org-a',
          rule: rule('current-org', 850),
        ),
      ],
    );

    final result = profile.resolve(calculator: calculator, input: input);

    expect(result.source, ShiftPayRuleSource.organization);
    expect(result.calculation.amount, 850);
  });

  test('hybrid organization-first uses one source and never adds rates', () {
    final profile = ShiftPayProfile(
      id: 'profile-3',
      mode: ShiftPayMode.hybrid,
      organizationId: 'org-a',
      hybridPriority: HybridShiftPayPriority.organizationFirst,
      rules: [
        ShiftPayRuleEntry(
          source: ShiftPayRuleSource.personal,
          rule: rule('personal-night', 700),
        ),
        ShiftPayRuleEntry(
          source: ShiftPayRuleSource.organization,
          organizationId: 'org-a',
          rule: rule('org-night', 900),
        ),
      ],
    );

    final result = profile.resolve(calculator: calculator, input: input);

    expect(result.source, ShiftPayRuleSource.organization);
    expect(result.calculation.amount, 900);
  });

  test('hybrid require-selection reports ambiguity when both sources match', () {
    final profile = ShiftPayProfile(
      id: 'profile-4',
      mode: ShiftPayMode.hybrid,
      organizationId: 'org-a',
      rules: [
        ShiftPayRuleEntry(
          source: ShiftPayRuleSource.personal,
          rule: rule('personal-night', 700),
        ),
        ShiftPayRuleEntry(
          source: ShiftPayRuleSource.organization,
          organizationId: 'org-a',
          rule: rule('org-night', 900),
        ),
      ],
    );

    final result = profile.resolve(calculator: calculator, input: input);

    expect(result.sourceSelectionRequired, isTrue);
    expect(result.hasRule, isFalse);
    expect(result.source, isNull);
    expect(result.calculation.rule, isNull);
    expect(result.calculation.amount, isNull);
  });

  test('hybrid explicit source selection resolves only that source', () {
    final profile = ShiftPayProfile(
      id: 'profile-5',
      mode: ShiftPayMode.hybrid,
      organizationId: 'org-a',
      rules: [
        ShiftPayRuleEntry(
          source: ShiftPayRuleSource.personal,
          rule: rule('personal-night', 700),
        ),
        ShiftPayRuleEntry(
          source: ShiftPayRuleSource.organization,
          organizationId: 'org-a',
          rule: rule('org-night', 900),
        ),
      ],
    );

    final result = profile.resolve(
      calculator: calculator,
      input: input,
      selectedSource: ShiftPayRuleSource.personal,
    );

    expect(result.source, ShiftPayRuleSource.personal);
    expect(result.calculation.amount, 700);
  });

  test('unconfigured shifts remain explicitly unconfigured', () {
    final profile = ShiftPayProfile(
      id: 'profile-6',
      mode: ShiftPayMode.personal,
      rules: const [],
    );

    final result = profile.resolve(calculator: calculator, input: input);

    expect(result.hasRule, isFalse);
    expect(result.calculation.amount, isNull);
  });

  test('organization source uses its own configured decimal precision', () {
    final profile = ShiftPayProfile(
      id: 'profile-org-precision',
      mode: ShiftPayMode.organization,
      organizationId: 'org-a',
      decimalPlaces: 2,
      organizationDecimalPlaces: 0,
      rules: [
        ShiftPayRuleEntry(
          source: ShiftPayRuleSource.organization,
          organizationId: 'org-a',
          rule: rule('org-fractional', 123.456),
        ),
      ],
    );

    final result = profile.resolve(calculator: calculator, input: input);

    expect(result.source, ShiftPayRuleSource.organization);
    expect(result.calculation.amount, 123);
  });

  test('organization mode requires an organization identifier', () {
    expect(
      () => ShiftPayProfile(
        id: 'invalid',
        mode: ShiftPayMode.organization,
        rules: const [],
      ),
      throwsArgumentError,
    );
  });
}
