# Flexible Workforce & Shift Scheduler — Data Model

## 1. Modeling rules

- IDs are stable and opaque; do not use display names as primary keys.
- Every tenant-owned record carries a workspace/organization scope.
- Optional information remains nullable; missing data is not fabricated.
- Canonical schedule facts are separate from display/layout and export artifacts.
- Timestamps are stored consistently and local work times include an explicit timezone context.
- Version mutable policies, templates, and schedules where reproducibility matters.
- This is a target logical model. Phase 0 must compare it with existing Dart models and persistence before adding duplicate entities.

## 2. Core entities

| Entity | Key fields / purpose |
|---|---|
| Workspace | id, name, status, timezone, createdAt |
| Organization | id, workspaceId, parentId, name, status, ownerId |
| Department | id, organizationId, parentDepartmentId, name, code, status, ownerId |
| Employee | id, workspaceId, employeeCode, displayName, professionId?, positionId?, status, employmentType? |
| Profession | id, workspaceId, name, description, status |
| Position | id, workspaceId, name, description, status |
| Skill | id, workspaceId, name, description, validityPolicy? |
| EmployeeSkill | id, employeeId, skillId, validFrom?, validUntil?, evidenceRef?, status |
| ShiftType | id, workspaceId, code, name, category?, status |
| ShiftTemplate | id, shiftTypeId, startLocalTime, endLocalTime, timezone, crossesMidnight, breaks, effectiveRange, version |
| WorkLocation | id, workspaceId, parentLocationId?, name, type, status |
| Availability | id, employeeId, startAt, endAt, availabilityType, status, source |
| LeaveRequest | id, employeeId, startAt, endAt, leaveType, approvalStatus, decisionActor?, decidedAt? |
| StaffingRequirement | id, departmentId, shiftTemplateId, dateRange, minimum, maximum, requiredPositionIds, requiredSkillIds |
| SchedulingRule | id, workspaceId, scope, ruleKey, configuration, severity, enabled, priority, version |
| Schedule | id, workspaceId, organizationId, departmentId?, periodStart, periodEnd, timezone, status, revision |
| ShiftAssignment | id, scheduleId, employeeId, shiftTypeId, shiftTemplateVersion, startAt, endAt, locationId?, status, source |
| ScheduleRow | id, layoutId, key, label, order |
| ScheduleColumn | id, layoutId, key, label, order, dataBinding |
| ScheduleCell | id, scheduleId, rowKey, columnKey, assignmentId?, displayOverride? |
| ScheduleLayout | id, workspaceId, departmentId?, name, definition, version, status |
| ImportJob | id, workspaceId, sourceRef, sourceType, mappingVersion, status, reportRef, createdBy |
| ImportDecision | id, importJobId, candidateKey, action, targetEntityId?, reason |
| ExportTemplate | id, workspaceId, name, sourceType, fileRef, schema, version, status, ownerId |
| ExportProfile | id, workspaceId, name, mode, layoutDefinition, mappingDefinition, version, status |
| TemplateVersion | id, exportTemplateId, version, fileRef, compatibility, createdBy, createdAt |
| ExportJob | id, workspaceId, scheduleId, scheduleRevision, profileId, profileVersion, format, status, outputRef |
| Approval | id, scheduleId, scheduleRevision, decision, approverId, decidedAt, validationSummaryRef |
| AuditLog | id, workspaceId, actorId, action, entityType, entityId, revision, occurredAt, outcome, correlationId |

## 3. Relationships

- Workspace owns organizations, employees, professions, positions, skills, templates, rules, layouts, import/export profiles, and schedules.
- Organization contains departments and may contain child organizations.
- Department groups employees, staffing requirements, and schedule ownership.
- Employee links to optional profession and position and has zero or more EmployeeSkill records.
- ShiftType has one or more versioned ShiftTemplates.
- ShiftAssignment belongs to a Schedule and references one employee, shift type, time interval, and optional location.
- Schedule has many assignments and references a layout only for presentation.
- ImportJob produces staged candidates and decisions; only confirmed decisions create/update canonical entities.
- ExportJob references an immutable schedule revision and an export profile/template version.
- Approval references the exact schedule revision that was reviewed.
- AuditLog references changes and workflow outcomes.

## 4. Export design model

Three modes must be represented explicitly:

- **prebuilt_template:** system-provided or user-imported file template.
- **generated_page:** rendering of the selected generated schedule page/view.
- **custom_design:** user-defined document/layout design.

ExportProfile stores field/cell mapping, formatting, grouping, dimensions, page settings, and mode-specific options. ExportTemplate stores the source template reference and schema. TemplateVersion preserves immutable versions. ExportJob records the schedule revision and profile/template version used.

## 5. Schedule and assignment states

Suggested lifecycle values (final enum representation must follow existing code conventions):

- Schedule: draft, validation_failed, review_required, approved, published, archived.
- Assignment: proposed, confirmed, rejected, cancelled.
- ImportJob: selected, inspecting, preview_ready, validation_failed, awaiting_confirmation, committed, cancelled, failed.
- ExportJob: queued, rendering, preview_ready, completed, failed, cancelled.
- Approval: pending, approved, rejected, revoked.

A state transition must be authorized and validated. Generation alone never changes a schedule to published.

## 6. Integrity and constraints

- Unique employee code within its configured tenant/organization scope where policy requires.
- Foreign keys and tenant scope must agree.
- End time must be after start time after timezone/overnight normalization.
- No overlapping assignments for the same employee unless a specific approved rule allows it.
- Staffing counts are evaluated by the applicable date, shift, location, and required qualification.
- Approval must reference the exact revision and validation report.
- Export must reference a stable schedule revision and profile/template version.
- Duplicate detection is a review signal; uncertain matches are not auto-merged.
- Soft delete/archive must preserve audit and historical references.
- Data migrations must be versioned, tested, and recoverable.
