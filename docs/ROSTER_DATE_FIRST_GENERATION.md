# Date-first roster generation

## Purpose

Roster sheets can contain several independent blocks in one worksheet. A single
worksheet title or month must not determine the dates for every block. The
parser therefore exposes a two-phase generation contract.

## Phase 1 — generate the roster structure

`MonthlyRosterSectionParser.generateDateStructure(input)` reads only the
section structure:

- section heading and its own declared date period;
- original spreadsheet column for each displayed day;
- resolved calendar date for each date column;
- shift-row label and original row index.

The result is a `MonthlyRosterParseReport` whose sections contain
`dateColumns` and `rosterRows`. Its `assignments` list is empty by design.
This phase is deterministic and does not need employee names.

Each section resolves dates only inside its own declared range. A range such as
16 November 2569–15 December 2569 can coexist with a November-only section in
the same sheet. Buddhist years are normalized to Gregorian dates internally.

## Phase 2 — populate employee assignments

`MonthlyRosterSectionParser.populateAssignments(input, structure)` uses the
row and column coordinates from Phase 1 to read employee names. It does not
recalculate dates, infer another section's month, or change the source sheet.
The normal `parse(input)` method composes both phases for existing callers.

## Fail-closed rules

- An explicit section date range takes precedence over the worksheet title.
- A worksheet-title fallback is allowed only when the sheet contains one
  recognized date grid.
- When a multi-section sheet has an undated section, that section is skipped
  with a warning instead of borrowing a month from another section.
- Displayed day numbers outside the section's date range remain warnings and
  are not assigned a guessed date.
- Empty worker cells do not produce calendar assignments.
- Calendar writes remain behind the existing Preview/Diff and explicit
  confirmation workflow. This parser change does not sync or delete events.

## Regression coverage

The parser tests cover independent November and 16 November–15 December
sections in one sheet, explicit Phase 1 output before names are populated,
Phase 2 worker assignment, and rejection of an undated section that would
otherwise inherit the worksheet month.

## Production parser boundary

The production `ShiftParser` stops searching for a section period at the preceding date-header grid. An undated block in a multi-block worksheet is skipped instead of inheriting the prior block's period or the worksheet tab month. The worksheet-title fallback remains available for a single date grid.
