# AI Provider and Research Foundation

## Status

Proposed implementation plan; no live provider calls are enabled by this change.

## Goals

- Offer three selectable model providers: OpenAI, Google Gemini, and Anthropic Claude.
- Add AI Support, external AI Research, internal Roster Analysis, and Research Report capabilities.
- Keep the existing deterministic roster parser and rule engine authoritative.
- Keep all provider credentials on the server, never in Flutter assets, source, preferences, or browser storage.
- Require explicit user review before any roster persistence or Google Calendar/Sheets synchronization.

## Current repository constraints

The Flutter app already contains a provider-neutral `RosterAIProvider` contract and a rule-first `HybridRosterAIAnalyzer`. The existing AI Support screen is local-only and analyzes pasted CSV/TSV in memory.

The Laravel backend currently exposes health, readiness, and client-diagnostics routes only. It does not yet provide an authenticated user identity or tenant authorization boundary for roster-bearing requests. Therefore, adding an endpoint that forwards roster data to a model is unsafe until authentication and tenant authorization are implemented and tested.

## Proposed architecture

### Provider selection

- Stable provider identifiers: `openai`, `gemini`, `claude`.
- OpenAI is the initial default selection.
- The Flutter client stores only the selected provider identifier and UI preferences.
- Backend configuration determines whether each provider is configured and available.
- The UI must distinguish `not configured`, `ready`, and `temporarily unavailable`; it must not infer readiness from the local selection.
- Model names, API keys, request limits, and provider endpoints are server-side configuration.

### Capability separation

1. **AI Support** — conversational guidance about app usage and roster workflows.
2. **AI Research** — external research with source title, publisher, URL, publication/update date when available, retrieval timestamp, and a clear distinction between evidence and generated interpretation.
3. **Roster Analysis** — deterministic parsing, counting, validation, and anomaly detection over explicitly selected, authorized data. AI may explain ambiguous findings but does not replace calculations.
4. **Research Report** — a reviewable report recording scope, date range, data snapshot reference, methods, warnings, sources, provider/model, and generation time.

External research requires a separately configured retrieval/search capability or a provider-supported grounded-search tool. A chat completion without retrieval must never be presented as web research or cited evidence.

### Data protection and authorization

Before any roster-bearing AI endpoint is enabled:

- Establish authenticated user identity on the Laravel API.
- Establish tenant/organization membership and role authorization on every request.
- Verify ownership/access to the requested roster and date range server-side; never trust client-supplied tenant IDs alone.
- Minimize payloads and prefer aggregates or pseudonymous identifiers when names are not needed.
- Do not log prompts, roster rows, employee names, Google tokens, or provider credentials.
- Apply rate limits, input-size limits, timeouts, and provider error redaction.
- Keep provider keys in deployment secrets/environment configuration only.
- Return a clear unavailable state when no provider is configured; preserve local deterministic functionality.

### Roster safety

- Existing parser/rule results remain authoritative for dates, shift codes, counts, and constraints.
- Send only unresolved fields to a model when interpretation is needed.
- Validate model output against deterministic allowlists and schema constraints.
- Treat confidence as advisory, not proof.
- Never write to Google Sheets, Google Calendar, or the canonical roster from an AI response.
- Require explicit preview and confirmation for any future apply/sync action.

## Research topics and domain requirements

Research and analysis should support the configured shift categories: เช้า, กลางวัน, บ่าย, ดึก, and on-call. Work patterns must be configurable by location and workday. The กลางวัน category may represent lunch-break coverage/substitution and may have lost-time compensation; defaults must remain editable, with compensation rules configured per shift or location. The design must not assume only private-sector or weekday-only work; government schedules, daily workers, and weekends must remain representable.

## Delivery sequence

1. READ: inspect authentication, tenant model, deployment topology, existing parser contracts, tests, and CI.
2. ANALYZE: agree API trust boundary, provider configuration, research retrieval source, retention, and data minimization.
3. MODIFY: add provider selection/status UI and capability navigation first; keep remote execution disabled until the backend security gate is satisfied.
4. TEST: test provider selection persistence, unavailable/configured states, adapter contract behavior with fakes, authorization denial, tenant isolation, rate limiting, redacted errors, citation serialization, and no-write guarantees.
5. AUDIT: inspect the diff, secrets, logs, data flow, DISKPATH manifests, and all CI checks before merge.

## Explicit non-goals for the first increment

- No API key entry or storage in Flutter.
- No anonymous endpoint that proxies requests to paid AI providers.
- No automatic roster import, modification, or calendar synchronization.
- No claim of external research until source retrieval and citations are actually implemented.
- No replacement of deterministic roster parsing with an LLM.
