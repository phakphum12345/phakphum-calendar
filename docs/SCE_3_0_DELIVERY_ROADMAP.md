# SCE 3.0 Delivery Roadmap

สถานะ: เอกสารแผนดำเนินงานบน repository; ยังไม่ถือว่า capability ใดเสร็จจนกว่าจะมี implementation, tests และหลักฐาน CI

## Guardrails

- ทำงานแบบ READ → ANALYZE → MODIFY → TEST → AUDIT ทุก phase
- ใช้ canonical `Schedule`, `ScheduleRepository`, `RuleEvaluator` และ Calendar Workflow เดิม ห้ามสร้าง source of truth ซ้ำ
- ทุกการเปลี่ยนแปลงลง feature branch และ PR; ไม่ push ตรงเข้า `main`
- ห้าม merge เมื่อ checks ยัง pending/failed, มี conflict, หรือมีผลกระทบต่อข้อมูลที่ยังไม่ได้ตรวจสอบ
- Google Sheets ใช้ read-only สำหรับการอ่านตารางเวร เว้นแต่มี action เฉพาะที่อธิบายและขอความยินยอมชัดเจน
- Google Calendar เขียนเฉพาะหลัง preview/ยืนยัน และป้องกัน duplicate/provider-owned events
- ห้ามส่งข้อมูลส่วนบุคคลหรือ spreadsheet URL ไปบริการ AI โดยอัตโนมัติ
- ทุก phase ต้องมี tests ที่ครอบคลุม behavior และ regression; ห้ามเปลี่ยน implementation map เป็น Complete จากเอกสารเพียงอย่างเดียว

## Phase 0 — Baseline, PR and release health

