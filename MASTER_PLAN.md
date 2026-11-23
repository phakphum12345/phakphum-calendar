# SCE Master Plan

## 1. Project identity

- Product: Shift Tools
- Short name: SCE
- Codename: Nightingale
- Initial release target: 1.0
- Framework: Flutter
- Primary language: Dart

## 2. Mission

Create a reliable shift management platform that reads roster data from Google Sheets,
understands hospital-specific shift relationships and colors, validates business rules,
and synchronizes only confirmed changes to Google Calendar.

## 3. Core principles

1. Accuracy before automation.
2. The system must not guess unknown business rules.
3. Every synchronization must have a preview.
4. Source spreadsheets are read-only.
5. Every Calendar event must have a stable Sync ID.
6. Every change must be traceable.
7. Configuration is preferred over hardcoding.
8. Business rules must not live in UI widgets.
9. Google APIs must not be called directly from widgets.
10. Parser, rule engine, and calendar engine remain separate.

## 4. User flow

```text
เลือกไฟล์ตารางเวร

[เลือกไฟล์ต้นฉบับ]
[เลือกไฟล์ปัจจุบัน]
[เปรียบเทียบไฟล์]
[อัปเดต Google Calendar]
```

Files are selected through Google Drive Picker.

## 5. Architecture

```text
Presentation
  -> Application Use Cases
  -> Domain Models and Rules
  -> Infrastructure / Google APIs / Local Storage
```

Feature modules:

- Authentication
- Google Drive
- Google Sheets
- Shift Parser
- Relationship Engine
- Business Rule Engine
- Simulation
- Diff Engine
- Calendar Engine
- History
- Dashboard
- Reports
- Settings

## 6. Shift relationship model

Every parsed shift must be able to represent:

- Original Owner
- Actual Worker
- Transfer From
- Transfer To
- Relationship Type
- Status
- Source cell
- Source sheet
- Source spreadsheet
- Start and end date-time
- Background color
- Stable Sync ID

## 7. Synchronization behavior

The Calendar synchronization engine must operate by diff:

- Add new events
- Update changed events
- Delete events that no longer belong to the user
- Leave unchanged events untouched

Never delete and rebuild the entire calendar as a normal synchronization strategy.

## 8. Delivery support policy

The required application delivery targets are Windows and Web. Android, iOS,
and Linux also have active optional artifact workflows; macOS is paused:

```text
main
├── Required: Windows + Web
├── Optional artifacts: Android + iOS + Linux
└── Paused: macOS
```

Android, iOS, and Linux builds are best-effort and do not block the Final Gate.
Laravel Backend CI validates backend changes but is not a deployment workflow.

The detailed delivery state is maintained in `docs/DELIVERY_STATUS.md` and the
workflow support contract in `.github/workflows/README.md`.

## 9. CI/release contract

The required main-branch release evidence is:

- `.github/workflows/ci-auto-detect.yml` — capability-aware analysis and tests.
- `.github/workflows/windows.yml` — Windows x64 release ZIP and SHA-256 checksum.
- `.github/workflows/web.yml` — Flutter Web release artifact and GitHub Pages deployment.
- `.github/workflows/final-gate.yml` — verifies the required workflows for the same commit.

Optional artifact workflows build Android APK, unsigned iOS IPA, and Linux
archives. `.github/workflows/laravel.yml` runs backend tests on relevant
pull requests and `main` pushes; it does not deploy the API. Check Actions for
the result of a specific commit rather than treating a static PASS list as
current.

Failure-containment rules:

1. Optional Android, iOS, and Linux builds must never block required Windows/Web delivery.
2. Missing `integration_test/` must never fail a supported release workflow.
3. `coverage/lcov.info` is not a required artifact of Windows/Web release workflows.
4. Formatting changes are committed explicitly, not auto-committed by release gates.
5. Windows and Web workflows remain independent.

## 10. Roadmap

### Sprint 0 — Foundation
- project structure;
- documentation;
- coding rules;
- ADR system;
- base models;
- CI templates;
- test framework.

### Sprint 1 — Google integration
- Google Sign-In;
- Drive Picker;
- Sheets API;
- Calendar API;
- OAuth configuration guide.

### Sprint 2 — Shift parser
- dates;
- names;
- background colors;
- merged cells;
- normalized ShiftRecord.

### Sprint 3 — Relationships and rules
- own shift;
- received shift;
- given-away shift;
- major exchange;
- clinic exchange;
- borrowed name;
- overnight validation;
- conflicts and missing data.

### Sprint 4 — Calendar synchronization
- simulation;
- diff;
- preview;
- add/update/delete;
- extended properties;
- history.

### Sprint 5 — Dashboard and reports
- shift counts;
- working hours;
- OT;
- received/given shifts;
- history;
- PDF and spreadsheet exports.

### Sprint 6 — Production release
- security review;
- integration tests;
- multi-platform builds;
- release 1.0.

## 11. Definition of Done

A feature is complete only when:

- implementation is finished;
- `flutter analyze` passes;
- relevant unit tests pass;
- relevant widget tests pass;
- user-facing errors are understandable;
- documentation is updated;
- changelog is updated;
- an ADR exists when architecture changed.

## 12. Immediate next milestone

Maintain Windows and Web as the required delivery targets, keep Android, iOS,
and Linux artifact builds optional, and restore macOS only after an explicit
platform-specific verification cycle.
