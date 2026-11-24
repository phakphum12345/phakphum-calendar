# AI provider and backend contract

Client requests identify capability, locale, request ID and optional selected context. Server derives identity from authenticated session; never trusts client-supplied user or organization IDs.

Backend authenticates/authorizes every request, loads context after permission checks, applies tenant scope, quotas, payload limits and timeouts, keeps provider credentials server-side, validates structured output and returns typed failures.

Provider adapters expose readiness, provider/model identity, schemas, cancellation, limits and normalized errors. Local deterministic features remain available without external services. No paid provider is added by default. Mocks test contracts but do not prove live readiness.