1. ตรวจ PR ที่เปิดอยู่ (#40 OAuth/Pages, #41 Timeline history, #42 roster parser support) และตรวจ head/base, conflicts, changed files, check runs และ deployment status ก่อนรวมงาน
2. ระบุความเปลี่ยนแปลงที่ซ้ำกันและเรียงลำดับการรวมตาม dependency; ห้ามเขียนทับการแก้ไขใน branch อื่น
3. ตรวจ workflows สำหรับ format, analyze, unit/widget tests, web/Android/Windows builds และ Pages deploy
4. เก็บ baseline ของ `main` และบันทึก check/run links ใน PR description

**Exit criteria:** มี baseline ที่ตรวจสอบย้อนกลับได้; รู้ว่า PR ใดพร้อม/ติดขัด; ไม่ merge PR ที่ยังไม่มีหลักฐานผ่าน

## Phase 1 — Navigation and Dashboard

- จัดเมนูหลักให้สอดคล้อง SCE 3.0: Dashboard, ตารางเวร, บุคลากร, แลกเวร, รายงาน, ตั้งค่า โดยคงเมนูเสริมและความแตกต่างของ Personal/Organization edition ที่จำเป็น
- ลดความรับผิดชอบของ `AppShell` แบบ incremental; ไม่ย้ายหน้าหรือ controller โดยไม่รักษา dependency lifecycle
- Dashboard ใช้ข้อมูลจาก canonical services: next shift, today/tomorrow, monthly counts, exchange requests, income estimate (เมื่อมีข้อมูลจริง), calendar sync และ conflicts
- ทุก quick action ต้องนำไปหน้าจอ/flow ที่มีอยู่จริง; ห้ามแสดงตัวเลขจำลองเป็นข้อมูลจริง
- เพิ่ม widget tests สำหรับ responsive breakpoints, edition-dependent destinations, empty/error/loading states และ dashboard summaries

**Exit criteria:** mobile/tablet/desktop navigation ใช้ได้, ไม่มี route index ผิดเมื่อ edition เปลี่ยน, tests ผ่าน

## Phase 2 — Roster editor, employees and templates

- ตรวจความสามารถ editor ปัจจุบันก่อนเพิ่ม bulk select, copy/repeat, move, recurring assignments และ preview
- เพิ่ม employee profile/availability/department/role ผ่าน domain/repository ที่มีอยู่; ตรวจ authorization ที่ application boundary
- ขยาย shift templates โดยไม่ hard-code อัตราและ policy
- รองรับ month/week/day/timeline/department/employee views ตาม capability ที่มีข้อมูลและ controller รองรับ
- เพิ่ม A4 print/export tests และ preserve existing schedule schema compatibility

**Exit criteria:** การแก้ไข roster ผ่าน canonical repository, bulk changes มี preview, employee/template tests ผ่าน

## Phase 3 — Rules, conflicts, policy and preview

- กำหนดสัญญา conflict result กลางและ mapping severity Error/Warning/Information
- ทำ rules configurable ต่อ workspace/profile และตรวจ duplicate, overlap, rest time, leave, holiday, role/department eligibility
- เพิ่ม Policy Engine แบบ explicit decision: Ask/Allow/Block/Warn/Require Approval/Override
- รวม preview semantics สำหรับ Create/Update/Delete/Unchanged/Skip/Conflict/Warning/Error/Auto Fixed
- Fail closed เมื่อข้อมูลจำเป็นไม่ครบ; ห้าม auto-fix แบบเงียบ

**Exit criteria:** deterministic tests, policy boundary tests, preview regression tests และมี audit reason สำหรับ override

## Phase 4 — Shift exchange, approval, notifications and audit

- สร้าง workflow Request → receiver acceptance → approval → conflict validation → canonical mutation → recalculation → calendar preview/sync → audit
- รองรับ accept/reject/cancel/withdraw และสถานะที่ชัดเจน
- Notification delivery ต้อง idempotent และไม่เปิดเผยข้อมูลข้าม workspace
- Audit log บันทึก actor, timestamp, action, before/after, source, result และ controlled error โดยไม่บันทึก secret/token

**Exit criteria:** state-transition tests, authorization tests, duplicate-request tests และ audit coverage

## Phase 5 — Payroll, overtime and reports

- สร้าง canonical payroll aggregate จาก assignment, employee, department, template และ workspace rates
- precedence: assignment override → employee override → department rate → template rate → workspace default
- รองรับ hourly/fixed, OT, night/holiday multiplier, allowances/deductions, preview และ locked period
- แสดง unavailable/unknown เมื่อข้อมูลอัตราไม่ครบ ห้ามแสดงยอดเงินที่แต่งขึ้น
- รายงานรายบุคคล/หน่วยงาน/OT/exchange/sync/audit และ export PDF/Excel/CSV/A4

**Exit criteria:** calculation tests รวม edge cases, rounding/timezone/overnight, locked-period protections และ export tests

## Phase 6 — Google Sheets import and relationship mapping

- คง read-only default; รองรับ spreadsheet/sheet/range selection, column mapping, validation และ source metadata
- ใช้ stable source IDs/checksum/incremental diff/history และ relationship mapping
- Import pipeline: Parse → Map → Rules → Conflicts → Preview → Confirm → canonical ScheduleRepository
- ไม่เขียนข้อมูลกลับ Google Sheets ใน flow import
- ตรวจ duplicate, partial parser recovery, timezone, malformed rows และ data privacy

**Exit criteria:** fixture-based parser tests, idempotent import tests, preview correctness, no source write calls

## Phase 7 — Google Calendar workflow

- ส่งเฉพาะเวรของผู้ใช้และรายการที่ผ่านเงื่อนไขอนุมัติ
- รักษา workflow ปัจจุบัน: UserShiftEventMapper → Candidate → Diff → Preview → Plan → Executor → Gateway
- เพิ่ม stable sync IDs, duplicate prevention, provider-event protection, retry/resume และ offline queue
- ทุก destructive action ต้องมี preview และ confirmation; Timeline/history read-only ต้องไม่ trigger Calendar writes
- เก็บ sync history และผลราย event พร้อม controlled errors

**Exit criteria:** create/update/delete/skip/retry tests, duplicate protection tests และ integration mocks ยืนยันว่า history-only ไม่เขียน Calendar

## Phase 8 — Workspace/profile, permissions and backup/restore

- แยก Workspace, Organization/Hospital และ Personal Profile พร้อม override precedence
- ตรวจ tenant/workspace isolation ทุก repository/service/action
- ทำ versioned JSON หรือ encrypted ZIP backup/restore พร้อม preview, merge/replace, validation และ history
- ไม่ใส่ OAuth token, secret หรือ credential ลง backup โดยปริยาย
- ทดสอบ corrupted/old-version backup และ rollback/failure safety

**Exit criteria:** isolation tests, migration compatibility tests, backup round-trip tests และ restore preview

## Phase 9 — Localization, accessibility, performance and release

- ย้ายข้อความที่ยัง hard-code ไป localization โดยเริ่มจากหน้าที่แก้ใน phases ก่อนหน้า
- ตรวจ keyboard/focus/semantics, text scaling, responsive layout, contrast และ empty/error states
- ตรวจ startup, large rosters, parser throughput, sync retries และ memory/disk failure paths
- รัน `dart format .`, `flutter analyze`, `flutter test`, web/Android/Windows build และ workflow gates ที่ repo กำหนด
- ตรวจ release artifacts, Pages deployment, auth configuration และ smoke tests หลัง deploy

**Exit criteria:** CI green สำหรับ commit SHA เดียวกัน, artifact/deploy evidence, no unresolved high-severity issues

## Working queue

| Order | Work item | Depends on | State |
|---|---|---|---|
| 1 | Verify current PRs #40/#41/#42 and release baseline | None | In progress |
| 2 | Navigation/Dashboard gap analysis and tests | 1 | Planned |
| 3 | Roster editor + employees/templates | 2 | Planned |
| 4 | Rules/conflicts/policy/preview contracts | 3 | Planned |
| 5 | Exchange/approval/notifications/audit | 4 | Planned |
| 6 | Payroll and reports | 3, 4 | Planned |
| 7 | Sheets mapping/import hardening | 1, 3, 4 | Planned |
| 8 | Calendar workflow hardening | 1, 4, 7 | Planned |
| 9 | Workspace/permissions/backup | 3, 4 | Planned |
| 10 | Localization, accessibility, release audit | All applicable phases | Planned |

## Definition of done for every PR

- Scope and compatibility impact described.
- Tests added/updated for behavior and regression.
- Format/analyze/test/build results reported with exact commit SHA and links.
- No secrets, tokens, personal data, or spreadsheet URLs in logs/test fixtures.
- Implementation map updated only for verified completed capabilities.
- PR merged only when checks are green, conflicts are resolved, and changed files are audited.
