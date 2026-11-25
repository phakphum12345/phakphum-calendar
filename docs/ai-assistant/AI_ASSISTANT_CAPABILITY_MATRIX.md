# AI Assistant capability matrix

| Capability | Minimum behavior | Acceptance evidence |
|---|---|---|
| Local help | Offline answers grounded in bundled/versioned help | Offline E2E and source references |
| Live conversation | Real configured provider through backend | Non-mock request in deployed test environment |
| Roster explanation | Selected roster and deterministic evidence | Source row/cell trace and authorization test |
| Roster proposal | Suggest unresolved mappings/corrections | Preview and explicit accept/reject |
| External research | Real retrieval with provenance | Valid URLs and claim-to-source validation |
| Research report | Reviewable report with method and sources | Export and provenance metadata |
| Tool assistance | Narrow allowlisted actions | Permission, preview, confirmation and audit |

States: AVAILABLE_LOCAL, AVAILABLE_REMOTE, REQUIRES_SIGN_IN, REQUIRES_ORG_ROLE, REQUIRES_CONSENT, NOT_CONFIGURED, UNAVAILABLE, PLANNED. UI derives remote readiness from backend health. A chat screen/mock/green CI is not proof of live AI.