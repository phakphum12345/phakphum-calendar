# AI Assistant — End-to-End Real-World Readiness

- Repository: `phakphum12345/phakphum-calendar`
- Added to documentation package: 2026-11-24
- Status: **NOT READY for real-world AI assistant use**
- Scope: AI Support, roster analysis, AI-assisted interpretation, external research, and research reports
- This document is an implementation and acceptance contract, not a claim that a live provider or complete agent is already available.

## 1. Executive finding

The repository contains useful AI-related foundations, but the current documented application is not yet a fully operational, general-purpose AI assistant.

Verified from the current documentation:
- The AI Support screen is a Thai-language, local-only help surface with deterministic guidance.
- It can analyze pasted CSV/TSV-style tables in memory using the existing roster analyzer.
- It does not make network requests, use a live model provider, automatically read the active roster, or apply changes.
- A provider-neutral `RosterAIProvider` contract and rule-first `HybridRosterAIAnalyzer` exist, but no provider is configured by default and no live provider execution is enabled.
- The documented backend has no roster-bearing AI endpoint. Identity and organization routes do not by themselves authorize AI access to roster data.
- External research is not real research unless retrieval/search is implemented and sources are returned. A model response alone must not be presented as sourced research.
- The smart roster generator is deterministic; “smart” does not mean it calls an LLM.

Therefore, the current state is a **local AI-support prototype plus provider-neutral foundations**, not a working live AI assistant. Re-audit source code and runtime before implementation because documentation can become stale.

## 2. Product capabilities to deliver

### 2.1 AI Support
- Answer Thai and English questions about using the app, shift setup, imports, calendar comparison, synchronization, and troubleshooting.
- Explain what the assistant can and cannot access.
- Use application help content and versioned product documentation as its knowledge base.
- Show when an answer is based on local documentation versus an external source.
- Provide actionable next steps, not generic filler.
- Retain conversation context only within the declared user/session privacy policy.

### 2.2 Roster Analysis Assistant
- Work only on a roster the user explicitly selected and is authorized to access.
- Reuse deterministic readers, date parsing, shift-code rules, and validation first.
- Explain missing dates, ambiguous names, unknown shifts, duplicates, conflicts, and low-confidence fields.
- Show evidence including source file/sheet/cell/row, raw value, normalized value, and reason.
- Never let a model invent dates, shift times, staff identity, or payment rules.
- Keep proposed interpretations separate from confirmed roster records.

### 2.3 AI Research
- Search/retrieve external sources only through an explicitly configured retrieval capability.
- Return source title, publisher/domain, URL, publication/update date when available, retrieval time, and the specific claims supported.
- Distinguish quoted/source-backed facts, assistant synthesis, assumptions, and unknowns.
- If retrieval is unavailable, clearly say that live research is unavailable; do not fabricate citations or imply browsing occurred.

### 2.4 Research Reports
- Generate reviewable reports with question, scope, date range, data snapshot reference, method, sources, provider/model, warnings, generation time, and limitations.
- Allow user preview, edit, export, and deletion according to retention policy.
- Preserve provenance so a report can be audited and reproduced where feasible.

### 2.5 Tool-assisted actions — staged rollout
- Stage 1: read-only answers and analysis.
- Stage 2: prepare drafts/previews such as roster corrections or calendar sync plans.
- Stage 3: execute only explicitly authorized actions after a clear preview and user confirmation.
- Every tool must have a typed schema, permission check, timeout, bounded input/output, audit event, and deterministic error response.
- Never give the model direct database, filesystem, Google token, or unrestricted API access.

## 3. Current gap register

| ID | Gap | Documented current state | Required result |
|---|---|---|---|
| AI-001 | Live provider execution | No live provider enabled | At least one verified provider adapter works end-to-end when configured |
| AI-002 | Provider configuration | Provider-neutral contract only; no provider configured by default | Server-side provider readiness and safe configuration |
| AI-003 | Backend execution boundary | No roster-bearing AI endpoint documented | Authenticated, authorized, rate-limited server endpoint |
| AI-004 | Active context | AI Support does not automatically read active roster | Explicit user-selected context with permission and data-minimization |
| AI-005 | Conversation lifecycle | Current support is local deterministic guidance | Session/message lifecycle, cancellation, errors, and bounded context |
| AI-006 | Research retrieval | No verified live retrieval flow | Real retrieval, provenance, and citation validation |
| AI-007 | Tool execution | No safe end-to-end assistant tool workflow documented | Typed allowlisted tools with preview/confirmation and audit |
| AI-008 | User privacy | Roster transmission not enabled by default | Explicit consent, minimization, retention, deletion, redaction |
| AI-009 | Availability and cost | Live provider is not configured | Clear unavailable state, quotas, limits, and cost controls |
| AI-010 | Runtime proof | Documentation describes foundations, not live operation | Normal-user end-to-end tests on deployed supported targets |

