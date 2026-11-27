# Roster vertical-layout implementation boundary

**Status:** IN PROGRESS — first integrated date-down parser path exists on PR #192; not yet accepted.
**Date:** 2026-11-27

## Delivered in the current PR #192 branch

- Explicit `datesAcrossColumns` and `datesDownRows` orientation values.
- A coordinate mapper for original zero-based worksheet row/column coordinates.
- Vertical date-axis detection and a two-phase parser integration: resolve the date structure first, then populate assignments.
- Horizontal and vertical sections can coexist in one worksheet; separate vertical tables can be discovered by date-axis column.
- Date-down sections preserve date-row index, assignment-column index, source A1 cell, source sheet metadata and normalized source cells.
- Thai month/year headings, explicit Thai date ranges, explicit Gregorian/Thai Buddhist Era date cells and Excel DateTime values are handled without inventing a period.
- Duplicate, out-of-order, unresolved and near-complete missing-date diagnostics include source coordinates.
- The Grid review page can correct a date-down row against retained source cells, rebuild the section and revalidate the anomaly set.
- The monthly roster view renders date-down sections with date rows and assignment columns.
- Regression test sources cover vertical and mixed layouts, side-by-side sections, two-phase parsing, local Grid XLSX scanner integration, explicit dates, missing/duplicate/out-of-order dates and reviewer correction.

## Current limits — do not claim complete universal import

- Automatic inference is still conservative and expects a date axis with at least seven recognizable date cells plus an assignment-header/data shape.
- Reviewer-selected orientation for genuinely ambiguous structures is not yet exposed as a complete UI decision.
- Multi-level and merged-header propagation is not fully implemented for all workbook sources.
- All left/right assignment-axis permutations and employee-columns-with-shift-values semantic reversal are not yet accepted.
- Profile hints are not yet applied consistently to the vertical axis.
- Actual X-OPD November 2569, 16 November–15 December 2569 and US Clinic ภปร.4 source workbooks have not been validated in this execution.
- Full correction, re-import reconciliation and downstream canonical import acceptance still require exact-head CI and independent review.

## Acceptance gates

1. Exact-head Flutter/Dart, widget, backend and platform workflows pass; inspect failures, skipped jobs and missing evidence individually.
2. Review page tests prove row-based corrections rebuild assignments and clear only the corrected anomaly set.
3. Original workbook fixtures validate source coordinates and section boundaries without template-specific row/column constants.
4. Independent code review and product acceptance.
5. Verify preview remains read-only and no Calendar sync or Schedule write occurs before explicit approval.

No production persistence, Google Calendar mutation, migration or deployment was performed by the parser work.
