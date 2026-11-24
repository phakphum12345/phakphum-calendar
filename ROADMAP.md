# Roadmap

This roadmap describes intended capability milestones. It is not a claim that a milestone is implemented or released. Use `IMPLEMENTATION_STATUS.md`, `REQUIREMENTS_TRACEABILITY.md`, and exact-commit CI evidence for delivery status.

## Existing product milestones

- v0.1 — Foundation
- v0.2 — Google integration
- v0.3 — Shift parser
- v0.4 — Relationship and business rules
- v0.5 — Calendar preview and synchronization
- v0.6 — Dashboard
- v0.7 — Reports
- v0.8 — History
- v0.9 — Optimization and security
- v1.0 — Production release

## Universal Roster Intelligence expansion

| Phase | Milestone | Scope | Completion evidence |
|---|---|---|---|
| 0 | Repository baseline | Exact SHA/PR/CI audit, source inventory, documentation reconciliation and preservation of local work | Capability matrix and evidence-backed baseline |
| 1 | Parser reliability | Section-local parsing, Thai/BE/Gregorian date ranges, column integrity and malformed-header diagnostics | Golden fixtures and parser regression tests |
| 2 | Universal structure | Provider/reader contracts, multi-section detection, layout profiles and source coordinates | Multiple independent layouts pass structure tests |
| 3 | Canonical roster model | People, shifts, assignments, availability, relationships and provenance | Mapping/round-trip tests without data loss |
| 4 | Reconciliation | Source fingerprints, revisions, duplicate detection and proposed change sets | Re-import and conflict tests prove non-destructive behavior |
| 5 | Review and recovery | Evidence, confidence, partial import, approvals, audit and safe recovery | Invalid/ambiguous records cannot bypass review |
| 6 | Template and generator | Reusable profiles, mapping rules, preview, document/calendar export | Generated output matches approved records |
| 7 | Calendar integration | Idempotent writes, retry, resume, ambiguous-outcome reconciliation and history | Authorized test-account E2E |
| 8 | UX and platform quality | Responsive review/import/sync flows, accessibility and platform capability checks | Target-width and platform test matrix passes |
| 9 | Security and scale | Privacy, tenant isolation, large-file performance and operational resilience | Security and reproducible benchmark evidence |
| 10 | System acceptance | Full end-to-end acceptance and release verification | All required checks pass on the exact release SHA |

## Delivery rules

1. Preserve existing supported behavior; expand capability rather than merely renaming or restructuring it.
2. Prefer local deterministic processing and existing infrastructure; justify new paid services before adoption.
3. Do not silently infer dates, people, shift meanings or deletions.
4. Do not mutate source workbooks or write to Calendar before preview and explicit confirmation.
5. Do not delete unfinished work. Remove only proven duplicates after dependency and capability migration review.
6. A skipped or missing check is not a pass. Unknown evidence remains UNKNOWN.
7. No direct push to `main`, merge, production deployment or OAuth scope expansion without explicit authorization.
8. Update requirements traceability, implementation status and relevant domain docs with each implementation PR.
