<!-- Historical snapshot: audit dated 2026-07-24. Do not treat its test counts, branch state or implementation findings as current. See ../../IMPLEMENTATION_STATUS.md and ../../REQUIREMENTS_TRACEABILITY.md for the newer repository-wide inventory. -->

# Shift Tools Project Audit

**Audit date:** 2026-07-24
**Branch:** `feature/shift-tools-foundation`
**Scope:** Entire repository, with detailed static inspection of `lib/`, `test/`, platform configuration, dependencies, routes, and documentation
**Change policy:** No application code was changed. No commit was created.

## Executive Summary

Shift Tools currently passes formatting, static analysis, and all 133 tests. The repository contains substantial tested foundations for Excel import, scheduling, rules, schedule generation, Google Sheets, and Google Calendar. However, the runtime application still primarily uses a legacy application shell and controller while newer domain-driven components exist alongside it. This creates duplicate domain concepts, service boundaries, and rule implementations.

The most important correctness defect is that the Excel reader's 50-row preview limit is also used as the import engine's input. A workbook with more than 50 rows can therefore produce an apparently successful but incomplete import. The largest structural risks are the 3,300-line application shell and 1,154-line application controller.

No repository-level `AGENTS.md` exists in the repository or its parent directory, so there were no additional repository-specific agent rules to apply. Existing project standards and the instructions for this audit were followed.

## Scores

All scores use **10 as the best result**. “Technical debt health” is higher when debt is lower.

| Category | Score | Rationale |
|---|---:|---|
| Architecture | 6/10 | Clear target layers and bounded feature folders exist, but the legacy runtime and newer domain architecture remain parallel. |
| Maintainability | 4/10 | Small feature files are generally clear, but two oversized central files and duplicated concepts increase change risk. |
| Scalability | 5/10 | Domain foundations are reusable, but scheduling algorithms and eager UI construction will not scale to large rosters. |
| Readability | 5/10 | Naming is mostly clear; oversized files and inconsistent terminology make navigation difficult. |
| Testing | 8/10 | All 133 tests pass with good unit and widget coverage; measured coverage and native/live integration verification are absent. |
| Performance | 5/10 | Current data sizes are workable, but repeated scans, pairwise checks, and broad rebuild regions will degrade with large schedules. |
| Technical debt health | 4/10 | There is substantial migration debt, duplicated architecture, incomplete runtime wiring, and weak enforcement of documented standards. |

## Validation Results

| Command | Result |
|---|---|
| `dart format .` | Passed — 278 files inspected, 0 changed |
| `flutter analyze` | Passed — no issues found |
| `flutter test` | Passed — all 133 tests passed |
| `git diff --check` | Passed — no whitespace errors |

The analyzer reported no build warnings. A native Android, iOS, desktop, or web build was not part of the requested validation, so platform build success is not proven by this audit.

## Repository Structure

The repository has three architectural generations:

```text
lib/
├── app.dart                         # composition, theme, limited named routing
├── controller/                     # legacy application controller
├── models/                         # legacy application models
├── services/                       # legacy provider and platform services
├── ui/                             # legacy application shell
├── core/
│   ├── di/                         # dependency registration foundation
│   ├── models/
│   ├── result/                     # typed result/failure hierarchy
│   ├── state/                      # shared ChangeNotifier state contract
│   └── utils/
├── domain/
│   ├── entities/                   # canonical domain entities
│   ├── repositories/               # repository interfaces
│   └── services/                   # external service interfaces
└── features/
    ├── excel_import/
    ├── rules/
    ├── rule_engine/                # older parallel rule implementation
    ├── schedule/
    ├── schedule_generation/
    └── ...                         # authentication, workflow, providers, etc.
```

The intended direction is domain-driven and feature-oriented. The actual production path is still largely:

```text
ShiftToolsApp → AppController → legacy services/models → AppShell
```

The dependency registration foundation and several canonical repository/service interfaces are not yet the application's composition root. `lib/core/services/` and `lib/core/widgets/` are empty.

