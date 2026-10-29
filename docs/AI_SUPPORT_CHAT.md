# AI Support Chat prototype

## Included
- Thai-language chat screen accessible from the app bar via **AI Support**.
- Suggested prompts for incomplete roster parsing, shift codes, pre-sync checks, and Excel/CSV imports.
- Local, deterministic guidance for those topics.
- A visible notice that the screen is a prototype and is not connected to a live AI service.

## Safety and current limits
- No network request or external AI provider is used.
- The page does not read current roster contents, write data, or trigger Google Calendar sync.
- Replies are general guidance, not a diagnosis of a specific roster.
- Users must verify all shift codes, dates, names, and times against the source before saving or syncing.

## Next integration step
After the provider-neutral analyzer and source adapters are reviewed, connect chat intents to a typed service interface. Keep secrets server-side, minimize data sent to any provider, and require explicit user review before applying proposals or syncing.
