# Flexible Workforce & Shift Scheduler

เอกสารชุดนี้กำหนดทิศทางการขยาย Shift Tools / Phakphum Calendar ไปสู่ระบบบริหารกำลังคนและจัดตารางเวรที่ผู้ใช้กำหนดโครงสร้างเองได้ โดยต่อยอดจาก roster, shift templates, rule engine, schedule generation, import/export, preview, calendar sync และ audit boundaries ที่มีเอกสารอยู่แล้ว

> **สถานะ:** Requirements and architecture proposal. ยังไม่ใช่หลักฐานว่า implementation หรือ acceptance tests ผ่านแล้ว  
> **หลักการเปลี่ยนแปลง:** เพิ่มความสามารถผ่านขอบเขตเดิม ไม่สร้าง roster store, parser, rule engine หรือ calendar sync subsystem ซ้ำ

## เอกสารในชุดนี้

| เอกสาร | เนื้อหา |
|---|---|
| [Requirements](REQUIREMENTS.md) | ข้อกำหนดผลิตภัณฑ์และ functional requirements |
| [Architecture](ARCHITECTURE.md) | Module boundaries, layers, flows, security |
| [Data Model](DATA_MODEL.md) | Canonical entities, relationships, integrity |
| [Roadmap](ROADMAP.md) | Phases, dependencies, delivery gates |
| [Acceptance Tests](ACCEPTANCE_TESTS.md) | เกณฑ์ตรวจรับและหลักฐานที่ต้องมี |

## ความสัมพันธ์กับระบบเดิม

- MASTER_PLAN.md ยังคงเป็น master plan ของ Shift Tools / SCE
- ARCHITECTURE.md, DATA_MODEL.md, BUSINESS_RULES.md และ docs/SCE_3_0_SYSTEM_DESIGN.md ยังคงเป็นเอกสารฐานของระบบเดิม
- เอกสารชุดนี้ขยายขอบเขตด้าน organization-defined workforce scheduling, configurable schedule layouts, import governance และ export design modes
- Google Calendar เป็นปลายทางการซิงก์ ไม่ใช่ฐานข้อมูลหลักของตารางเวร
- ต้องตรวจ source code, persistence, tests และ UI ก่อนระบุสถานะของ feature ใดว่า implemented

## Product invariants

1. Workspace ใหม่เริ่มต้นโดยไม่มีองค์กร หน่วยงาน บุคลากร ตารางเวร หรือข้อมูลตัวอย่างที่บันทึกเป็นข้อมูลจริง
2. ผู้ใช้กำหนดโครงสร้าง แถว คอลัมน์ วิชาชีพ ตำแหน่ง เวร สถานที่ และกฎได้
3. ข้อมูล canonical แยกจาก layout และ export presentation
4. Import เป็น candidate จนกว่าจะ preview, validate และยืนยัน
5. Generated schedules เป็น Draft จนกว่าผู้มีสิทธิ์อนุมัติ
6. Unknown, skipped หรือ missing evidence ไม่เท่ากับ PASS
7. ทุกการเปลี่ยนแปลงที่มีผลต่อข้อมูลต้องตรวจสอบย้อนหลังได้
8. ไม่เขียนทับหรือลบข้อมูลเดิมโดยไม่มี explicit confirmation และ recovery path
