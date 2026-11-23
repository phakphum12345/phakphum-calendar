# Organization Member Management

This document describes the member-management API and UI introduced by PR #164. It must be treated as current only after that PR is merged and its exact-head checks pass.

## Authorization

- Only organization owners and admins accepted by the existing `requireManager` policy may add members, change member roles, or remove members.
- The owner role is reserved. It cannot be assigned through member creation, changed through the role endpoint, or removed through the removal endpoint.
- Organization members must have an active membership to access organization member data.
- A removed member loses access immediately because membership authorization checks require `status = active`.

## Roles

The member role endpoint accepts:

- `staff`
- `incharge`
- `manager`
- `admin`

The owner role is intentionally excluded from the assignable role list.

## Endpoints

All endpoints are under `/api/v1` and require an authenticated Google account.

### List active members

`GET /organizations/{organizationId}/members`

Returns active memberships only.

### Add or reactivate a member

`POST /organizations/{organizationId}/members`

Request body:

```json
{
  "email": "member@example.com",
  "employee_id": "EMP-001",
  "role": "staff"
}
```

- `201` means a new membership was created.
- `200` means an existing inactive membership was reactivated.
- `409` means the account or employee identity conflicts with an active or existing assignment.

Reactivation updates the existing membership row rather than creating a duplicate.

### Change a member role

`PATCH /organizations/{organizationId}/members/{userId}`

Request body:

```json
{
  "role": "manager"
}
```

- `200` means the active member role was updated.
- `404` means no active membership exists for that user.
- `409` means the target is the protected owner membership.
- `422` means the requested role is not assignable.

### Remove a member

`DELETE /organizations/{organizationId}/members/{userId}`

Removal is a soft status change to `inactive`. It does not delete the membership row, user account, roster assignments, or historical data.

- `200` means the membership was deactivated.
- `404` means no active membership exists for that user.
- `409` means the target is the protected owner membership.

An administrator can later reactivate the same membership through the add-member endpoint.

## Join-request history

An already approved join-request record is retained as history. If its member is later removed, submitting a new request does not overwrite the approved record; the API returns `membership_inactive` and instructs the user to contact an administrator for reactivation.

If an older pending request is approved while an inactive membership row already exists, approval reactivates that row instead of inserting a duplicate.

## Audit and ownership limitations

- Membership rows are preserved, but a dedicated append-only membership event/audit log is not part of this change.
- Ownership transfer is not implemented. The owner membership is protected from role changes and removal.
- These endpoints do not modify production data by themselves; they act only when an authorized user invokes them.

## Verification

The implementation is covered by Laravel feature tests for authorization, role changes, owner protection, soft removal, access revocation, reactivation, and preservation of approved join-request history, plus Flutter gateway and widget tests for the admin controls.
