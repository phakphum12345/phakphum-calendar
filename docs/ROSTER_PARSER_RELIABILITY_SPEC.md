# Roster Parser Reliability Specification

**Status:** Target behavior and regression specification; implementation status must be verified separately.  
**Prepared:** 2026-11-24  
**Related:** [Parser foundation](PARSER_FOUNDATION.md), [AI roster analyzer](AI_ROSTER_ANALYZER_LOGIC_TH.md), [Roster knowledge architecture](ROSTER_KNOWLEDGE_BASE_ARCHITECTURE_TH.md), [Master plan](UNIVERSAL_ROSTER_INTELLIGENCE_MASTER_PLAN.md)

## 1. Problem statement

A single worksheet can contain multiple independent roster tables. Each section may have its own title, date period, header orientation, employee axis, shift axis, blank columns, merged cells and validation state. A worksheet-wide period or layout assumption can shift dates or assign one section's period to another.

The parser must treat each detected section as an independent parsing unit while retaining its original worksheet coordinates.

## 2. Required invariants

1. Every section owns its detected title, source range, period candidates, layout profile and findings.
2. One section's period must never be inherited by another section unless an explicit, reviewed workbook-level rule says so.
3. Original row/column coordinates are immutable evidence. Removing blank columns or normalizing headers must not change the source coordinate.
4. Date values are resolved against the section's own period and source evidence.
5. Duplicate, missing, out-of-order or impossible dates create findings; they do not cause silent column shifts.
6. A blocking date anomaly blocks only the affected section when section boundaries are reliable.
7. If section boundaries are ambiguous, block the affected region or whole import rather than risk assigning data to the wrong section.
8. A valid section may proceed through preview even when another independent section is blocked.
9. Every inferred date, person or shift carries its evidence and resolution state.
10. No parser auto-correction may rewrite the source workbook.

## 3. Section model

A section candidate should expose, at minimum:

- source document and worksheet identity;
- stable section key;
- source start/end row and column;
- title/header cell evidence;
- date-period candidates and selected period;
- date-header row/column orientation;
- employee-name axis and shift-data region;
- merged/hidden region metadata where available;
- parser/profile version;
- confidence and unresolved ambiguities;
- validation findings.

The implementation must map this contract onto existing models before adding parallel abstractions.

## 4. Date-period resolution rules

### 4.1 Evidence precedence

Use explicit connected date ranges before isolated title tokens. A range is connected by supported separators such as hyphen, en dash, em dash or a configured Thai range word. Parse both endpoints as a pair and validate that the end is not before the start.

A safe precedence order is:

1. Explicit date range within the section title or its associated period row.
2. Explicit paired date cells within the section header.
3. A profile-defined period rule with recorded provenance.
4. A single month/year heading only when no explicit range exists.
5. Otherwise unresolved; require user selection.

Do not interpret arbitrary numbers in organization or department names as day values. Month names must be recognized from a finite locale-aware vocabulary; arbitrary Thai tokens must not become months.

If two explicit ranges disagree, do not silently choose the first. Return an ambiguity finding with both source spans.

### 4.2 Calendar conventions

- Support Thai month names/abbreviations and Gregorian month names where configured.
- Support Buddhist Era and Gregorian years with an explicit conversion rule.
- Support numeric Excel serial dates using the workbook's date system.
- Support cross-month, cross-year and leap-day periods.
- Keep inclusive date semantics explicit.
- Preserve original text and normalized ISO date values together.

### 4.3 Supplied examples as regression inputs

The following examples are derived from the user's provided transcription and should be represented as synthetic unit-test fixtures until raw workbook provenance is available.

| Section | Heading/period evidence | Expected period |
|---|---|---|
| PORTABLE | 16 พฤศจิกายน 2569 – 15 ธันวาคม 2569 | 2026-11-16 through 2026-12-15 |
| MRI | 1–30 พฤศจิกายน 2569 | 2026-11-01 through 2026-11-30 |
| X-OPD | November 2569, malformed date header | Period may be 2026-11-01 through 2026-11-30 only if supported by section evidence; malformed columns remain errors |
| GEN | Department title contains number 4; explicit 1–30 พฤศจิกายน 2569 range | 2026-11-01 through 2026-11-30 |
| US | 16 พฤศจิกายน 2569 – 15 ธันวาคม 2569 | 2026-11-16 through 2026-12-15 |
| CT Special | 16 พฤศจิกายน 2569 – 15 ธันวาคม 2569 | 2026-11-16 through 2026-12-15 |

The presence of the number 4 in a section title is not date evidence. The explicit paired range must win.

