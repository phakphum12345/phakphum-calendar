# Three-Mode Shift Pay — Implementation Specification

- Status: requirements contract with merged implementation foundations
- Related PRs: #181 (Flutter source resolution), #183 (backend persistence), #186 (backend calculation and immutable snapshots)
- Current status: modes, persistence and calculation APIs are merged; profile-specific decimal rounding is supported. PR #201 adds deterministic equal-specificity conflict detection in Dart and backend calculation snapshots; all 12 workflows passed on the prior exact head. Hybrid conflict and explicit source-selection API regression tests were then added and require a fresh exact-head CI run. Confirmed-roster integration and monthly statements remain open.
- Existing foundation: `ShiftPayCalculator`, `ShiftPayRule`, `ShiftTypeDefinition`, shift templates

## 1. Product modes

### Personal

- A user owns and edits their own pay profile and shift types.
- Organization membership is not required.
- Personal data is scoped to the signed-in user (or local-only profile where the product's offline mode permits it).
- Personal mode must be available without organization creation, invitation, subscription, or organization API dependency.
- Personal rates are private to that user unless the user explicitly exports/shares them.

### Organization

- An organization owns shared shift-pay rules and shift-type definitions.
- Only authorized roles may create, edit, approve, or publish rules.
- Members may view/use only rules permitted by their organization role.
- Organization identifiers must be enforced at repository/API boundaries; a client-provided ID alone is not authorization.
- A user who is not in an organization cannot enter Organization mode until they join or are invited.

### Hybrid

- A user can maintain personal rules and use an organization rule set.
- The active organization must be selected when the user belongs to more than one.
- The user selects one policy:
  - `organizationFirst`
  - `personalFirst`
  - `requireSelection`
- When both sources match and policy is `requireSelection`, the app must stop and ask the user to choose; it must not calculate a combined total.
- The selected source and matched rule must be visible on every calculation row.
- Never add Personal + Organization pay for the same assignment unless a future, separately specified and explicitly approved component model is introduced.

## 2. Rule definition

Each rule should have:

- stable rule ID and schema version;
- owner/source: personal user ID or organization ID;
- name/description and active state;
- effective-from and optional effective-until dates;
- employment type;
- shift type ID;
- work-day category and date override policy;
- optional department, location, work point, and assignment purpose;
- rate method: fixed per shift, hourly, or multiplier applied to an explicitly defined base;
- amount/rate and currency code;
- decimal precision and rounding mode;
- salary-included or compensatory-time treatment where applicable;
- audit metadata and created/updated version.

The existing calculator's specific scope dimensions should be retained. More-specific rules must resolve deterministically; equal-specificity conflicts must be surfaced as configuration errors rather than resolved by arbitrary iteration order.

## 3. Shift type configuration

Users must be able to create and edit arbitrary shift types, not only fixed morning/afternoon/night enums.

Fields:
- stable ID and display name/code;
- start and end time;
- overnight indicator;
- paid/working hours and break duration;
- active/inactive state;
- optional color and display order.

Validation:
- permit shifts crossing midnight;
- reject invalid or ambiguous times;
- distinguish unpaid break from compensable working time;
- do not infer payment from the shift's name;
- do not rewrite saved templates or historical assignments when a definition changes.

## 4. Calculation lifecycle

1. Identify an assignment and its lifecycle state.
2. Exclude draft/planned assignments from actual-pay totals; forecast may be shown separately.
3. Resolve the selected profile/mode and organization context.
4. Determine the applicable rule set and date-specific work-day classification.
5. Match exactly one rule using deterministic specificity and effective-date logic.
6. Resolve Hybrid precedence/source selection.
7. Calculate from actual hours and configured formula.
8. Apply the selected source's configured decimal precision using the backend's half-up rounding contract.
9. Store an immutable snapshot with all inputs, source, rule version, formula, result, and timestamp.
10. Link the snapshot to the assignment and include it once in the monthly statement.

If no rule matches, return a distinct `notConfigured` state. Do not treat null as zero or as proof that no payment is due.

## 5. Required result states

| State | Meaning | Display |
|---|---|---|
| `calculated` | One rule matched and calculation completed | Amount and source/rule |
| `notConfigured` | No applicable rule | Needs rule setup |
| `sourceSelectionRequired` | Both Hybrid sources match under require-selection | Ask user to select one |
| `includedInSalary` | Shift is covered by base salary | No additional shift pay |
| `compensatoryTime` | Rule grants time off instead of extra cash | Show compensatory entitlement |
| `notActual` | Assignment is planned/draft | Forecast only; exclude from actual total |
| `invalidRule` | Rule configuration conflicts or is invalid | Block calculation and explain |

## 6. Persistence and historical integrity

- Use a versioned serialization format and explicit migrations.
- Store profile mode, organization context, Hybrid policy, rules, shift types, and assignment-level source selection.
- Preserve legacy template rate fields during migration; do not reinterpret or delete them without an explicit migration contract.
- Keep historical calculation snapshots immutable.
- Rule edits affect future calculations by effective date; historical statements remain reproducible.
- Use idempotency keys based on assignment/version/profile/rule context to prevent duplicate totals after retries or sync.
- Define offline conflict resolution and sync behavior before enabling cross-device editing.

## 7. Authorization

- Personal rules: owner-only access by default.
- Organization rules: role-based read/write/approve/export.
- Hybrid: personal source remains private; organization source follows organization permissions.
- Enforce access in the backend/repository layer and test cross-user/cross-organization denial.
- Audit sensitive changes with actor, timestamp, old/new values, and approval state.

## 8. Monthly statement

Every statement must provide:
- period, profile/mode, currency, and generation timestamp;
- assignment-level rows with date, shift, actual hours, department/location/work point;
- selected source, matched rule ID/version, formula inputs, rounding, and amount;
- distinct zero, included-in-salary, compensatory, not-configured, and forecast states;
- totals by shift type and other authorized groupings;
- a reconciliation showing that the statement total equals the sum of eligible assignment rows.

Do not mix forecast assignments with actual totals. Do not claim statutory payroll, tax, or legal overtime compliance.

## 10. Equal-specificity conflict handling — PR #201

- If multiple active rules match the same assignment at the same highest specificity, return a non-payable configuration conflict.
- Do not choose the first rule by list order or database iteration order.
- Return `invalid_rule` / `ambiguous_rule`, sorted conflicting rule IDs and per-source conflict detail.
- Personal and Organization modes block when their selected source conflicts.
- Hybrid `personalFirst` / `organizationFirst` block when the priority source conflicts rather than silently falling through to a lower-priority source.
- Hybrid `requireSelection` reports a rule conflict before source selection; selecting a source must not hide a conflict inside that source.
- No amount is emitted and no rule snapshot is selected for an ambiguous result.

## 9. Acceptance gates

- Personal mode can be configured and used with no organization membership.
- Organization rules are tenant-isolated and role-protected.
- Hybrid precedence works for all three policies and never double-counts.
- Rule matching is deterministic and conflicts are surfaced.
- Overnight, breaks, day categories, holidays, location, department, and work point are tested.
- Missing rule and non-cash treatments are distinct.
- Persistence survives restart and migration without historical data loss.
- Reprocessing the same assignment does not duplicate pay.
- Monthly report totals reconcile exactly to immutable detail rows.
