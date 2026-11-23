# Roster Global Knowledge Base Architecture (TH)

## Purpose

Build a roster-format system that can recognize many organization-specific roster layouts without forcing them into one universal template. This document defines the first implementation boundary; it does not claim that a global catalog of every roster format already exists.

## Operating principles

1. **Detect, don't assume.** Analyze each imported block independently. A workbook may contain several sections with different date ranges, column layouts, shift vocabularies, and organizations.
2. **Organization profiles are configurable.** A profile may define aliases, date/header patterns, shift codes, time rules, locations, overnight behavior, and validation rules. A profile applies only to its intended organization/workspace.
3. **Manual setup is a first-class fallback.** If automatic detection cannot confidently map a table or shift, let the user define the mapping in a preview/setup flow. Preserve the original cell values and the source coordinates.
4. **Uncertainty blocks unsafe writes.** Low-confidence date, person, shift, time, or location mappings must be shown as questions/warnings. Do not silently guess and do not sync to a calendar until the user confirms the preview.
5. **Shared knowledge is evidence-backed.** External websites can suggest common patterns and terminology. They are evidence, not authority over an organization's actual roster. Store source URL, retrieval date, license/usage notes, review status, and the scope where a rule may apply.
6. **Never claim exhaustive global coverage.** There is no assumed single website that contains every roster format worldwide. The knowledge base grows incrementally and reports its coverage and provenance.
7. **Keep local and shared data separate.** User/private roster data must not be uploaded to a public/global knowledge base by default. Only reviewed, non-sensitive patterns or user-approved contributions may be shared.
8. **Version changes and audit them.** Every profile/knowledge rule has an identifier, version, provenance, and change history. A new rule must not silently rewrite existing schedules.

## Suggested analysis pipeline

1. Import a workbook, Google Sheet, calendar, PDF/image, pasted table, or manual table.
2. Preserve raw input, sheet/block boundaries, cell coordinates, and source metadata.
3. Detect candidate sections and each section's own date range and layout.
4. Match candidate organization profiles and known patterns; return confidence and evidence for every match.
5. If confidence is insufficient, ask the user to select an existing profile, edit a profile, or create a new one.
6. Normalize only confirmed interpretations into canonical roster records.
7. Show a diff/preview with date, person, role/shift, time, location, warnings, and source cells.
8. Run validation and duplicate checks.
9. Sync only after explicit user confirmation, preserving the existing guarded sync flow.

## Confidence and fallback

Confidence must be field-specific rather than one opaque score. At minimum track date, person, role/shift, time range, location, and organization-profile match. A high-confidence date does not imply that a shift's hours are known.

Recommended behavior:
- **High confidence:** show the detected interpretation and allow review.
- **Medium confidence:** show alternatives and ask for confirmation.
- **Low confidence or conflicting evidence:** do not create a sync-ready assignment; open manual mapping.
- **No matching profile:** offer to create a private profile from user-confirmed mappings.

Thresholds should be configurable and validated with fixtures before they are used to gate sync.

## Knowledge entry lifecycle

`discovered → source-checked → reviewed → tested → published → superseded`

A discovered web page is not automatically a rule. Review should verify:
- the source is credible and the URL is stable;
- reuse is allowed by its license/terms;
- the proposed pattern is generalizable and does not contain personal data;
- the rule's jurisdiction, industry, organization scope, and limitations are documented;
- tests cover examples and counterexamples;
- a reviewer approved publication.

If the source is unavailable, ambiguous, or contradictory, preserve the uncertainty and request manual confirmation.

## Initial knowledge categories

- Table layouts: date headers across columns, dates down rows, repeated blocks, merged headings, multiple periods per workbook.
- Date interpretation: locale, Buddhist/Gregorian year, abbreviated months, cross-month ranges, leap years, and explicit date headers.
- Shift vocabulary: aliases and local terms; aliases never imply a universal time range.
- Shift-time rules: start/end times, overnight behavior, time zones, split shifts, on-call, and exceptions.
- Assignment semantics: primary duty, replacement, extra duty, leave, off, absence, exchange, and on-site/site assignments.
- Location and unit metadata: clinic, ward, station, site, and department.
- Import/export behaviors and supported source formats.

## Separation of concerns

- **Core parser:** structural reading and date/value normalization; no organization-specific hard-coded assumptions.
- **Organization profile:** locally configured aliases, mappings, time rules, and validation constraints.
- **Shared knowledge catalog:** reviewed, versioned, provenance-backed patterns that can be suggested to profiles.
- **Manual profile editor:** user-owned rules and examples.
- **Review/sync gate:** the only path from parsed candidates to calendar writes.

The existing monthly-grid adapter contains hard-coded role-to-time mappings. Those mappings should be treated as a legacy/default profile during migration, not as universal truth. Preserve compatibility while replacing implicit assumptions with explicit, reviewable profiles.

## Acceptance criteria for implementation

- A workbook can contain multiple blocks with different periods and layouts.
- No global rule forces every organization to use the same shift names or times.
- Users can create and edit a profile when automatic detection fails.
- Unknown shifts remain unknown until mapped; their time is not guessed.
- Each detected field has evidence/confidence and a pointer to raw source cells.
- External-source knowledge records provenance and review status.
- Private roster names and assignments are not sent to public sources or shared by default.
- Calendar sync remains preview-and-confirm; low-confidence records cannot bypass it.
- Tests cover cross-month dates, year boundaries, leap days, ambiguous headings, conflicting profiles, and custom user-defined rules.