## 5. Date-header-to-column mapping

The parser must not greedily shift later cells to compensate for a missing or duplicated day.

For each section:
- retain the original column index;
- record the displayed day and raw cell value;
- calculate candidate calendar dates within the selected period;
- check uniqueness, completeness, monotonicity and expected period length;
- report the exact source column for each anomaly;
- distinguish a blank header from a merged continuation or formula-empty cell;
- use weekday headers only as independent corroborating evidence.

A global or dynamic-programming resolver may be evaluated if the current monotonic cursor algorithm cannot represent valid layouts. Any replacement must be compared against existing tests and must never optimize by silently changing source-column identity.

## 6. X-OPD malformed-header behavior

The supplied transcription indicates a duplicated day 30, a missing day 17, an apparent gap around day 26 and a later day sequence. Required behavior:

- preserve the original column positions;
- report duplicate 30 and missing expected dates separately;
- identify the affected columns and observed values;
- do not relabel the first 30 as 17 without independent evidence;
- block X-OPD conversion if date mapping is ambiguous;
- continue processing other sections only when their boundaries are independent and reliable.

Exact Excel column numbers must be derived from the original source coordinates, not guessed from a Markdown rendering.

## 7. US cross-month behavior

The expected period is 16 November 2026 through 15 December 2026. A correct parser must map day headers 16–30 to November and 1–15 to December without offsetting the first day to November 1.

A possible failure hypothesis is that a number in the department title (for example, “ภปร. 4”) is being considered before the connected date range. This is not yet a confirmed root cause. Confirm by:
1. writing a focused test against the current Thai period parser;
2. recording the actual selected period and matched source span;
3. testing the explicit cross-month range with and without the title number;
4. testing a parenthetical explicit range where a title contains another month/day token;
5. verifying no regression for month-only headings.

Do not describe this hypothesis as fixed until the test reproduces and passes after a code change.

## 8. Validation finding contract

Each finding should contain:
- stable machine-readable code;
- severity (info, warning, blocking);
- section key and source coordinates;
- expected value and observed value;
- concise explanation;
- evidence/source span;
- whether user correction is possible;
- whether the finding blocks preview, persistence or Calendar sync.

Avoid using localized display strings as error identifiers. UI messages may be translated from stable codes.

## 9. Partial import policy

- Valid sections can be previewed and confirmed independently.
- A section with blocking structural/date/person conflicts cannot be persisted as a trusted roster.
- The import summary must show accepted, blocked, skipped and unresolved sections separately.
- Skipped is not success; the user must see why a section was not imported.
- The overall import must retain a source-level audit record even when partial import is allowed.

## 10. Test matrix

Required test families:

1. Explicit date range outranks isolated day/month tokens in title.
2. Number in organization name does not become a day.
3. Thai BE year conversion and Gregorian year parsing.
4. Cross-month and cross-year period mapping.
5. Month-only fallback only when no explicit range exists.
6. Conflicting explicit ranges produce ambiguity.
7. Duplicate/missing/out-of-order day headers retain column identity.
8. Blank, merged continuation and formula-empty cells remain distinguishable when source data exposes them.
9. Multiple independent sections with different periods in one worksheet.
10. One blocked section does not corrupt another valid section.
11. Existing parser fixtures remain unchanged in expected output.
12. Leap day, year boundary and timezone-independent calendar dates.

## 11. Exit criteria

This work is accepted only when focused tests reproduce the reported behavior, regression tests cover existing parser contracts, integration tests verify the complete import path, and the preview accurately displays source evidence and section-level outcomes. Original workbook inspection is required to certify raw Excel coordinates and merged/hidden-cell provenance, but is not a prerequisite for adding the supplied transcription as synthetic parser-level tests.


## Implementation note — explicit range precedence (2026-11-24)

The parser implementation now prioritizes adjacent date tokens connected by an explicit range separator (`-`, `ถึง`, or `to`) over unrelated earlier date-like tokens in a heading. This prevents numeric unit identifiers (for example `ภปร. 4`) from displacing the actual parenthesized roster period.

If a heading contains multiple explicit ranges, parsing fails as ambiguous. The section parser must not silently convert that failure into a month-only period. Month-only fallback is retained only for headings without an explicit range expression.

Regression coverage added:
- Numbered unit identifier before a parenthesized month range.
- Ambiguous heading with multiple explicit date ranges.
- Section-level GEN heading resolution to the explicit range.

Execution status: regression tests have been added but have **not yet been executed** in this environment. Formatting and static analysis remain unverified.