Do not mark a gap PASS because a screen, interface, mock provider, unit test, or build exists.

## 4. Target architecture

### 4.1 Flutter application
- AI Assistant entry point and capability navigation.
- Conversation view with streaming/non-streaming states, cancel/retry, and clear error messages.
- Context selector: no context, selected roster, selected report, or selected help topic.
- Provider status display derived from backend readiness; never claim ready from a local preference.
- Review panel for citations, roster findings, proposed changes, and action previews.
- Accessible Thai/English UI and responsive behavior.

### 4.2 Backend trust boundary
- Authenticate the user for every private request.
- Authorize access to each requested roster, organization, report, and action on the server.
- Verify organization membership and role; never trust a client-supplied organization ID alone.
- Enforce per-user and per-organization quotas, request size, timeouts, concurrency limits, and abuse controls.
- Keep provider keys and retrieval credentials in deployment secrets/environment only.
- Redact provider errors and never log tokens, raw roster content, employee names, or full prompts by default.
- Return explicit states such as not configured, unauthorized, rate limited, timeout, provider unavailable, invalid response, and success.
- Use a provider-neutral service interface so providers can be swapped without changing the Flutter UI.

### 4.3 Provider strategy and zero-cost constraint
- Keep the application usable without a paid AI provider: deterministic help, roster parsing, validation, and manual review must continue.
- Do not introduce a paid provider, paid search API, hosted vector database, or new paid infrastructure without explicit approval.
- Prefer local deterministic capabilities and existing infrastructure first.
- Provider identifiers may include OpenAI, Gemini, and Claude only when each is actually configured and verified; selecting a provider in UI does not mean it is available.
- Make model, endpoint, timeout, token limit, quota, and provider status server-side configuration.
- Do not embed provider API keys in Flutter, web assets, source control, app preferences, or local browser storage.
- If no provider is configured, display a useful offline/local mode rather than a fake AI response.

### 4.4 Retrieval and knowledge
- Version the app-help knowledge base and map each answer to the relevant document/version.
- External research must use a real retrieval source and preserve provenance.
- Separate internal product documentation from public web sources and private user data.
- Do not put personal roster data into a shared/global knowledge base.
- Use only reviewed, non-sensitive patterns for shared knowledge.

### 4.5 Model output contract
- Require structured responses with capability, answer, claims, citations, proposed operations, warnings, and uncertainty.
- Validate schema, maximum sizes, URLs, and citation references server-side.
- Treat model confidence as advisory only.
- Reject malformed output and values outside allowlists.
- Never treat generated content as an authorization decision or source of truth.

## 5. Security, privacy, and governance

- Explicitly disclose when user data will be sent to an external provider.
- Ask consent at the point of use for roster-bearing remote analysis; provide local-only fallback.
- Send only the minimum necessary fields; pseudonymize staff names where identity is not needed.
- Never send Google access/refresh tokens, passwords, secrets, or unrelated personal data to a model.
- Enforce tenant isolation and owner/member/payroll role rules server-side.
- Keep private prompts and outputs out of ordinary application logs.
- Define retention and deletion for conversation history, reports, cached context, and provider traces.
- Provide user-visible clear-history and delete-report flows consistent with the declared retention policy.
- Rate-limit and defend against prompt injection in uploaded files, spreadsheet cells, retrieved pages, and tool results.
- Treat external content and imported documents as untrusted data, never as instructions to override system policy.
- Require human confirmation for any change to canonical roster, Google Calendar, Google Sheets, pay rules, or organization settings.
- Record actor, action, target, timestamp, confirmation, and outcome for every executed tool action.

## 6. Implementation phases

### Phase A — repository and runtime audit
- Inspect actual AI Support screen, provider interfaces, service wiring, backend routes, authentication, organization authorization, deployment configuration, tests, and current runtime.
- Trace one user message from UI to final response.
- Verify whether any live provider can actually be called; do not infer from a provider interface.
- Identify duplicated AI entry points and reuse existing modules instead of creating competing stacks.
- Publish file-level findings and exact evidence.

### Phase B — reliable local assistant
- Connect the support screen to a typed local assistant service.
- Load relevant versioned help documentation.
- Support user-selected context without automatic broad roster access.
- Improve deterministic help and roster diagnostics.
- Add structured error states, cancellation, session reset, and accessibility.
- Test completely offline.

### Phase C — secure provider execution
- Add server-side provider configuration and readiness endpoint.
- Add authenticated chat endpoint with authorization, limits, timeouts, and redaction.
- Add at least one provider adapter only after owner-approved provider and infrastructure choices.
- Add a fake provider for deterministic tests; fake-provider tests do not count as live-provider proof.
- Verify a real configured provider in a controlled environment without exposing credentials.

