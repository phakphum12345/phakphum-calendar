# Roster vertical-layout implementation boundary

**Status:** Foundation only; end-to-end vertical import is not implemented.
**Date:** 2026-11-27

## Delivered in this change

- Explicit `datesAcrossColumns` and `datesDownRows` orientation values.
- A coordinate mapper that converts logical date/assignment offsets into original zero-based worksheet row/column coordinates.
- Focused tests for both orientations and rejection of negative offsets/origins.

## Current limitation

The existing `MonthlyRosterSectionParser` is still horizontal: it discovers date headers by worksheet row and populates assignments by date column. This foundation does not enable vertical roster import and must not be presented as such.

## Required integration work

1. Detect or accept reviewer-selected orientation independently for each section; retain evidence and confidence for automatic detection.
2. Resolve date and assignment axes independently without transposing or rewriting source cells.
3. Retain both row and column source coordinates and exact A1 provenance for date headers, assignment values, and labels.
4. Validate date anomalies along the selected date axis and extract assignments along the orthogonal axis.
5. Support merged cells, multi-level headers, multiple sections and mixed orientations within one worksheet.
6. Add end-to-end parser, preview, correction, persistence, and Calendar-sync-gating tests using horizontal, vertical, and mixed-orientation fixtures.

Until all six items pass, vertical-layout support remains incomplete. No production persistence or Calendar mutation is authorized by this foundation.
