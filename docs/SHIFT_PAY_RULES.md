# Work-day classification and shift-pay rules

The shift-pay calculator is a configurable domain component. It calculates **additional shift pay only**; it does not calculate base salary, statutory overtime, deductions, or a complete payroll.

## Work-day classification

```dart
const policy = WorkDayPolicy(weeklyDaysOff: {6, 7}); // Saturday and Sunday
```

Date overrides use `YYYY-MM-DD` keys and take precedence over recurring weekly days off. Use `officialHoliday` for an official holiday and `festival` for a festival or special local event. Without an override, dates are classified as a recurring day off or a regular weekday.

This is intentionally not a built-in national holiday calendar: organizations must configure the dates relevant to their location and year.

## Rules

Each `ShiftPayRule` is specific to:
- employment type: `salaried` or `dailyPaid`;
- day category: regular weekday, official holiday, weekly day off, or festival;
- shift period: morning, afternoon, or night.

A rule can optionally scope to a department and/or location. More specific scopes override general rules. Rules must be configured separately where the policy differs.

- Set `salaryIncluded: true` when that shift is covered by normal salary and has no additional shift payment under the rule. The calculated additional amount is zero.
- Use `fixedAmount` for a fixed additional amount per shift, or `hourlyRate` with the actual shift hours. `multiplier` applies to the selected amount.
- If no rule matches, the result has `hasRule == false` and `amount == null`. This means the rule is not configured, not that the shift is unpaid.

## Important payroll boundary

Do not treat this calculator as legal or statutory payroll guidance. Actual rates, eligibility, holiday definitions, overtime, salary inclusion, and rounding must be reviewed and configured by the responsible organization. The engine deliberately does not invent rates or assume one policy fits every department.