### Phase D — roster context and analysis
- Connect selected roster adapters through a common, typed context object.
- Keep deterministic parser and rules authoritative.
- Ask AI only to explain or propose interpretation for unresolved fields.
- Show raw evidence and alternatives.
- Require explicit confirmation before applying any proposal.

### Phase E — real research and reports
- Implement retrieval/search source, provenance schema, URL/date validation, and source-grounded synthesis.
- Add report generation, review, export, and retention.
- Test retrieval failure and unsupported claims.
- Do not label a plain model completion as research.

### Phase F — bounded tools and actions
- Define an allowlist of narrow read-only tools first.
- Add permission checks and audit logs.
- Add preview-only write proposals.
- Enable a write action only after separate approval, integration tests, and explicit confirmation UX.
- Preserve existing calendar sync confirmation guard; AI must not bypass it.

### Phase G — production verification
- Test with a normal non-owner account and a least-privilege organization member.
- Test Personal mode without organization membership.
- Test provider unavailable, revoked credentials, timeout, rate limit, invalid output, and network loss.
- Verify on every platform where AI Assistant is advertised.
- Verify deployed version and exact source SHA.
- Publish supported-capability matrix and operational runbook.

## 7. End-to-end user journeys

1. User opens AI Assistant while offline and receives useful local help without a fabricated live response.
2. User asks a product question and receives an answer linked to the correct versioned app documentation.
3. User selects one roster and requests analysis; assistant displays findings with source-cell evidence and uncertainty.
4. User asks for external research; assistant retrieves sources or clearly reports retrieval unavailable.
5. User requests a research report; assistant creates a reviewable report with provenance and warnings.
6. User asks to prepare a roster correction; assistant shows a diff and waits for confirmation.
7. User asks to sync; assistant prepares the existing calendar preview and cannot call sync without the normal confirmation flow.
8. User has no organization; Personal/local features remain usable without organization access.
9. Provider is unconfigured or unavailable; app shows a truthful state and deterministic fallback.

## 8. Acceptance matrix

| ID | Test | PASS evidence |
|---|---|---|
| AI-E2E-001 | Offline support | Local help works with network disabled; no fake provider response |
| AI-E2E-002 | Documentation-grounded answer | Answer points to an existing, relevant, versioned help source |
| AI-E2E-003 | Live provider | Real configured provider returns a validated response through backend; fake adapter is insufficient |
| AI-E2E-004 | Provider secret boundary | No provider secret in app bundle, logs, responses, or repository |
| AI-E2E-005 | User authentication | Unauthenticated private request is denied |
| AI-E2E-006 | Tenant isolation | Cross-user and cross-organization roster access is denied |
| AI-E2E-007 | Context minimization | Only selected necessary roster fields are sent |
| AI-E2E-008 | Uncertain roster data | Unknown fields remain unresolved; evidence and alternatives are shown |
| AI-E2E-009 | No automatic mutation | AI output cannot modify roster/calendar without explicit confirmation |
| AI-E2E-010 | Existing sync guard | Calendar sync still requires normal preview and confirmation |
| AI-E2E-011 | Real research | Each external claim has a valid retrieved source; no fabricated citations |
| AI-E2E-012 | Research unavailable | Assistant clearly reports unavailable and does not invent sources |
| AI-E2E-013 | Provider failure | Timeout, quota, revoked key, malformed output, and outage show safe actionable errors |
| AI-E2E-014 | Abuse controls | Rate limits, request-size limits, and concurrency limits are enforced |
| AI-E2E-015 | History and deletion | Retention, clear-history, and report deletion match policy |
| AI-E2E-016 | Normal user | End-to-end journey works for a non-owner account |
| AI-E2E-017 | Personal mode | User can use supported assistant features without joining an organization |
| AI-E2E-018 | Platform support | Each advertised platform passes install, auth, chat, and failure-state tests |
| AI-E2E-019 | Runtime provenance | Test evidence records app version, environment, and exact deployed SHA |
| AI-E2E-020 | No-cost fallback | Core calendar/roster workflows remain usable without a paid AI provider |

## 9. Definition of done

AI Assistant may be labelled **usable in production** only when:
1. the local assistant works offline and is honest about its capabilities;
2. at least one explicitly approved real provider is integrated and verified end-to-end, if live AI is part of the advertised feature;
3. authenticated backend access and tenant authorization are enforced;
4. selected roster context is minimized and private;
5. research uses real retrieval and traceable citations;
6. tool actions are bounded, audited, and require confirmation;
7. a normal user completes the end-to-end journeys;
8. failure, privacy, cost, and retention behavior pass acceptance tests;
9. exact deployment/runtime evidence is recorded.

Until then, use the status **NOT READY / IN PROGRESS**. A mock, local rules engine, provider interface, or successful build is not proof of a live AI assistant.
