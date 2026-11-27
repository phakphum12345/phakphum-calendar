# Shift Parser Foundation

## Purpose

The parser foundation converts Google Sheets API responses into a stable,
testable representation before hospital-specific parsing begins.

## Extracted cell information

Each populated API cell can carry:

- zero-based row and column indexes;
- A1 coordinate;
- formatted value;
- effective raw value;
- formula;
- effective background color;
- effective number format;
- merged-range membership;
- merged-range anchor coordinate.

## Merged ranges

Google Sheets merged ranges use zero-based, end-exclusive grid coordinates.
SCE preserves this exact model and calculates the anchor as the top-left cell.

## Background colors

SCE prefers `backgroundColorStyle.rgbColor` and falls back to the deprecated
`backgroundColor` field. Theme-color resolution is not implemented yet.

Colors are stored as normalized red, green, blue, and alpha values from 0 to 1.
Business meanings are resolved through configurable rules and tolerance rather
than hardcoded color names.

## Important limitation

The exact Google color values used by the hospital roster are still unknown.
Graphite, Tomato, Lavender, Purple, Avocado, Banana, Parrot, and default blue
must be sampled from a real roster before activating relationship rules.

## Next parser step

Create a roster layout profile that identifies:

- date headers;
- employee-name column;
- shift rows or columns;
- category labels;
- user identity;
- original owner and actual worker fields.

No layout assumption should be added until a sample roster is available.

## Current local Grid import extension — PR #192 (2026-11-27)

PR #192 extends the existing parser boundary rather than introducing a separate parser per file type:

- XLSX worksheet reads preserve source row/column indexes, A1 coordinates, merged-cell anchor/membership and effective background color value.
- CSV/TSV/TXT file selection is connected to the same Grid scanner, section parser, review session and correction workflow.
- Date-axis/orientation detection is performed per roster section, allowing horizontal, vertical and mixed sections in one workbook.
- Source fingerprint and section provenance remain attached through review and conditional Schedule persistence.
- Date-axis validation occurs before worker assignment; ambiguous or invalid date sequences remain review/blocking diagnostics.

**Current evidence:** PR #192 head `b3dd82757c9652a774b35f7a975170a0bc6f26af` has new exact-head CI pending after the latest source/test changes. PR #199's standalone orientation foundation was closed without merge after its work was superseded by #192.

**Known limitations:** theme-color resolution remains unimplemented; source color values must be validated against real workbooks. Original X-OPD November 2569, 16 Nov–15 Dec 2569 and US Clinic ภปร.4 workbook acceptance is still pending. Synthetic fixtures do not establish correctness for those original files.

