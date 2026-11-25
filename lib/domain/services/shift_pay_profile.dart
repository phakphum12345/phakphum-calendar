import 'shift_pay_calculator.dart';

/// The user's selected operating model for additional shift pay.
enum ShiftPayMode { personal, organization, hybrid }

/// Which owner's rules take precedence when both sources are available.
enum HybridShiftPayPriority {
  organizationFirst,
  personalFirst,
  requireSelection,
}

/// Ownership of one rule. Organization IDs are explicit to prevent
/// accidentally applying a rule from another tenant.
enum ShiftPayRuleSource { personal, organization }

class ShiftPayRuleEntry {
  const ShiftPayRuleEntry({
    required this.source,
    required this.rule,
    this.organizationId,
  });

  final ShiftPayRuleSource source;
  final ShiftPayRule rule;
  final String? organizationId;

  bool belongsToPersonalProfile() => source == ShiftPayRuleSource.personal;

  bool belongsToOrganization(String? id) =>
      source == ShiftPayRuleSource.organization &&
      id != null &&
      id.isNotEmpty &&
      organizationId == id;
}

/// A user's pay configuration. Persistence and organization authorization are
/// deliberately handled by repositories/services, not by this value object.
class ShiftPayProfile {
  ShiftPayProfile({
    required this.id,
    required this.mode,
    required Iterable<ShiftPayRuleEntry> rules,
    this.organizationId,
    this.hybridPriority = HybridShiftPayPriority.requireSelection,
    this.currencyCode = 'THB',
    this.decimalPlaces = 2,
    this.organizationDecimalPlaces,
  }) : rules = List.unmodifiable(rules) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode)) {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'must be a three-letter uppercase currency code',
      );
    }
    if (decimalPlaces < 0 || decimalPlaces > 4) {
      throw ArgumentError.value(decimalPlaces, 'decimalPlaces');
    }
    final organizationPlaces = organizationDecimalPlaces ?? decimalPlaces;
    if (organizationPlaces < 0 || organizationPlaces > 4) {
      throw ArgumentError.value(organizationPlaces, 'organizationDecimalPlaces');
    }
    if (mode == ShiftPayMode.organization &&
        (organizationId == null || organizationId!.trim().isEmpty)) {
      throw ArgumentError('Organization mode requires an organizationId.');
    }
    final ids = <String>{};
    for (final entry in this.rules) {
      if (!ids.add('${entry.source.name}:${entry.organizationId ?? ''}:${entry.rule.id}')) {
        throw ArgumentError('Duplicate shift-pay rule entry: ${entry.rule.id}');
      }
      if (entry.source == ShiftPayRuleSource.personal &&
          entry.organizationId != null) {
        throw ArgumentError('Personal rules cannot carry an organizationId.');
      }
      if (entry.source == ShiftPayRuleSource.organization &&
          (entry.organizationId == null || entry.organizationId!.trim().isEmpty)) {
        throw ArgumentError('Organization rules require an organizationId.');
      }
    }
  }

  final String id;
  final ShiftPayMode mode;
  final String? organizationId;
  final HybridShiftPayPriority hybridPriority;
  final String currencyCode;
  final int decimalPlaces;
  final int? organizationDecimalPlaces;
  final List<ShiftPayRuleEntry> rules;

  /// Resolves exactly one source for an assignment. It never adds a personal
  /// amount to an organization amount, preventing accidental double payment.
  ShiftPayResolvedCalculation resolve({
    required ShiftPayCalculator calculator,
    required ShiftPayInput input,
    Map<String, WorkDayCategory> dateOverrides = const {},
    ShiftPayRuleSource? selectedSource,
  }) {
    final personal = rules
        .where((entry) => entry.belongsToPersonalProfile())
        .toList(growable: false);
    final organization = rules
        .where((entry) => entry.belongsToOrganization(organizationId))
        .toList(growable: false);

    ShiftPayCalculation calculate(
      List<ShiftPayRuleEntry> entries, {
      int? precision,
    }) => calculator.calculate(
      input: input,
      rules: entries.map((entry) => entry.rule),
      dateOverrides: dateOverrides,
      decimalPlaces: precision ?? decimalPlaces,
    );

    switch (mode) {
      case ShiftPayMode.personal:
        final result = calculate(personal);
        return ShiftPayResolvedCalculation(
          calculation: result,
          source: result.hasRule ? ShiftPayRuleSource.personal : null,
        );
      case ShiftPayMode.organization:
        final result = calculate(
          organization,
          precision: organizationDecimalPlaces ?? decimalPlaces,
        );
        return ShiftPayResolvedCalculation(
          calculation: result,
          source: result.hasRule ? ShiftPayRuleSource.organization : null,
        );
      case ShiftPayMode.hybrid:
        if (selectedSource != null) {
          final entries = selectedSource == ShiftPayRuleSource.personal
              ? personal
              : organization;
          final result = calculate(
            entries,
            precision: selectedSource == ShiftPayRuleSource.organization
                ? organizationDecimalPlaces ?? decimalPlaces
                : decimalPlaces,
          );
          return ShiftPayResolvedCalculation(
            calculation: result,
            source: result.hasRule ? selectedSource : null,
          );
        }
        final personalResult = calculate(personal);
        final organizationResult = calculate(
          organization,
          precision: organizationDecimalPlaces ?? decimalPlaces,
        );
        if (personalResult.hasRule && organizationResult.hasRule &&
            hybridPriority == HybridShiftPayPriority.requireSelection) {
          // Do not expose either candidate amount while the source is
          // ambiguous. Consumers must receive a non-payable result until the
          // user explicitly selects one source.
          return ShiftPayResolvedCalculation(
            calculation: ShiftPayCalculation(
              dayCategory: personalResult.dayCategory,
              rule: null,
              amount: null,
              isCoveredBySalary: false,
            ),
            source: null,
            sourceSelectionRequired: true,
          );
        }
        if (hybridPriority == HybridShiftPayPriority.personalFirst) {
          if (personalResult.hasRule) {
            return ShiftPayResolvedCalculation(
              calculation: personalResult,
              source: ShiftPayRuleSource.personal,
            );
          }
          return ShiftPayResolvedCalculation(
            calculation: organizationResult,
            source: organizationResult.hasRule
                ? ShiftPayRuleSource.organization
                : null,
          );
        }
        if (organizationResult.hasRule) {
          return ShiftPayResolvedCalculation(
            calculation: organizationResult,
            source: ShiftPayRuleSource.organization,
          );
        }
        return ShiftPayResolvedCalculation(
          calculation: personalResult,
          source: personalResult.hasRule ? ShiftPayRuleSource.personal : null,
        );
    }
  }
}

class ShiftPayResolvedCalculation {
  const ShiftPayResolvedCalculation({
    required this.calculation,
    required this.source,
    this.sourceSelectionRequired = false,
  });

  final ShiftPayCalculation calculation;

  /// Null means no rule matched, or the user must choose between two matches.
  final ShiftPayRuleSource? source;
  final bool sourceSelectionRequired;

  bool get hasRule => calculation.hasRule && source != null;
}
