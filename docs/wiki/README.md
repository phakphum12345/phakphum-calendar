# Shift Tools — Project Wiki

เอกสารชุดนี้เป็นศูนย์กลางสำหรับการพัฒนา ทดสอบ ดูแล และเผยแพร่ Shift Tools ตั้งแต่รุ่นทดลองจนถึง Production

## เริ่มต้นอ่าน

1. [ภาพรวมสถาปัตยกรรม](ARCHITECTURE.md)
2. [มาตรฐานการเขียนโค้ด](CODING_STANDARDS.md)
3. [ข้อกำหนด Rule Engine](RULE_ENGINE_SPEC.md)
4. [แนวทางการทดสอบ](TESTING_GUIDE.md)
5. [แนวทางการมีส่วนร่วม](CONTRIBUTING.md)
6. [ขั้นตอนการออกเวอร์ชัน](RELEASE_PROCESS.md)
7. [ความเป็นส่วนตัวและความปลอดภัย](SECURITY_AND_PRIVACY.md)

## หลักการสำคัญ

- อ่านข้อมูลต้นทางแบบ read-only เป็นค่าเริ่มต้น
- แสดง Preview และ Conflict ก่อนเขียน Google Calendar
- ห้ามเดากฎที่อาจกระทบเวรจริงโดยไม่มีคำเตือนหรือการยืนยัน
- แยก Domain Logic ออกจาก Flutter UI และบริการภายนอก
- การเปลี่ยนกฎสำคัญต้องมี Unit Test และบันทึกใน CHANGELOG
- ห้าม commit token, OAuth secret, ลิงก์ชีตส่วนตัว หรือข้อมูลผู้ป่วย


## Repository-wide engineering status

- [Central documentation index](../../DOCUMENTATION_INDEX.md)
- [Implementation status](../../IMPLEMENTATION_STATUS.md)
- [Requirements traceability](../../REQUIREMENTS_TRACEABILITY.md)
- [Backend API documentation](../../backend/API_DOCUMENTATION.md)
- [Backend database schema](../../backend/DATABASE_SCHEMA.md)
