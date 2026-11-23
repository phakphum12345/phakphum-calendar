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
- organization-defined shift type (for example morning, night, 12-hour, on-call, or a local shift); the type ID is not limited to a fixed enum.

A rule can optionally scope to a department and/or location. More specific scopes override general rules. Rules can also be scoped to a specific work point (such as a ward, counter, or relief station) and assignment purpose (`regularCoverage`, `breakRelief`, `premiumDuty`, `replacement`, or `other`). This supports cases where a person covers another point while its usual worker takes a break, and where one location pays a fixed premium or differential but another does not. `ShiftPayComponent` labels the configured amount as a shift allowance, premium, differential, break-relief payment, or other component; the amount still comes only from the configured fixed amount or hourly rate. Rules must be configured separately where the policy differs. A scheduled shift and an entitlement to extra pay are separate concepts.

- Set `salaryIncluded: true` or `treatment: ShiftPayTreatment.includedInSalary` when the shift is covered by normal salary and has no additional shift payment. The calculated additional amount is zero.
- Use `treatment: ShiftPayTreatment.compensatoryTime` when a shift (for example, a night shift) substitutes for another shift such as the morning shift instead of generating extra cash pay. Set `compensatesShiftTypeId` and explicitly configure `compensatoryWeekdays` using Monday = 1 through Sunday = 7. The rule applies only on those configured weekdays; it does not assume that every night shift is compensatory or that weekdays always follow the same schedule.
- Use `fixedAmount` for a fixed additional amount per shift, or `hourlyRate` with the actual shift hours. `multiplier` applies to the selected amount.
- If no rule matches, the result has `hasRule == false` and `amount == null`. This means the rule is not configured, not that the shift is unpaid.

## Important payroll boundary

Do not treat this calculator as legal or statutory payroll guidance. Actual rates, eligibility, holiday definitions, overtime, salary inclusion, and rounding must be reviewed and configured by the responsible organization. The engine deliberately does not invent rates or assume one policy fits every department.


## Configurable shift types

Use `ShiftTypeDefinition` to describe the shift types the organization actually uses. Each definition has an organization-defined ID and name, start/end minutes, an overnight flag, and an active flag. The IDs referenced by pay rules are strings, not a closed morning/afternoon/night enum, so new shift types can be added without changing the calculator. For example, a one-hour shift from 12:00–13:00 can be configured as its own shift type. The current pull request adds the domain model; a settings screen and persistence for these definitions still need to be implemented.


## Lunch break and break-relief defaults

For a brand-new installation with no saved shift templates, the editable template
catalog uses `shift:day` as a **ช่วงพักกลางวัน (lunch break)** from 12:00 to
13:00 with zero working hours and no default rate. The historical ID is retained
to make the default's identity stable. This is a template default, not a payroll
rule and not proof that the break is unpaid under any employment policy.

Users can edit the time and template for each location. If someone covers a work
point while another worker takes a break, record that assignment separately using
`ShiftAssignmentPurpose.breakRelief`, the actual hours, work point, location,
and an explicitly configured `ShiftPayRule` if the organization provides a
break-relief payment. A missing pay rule means “not configured,” not “unpaid.”

The initial catalog is seeded only when the template repository is empty. Existing
saved templates are deliberately not rewritten automatically, because they may
contain user-customized times, rates, locations, or IDs. Existing installations
must review/edit their saved `shift:day` template explicitly; importing or syncing
a roster must not silently change historical assignments.

Shift names such as morning, afternoon, night, and on-call describe scheduling
patterns; they do not independently imply an allowance. Organization-defined
workday, location, employment type, assignment purpose, and pay rules determine
whether additional compensation is configured. Night duty may be configured as
regular coverage or as compensatory time replacing a morning duty.
