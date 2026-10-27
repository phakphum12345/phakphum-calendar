/// Configurable work-day classification and additional shift-pay calculation.
///
/// This engine calculates additional shift pay only. It does not calculate base
/// salary, statutory overtime, tax, or payroll deductions. Rates must be supplied
/// by the organization; no jurisdiction-specific amounts are assumed.
enum WorkDayCategory {
  regularWeekday,
  officialHoliday,
  weeklyDayOff,
  festival,
}

enum EmploymentType {
  salaried,
  dailyPaid,
}

enum ShiftPeriod {
  morning,
  afternoon,
  night,
}

class WorkDayPolicy {
  const WorkDayPolicy({this.weeklyDaysOff = const <int>{}});

  /// DateTime weekday numbers: Monday = 1 ... Sunday = 7.
  final Set<int> weeklyDaysOff;

  /// Explicit date overrides win over recurring weekly days off.
  /// Keys must be ISO calendar dates: YYYY-MM-DD.
  WorkDayCategory classify(
    DateTime date, {
    Map<String, WorkDayCategory> dateOverrides = const {},
  }) {
    final key = calendarDateKey(date);
    final override = dateOverrides[key];
    if (override != null) return override;
    if (weeklyDaysOff.contains(date.weekday)) {
      return WorkDayCategory.weeklyDayOff;
    }
    return WorkDayCategory.regularWeekday;
  }
}

String calendarDateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// A rule for the additional amount payable for one assigned shift.
///
/// A null department/location acts as a wildcard. More specific rules take
/// precedence over broad rules. Configure separate rules for each employee
/// type, day category and shift period as needed.
class ShiftPayRule {
  const ShiftPayRule({
    required this.id,
    required this.employmentType,
    required this.dayCategory,
    required this.shiftPeriod,
    this.department,
    this.location,
    this.salaryIncluded = false,
    this.fixedAmount,
    this.hourlyRate,
    this.multiplier = 1,
    this.active = true,
  }) : assert(fixedAmount == null || fixedAmount >= 0),
       assert(hourlyRate == null || hourlyRate >= 0),
       assert(multiplier >= 0),
       assert(salaryIncluded || fixedAmount != null || hourlyRate != null);

  final String id;
  final EmploymentType employmentType;
  final WorkDayCategory dayCategory;
  final ShiftPeriod shiftPeriod;
  final String? department;
  final String? location;

  /// True when the shift is covered by normal salary and earns no additional
  /// shift-pay under this rule.
  final bool salaryIncluded;
  final double? fixedAmount;
  final double? hourlyRate;
  final double multiplier;
  final bool active;
}

class ShiftPayInput {
  const ShiftPayInput({
    required this.date,
    required this.employmentType,
    required this.shiftPeriod,
    required this.hours,
    this.department,
    this.location,
  }) : assert(hours >= 0);

  final DateTime date;
  final EmploymentType employmentType;
  final ShiftPeriod shiftPeriod;
  final double hours;
  final String? department;
  final String? location;
}

class ShiftPayCalculation {
  const ShiftPayCalculation({
    required this.dayCategory,
    required this.rule,
    required this.amount,
    required this.isCoveredBySalary,
  });

  final WorkDayCategory dayCategory;

  /// Null means no matching rule exists; the amount is intentionally null
  /// rather than silently treating an unconfigured shift as unpaid.
  final ShiftPayRule? rule;
  final double? amount;
  final bool isCoveredBySalary;

  bool get hasRule => rule != null;
}

class ShiftPayCalculator {
  const ShiftPayCalculator({this.workDayPolicy = const WorkDayPolicy()});

  final WorkDayPolicy workDayPolicy;

  ShiftPayCalculation calculate({
    required ShiftPayInput input,
    required Iterable<ShiftPayRule> rules,
    Map<String, WorkDayCategory> dateOverrides = const {},
  }) {
    final dayCategory = workDayPolicy.classify(
      input.date,
      dateOverrides: dateOverrides,
    );
    final candidates = rules.where((rule) {
      if (!rule.active ||
          rule.employmentType != input.employmentType ||
          rule.dayCategory != dayCategory ||
          rule.shiftPeriod != input.shiftPeriod) {
        return false;
      }
      if (rule.department != null &&
          _normalize(rule.department) != _normalize(input.department)) {
        return false;
      }
      if (rule.location != null &&
          _normalize(rule.location) != _normalize(input.location)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => _specificity(b).compareTo(_specificity(a)));

    if (candidates.isEmpty) {
      return ShiftPayCalculation(
        dayCategory: dayCategory,
        rule: null,
        amount: null,
        isCoveredBySalary: false,
      );
    }

    final rule = candidates.first;
    if (rule.salaryIncluded) {
      return ShiftPayCalculation(
        dayCategory: dayCategory,
        rule: rule,
        amount: 0,
        isCoveredBySalary: true,
      );
    }

    final base = rule.fixedAmount ??
        (rule.hourlyRate == null ? null : input.hours * rule.hourlyRate!);
    return ShiftPayCalculation(
      dayCategory: dayCategory,
      rule: rule,
      amount: base == null ? null : base * rule.multiplier,
      isCoveredBySalary: false,
    );
  }

  int _specificity(ShiftPayRule rule) =>
      (rule.department == null ? 0 : 2) +
      (rule.location == null ? 0 : 1);

  String? _normalize(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
