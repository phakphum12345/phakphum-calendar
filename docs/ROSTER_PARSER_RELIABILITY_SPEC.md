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

If a heading contains multiple explicit ranges, parsing fails as ambiguous. The section parser must not silently convert that failure into a month-only period or borrow the worksheet-tab month, including when the worksheet contains only one section. Month-only fallback is retained only for headings without an explicit range expression.

Regression coverage added:
- Numbered unit identifier before a parenthesized month range.
- Ambiguous heading with multiple explicit date ranges, including proof that a single-section worksheet does not fall back to its tab month.
- Section-level GEN heading resolution to the explicit range.
- A malformed X-OPD duplicate-day header is blocked while a valid PORTABLE section in the same worksheet remains convertible.

## Execution evidence — 2026-11-26

The following checks have now been executed against the parser changes:

- Dart / Flutter quality (static analysis, full unit suite and integration tests): **PASS** at commit `6651409891716a7c787f65d746977504106de8e5` ([workflow](https://github.com/phakphum12345/phakphum-calendar/actions/runs/45769304874)).
- Non-mutating Dart formatting baseline: **PASS** at the same commit ([workflow](https://github.com/phakphum12345/phakphum-calendar/actions/runs/45769305220)).
- Web build, Linux release build, cross-platform runtime and isolated Schedule CAS contract: **PASS** at the same commit ([web](https://github.com/phakphum12345/phakphum-calendar/actions/runs/45769304835), [Linux](https://github.com/phakphum12345/phakphum-calendar/actions/runs/45769304707), [runtime](https://github.com/phakphum12345/phakphum-calendar/actions/runs/45769304766), [CAS](https://github.com/phakphum12345/phakphum-calendar/actions/runs/45769304834)).
- Laravel Backend CI, including Pint formatting and Laravel tests: **PASS** at commit `772dea9bb0236ef251a4469fc93bbcea5432e568` ([workflow](https://github.com/phakphum12345/phakphum-calendar/actions/runs/45769999225)).

The parser source and regression tests were unchanged between the Flutter-tested commit and the later PHP-only formatting commits. The latest exact-head cross-platform workflow and pull-request gate must still be checked before release. This evidence does not authorize merge, deployment or Calendar synchronization.


## 12. Universal layout support — flexible input, strict interpretation

This parser is **not bound to a named workbook, department, worksheet title, fixed month, fixed row number, fixed column count or one visual template**. The examples elsewhere in this document are regression cases, not accepted input templates. A new workbook must not require a code change merely because its department name, sheet name, number of columns or roster period differs.

### 12.1 Supported input-shape principles

The parser should discover a roster from workbook evidence and normalize it into the canonical section/assignment model. It must be designed to accommodate, where the source format exposes sufficient evidence:

- Dates across columns with people across rows.
- Dates down rows with people or shifts across columns.
- Multiple independent roster tables on one worksheet.
- Multiple worksheets, departments, units or schedule periods in one workbook.
- One continuous period, cross-month/cross-year periods, partial months and schedules spanning six or more months.
- One-row, multi-row and multi-level headers; repeated headers; title and period rows above or beside the table.
- Variable numbers and ordering of columns, rows, staff, shifts and sections.
- Blank spacer rows/columns, hidden rows/columns, merged cells and formula-derived values.
- Date cells represented as native date values, Excel serials, supported text formats, or split day/month/year cells.
- Localized Thai and Gregorian date labels, Buddhist Era and Gregorian years.
- Optional metadata columns (for example department, role, shift type, note or status) without assuming their fixed positions.

This is a capability target, not a claim that every arbitrary spreadsheet can be interpreted without review. Unsupported or insufficiently evidenced structures must produce a clear unresolved result rather than a guessed roster.

### 12.2 Discovery and normalization pipeline

Keep discovery separate from assignment interpretation. The logical pipeline is:

1. **Read source faithfully** — retain workbook/sheet identity, cell values and types, formulas/cached values when available, merged ranges, hidden-state metadata and original row/column coordinates.
2. **Discover candidate regions** — identify possible tables/sections from populated regions, whitespace boundaries, repeated header patterns, titles and date evidence. Do not use a fixed row/column address as the discovery rule.
3. **Classify axes and headers** — evaluate row-oriented and column-oriented date/person/shift arrangements, including multi-level headers. Record competing candidates and evidence.
4. **Resolve section boundaries and periods** — resolve each candidate independently. Never borrow a neighboring section's period merely because it is the only known period on the sheet.
5. **Map source cells to semantic fields** — identify date, person, shift, status and metadata fields while preserving source coordinates and evidence.
6. **Normalize assignments** — produce canonical records only after the section's structure and date mapping are sufficiently resolved.
7. **Validate and score confidence** — check uniqueness, completeness, chronology, period consistency, person identity and assignment conflicts.
8. **Review unresolved decisions** — present evidence and allow explicit user mapping/correction without changing the original source.
9. **Revalidate from source** — every correction must rebuild affected normalized records and rerun all dependent validations.
10. **Commit only approved, valid records** — blocked or unresolved sections cannot silently enter trusted Schedule persistence or Calendar synchronization.

Implementations may combine internal stages for performance, but must preserve these boundaries and observable outcomes.

### 12.3 Layout inference is evidence-based

For every candidate layout, retain the evidence used to infer:

- orientation (dates on rows or columns);
- header row/column ranges and hierarchy;
- date axis and its source cells;
- person/name axis and identity evidence;
- shift/value region;
- section title and period source;
- table bounds and blank/merged-cell interpretation;
- optional field mappings;
- confidence, alternatives and unresolved ambiguities.

Do not make one heuristic (for example, “seven date cells means a header”) the sole definition of a valid table. Heuristics may nominate candidates; the combined evidence and validation determine whether a candidate is safe to normalize.

### 12.4 Profiles are optional hints, never format locks

A user-defined or previously learned layout profile may improve discovery, but:

- A profile is optional. A workbook must still be importable through automatic discovery and review without one.
- A profile is a hint, not proof. Current source evidence takes precedence when it conflicts with a profile.
- Profile fields must not force fixed sheet names, row numbers, column counts, date ranges or staff positions unless the user explicitly chooses a strict mapping for that import.
- A profile mismatch must be visible and reviewable; it must not silently discard source regions or coerce cells into the wrong fields.
- Profiles must be versioned and scoped (for example, user/workspace/source family) without making the parser dependent on one organization or workbook.
- User corrections may be offered as a candidate profile update only after explicit confirmation. Never silently rewrite a saved profile from one ambiguous workbook.

### 12.5 Canonical output and provenance

All supported input layouts must converge on one canonical representation. Each normalized assignment should retain, directly or through a stable provenance reference:

- source document identity and source revision/fingerprint;
- worksheet identity and section identity;
- original cell/row/column coordinates for date, person, shift and status evidence;
- raw source values and normalized values;
- mapping method (automatic, profile-assisted or user-confirmed);
- confidence and validation findings;
- correction/review actor and decision metadata where available.

The canonical model must not encode presentation assumptions such as “date is always a column” or “staff is always a row”. Layout-specific details belong in the source mapping/provenance layer.

### 12.6 Ambiguity and safety rules

- If both orientations are plausible, show the competing interpretations and request a mapping decision; do not pick one solely because it matches a familiar fixture.
- If a section boundary cannot be established safely, block the ambiguous region rather than merge neighboring tables.
- If date headers are incomplete, duplicated or out of order, preserve source positions and block only the affected section when isolation is reliable.
- If person identity is uncertain or aliases collide, do not silently assign a shift to a different person.
- Unknown cell values must remain visible as unmapped evidence; do not drop them merely because they are not in the current shift dictionary.
- Empty cells are not equivalent to confirmed days off. A genuinely empty date/assignment may be acknowledged only through an explicit, auditable user decision.
- A correction is valid only against the source revision from which the preview was built. If the source changes, invalidate stale review decisions and require re-evaluation.
- No automatic correction may move an assignment to another date, person or shift without independent source evidence or explicit user confirmation.

### 12.7 Parameterized layout test matrix

Tests must be generated from layout dimensions and semantic variations, not copied from one workbook. At minimum, parameterize combinations of:

| Dimension | Variations |
|---|---|
| Date axis | columns; rows |
| Person axis | rows; columns; multi-column identity |
| Header depth | one row/column; multiple levels; repeated headers |
| Sections | one; multiple same-sheet; multiple worksheets |
| Period | one month; cross-month; cross-year; six-plus months; partial range |
| Date encoding | native date; Excel serial; localized text; split date components |
| Cell geometry | contiguous; spacer rows/columns; merged headers; hidden rows/columns |
| Metadata | absent; reordered; additional unknown columns |
| Data quality | complete; blank; duplicate; missing; out-of-order; conflicting |
| Profile | absent; matching hint; partial hint; stale/conflicting hint |
| Review | no correction; one correction; repeated correction; source changed after preview |

For each generated case, assert both the normalized semantic result and the original source-coordinate mapping. Include negative cases where the correct outcome is ambiguity/blocking rather than successful import. Add metamorphic checks: inserting harmless spacer rows/columns or renaming a sheet/department must not change the semantic assignments; permuting optional metadata columns must not change date/person/shift mapping when headers still identify them.

### 12.8 Explicit non-goals and limitations

- Do not promise support for every arbitrary spreadsheet, image, PDF or OCR layout. Each new source modality needs its own reader, evidence model and accuracy/consent tests.
- Do not use AI/LLM guesses as authoritative date, person or shift assignments. AI may propose mappings with evidence for user review.
- Do not make the X-OPD, PORTABLE, MRI, US, GEN or any other named example the canonical template.
- Do not require users to preconfigure a profile before importing a new format.
- Do not trade correctness for a green import status. An explicit blocked/unresolved result is preferable to a plausible but incorrect roster.

### 12.9 Acceptance criteria for universal-format readiness

Universal-format readiness is not established by passing one named workbook. It requires:

1. Parameterized tests across the layout dimensions above, including both orientations and multiple independent sections.
2. Metamorphic tests proving harmless sheet renames, department renames, spacer insertion and optional-column reordering do not change semantic output.
3. Negative tests proving ambiguous layouts, missing dates, duplicate dates and uncertain identities are blocked with actionable findings.
4. Correction tests proving source-revision checks, repeated corrections, full assignment reconstruction and revalidation.
5. End-to-end import-preview-review-persistence tests showing provenance survives each boundary.
6. A documented list of actual reader limitations (for example, unsupported formula caches or merged-cell semantics) rather than an unqualified “supports all formats” claim.
7. Regression coverage for every reported real-world failure, while keeping those workbooks as examples rather than hard-coded templates.

A release may claim only the layout families exercised by the current exact-head test evidence. “Flexible” means new layouts can be discovered and reviewed without hard-coded workbook identity; it does not mean unsafe or unsupported inputs are silently accepted.
