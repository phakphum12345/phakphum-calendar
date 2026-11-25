# Shift-pay lifecycle

Define shift types/effective dates; create versioned rule under Personal or Organization; validate dimensions/rate/currency/treatment/interval; resolve source; match one rule for confirmed assignment; calculate from actual inputs; persist immutable snapshot; aggregate monthly statement.

Rule identity includes owner/source, stable ID, version, effective dates, currency, treatment, dimensions, formula and audit metadata. Editing creates a new version and never rewrites historical calculations. Distinguish additional pay, salary-included, compensatory, not configured, invalid/ambiguous and not eligible.