## Checklist Findings

### 1. Folder structure

Feature folders generally separate domain, data/application, and presentation concerns. Older root-level `controller`, `models`, `services`, and `ui` folders remain the production center, creating a hybrid structure. Empty core folders and runtime-unreachable feature pages add noise.

### 2. Architecture consistency

The new architecture uses entities, repository contracts, service interfaces, typed results, and standardized controller state. The legacy application uses direct concrete services, broad controller ownership, generic exceptions, and a monolithic shell. The dependency registration mechanism exists but is not wired into `ShiftToolsApp`.

### 3. Duplicate models

- `lib/core/models/shift_record.dart` models a normalized roster/calendar record, while `lib/features/excel_import/domain/shift_record.dart` models an imported spreadsheet row.
- `lib/models/shift.dart`, `lib/domain/entities/shift_type.dart`, and the schedule feature's `Shift` terminology represent overlapping shift concepts.
- Legacy schedule/shift collections overlap with the canonical `Schedule`, `ScheduleDay`, and `ScheduleMonth` entities.
- `ImportError`, `ImportIssue`, and `ImportFailure` overlap in name and responsibility across UI, import result, and core failure layers.

### 4. Duplicate controllers

There are no exact duplicate controller class names. Responsibility is duplicated: `AppController` overlaps authentication, roster selection, workflow, Excel import, and schedule-related controllers. This makes ownership and the authoritative state source unclear.

### 5. Duplicate services

- Legacy `SheetsService`, newer Google Sheets gateways, and the canonical `GoogleSheetsService` interface overlap.
- Legacy `CalendarService`, calendar gateways, `CalendarSyncGateway`, and the canonical `CalendarSyncService` overlap.
- `ScheduleService`, `ManualScheduleService`, `ScheduleGenerator`, and manual shift operations in `AppController` overlap.
- `ExcelReaderService` and `LocalRosterFileService` both decode XLSX input for different flows without a shared workbook adapter.

### 6. Dead code

No byte-identical Dart files were found. Several implementations are not reachable from production navigation:

- Schedule workspace and monthly, weekly, and daily schedule pages.
- Rule validation page.
- Schedule generator services, outside tests.
- The dependency registration mechanism.
- Canonical repository and external service interfaces without production adapters.

These files are better described as dormant foundations than proven dead code, but retaining parallel unintegrated paths increases maintenance cost.

### 7. Unused imports

`flutter analyze` reported no unused imports.

### 8. Unused dependencies

`cupertino_icons` has no import in application or test code and is the only clearly unused runtime dependency. Other declared packages have direct imports or build/tooling configuration.

### 9. Files larger than 500 lines

| File | Lines | Finding |
|---|---:|---|
| `lib/ui/app_shell.dart` | 3,300 | Contains the shell, multiple pages, dialogs, cards, controls, and feature-specific views. |
| `lib/controller/app_controller.dart` | 1,154 | Owns authentication, providers, shifts, settings, notifications, import, refresh, and orchestration concerns. |

Both violate the project's 500-line standard.

### 10. Circular dependencies

A graph of 228 Dart files and 475 internal import/export edges contained **zero cyclic strongly connected components**.

### 11. Widgets that should be extracted

`app_shell.dart` should be split by feature. Primary extraction candidates include the tools page and cards, dashboard, Google Sheet picker, account card, auto-refresh controls, manual source dialog, preview page, shift settings dialog, notifications page, audit page, saved-sheet card, settings page, and future-sheet card. Extraction should preserve behavior and move state ownership only after characterization tests exist.

### 12. State management consistency

Newer controllers use `ChangeNotifier` with common loading, error, success, and message semantics. `AppController` still acts as a broad mutable state container, while feature controllers sometimes represent the same concerns. The project is consistent in its choice of `ChangeNotifier`, but inconsistent in controller scope and state ownership.

### 13. Route management

Only the Excel import page has a central named route. Column mapping and import summary use direct `MaterialPageRoute` navigation. Schedule and rule pages are not connected to production navigation. Route naming, argument typing, deep-link behavior, and ownership are therefore fragmented.

