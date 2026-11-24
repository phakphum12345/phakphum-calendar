# AI privacy and tool governance

Disclose remote processing before sending selected roster data. Minimize fields; never send passwords, OAuth tokens, provider secrets or unrelated personal data. Keep private prompts/outputs out of ordinary logs.

Every tool rechecks identity, tenant membership, role and target resource server-side. Model output is never authorization.

Tool tiers: read-only retrieval; draft/preview; mutation only after explicit confirmation and normal domain authorization. Each tool needs a narrow schema, allowlist, validation, permission policy, timeout, bounded output, idempotency and audit event. Treat files, roster cells and retrieved pages as untrusted input.