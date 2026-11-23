# Hybrid Roster AI Analyzer

## Goal

Add an optional AI-assisted interpretation layer across Google Sheets, Excel/CSV,
and image/OCR imports without replacing the existing deterministic readers.
This first increment defines a provider-neutral, testable contract. It does not
ship a live model integration or transmit roster data.

## Pipeline

1. Read the source using its existing adapter (Sheets, spreadsheet/file, or OCR).
2. Apply configured shift-code/time rules and deterministic parser rules.
3. Mark only unresolved fields as ambiguous.
4. If an AI provider has been explicitly configured, send the minimum context
   for those ambiguous fields only.
5. Accept a model proposal only if its value is in the supplied allowlist and
   confidence is finite and meets the configured threshold.
6. Show rule-resolved values, AI proposals, and unresolved values in review UI.
7. Require the user to confirm before any persistence or calendar sync.

## Module boundaries

- `RosterRuleResolver`: adapts existing parser and shift-template rules.
- `RosterAIProvider`: provider-neutral boundary for a future local or server-side model.
- `HybridRosterAIAnalyzer`: invokes rules first and AI only after an ambiguous result.
- `RosterFieldAnalysis`: review proposal only; it does not expose write/sync actions.

## Safety and privacy

- No API keys, tokens, or model credentials in Flutter source or app builds.
- No provider is configured by default; ambiguous fields remain in review.
- Never treat model confidence as proof of correctness.
- Reject values outside the deterministic allowlist.
- Keep original source text and cell/row references available for user verification.
- Remote AI must be opt-in, server-proxied, and data-minimized; do not transmit a
  full roster when a single ambiguous field is sufficient.
- No automatic writes to Google Sheets or Google Calendar.
- Keep a deterministic-only fallback when the provider is unavailable.

## Next integration steps

1. Connect Sheets, spreadsheet, and OCR adapters to a common field-input mapper.
2. Implement a deterministic rule resolver from configured shift codes, times,
   locations, and known date formats.
3. Add a review UI showing source value, proposed value, reason, and confirm/edit actions.
4. Implement an authenticated server-side provider only after privacy and deployment
   configuration are agreed.
5. Add integration tests that assert no calendar write occurs before explicit user confirmation.

## Validation status

This PR is a foundation/contract only. It does not claim to recognize images or
provide live AI responses until a provider and source adapters are integrated.