### 14. Theme consistency

The root app defines a Material 3 theme using `ColorScheme` and component themes. Older UI code frequently uses direct colors and local styling, which can diverge from the central theme and makes dark mode or brand changes expensive.

### 15. Material 3 compliance

`useMaterial3: true` is enabled and newer screens use Material 3 components. Compliance is partial because legacy views bypass theme tokens and carry extensive local visual definitions.

### 16. Error handling

The core includes typed `Result<T>` and `Failure` types, but legacy controllers and services still throw generic exceptions, catch broadly, and convert failures to strings. Network, authentication, import, validation, and provider failures do not yet follow one consistent classification and recovery contract.

### 17. Null safety

The project is null-safe and analysis is clean. A small number of forced unwraps rely on implicit invariants. These should be replaced with explicit invariant checks where input or date lookup can fail. Time and timezone handling also require stronger domain-level policy before calendar synchronization expands.

### 18. Test coverage

The repository has 50 Dart test files and 133 passing tests, including controller, service, domain, import, schedule, rule, and widget tests. No coverage report was generated, so line and branch coverage are unknown. Provider integrations use fakes and do not prove live API or platform configuration. No full native platform build was run.

### 19. Build warnings

`flutter analyze` is clean. The current lint configuration is based primarily on `flutter_lints` and does not enforce several project standards, including public DartDoc coverage and file-size limits. Native plugin registration and signing/configuration were not build-tested in this audit.

### 20. Performance

- `AppShell` contains large `setState` rebuild regions and eagerly composed screens.
- `AppController` computed getters repeatedly scan shift collections during UI builds.
- Auto assignment repeatedly rebuilds and sorts candidate lists and rescans schedule assignments.
- Conflict detection performs pairwise comparisons per day and does not detect an overnight assignment conflicting with an assignment stored on the following day.
- Each registered schedule rule can traverse the schedule independently.
- The schedule grid uses nested scrollables and eager month construction rather than virtualization designed for large employee-by-day matrices.
- A one-second automatic refresh option can create unnecessary provider load and quota pressure.

## Issues Ordered by Severity

### Critical — Excel import silently truncates data

**Problem:** `ExcelReaderService.readWorksheet()` reads only the first 50 rows for preview, and the import engine consumes that same bounded row collection. With a header row, at most 49 data rows are imported.

**Impact:** A user can receive a successful summary while records after the preview limit are omitted. This is a data-integrity risk.

**Recommended fix:** Separate preview reads from complete import reads. Keep the UI preview bounded, but make the import engine consume all worksheet rows through a dedicated full-read API. Add tests using more than 50 rows and assert exact totals, issues, and records.

**Estimated effort:** Medium — 2–4 engineering days.

### High — Oversized application shell and controller

**Problem:** `app_shell.dart` is 3,300 lines and `app_controller.dart` is 1,154 lines, both exceeding the 500-line standard and combining unrelated responsibilities.

**Impact:** Small changes have a wide regression surface, widget rebuilds are difficult to reason about, ownership is unclear, and parallel work is prone to conflicts.

**Recommended fix:** Add characterization tests, then extract shell sections into existing feature presentation folders and transfer controller concerns into focused feature controllers. Keep one explicit composition layer.

**Estimated effort:** Extra large — 2–4 weeks, performed incrementally.

### High — Two incompatible rule-engine stacks

**Problem:** `features/rule_engine` and `features/rules` both define rule engines, violations, severity, and validation behavior with different models.

**Impact:** New rules can be implemented against the wrong stack; behavior, UI, and tests can diverge; future AI and scheduling integrations lack one stable contract.

**Recommended fix:** Select the canonical rule domain, write adapters for any retained legacy callers, migrate tests and UI, then remove the superseded implementation.

**Estimated effort:** Large — 1–2 weeks.

### High — Parallel legacy and canonical application architectures

**Problem:** Canonical domain entities, repositories, service interfaces, typed results, and dependency registration exist alongside the concrete legacy runtime, but are not the application's composition root.

