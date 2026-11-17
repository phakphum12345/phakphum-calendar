# Synthetic roster regression corpus

## Purpose

This corpus provides deterministic regression inputs when no real roster workbook
is available. Every name and assignment is fictional. These fixtures validate
specific parser contracts; they are not evidence of accuracy against unseen
hospital templates.

## Scenario coverage

- Standard short weekly date grid and sparse assignments.
- Shifted date/name columns constrained by `RosterLayoutProfile`.
- Multiple independently dated sections in one worksheet.
- Out-of-range displayed dates produce diagnostics and are not guessed.
- Short date headers explicitly labelled `วันที่`, with empty worker cells.
- Leap-day and cross-month date resolution.
- Multiple configured shift-label columns, with rightmost non-empty label selection and restricted worker columns.
- Sections without their own date range are skipped rather than borrowing another section or the sheet month.
- Seven-day numeric headers without an explicit `วันที่` label.

## Running

```bash
flutter test test/synthetic_roster_corpus_test.dart
```

## Expected safety properties

- Date structure is resolved before worker names are populated.
- Source-cell coordinates remain attached to every parsed assignment.
- Empty cells do not create assignments.
- Dates outside the declared period are excluded with a warning.
- Fictional fixture names must never be treated as production staff data.
- These tests do not write to Google Sheets or Google Calendar.

## Evidence boundary

A passing synthetic corpus means only that the listed scenarios behave as
specified. Real-workbook compatibility remains **UNKNOWN** until representative
workbooks are supplied and tested with personal information removed.
