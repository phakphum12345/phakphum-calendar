# Testing, Evidence and Release Acceptance

**Status:** Consolidated acceptance policy; complements [Testing](../TESTING.md), [Testing Guide](wiki/TESTING_GUIDE.md) and [Delivery Status](DELIVERY_STATUS.md).  
**Prepared:** 2026-11-24

## 1. Purpose

Provide one evidence model for deciding whether a change is correct, compatible, secure and releasable. Test count, green badges, successful compilation and documentation presence are not substitutes for requirement-level proof.

## 2. Evidence states

Use these states consistently:

- **PASS:** the named check executed successfully against the stated commit and relevant environment.
- **FAIL:** the check executed and exposed a defect or failed requirement.
- **SKIPPED:** the check did not execute; it is not a pass.
- **UNKNOWN:** evidence is unavailable, incomplete, stale or cannot be tied to the target commit.
- **PARTIAL:** only a documented subset of the requirement is proven.
- **PLANNED:** acceptance is defined but implementation/evidence is not established.

Every status must identify the scope. A unit test PASS does not imply end-to-end PASS. A workflow run PASS does not imply that a nested deployment job passed.

## 3. Required change evidence

Every implementation PR should include:
- exact base and head SHA;
- requirements/traceability IDs affected;
- source files and public interfaces changed;
- tests added/modified and exact commands;
- compatibility and regression assessment;
- data migration/backup/rollback risk;
- security/privacy and authorization impact;
- UI/platform impact;
- workflow run/check IDs and conclusions;
- known limitations and explicitly skipped checks.

## 4. Test pyramid and responsibility

| Layer | Proves | Does not prove |
|---|---|---|
| Unit | Local deterministic rule/model behavior | Full workflow or provider behavior |
| Property/fuzz | Robustness over generated input ranges | Correctness for every real-world workbook |
| Widget | User-visible interaction and state | Native provider/production integration |
| Backend feature | Route, validation, middleware and database behavior | Flutter client behavior |
| Contract | Client/server schema compatibility | Live provider availability |
| Integration | Multiple modules/adapters cooperate | Production deployment |
| E2E | A defined user journey in a controlled environment | Untested platforms/data shapes |
| Performance | Measured workload on recorded environment | Universal performance |
| Security | Specific threat/authorization cases tested | Absence of all vulnerabilities |
| CI/build | Exact workflow/build tasks executed | Deployment or runtime not included in those tasks |

## 5. Roster critical-path acceptance

The minimum critical path is:

1. Acquire a source without modifying it.
2. Preserve source identity and snapshot evidence.
3. Detect independent sections and section-local periods.
4. Parse dates, people, shifts and relationships with source coordinates.
5. Validate and expose all blocking findings.
6. Preview accepted and blocked sections separately.
7. Require confirmation before persistence or external writes.
8. Persist canonical records and revision provenance.
9. Generate output using the selected profile/template version.
10. Preview exact target changes.
11. Confirm and execute through the existing sync boundary.
12. Verify per-item provider outcomes and record audit/history.
13. Re-import/retry safely without duplicates or destructive replacement.

Each step needs at least one focused automated test; the full journey needs an integration/E2E test with synthetic or consented data.

## 6. Regression matrix

- Excel workbook with multiple sections and independent periods.
- Thai BE and Gregorian dates, cross-month/year, leap day and malformed headers.
- CSV/TSV/TXT supported import paths.
- Google Sheets read and source permission behavior.
- Sparse, merged, hidden, formula and blank cells where the reader supports them.
- Shift aliases, unknown shift, overnight time and profile precedence.
- Similar employee names, aliases and organization scoping.
- Duplicate source import, revision update and malformed-source removal protection.
- Partial section failure and valid-section continuation.
- Preview stale-state invalidation and confirmation boundary.
- Calendar idempotency, partial failure, timeout reconciliation and resume.
- Timeline history, restoration semantics and migration compatibility.
- Personal/Organization separation and tenant isolation.
- Compact/mobile/desktop layouts and keyboard/accessibility paths.

## 7. CI and branch gate

For a proposed PR:
1. Inspect PR base/head SHA and current state.
2. Confirm required reviews and unresolved threads.
3. Enumerate all checks and workflow jobs.
4. Classify every check PASS/FAIL/SKIPPED/UNKNOWN.
5. Verify that successful checks belong to the current head SHA.
6. Do not convert skipped/missing/pending checks into PASS.
7. Re-run checks after the head changes.
8. Re-check mergeability immediately before any authorized merge.

A successful parent workflow with a skipped deployment child is not a successful deployment. A green check from an older commit does not certify a newer head.

## 8. Release gate

Release may be considered only when:
- required product acceptance tests pass;
- required Flutter and backend tests pass;
- OSV-Scanner lockfile scan and `composer audit --locked` pass on the exact head;
- every production release artifact is built with the configured HTTPS shared backend origin;
- supported platform builds pass;
- security/privacy review has no unresolved blocker;
- migrations and recovery are verified;
- exact-head required CI is green;
- deployment and deployed SHA are verified if release includes deployment;
- rollback/recovery instructions are available;
- user-facing limitations are documented.

If a requirement is intentionally not applicable, document the reason and approval; do not silently mark it skipped and call the release complete.

## 9. Data and environment safety

- Use synthetic data by default.
- Do not copy real roster data into fixtures, logs or issue comments.
- Use dedicated test accounts for provider E2E.
- Do not run destructive migration/restore tests against production.
- Keep secrets in approved secret stores; never echo them in logs.
- Do not alter branch protection, OAuth scopes, production data or deployment settings as part of routine tests without explicit approval.

## 10. Current limitations

This specification does not report current test outcomes. The exact current branch head, workflow runs and platform builds must be inspected when implementation changes are made. Existing historical audit documents remain historical evidence and must not be silently rewritten.