**Impact:** There are multiple representations and integration paths for the same business operation, increasing defects and making dependency substitution difficult.

**Recommended fix:** Define one migration boundary per provider workflow. Wire explicit dependencies at app startup, adapt legacy services behind canonical interfaces, and migrate callers one vertical slice at a time.

**Estimated effort:** Extra large — 3–6 weeks.

### High — Overnight conflicts can cross the current detection boundary

**Problem:** Conflict detection compares assignments grouped on the same `ScheduleDay`. A night shift that ends on the next day can overlap an assignment stored on that following day without being compared.

**Impact:** Invalid schedules can pass conflict validation and reach users or calendar synchronization.

**Recommended fix:** Normalize assignments to absolute start/end instants and compare adjacent-day intervals. Add timezone-aware overnight, daylight-transition, and boundary tests.

**Estimated effort:** Medium — 3–5 engineering days.

### High — Public API documentation standard is not enforced

**Problem:** A static approximation found roughly 355 public type declarations, with the great majority lacking immediately associated DartDoc. Manual inspection confirms the gap is widespread.

**Impact:** Public contracts are harder to understand and safely evolve, and the repository does not meet its stated documentation rule.

**Recommended fix:** Document public domain and service APIs first, enable `public_member_api_docs` gradually, and suppress only intentionally internal APIs by making them private.

**Estimated effort:** Large — 1–3 weeks.

### High — New feature foundations are not production-integrated

**Problem:** Schedule, rule validation, and generation foundations are tested but not reachable from production routes. Schedule generation and rules also lack the complete model/controller/service/test/documentation package required by project standards.

**Impact:** Passing isolated tests can be mistaken for a completed user capability, while dormant code accumulates and diverges.

**Recommended fix:** Require a feature completion checklist and clearly mark experimental modules. Integrate only after controller, documentation, navigation, and end-to-end state ownership are defined.

**Estimated effort:** Medium — 3–7 days per feature boundary.

### Medium — Ambiguous and duplicate domain naming

**Problem:** Multiple `Shift`, `ShiftRecord`, schedule, import error, and failure concepts use overlapping names across layers.

**Impact:** Imports and type selection are error-prone, and adapters become implicit rather than documented.

**Recommended fix:** Establish a domain glossary. Use precise names such as `ImportedShiftRow`, `CalendarShiftRecord`, and `ShiftType`, and provide explicit mapping functions at boundaries.

**Estimated effort:** Medium — 3–5 engineering days.

### Medium — Fragmented route management

**Problem:** Named routes, direct `MaterialPageRoute` pushes, and unreachable feature pages coexist.

**Impact:** Navigation tests, argument validation, deep links, and access control become inconsistent.

**Recommended fix:** Introduce one lightweight route registry with typed argument builders using existing Flutter navigation; migrate routes incrementally without adding a routing package unless requirements justify it.

**Estimated effort:** Medium — 3–5 engineering days.

### Medium — Error handling uses competing contracts

**Problem:** Typed failures coexist with thrown generic exceptions, broad catches, and user-facing strings embedded in controllers.

**Impact:** Recovery behavior is inconsistent, telemetry lacks stable categories, and tests must assert implementation-specific messages.

**Recommended fix:** Convert external exceptions to typed failures at adapters, keep validation failures in the domain, and let presentation map stable failure codes to localized messages.

**Estimated effort:** Large — 1–2 weeks.

### Medium — Scheduling algorithms will not scale to large rosters

**Problem:** Auto assignment repeatedly scans and sorts candidates, conflict detection is pairwise, and rules independently traverse schedules.

**Impact:** Response time can grow sharply with employees, days, assignments, and rules.

**Recommended fix:** Build per-employee and per-date indexes once per operation, maintain counters incrementally, pre-sort stable candidate pools, and benchmark realistic 100-, 500-, and 1,000-employee scenarios.

**Estimated effort:** Large — 1–2 weeks.

### Medium — Schedule UI is not designed for large matrices

