# SCE 3.0 Implementation Map

สถานะนี้ใช้สำหรับวางแผน migration จาก repository ปัจจุบัน โดยต้องตรวจซ้ำ
หลังแต่ละ phase

| Capability | Current status | Existing production boundary | Next action |
|---|---|---|---|
| Canonical roster | Complete foundation | `domain/entities/schedule.dart`, `ScheduleRepository` | Extend metadata without breaking schema |
| Responsive shell | Partial | `app.dart`, `ui/app_shell.dart` | Align six destinations and extract pages |
| Dashboard | Partial | `_DashboardPage` in `app_shell.dart` | Move to feature and add SCE cards |
| Schedule views | Phase 2 editor slice | `features/schedule/` | Extend selection, templates and drag preparation |
| Employee directory | Phase 2 production slice | `features/employees/` | Add profiles, permissions and import/export |
| Shift exchange | Domain/service partial | `features/shift_exchange/` | Add repository, workflow and UI |
| Reports/A4 | Partial production slice | `features/reports/` | Add report families and exports |
| Settings | Phase 2 template slice | `_SettingsPage`, `features/shift_templates/` | Split workspace/profile settings |
| Rule engine | Strong foundation | `RuleEvaluator`, validation service | Configurable registrations and severities |
| Conflict engine | Partial | schedule generation/conflict services | Canonical conflict result boundary |
| Policy engine | Missing | none | Implement after rule/conflict contract |
| Preview engine | Partial | simulation and calendar preview | Unify bulk-operation preview semantics |
| Excel import | Production foundation | `features/excel_import/` | Extend source metadata and preview |
| Google Sheets | Partial | gateway and import adapter | Range/mapping/checksum/incremental history |
| Google Calendar | Production foundation | workflow/calendar sync modules | User-only selection, offline queue |
| Payroll/OT | Missing | no canonical payroll aggregate | Implement after templates and employees |
| Notifications | Partial | legacy alerts | Add repository and delivery channels |
| Permissions | Domain foundation | access-control module | Wire policies to active routes/actions |
| Audit/history | Partial | audit and sync history modules | Cover roster/exchange/payroll/profile |
| Workspace/profile | Domain foundation | tenancy/organization modules | Add persisted workspace isolation |
| Backup/restore | Missing | none | Versioned profile/roster backup |
| Localization | Partial | generated Thai/English l10n | Remove remaining active hard-coded strings |
| CI/release | Strong foundation | `.github/workflows/` | Keep Auto Detect CI, Windows, and Web required gates green; record Android/iOS/Linux as optional artifact evidence |

## Immediate order

1. Keep required main gates green (Auto Detect CI, Windows, and Web); track Android, iOS, and Linux as optional artifact evidence.
2. Extract top-level navigation and Dashboard from legacy `AppShell`.
3. Extend the canonical manual editor with bulk selection and repeat actions.
4. Add configurable Conflict/Policy/Preview boundaries.
5. Add employee availability and department capacity.

## Roster Configuration & Intelligent Sync

The detailed target behavior, phases, acceptance criteria, test matrix, and safety constraints are maintained in [Roster Configuration & Sync Roadmap](ROSTER_CONFIGURATION_AND_SYNC_ROADMAP.md).

| Capability | Current status | Existing production boundary | Next action |
|---|---|---|---|
| Roster source providers | Partial foundation; exact provider coverage requires Phase 0 audit | Existing local import and Google Sheets adapters | Define extensible provider contract; preserve active source until explicit activation |
| Roster configuration profiles | Partial foundations exist in column mapping and shift templates; reusable profile lifecycle not yet verified | Excel import mapping and shift templates | Add persisted, versioned, reusable profiles and explicit precedence |
| Configurable layout/date parser | Partial | Excel import and section/date parsing | Audit then extend row/column/section mapping, BE/CE and cross-period date rules |
| Shift aliases/time rules | Partial | Shift templates and canonical schedule | Add profile/source/location-scoped aliases and time rules, including overnight shifts |
| Analyze/validation/preview | Partial foundation | Import draft, validation, simulation and calendar preview | Unify provenance, ambiguity resolution, stale-preview invalidation and explicit confirmation |
| Generator/Calendar sync integration | Production foundation; exact profile-driven flow requires audit | Existing generation and Calendar sync workflows | Consume only validated preview output; verify idempotency and per-item outcomes |
| Roster source/profile history | Partial | Audit, sync history and workspace/profile foundations | Persist source provenance, profile versions, corrections and append-only history |

## Updated execution order

The roster roadmap adds a prerequisite audit before implementation. It is a focused workstream and must be integrated with the existing SCE 3.0 work rather than creating a competing subsystem.

1. **Phase 0 — READ / ANALYZE:** audit existing source selection, import readers, date parsing, shift templates, profile/persistence, generator, preview, Calendar sync, Timeline and tests. Establish a file-level baseline.
2. **Phase 1 — Source/Profile contracts:** define extensible providers, persisted profiles, schema versioning and configuration precedence.
3. **Phase 2 — Reader/Date parser:** extend existing readers and mapping UI; cover BE/CE, explicit section dates and cross-month/year periods.
4. **Phase 3 — Shift/Time rules:** extend existing shift templates with aliases, context-specific rules, special categories and overnight shifts.
5. **Phase 4 — Analyze/Preview:** unify provenance, warnings/errors, correction, validation and explicit confirmation.
6. **Phase 5 — Generator/Sync:** integrate validated output with existing generation and Calendar sync, including idempotency and partial-failure recovery.
7. **Phase 6 — History/Persistence:** preserve and connect roster history, audit, profile versions and Calendar Timeline.
8. **Phase 7 — E2E/Release audit:** run regression, platform builds and CI; verify exact PR head checks and main after merge.

The existing SCE 3.0 immediate work remains in scope. Before implementation, Phase 0 must identify dependencies and sequencing conflicts so that navigation/editor work and roster workflow changes share existing routes and repositories. Do not infer that the statuses in this map prove all end-to-end paths are complete.
