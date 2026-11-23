# AI Support Chat

## Included
- Thai-language chat screen accessible from the app bar via **AI Support**.
- Suggested prompts for incomplete roster parsing, shift codes, pre-sync checks, and Excel/CSV imports.
- Local, deterministic guidance for common questions.
- Local analysis of pasted CSV/TSV-style tables using the existing `AiRosterAnalyzer`; reports row counts, uncertain duty types, low confidence, and date warnings.

## Safety and current limits
- No network request or external AI provider is used.
- The page does not automatically read the active roster, write data, or trigger Google Calendar sync.
- Pasted table data is analyzed in memory only; results are advisory and never applied automatically.
- Users must verify all shift codes, dates, names, and times against the source before saving or syncing.
- Excel file picking, automatic access to the currently loaded roster, and a live AI provider are not connected yet.

## Next integration step
Connect source-specific adapters and the active roster to a typed support service. Keep provider secrets server-side, minimize data sent to any provider, and require explicit user review before applying proposals or syncing.