**Problem:** Nested scroll views and eager grid construction are suitable for a small month view but not a large employee-by-day schedule.

**Impact:** Memory use, layout time, and interaction latency will rise as roster size grows.

**Recommended fix:** Define the actual large-schedule interaction model, then use two-dimensional virtualization or paged employee rows with synchronized headers. Add frame-time benchmarks.

**Estimated effort:** Large — 2–3 weeks.

### Medium — Theme tokens are inconsistently applied

**Problem:** The app has a central Material 3 theme, but the legacy shell uses many direct colors and local styles.

**Impact:** Brand changes, accessibility improvements, high contrast, and dark mode require broad manual edits.

**Recommended fix:** Define semantic theme extensions for schedule, status, holiday, selected-day, and provider states, then replace direct colors during widget extraction.

**Estimated effort:** Medium — 4–7 engineering days.

### Medium — State ownership overlaps during the ChangeNotifier migration

**Problem:** Focused controllers and `AppController` can represent the same workflow state.

**Impact:** Stale state, duplicate notifications, and difficult lifecycle/disposal behavior can emerge as features are connected.

**Recommended fix:** Document the owner of each state category and enforce one-way dependencies: presentation controller → use case/service → repository. Keep cross-feature orchestration in a narrow workflow controller.

**Estimated effort:** Large — 1–2 weeks.

### Medium — XLSX decoding is duplicated

**Problem:** Excel import and local roster file flows decode workbooks independently.

**Impact:** File validation, merged-cell behavior, limits, and error messages can diverge.

**Recommended fix:** Share a low-level workbook adapter while keeping feature-specific row mapping separate.

**Estimated effort:** Medium — 2–4 engineering days.

### Medium — Time and timezone are implicit dependencies

**Problem:** Scheduling and calendar code uses direct `DateTime.now()` calls and mixed local/absolute time assumptions.

**Impact:** Tests can be nondeterministic and DST, overnight, or provider timezone behavior can be wrong.

**Recommended fix:** Inject a small clock abstraction and define a timezone policy at calendar and schedule boundaries.

**Estimated effort:** Medium — 3–5 engineering days.

### Medium — Lints do not enforce project standards

**Problem:** The analyzer is clean under `flutter_lints`, but file length, documentation coverage, dependency boundaries, and stricter correctness rules are not enforced.

**Impact:** The project can pass analysis while violating its own architectural and documentation requirements.

**Recommended fix:** Add selected strict analyzer rules gradually and a repository check for file size and forbidden dependency directions.

**Estimated effort:** Small — 1–2 engineering days plus incremental cleanup.

### Low — Unused runtime dependency

**Problem:** `cupertino_icons` is declared but not imported.

**Impact:** Minor dependency and maintenance noise.

**Recommended fix:** Remove it after confirming no planned Cupertino icon use, then refresh the lockfile and run the full validation suite.

**Estimated effort:** Small — less than one hour.

### Low — Empty and dormant folders reduce signal

**Problem:** `lib/core/services/` and `lib/core/widgets/` are empty, while several future-facing modules are disconnected.

**Impact:** Contributors cannot easily distinguish active architecture from planned structure.

**Recommended fix:** Remove empty directories from tracked documentation diagrams and label experimental modules explicitly until integrated.

**Estimated effort:** Small — less than one day.

### Low — Coverage and platform confidence are unmeasured

**Problem:** The test suite passes, but no coverage thresholds, release-mode smoke build, or live provider contract tests are part of this audit.

**Impact:** Untested branches and platform configuration failures may remain hidden.

**Recommended fix:** Add CI coverage reporting with pragmatic thresholds and platform smoke builds; keep provider contract tests isolated from the default deterministic suite.

**Estimated effort:** Medium — 2–5 engineering days.

## Recommended Next Implementation Task

**Separate Excel preview reading from full worksheet import and add a regression test for workbooks exceeding 50 rows.**

This is the only recommended next task because it resolves the highest-severity data-integrity risk without broadening feature scope.
