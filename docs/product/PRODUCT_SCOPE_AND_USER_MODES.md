# Product scope and user modes

## Personal
Use personal schedules and shift-pay rules without joining an organization. Personal data remains scoped to the user account.

## Organization
Organizations manage members, roles, shared shift definitions and rules. Every request is tenant-scoped and role-authorized; membership changes are auditable.

## Hybrid
Personal and organization sources coexist with explicit organization-first, personal-first or require-selection precedence. Resolve exactly one source per assignment; never silently add both.

## Invariants
No hidden cross-tenant access; no silent mutation of imported/confirmed records; AI proposals require normal authorization and confirmation; missing configuration is not silently zero/unpaid; local core workflows remain useful without external services.