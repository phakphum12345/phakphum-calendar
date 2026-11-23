# Flexible Workforce & Shift Scheduler — Acceptance Tests

## Status vocabulary

- **PASS:** test executed and evidence confirms the expected result.
- **FAIL:** test executed and expected behavior was not met.
- **SKIPPED:** test was intentionally not run; it is not a pass.
- **UNKNOWN:** evidence is missing, inconclusive, or unavailable.

A requirement without executable or inspectable evidence must not be marked PASS.

## 1. Workspace and organization

- [ ] A newly created workspace has no seeded organization, department, employee, or schedule records.
- [ ] A user can create multiple organizations and nested departments.
- [ ] Editing one organization does not mutate another.
- [ ] Users without scoped permission cannot read or mutate protected organization data.
- [ ] Archive preserves historical references and audit evidence.

## 2. Workforce and capability

- [ ] Employee records support optional fields without fabricated defaults.
- [ ] Profession, position, and skill values are user-defined.
- [ ] Qualification validity dates affect eligibility.
- [ ] Duplicate candidates are surfaced for review; ambiguous records are not auto-merged.
- [ ] Cross-tenant employee access is denied and tested.

## 3. Shift, time, and location

- [ ] Shift templates support user-defined start/end times, overnight shifts, breaks, timezone, and effective dates.
- [ ] Invalid or unknown times are reported and cannot silently pass.
- [ ] Staffing minimum/maximum and qualification requirements are evaluated.
- [ ] Location eligibility is checked where configured.

## 4. Schedule Designer

- [ ] Two departments can use different row/column layouts for the same canonical data model.
- [ ] Reordering or restyling a layout does not change assignments.
- [ ] Daily, weekly, monthly, yearly, and custom ranges handle date boundaries correctly.
- [ ] Unsupported merged-cell or print features are disclosed rather than silently dropped.

## 5. Import

- [ ] Supported file type is identified before parsing.
- [ ] Preview displays source, mapping, accepted rows, skipped rows, warnings, and errors.
- [ ] User can correct mappings before commit.
- [ ] Exact and probable duplicates are distinguished.
- [ ] No existing record is overwritten before explicit per-operation confirmation.
- [ ] Cancelled or failed imports leave canonical records unchanged.
- [ ] Import report and audit event identify the source and outcome.
- [ ] Low-confidence PDF extraction is marked UNKNOWN/review-required rather than guessed.

## 6. Export

- [ ] Prebuilt Template mode accepts a supported system template and a user-imported template.
- [ ] Generated Page mode exports the selected page/view structure and supported visual formatting.
- [ ] Custom Design mode supports configurable header, logo, fields, tables, colors, sizing, and placement.
- [ ] Mapping errors are shown before rendering.
- [ ] Preview is available before file creation/print.
- [ ] XLSX, CSV, PDF, and print are tested for supported capabilities.
- [ ] CSV preview explains that visual formatting and merged cells are not preserved.
- [ ] Template and profile versions are retained and selectable.
- [ ] Exporting does not mutate the schedule or trigger a new generation.
- [ ] Re-exporting the same schedule revision with the same profile version is reproducible within documented renderer limits.

## 7. Scheduling and constraints

- [ ] Generation produces Draft, never Published.
- [ ] Same inputs, rule versions, and engine version produce deterministic output in deterministic mode.
- [ ] Overlaps, unavailable staff, leave conflicts, qualification gaps, and coverage shortages are reported.
- [ ] Hard failures block approval unless a scoped, audited override policy applies.
- [ ] Soft constraints report score/reason separately from hard validity.
- [ ] Unknown inputs produce UNKNOWN or review-required results, not PASS.
- [ ] Assignment explanations include relevant rule IDs and source references.

## 8. Approval, publication, and audit

- [ ] Approval is restricted to authorized roles.
- [ ] Approval references the exact schedule revision and validation report.
- [ ] A change after approval invalidates or supersedes the prior approval according to policy.
- [ ] Publishing is a separate explicit operation.
- [ ] Every create/update/archive/approve/publish/export/import operation produces an auditable event.
- [ ] Audit records are not silently rewritten by ordinary users.

## 9. Compatibility and operations

- [ ] Existing personal roster import and Google Calendar workflows continue to pass regression tests.
- [ ] Existing stable Calendar Sync IDs and historical events are preserved.
- [ ] Schema migration has forward and recovery tests.
- [ ] Backup/restore preserves tenant scope, revision history, and template versions.
- [ ] No credentials or sensitive employee data are exposed in logs or committed files.
- [ ] Web and Windows required delivery contracts remain intact; optional platform status is reported separately.

## 10. End-to-end scenario

1. Create an empty workspace.
2. Create an organization and two departments with different schedule layouts.
3. Add a small, explicitly synthetic test workforce and user-defined skills.
4. Configure shifts, locations, availability, leave, and staffing requirements.
5. Import a roster file into staging and resolve mappings.
6. Confirm import and inspect audit history.
7. Generate a Draft and inspect hard/soft constraint findings.
8. Correct blockers and submit for approval.
9. Approve the exact revision and publish it.
10. Export that same revision using all three export modes.
11. Verify that each export uses the same canonical assignments and that export did not mutate the schedule.
12. Verify tenant isolation, audit history, backup/restore, and existing Calendar regression tests.

Synthetic test data must be isolated from real user records and clearly labeled as test fixtures.
