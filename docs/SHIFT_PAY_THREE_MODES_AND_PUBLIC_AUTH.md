# Shift Pay: Three Operating Modes and Public-User Readiness

## Status

Planning and implementation contract. This document does not claim that shift-pay settings, payroll summaries, public Google OAuth, or production installers are already complete.

## Product goal

Allow every user to configure and understand additional compensation for shifts they actually work. The feature must work for independent workers who do not belong to an organization, organization-managed teams, and users who combine both.

The existing `ShiftPayCalculator` is a domain calculation component. The existing `ShiftTemplate.rate` is a simple template field. Neither alone proves that users can configure policy in the app, persist it safely, apply it to real roster assignments, and review a reliable monthly total. Complete the whole path before marking this feature done.

## Three operating modes

### 1. Personal

- A user owns and manages their own shift types, work-day calendar, locations, pay rules, and rates.
- No organization membership, organization administrator, or organization API is required.
- Support independent/freelance work and multiple workplaces or clients.
- Personal data must remain private to the signed-in user (or local-only profile if the app supports guest/local use).
- The user can configure fixed amount per shift, hourly rate, multiplier, salary-included/no-extra-pay, or compensatory time.

### 2. Organization

- An authorized organization administrator manages shared shift types, day classifications, work locations, and pay rules.
- Members can view applicable rules and their own calculated results; only authorized roles can edit organization policy.
- Rules are scoped to the organization and must never leak across organizations.
- Membership removal or role changes must not silently rewrite historical calculations.

### 3. Hybrid

- A user can work both under an organization and independently.
- The user can maintain personal rules alongside organization rules.
- Each rule must identify its owner/source (personal or a specific organization), and the calculation must record which exact rule was selected.
- Provide an explicit per-profile or per-assignment source policy: organization rule first, personal rule first, or require the user to choose. Do not silently combine two rates or double-pay one shift.
- If no eligible rule exists, show “not configured” rather than treating the shift as unpaid or inventing a rate.

## Configurable rule dimensions

Reuse and extend the existing domain concepts where possible. Users must be able to configure:

- User-defined shift type ID/name, start/end time, overnight handling, and active status.
- Employment/payment basis where relevant (e.g. salaried, daily-paid, independent/contract).
- Work-day category: regular weekday, weekly day off, official holiday, or festival/special day.
- Fixed amount per completed shift or hourly rate multiplied by actual eligible hours.
- Optional multiplier and separately labelled components such as shift allowance, premium, differential, break relief, and other.
- Optional department, site/location, work point, and assignment purpose.
- Included in salary (zero additional pay) or compensatory time, with explicit linked shift and weekday conditions.
- Currency and rounding policy must be explicit and consistent; do not assume a legal rate or national holiday calendar.

## Calculation and audit requirements

- Calculate only from confirmed/actual roster assignments, not merely planned shifts, unless the UI clearly labels a forecast.
- Handle overnight shifts and actual duration correctly.
- Show calculation detail: assignment date, shift type, hours, day category, source (personal/organization), selected rule, rate basis, multiplier, and resulting amount.
- Prevent duplicate counting when an assignment is edited, imported, replaced, or synchronized.
- Preserve a calculation snapshot (selected rule/rate and inputs) for closed historical periods. Editing today's rates must not silently recalculate past confirmed pay.
- Distinguish zero pay, salary included, compensatory time, and missing/unconfigured rules.
- Monthly totals must reconcile to the underlying assignment-level rows. Export/print should use the same calculation source.
- This is an additional shift-pay estimator, not statutory payroll, tax, base salary, or legal overtime advice.

## Required user journeys

1. First-run user chooses Personal, Organization, or Hybrid.
2. Personal user creates custom shifts and rates without joining an organization.
3. Organization admin configures shared rules and assigns roles.
4. Hybrid user links an organization and sets an explicit rule-source preference.
5. User imports or enters roster assignments, reviews unmatched rules, confirms actual shifts, and sees daily/monthly totals.
6. User changes a rate and can still inspect prior-period snapshots without historical drift.
7. User exports or prints a monthly statement with traceable per-shift details.

## Persistence and security

- Define versioned, validated storage for shift types, work-day policies, pay rules, source policies, and calculation snapshots.
- Personal records must be user-scoped; organization records must be organization-scoped and access-controlled server-side.
- Never trust a client-supplied organization ID or role without server authorization.
- Preserve existing user data during schema migration; do not delete existing shift templates or roster history.
- Support offline/local work where existing app architecture permits, with explicit sync/conflict behavior rather than overwriting newer settings.

## Google authentication and public-user readiness

The repository's current `docs/GOOGLE_SETUP.md` instructs operators to keep the OAuth consent screen in Testing. That is a tester-only setup, not a public-user launch configuration. The iOS `Info.plist` also contains placeholder OAuth client identifiers. Windows/Linux are explicitly unsupported by the current Google Sign-In service. These are known readiness gaps, not proof of a Google Cloud console configuration state.

Required work:
- Separate Google identity sign-in from optional Google API data scopes. Users must be able to create/sign into an account without granting Drive, Sheets, or Calendar access unless that feature is requested.
- Request additional Google scopes incrementally and explain why each is needed.
- Document External audience, production publishing, authorized origins/redirect URIs, platform-specific OAuth clients, app verification requirements for sensitive/restricted scopes, and support/contact/privacy links.
- Add clear diagnostics for missing/mismatched client IDs, redirect URI, package name, iOS bundle/reversed client ID, unverified-app/test-user restrictions, cancelled consent, and provider outages.
- Never commit client secrets, refresh tokens, private keys, or user data.
- Verify sign-in with non-owner, non-tester accounts on each supported platform before claiming public availability.
- Where a platform is not supported, provide a clear fallback and do not show a misleading working sign-in button.

Google Cloud Console publication, consent verification, domain ownership, and production client credentials may require owner actions outside this repository. Code changes alone cannot complete those external steps.

## Installation and release acceptance

- Provide signed, installable release artifacts for supported platforms, with checksum and version information.
- Android release must use a production signing configuration supplied securely; do not label debug-signed APKs as production.
- iOS distribution must use a valid signing/provisioning route; an unsigned IPA is build evidence, not an installable public release.
- Web deployment must have correct base path, OAuth origin/redirect configuration, and a documented update path.
- Windows/Linux installers or packages must include runtime dependencies and a first-run setup guide.
- Add user-facing installation, account setup, privacy, backup/restore, and troubleshooting documentation.
- Do not claim end-to-end ready until a clean install, account registration/sign-in, roster entry/import, pay-rule configuration, calculation, monthly report, and data persistence have been tested with a normal user account.

## Test matrix

- Unit: rule selection, mode isolation, hybrid precedence, no double counting, day classification, fixed/hourly/multiplier, overnight hours, salary included, compensatory time, missing rules, rounding/currency.
- Persistence: encode/decode, schema migration, invalid data, duplicate IDs, and round-trip preservation.
- Integration: roster assignment to calculation to monthly report; edit/import/sync idempotency; historical snapshot stability.
- Authorization: personal data isolation, organization role enforcement, cross-organization denial, hybrid source attribution.
- Auth: public non-tester Google account, cancelled consent, missing/mismatched OAuth config, each supported platform, incremental scopes, provider outage.
- Release: clean installation and first-run user journey on each claimed supported platform.

## Completion criteria

This work is complete only when all three modes are implemented end-to-end, calculation details reconcile with actual assignments and monthly reports, persistence and authorization tests pass, supported installers are genuinely installable, and public Google authentication has been verified with ordinary non-tester users. Any external Google Console action still outstanding must be listed as a blocker, not marked PASS.
