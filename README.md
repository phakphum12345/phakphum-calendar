# Shift Tools

Shift Tools is implementing the **Shift Calendar Engine (SCE) 3.0**
architecture. The canonical product specification and incremental migration
status are maintained in:

- [SCE 3.0 system design](docs/SCE_3_0_SYSTEM_DESIGN.md)
- [SCE 3.0 implementation map](docs/SCE_3_0_IMPLEMENTATION_MAP.md)

แอป Flutter สำหรับอ่านตารางเวรจาก Google Sheets แบบ read-only ตรวจรายการก่อนบันทึก และเพิ่มเวรที่ยืนยันแล้วลง Google Calendar รองรับ UI บน Web, Android, iOS, Windows, macOS และ Linux

## Quick preview (Web)

This repository builds a Flutter web version of the app and includes a GitHub Actions
workflow that publishes the `build/web` output to GitHub Pages on the `gh-pages`
branch when pushed to `main`.

- Expected Pages URL (after first successful deploy):
  https://phakphoum38-stack.github.io/phakphum-calendar

- To trigger a deploy manually, push to `main` or run the `Build Flutter Web` workflow
  from the Actions tab.

- To build and preview locally:

```bash
flutter pub get
flutter build web --release
cd build/web
# serve locally (Python)
python3 -m http.server 8080
# then open http://localhost:8080
```

If your environment doesn't have Flutter installed, the repository also contains
a GitHub Actions workflow that builds and deploys the web app automatically.

- แอปไม่ฝังลิงก์ชีต บัญชี Google, OAuth Client ID, token หรือผลลัพธ์ตารางเวรไว้ในซอร์สโค้ด
- มีช่อง **ชื่อที่ต้องค้นหา** ซึ่งเริ่มต้นว่าง ใช้เฉพาะรอบใช้งาน และใช้ชื่อโปรไฟล์ Google เป็นชื่อสำรอง
- ช่องชีต ชื่อ เดือน และปีเริ่มต้นว่าง ไม่มีค่าของผู้ใช้ฝังในแอปหรือ repository ผู้ใช้เลือกเดือนและปี ค.ศ. เองก่อนอ่าน
- ไอคอนแอปเป็นรูปชีตและปฏิทินบนทุกแพลตฟอร์มที่โปรเจกต์สร้างให้

## เวอร์ชันการใช้งาน

การเปิดแอปครั้งแรกต้องเลือกหนึ่งเวอร์ชัน และเปลี่ยนภายหลังได้จาก
**ตั้งค่า → เวอร์ชันการใช้งาน** โดยการสลับเวอร์ชันไม่ลบข้อมูลเดิม:

| เวอร์ชัน | เมนูและขอบเขตหลัก |
| --- | --- |
| บุคคลทั่วไป | แดชบอร์ด ตารางเวร รายเดือน รายงาน ตั้งค่า และ Google Calendar |
| องค์กร | ระบบบุคคลทั่วไปทั้งหมด พร้อมรายชื่อ บุคลากร แลกเวร บทบาท และ Admin Console |

ค่าที่เลือกเก็บใน local storage ของอุปกรณ์/เบราว์เซอร์ ไม่มีเวอร์ชันหรือ
ข้อมูลองค์กรฝังตายตัวใน build

## SCE 3.0 Phase 2

- หน้า **บุคลากร** เพิ่ม แก้ไข ค้นหา กรอง และปิดใช้งานข้อมูลบุคลากร
  แบบ soft deactivation โดยไม่ทำลายประวัติตารางเวร
- หน้า **ตั้งค่า → แม่แบบเวร** กำหนดรหัส ชื่อ เวลา สี ชั่วโมงทำงาน
  และอัตราเงินเวรได้ โดยมีแม่แบบเริ่มต้นที่แก้ไขได้
- หน้า **ตารางเวร → จัดตารางเวรด้วยตนเอง** เพิ่มหรือลบผู้ปฏิบัติงาน
  หลัง Preview และบันทึก canonical Schedule ผ่าน repository เดิม
- Employee Directory และ Shift Templates ใช้ storage key แยกจากข้อมูล legacy
  และ dependencies ทั้งหมดถูกสร้างจาก `AppDependencies`


### โครงสร้างตารางเวรรายเดือนแบบยืดหยุ่น

`MonthlyRosterSectionParser` เตรียมโครงสร้างสำหรับอ่านแท็บตารางรายเดือน
ที่มีหลายบล็อกต่อกัน เช่น เวรใหญ่, exten และคลินิก โดยค้นหาแต่ละบล็อกจาก
แถวหัวข้อ `วันที่` และเลขวันที่อย่างน้อย 7 คอลัมน์ ไม่ผูกกับชื่อบล็อก
ชื่อสถานที่ จำนวนแถว หรือจำนวนวันแบบตายตัว

ข้อมูลที่อ่านได้ในแต่ละรายการประกอบด้วย:

- ชื่อบล็อกตามหัวเรื่องในชีต
- ชื่อแถวหรือสถานที่ปฏิบัติงานตามค่าจริง
- ชื่อผู้ปฏิบัติงานและวันที่
- ตำแหน่งเซลล์ต้นทางและสีพื้นหลัง

หัวเรื่องรองรับทั้งช่วงวันที่และข้อความเดือน พ.ศ. ชื่อบล็อกใหม่หรือชื่อแถวใหม่
จึงเพิ่มใน Google Sheets ได้โดยไม่ต้องเพิ่ม enum หรือแก้เงื่อนไขชื่อใน parser
เมื่ออ่านไฟล์ แอปจะแปลง snapshot ชุดเดียวกับขั้น import และแสดงผลในเมนู
**รายเดือน** ผู้ใช้ค้นหาชื่อบล็อก สถานที่ หรือผู้ปฏิบัติงาน กรองแต่ละบล็อก
กำหนดช่วงวันที่ และอ่านเซลล์ใหม่ได้โดยไม่แก้ไขไฟล์ต้นฉบับ

แท็บ **รายเดือน** มี workflow นำเข้าของตัวเองโดยไม่เปลี่ยนหน้า Import หลัก:

- เลือก Google Sheets จากบัญชีที่ล็อกอิน หรือนำเข้า `.xlsx`, `.csv`, `.tsv`
  และ `.txt` จากเครื่อง
- เปิดกล้องหรือเลือกรูป แล้วตรวจภาพตัวอย่างก่อนบันทึกและ Import
- กด `+` เพื่อสร้างเทมเพลตรายเดือนแบบว่าง กำหนดช่วงวันที่ และเพิ่มกลุ่มเวร
  ได้หลายกลุ่ม
- แก้ไขหรือลบเทมเพลตที่สร้างไว้ได้ โดยเทมเพลตเก็บเฉพาะใน local storage
- ถ้า parser อ่านโครงสร้างตารางไม่ได้ แอปจะสร้างมุมมองรายเดือนกลางจาก
  รายการเวรที่ Import ได้

### รายชื่อและสถานะรายวัน

แท็บ **รายชื่อ** ใช้รายชื่อเจ้าหน้าที่ร่วมกับมุมมองตารางเวรรายวัน:

- เพิ่มรายชื่อหลายคนพร้อมกัน โดยใส่หนึ่งชื่อต่อหนึ่งบรรทัดหรือคั่นด้วยจุลภาค
- Import ไฟล์ตารางเวรด้วย parser ชุดเดียวกับแท็บรายเดือน
- เลือกวันที่อ้างอิง แล้วแปลงชื่อแถวในต้นฉบับเป็นสถานะ `เวร`, `แทนเวร`,
  `OFF`, `ลากิจ`, `ลาป่วย`, `ลาพักร้อน`, `ลาคลอด` หรือ `ลาบวช`
- เปลี่ยนสถานะของแต่ละคนจาก Dropdown หลังชื่อ
- ติ๊ก **ล็อก** และระบุจุดเวรหนึ่งจุดต่อคนได้ ส่วน generation API รองรับ
  `lockedDutyPointsByEmployeeId` เพื่อเลือกบุคคลนั้นที่จุดเดิมก่อนและไม่นำ
  ไปจัดในจุดอื่นเมื่อ caller ส่ง mapping นี้เข้า `GenerationRequest`
- การอ่านรายชื่อและสถานะไม่แก้ไขไฟล์ต้นฉบับ และการตั้งค่าล็อกในเครื่อง
  จะยังคงอยู่เมื่อ Import รายชื่อใหม่

### Admin Console

แท็บ **Admin** เป็นหน้าตั้งค่าบทบาทแบบกำหนดภายหลัง:

1. ค่าเริ่มต้นไม่มีบัญชี Admin หรืออีเมลฝังอยู่ในซอร์สโค้ด
2. ล็อกอิน Google แล้วกด **กำหนดบัญชีนี้เป็น Admin** เพื่อ bootstrap
   ผู้ดูแลคนแรก
3. Admin เพิ่มอีเมลและกำหนดบทบาท `Admin`, `Manager`, `In-charge`
   หรือ `Staff` ได้
4. ระบบปฏิเสธหน้า Admin Console สำหรับบัญชีที่ไม่ใช่ Admin และไม่อนุญาต
   ให้ลบ Admin คนสุดท้าย
5. หน้าจอแสดงสิทธิ์จาก `AccessPolicy` ของแต่ละบทบาท

การตั้งค่า Admin รุ่นปัจจุบันเก็บเฉพาะอุปกรณ์/เบราว์เซอร์ จึงเหมาะกับ
single-device configuration และการเตรียม workflow เท่านั้น หากต้องการบังคับ
สิทธิ์ร่วมกันหลายเครื่องหรือหลายผู้ใช้ใน production ต้องใช้ backend identity
store และตรวจ authorization ฝั่งเซิร์ฟเวอร์ ไม่ควรถือ local storage เป็น
security boundary ฝั่งเซิร์ฟเวอร์

## Version 4.1

- ค้นหา Google Sheets ได้ทั้งเรียงจากเวลาสร้างครั้งแรกและ
  `modifiedByMeTime` ล่าสุด โดยขอเฉพาะ `drive.metadata.readonly`
- เลือกเดือน/ปี ค.ศ. ได้หลายรายการโดยไม่จำกัด และอ่าน Calendar แยกตาม
  ช่วงที่เลือกก่อนรวมผล
- อ่านไฟล์ `.xlsx`, `.csv`, `.tsv` และ `.txt` ในหน่วยความจำ
  โดยไม่อัปโหลดชื่อไฟล์หรือเนื้อหา
- ปรับชื่อ เวลา ประเภท การเลือกใช้ และสี Calendar รายรายการได้
  สีรับคำสั่งเลข 1–11 หรือชื่อสี และใช้สีประเภทเป็นค่าเริ่มต้นเมื่อเว้นว่าง
- เปิดหรือลบกิจกรรม Calendar จากรายการชนได้ การลบต้องยืนยันก่อน
- รูป ภาพถ่าย กล้อง เว็บไซต์ และ Workspace อื่นใช้แบบกรอกและตรวจเอง
  แอปไม่เดาข้อมูลเวรด้วย OCR ที่ยังไม่ได้กำหนด

## Version 2.0 Foundation

โปรเจกต์นี้รวมรากฐานสำหรับหลายโรงพยาบาล หลายแผนก RBAC การแลกเวร Audit Log และ Rule Engine แล้ว ดูรายละเอียดที่ [Version 2.0 Wiki](docs/wiki/v2/README.md)

## เอกสารโครงการและ Wiki

เริ่มอ่านเอกสารสำหรับนักพัฒนาและการเตรียม Production ได้ที่ [Project Wiki](docs/wiki/README.md) ซึ่งรวม Architecture, Coding Standards, Rule Engine Specification, Testing, Contributing, Release และ Security/Privacy

- [คู่มือติดตั้งและใช้งานฉบับสมบูรณ์](docs/INSTALLATION_AND_USER_GUIDE.md)
- [การตั้งค่า Google](docs/GOOGLE_SETUP.md)
- [Laravel API](backend/README.md)

## Flutter + Laravel

repository นี้ประกอบด้วย:

- แอป Flutter ใน `lib/` สำหรับ import, calendar, validation, reports และ Google Calendar workflow
- Laravel API ใน `backend/` สำหรับ health, readiness และ diagnostic error intake

Laravel เป็น operational/future server boundary และยังไม่เปลี่ยน canonical Schedule,
local persistence หรือ Google Calendar synchronization ของแอป ดูวิธีติดตั้งและ API
ทั้งหมดที่ [backend/README.md](backend/README.md)


## สถานะของแต่ละระบบ

| ระบบ | เปิด UI | Google Sign-In/API ในแอป native | ไฟล์จาก GitHub Actions |
| --- | --- | --- | --- |
| Web | รองรับ | รองรับเมื่อตั้ง Web OAuth | `phakphum-calendar-web` และ GitHub Pages |
| Android | รองรับ | รองรับเมื่อตั้ง Android OAuth | `phakphum-calendar-android-apk` |
| iOS | รองรับ | รองรับเมื่อตั้ง iOS OAuth | `phakphum-calendar-ios-unsigned-ipa` |
| Windows | รองรับ | ยังไม่รองรับโดยแพ็กเกจที่ใช้ ให้เปิด Web สำหรับงาน Google | `phakphum-calendar-windows` |
| macOS | รองรับ | รองรับเมื่อตั้ง macOS OAuth และ URL scheme | `phakphum-calendar-macos` |
| Linux | รองรับ | ยังไม่รองรับโดยแพ็กเกจที่ใช้ ให้เปิด Web สำหรับงาน Google | `phakphum-calendar-linux` |

รายการระบบปฏิบัติการที่ Flutter รุ่นปัจจุบันรองรับดูได้จาก [Flutter supported platforms](https://docs.flutter.dev/reference/supported-platforms)

## วิธีใช้งาน

### 1. เตรียม Google Sheets

1. ให้ตารางมีชื่อผู้ปฏิบัติงานตรงกับชื่อเต็ม ชื่อจริง หรือนามสกุลในโปรไฟล์ Google ที่จะล็อกอิน
2. Google Sheets ต้นฉบับต้องเป็นไฟล์ที่บัญชีนั้นเป็นเจ้าของ ไม่ใช่ไฟล์ของบัญชีอื่นที่แชร์มา
3. คัดลอก URL ของชีตจากเบราว์เซอร์ แอปไม่กำหนดชีตส่วนกลางและไม่ส่ง URL นี้ขึ้น GitHub

ตัวอ่านรองรับเวร P1–P4, IPD, CT IPD, CT ER, ER, GEN และ 14 ชั้นตามรูปแบบตารางของโปรเจกต์

### 2. ล็อกอินและอนุญาตสิทธิ์

1. เปิดแอปแล้วกด **เข้าสู่ระบบด้วย Google**
2. เลือกบัญชี Google ที่เป็นเจ้าของชีตต้นฉบับ
3. เมื่อป็อปอัพสิทธิ์ปรากฏ ให้ตรวจรายการสิทธิ์ก่อนอนุญาต
4. แอปใช้ชื่อที่กรอกเป็นลำดับแรก และใช้ชื่อเต็ม/ส่วนของชื่อโปรไฟล์ Google เป็นชื่อสำรอง

แอปตรวจสิทธิ์อ่านที่เคยอนุญาตก่อน จึงไม่ควรแสดงป็อปอัพซ้ำโดยไม่จำเป็น ขั้นตอนอ่านใช้ Drive metadata แบบ read-only เพื่อตรวจ `ownedByMe` สิทธิ์เขียน Calendar, สำเนา Drive และสร้างแท็บชีตจะถูกขอเมื่อผู้ใช้เรียกฟังก์ชันนั้น

### 3. อ่านและตรวจตารางเวร

1. กด **เลือกไฟล์จาก Google Sheets** แล้วเลือกไฟล์ที่บัญชีเข้าถึงได้โดยตรง
   หรือเลือกไฟล์ `.xlsx`, `.csv`, `.tsv`, `.txt` ในเครื่อง
   ปุ่ม **เปิดกล้อง** จะขอสิทธิ์และเปิดกล้องทันที หลังถ่ายสามารถเลือก
   **บันทึกและ Import**, **ถ่ายใหม่** หรือ **ยกเลิก**
2. กรอก **ชื่อที่ต้องค้นหา** ให้ตรงกับชื่อในตารางเวร หรือปล่อยว่างเพื่อใช้ชื่อบัญชี Google
3. เลือก **เดือน** และ **ปี ค.ศ.** แล้วกด **เพิ่มเดือน (ไม่จำกัด)**
   หรือไม่กดเพิ่มเพื่ออ่านเดือนที่เลือกเพียงเดือนเดียว
4. เปิดหรือปิด **เก็บสำเนาต้นฉบับใน Drive** ตามต้องการ
5. กด **รีเฟรช/อ่านใหม่ตอนนี้** แอปจะยืนยันก่อนว่าไฟล์เป็นของบัญชีปัจจุบัน แล้วบันทึกเป็นไฟล์หลักของบัญชีนั้นเฉพาะในเครื่อง
6. ไปแท็บ **ตัวอย่าง** กด **ตั้งชื่อ เวลา ประเภท และสี** เพื่อตรวจหรือแก้
   และเลือกว่าจะนำรายการใดไปใช้
7. กด **เปรียบเทียบ Calendar** เพื่อตรวจรายการซ้ำและเวลาที่ชนกับกิจกรรมเดิม
8. ถ้ามีป็อปอัพแจ้งเตือน ให้เปิดแท็บ **แจ้งเตือน** แล้วตัดสินใจทุกรายการ
9. ตรวจตัวเลข “อ่านพบ / เลือกไว้ / มีใน Calendar / รอเพิ่ม / แจ้งเตือนค้าง” ก่อนดำเนินการ
10. กด **ยืนยันและบันทึก Calendar** เฉพาะเมื่อรายการถูกต้อง

แอปอ่านชีตต้นฉบับด้วย `spreadsheets.readonly` และไม่มีคำสั่งแก้เซลล์ในขั้นตอนอ่านเวร การเขียน Calendar จะเกิดหลังผู้ใช้กดยืนยันเท่านั้น

### 3.1 ใช้แท็บรายเดือนและรายชื่อ

1. เปิดแท็บ **รายเดือน** แล้วเลือก Google Sheets, ไฟล์ในเครื่อง, กล้อง
   หรือรูปภาพจากหน้านี้ได้โดยตรง
2. ตรวจบล็อก วันที่ แถวเวร และรายชื่อที่ parser อ่านได้ หรือกด `+`
   เพื่อสร้างเทมเพลตว่างและกลุ่มเวรเอง
3. เปิดแท็บ **รายชื่อ** เลือกวันที่อ้างอิง แล้วกด **Import ไฟล์**
4. ตรวจสถานะที่อ่านจากแถวต้นฉบับ และแก้จาก Dropdown เมื่อจำเป็น
5. ติ๊ก **ล็อก** เฉพาะบุคคลที่ต้องอยู่จุดเวรเดิม แล้วระบุชื่อจุดเวรให้ตรงกับ
   location ที่ใช้ในกฎ Generate
6. ในมุมมองตารางเวรรายวัน กดอ่านรายชื่อใหม่เพื่อแสดงข้อมูลที่บันทึกไว้ล่าสุด

หน้า **บุคลากร** ในรุ่นองค์กรสามารถกางแต่ละคนเพื่อดูวันที่และเวลาของเวร
จากตารางปัจจุบันได้ ปุ่ม **ซิงค์ข้ามอุปกรณ์** รวมข้อมูลกับไฟล์ส่วนตัว
ใน Google Drive ของบัญชีที่ล็อกอิน โดยใช้รหัสบุคลากรเป็นตัวจับคู่
ถ้ารหัสเดียวกันมีข้อมูลต่างกัน จะใช้ข้อมูลในอุปกรณ์ที่กดซิงค์

ปุ่ม **นำเข้าจาก Google Contacts** และ **ส่งออกไป Google Contacts**
จะแสดงรายการให้ตรวจและขอยืนยันก่อนทุกครั้ง ไม่มีการลบรายชื่อใน Contacts
และการส่งออกจะปรับปรุงเฉพาะ contact ที่แอปเคยติดป้ายรหัสไว้แล้ว
การทำงานเหล่านี้ต้องเปิด People API และตั้งค่า OAuth ตาม
[Google Setup](docs/GOOGLE_SETUP.md)

เมื่ออ่านตารางจาก Google Sheets แอปจะดึง revision ที่ Google Drive อนุญาต
แบบชั่วคราว เพื่อแสดงลำดับการเปลี่ยนชื่อผู้เข้าเวรของตำแหน่งเดียวกัน
ข้อมูลประวัติอาจไม่พร้อมใช้หาก Drive ไม่ส่ง revision export ที่อ่านได้

#### ค้นหาไฟล์ต้นฉบับจาก Drive metadata

- แอปเรียก Drive `files.list` ด้วย `drive.metadata.readonly` และแสดงเฉพาะ Google Sheets ที่บัญชีปัจจุบันเป็นเจ้าของ
- เลือกเรียงจาก `createdTime` ก่อนสุดหรือ `modifiedByMeTime` ล่าสุดได้
  สูงสุด 20 ไฟล์ และแสดง 10 ไฟล์แรกในหน้าแรก
- กดลูกศรข้างไฟล์เพื่อเลือกเป็นไฟล์หลัก แอปจะตรวจ `ownedByMe` ซ้ำก่อนบันทึกลิงก์ไว้ในเครื่อง
- รายการประวัติและชื่อไฟล์ใช้เฉพาะในหน่วยความจำ ไม่ถูกเขียนลง Audit log หรืออัปโหลดไป GitHub
- ฟังก์ชันนี้อ้างอิงเวลาที่ไฟล์ถูกแก้ไข ไม่ใช่รายละเอียดการเปลี่ยนแปลงระดับเซลล์ของ Google Sheets

#### เวลาเวรมาตรฐาน

| ประเภทเวร | เวลา |
|---|---|
| P1/P2/P3/P4 เช้า | 08:00–16:00 |
| P1/P2/P3/P4 บ่าย | 16:00–00:00 |
| P1/P2/P3/P4 ดึก | 00:00–08:00 |
| IPD เช้า | 08:00–16:00 |
| IPD บ่าย | 16:00–08:00 วันถัดไป |
| CT IPD เช้า | 08:00–16:00 |
| CT IPD บ่าย | 16:00–08:00 วันถัดไป |
| CT ER เช้า | 08:00–16:00 |
| CT ER บ่าย | 16:00–08:00 วันถัดไป |
| ER เช้า | 08:00–16:00 |
| ER บ่าย | 16:00–00:00 |
| ER ดึก | 00:00–08:00 |
| GEN เช้า | 07:30–12:00 |
| GEN บ่าย | 16:30–20:00 |
| 14 ชั้น เช้า | 07:00–08:00 |

#### สีจากไฟล์หลักไป Google Calendar

แอปใช้ Google Sheets `effectiveFormat` หรือรูปแบบเซลล์ใน `.xlsx`
เพื่ออ่านสีพื้นหลัง หน้า **ตัวอย่าง** จะแสดงทั้งสีจากไฟล์หลักและสี Calendar
ที่จะใช้ ผู้ใช้แก้ประเภท หรือพิมพ์เลขสี 1–11/ชื่อสีก่อนบันทึกได้

| สีในไฟล์หลัก | ความหมาย | สี Google Calendar |
|---|---|---|
| กราไฟต์ | เวรของตัวเอง | กราไฟต์ |
| มะเขือเทศ | เวรคนอื่น | มะเขือเทศ |
| ฟ้า | เวรคลินิก | ฟ้า |
| ลาเวนเดอร์ | แลกเวรใหญ่ | มะเขือเทศ |
| เผือก | เวรคลินิก (แบบพิเศษ) | อะโวคาโด |
| กล้วยหอม | ยืมชื่อเวร (ไม่จ่าย) | กล้วย/เหลือง |
| นกแก้ว | ยืมชื่อเวร (จ่าย) | เขียว |
| ลาเวนเดอร์ | ยกเวร | ลาเวนเดอร์ |

เนื่องจาก **แลกเวรใหญ่** และ **ยกเวร** ใช้สีลาเวนเดอร์ต้นทางเหมือนกัน แอปจะแสดงคำเตือนให้ตรวจประเภทในหน้า **ตัวอย่าง** แทนการเดาแล้วส่งสีผิด

#### เวรดึก, OFF และป็อปอัพรายการชน

- เวรดึกทุกเวรที่ทำงาน 00:00–08:00 จะสร้างรายการ `OFF` 08:00–16:00 ของวันเดียวกันอัตโนมัติ
- ชื่อกิจกรรมใน Calendar ใช้ชื่อเวรจากชีตพร้อมรหัส เช่น `P1 เช้า (UP1)` และรายการพักใช้ `OFF — เวรออฟหลังเวรดึก`
- แอปตรวจเวรที่ซ้อนกันในชีต, เวรที่ชนช่วง OFF, เวรที่ชนกิจกรรมเดิมใน Google Calendar และกิจกรรม Calendar ที่ชนช่วง OFF 08:00–16:00
- กิจกรรม Calendar ที่ตั้งเป็นว่าง (`transparent`) และกิจกรรมที่แอปเคยสร้างเองจะไม่ถูกแจ้งซ้ำ
- ถ้าพบรายการชน แอปจะแสดงป็อปอัพและหยุดการเขียน Calendar จนกว่าจะเลือก **รับทราบและคงไว้**, **ยืนยันรายการ** หรือ **ไม่นำเข้าปฏิทิน**
- ก่อนเขียนจริง แอปจะอ่าน Calendar ซ้ำอีกครั้งเพื่อป้องกันกิจกรรมใหม่ที่ถูกเพิ่มหลังการเปรียบเทียบครั้งแรก
- รายการชนจาก Calendar มีปุ่ม **เปิดกิจกรรม** และ **ลบกิจกรรม**
  โดยแอปจะขอสิทธิ์เขียนและยืนยันอีกครั้งเฉพาะเมื่อผู้ใช้กดลบ
- การตัดสินใจแจ้งเตือนเก็บในพื้นที่ของแอปบนเครื่องนั้นเท่านั้น ไม่ถูก commit หรืออัปโหลดไปยัง repository

### 4. ใช้แท็บบันทึก

- **บันทึกชีตปัจจุบัน** เก็บ URL อ้างอิงไว้เฉพาะอุปกรณ์/เบราว์เซอร์และแยกตามบัญชี Google
- **ใช้ไฟล์นี้** เปลี่ยนไฟล์หลักเฉพาะของบัญชีที่ล็อกอิน หลังตรวจความเป็นเจ้าของซ้ำ
- **เปิดดู** เปิดชีตจริงด้วยบัญชีที่ล็อกอิน ผู้ใช้จะแก้ชีตได้ตามสิทธิ์ที่ Google กำหนด
- **ลบ** ลบเฉพาะรายการอ้างอิงในแอป ไม่ลบไฟล์ Google Sheets จริง
- **สร้างชีตเดือนล่วงหน้า** ทำสำเนาแท็บต้นแบบเป็นแท็บใหม่ ผู้ใช้ควรตรวจวันที่และรายชื่อในแท็บใหม่ก่อนใช้งาน

### 5. Auto refresh และสำเนาต้นฉบับ

- Auto refresh เลือกช่วง 1–60 วินาทีได้ รอบใหม่จะไม่เริ่มซ้อนกับรอบที่ยังทำงาน
- ช่วง 1 วินาทีอาจแตะโควตา Google Sheets API หากพบ `429` ให้เพิ่มเป็น 2–10 วินาที
- เมื่อเปิดการเก็บสำเนา แอปสร้างสำเนาต้นฉบับใน Drive หนึ่งครั้งต่อไฟล์และเดือนก่อนซิงก์ โดยไม่แก้หรือลบไฟล์ต้นฉบับ
- ไฟล์ในเครื่องไม่ถูก Auto refresh และไม่ถูกอัปโหลดไป Drive อัตโนมัติ

## ติดตั้งจาก GitHub Actions

หน้า repository: [phakphoum38-stack/phakphum-calendar](https://github.com/phakphoum38-stack/phakphum-calendar)

1. เปิดแท็บ **Actions**
2. เลือก workflow ของระบบที่ต้องการ
3. เปิด run ล่าสุดที่สำเร็จบนสาขา `main`
4. เลื่อนลงส่วน **Artifacts** แล้วดาวน์โหลด artifact ตามตารางด้านบน
5. แตก ZIP ที่ GitHub สร้างครอบ artifact ก่อน แล้วจึงใช้ไฟล์แอปภายใน

GitHub กำหนดให้ผู้ดาวน์โหลด artifact ล็อกอินและมีสิทธิ์อ่าน repository ขั้นตอนมาตรฐานดูได้ที่ [Downloading workflow artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts?tool=webui)

ดาวน์โหลดผ่าน GitHub CLI ได้เช่นกัน:

```powershell
gh auth login
gh run list --repo phakphoum38-stack/phakphum-calendar
gh run download RUN_ID --repo phakphoum38-stack/phakphum-calendar
```

### ตรวจ SHA-256 ก่อนติดตั้ง

แต่ละ artifact มี `SHA256SUMS.txt` ยกเว้น Web artifact ที่ GitHub Pages นำไป deploy โดยตรง

Windows PowerShell:

```powershell
Get-FileHash .\phakphum-calendar-windows.zip -Algorithm SHA256
Get-Content .\SHA256SUMS.txt
```

macOS:

```bash
shasum -a 256 phakphum-calendar-macos.zip
cat SHA256SUMS.txt
```

Linux:

```bash
sha256sum -c SHA256SUMS.txt
```

ค่า hash ที่คำนวณต้องตรงกับบรรทัดของไฟล์นั้นใน `SHA256SUMS.txt`

## ติดตั้ง Web / PWA

1. เปิด [GitHub Pages ของแอป](https://phakphoum38-stack.github.io/phakphum-calendar/) ด้วย Chrome, Edge หรือ Safari รุ่นปัจจุบัน
2. หากเว็บแจ้งว่ายังไม่ได้ตั้ง OAuth ให้กด **ตั้งค่า Google OAuth** แล้ววาง Web Client ID ของโปรเจกต์ Google Cloud ที่เชื่อถือได้
3. ใน Chrome/Edge กดไอคอนติดตั้งที่แถบที่อยู่ หรือเมนู **Install app / ติดตั้งแอป** เพื่อใช้แบบ PWA
4. iPhone/iPad ใช้ Safari → Share → **Add to Home Screen**

Web Client ID ไม่ใช่ Client Secret แต่ควรใช้เฉพาะ ID ของโปรเจกต์ที่ตั้ง Authorized JavaScript origins ตรงกับ URL นี้ ค่าที่กรอกจากหน้าแอปเก็บใน browser profile ปัจจุบัน

## ติดตั้ง Android

1. ดาวน์โหลด `phakphum-calendar-android-apk`
2. แตกไฟล์และตรวจ SHA-256 ของ `app-release.apk`
3. ส่ง APK ไปยังโทรศัพท์แล้วเปิดไฟล์
4. Android อาจขออนุญาต **Install unknown apps** สำหรับแอปที่ใช้เปิด APK ให้อนุญาตเฉพาะแหล่งที่เชื่อถือได้
5. ติดตั้งแล้วเปิด **Shift Tools**

ข้อจำกัด: workflow ปัจจุบัน build แบบ release แต่ลงนามด้วย debug key ของโปรเจกต์ จึงเหมาะสำหรับทดสอบ ไม่ใช่ไฟล์สำหรับเผยแพร่ Play Store การใช้งานจริงควรตั้ง release keystore และเก็บรหัสผ่านใน GitHub Secrets

## ติดตั้ง iOS / iPadOS

artifact `phakphum-calendar-ios-unsigned-ipa` เป็น IPA ที่ยังไม่ลงลายเซ็น จึงติดตั้งบน iPhone/iPad ปกติโดยตรงไม่ได้

1. ดาวน์โหลดและตรวจ SHA-256 ของ `phakphum-calendar-unsigned.ipa`
2. ใช้ macOS/Xcode เปิดโปรเจกต์ `ios/Runner.xcworkspace`
3. เลือก Apple Developer Team และ bundle identifier ที่บัญชีมีสิทธิ์ใช้
4. ตั้ง iOS OAuth Client ID และ Reversed Client ID ให้ตรงกับ bundle ID
5. สร้าง signed archive จาก Xcode แล้วติดตั้งผ่านวิธีแจกจ่ายของ Apple ที่ทีมเลือก

หากต้องการเพียงตรวจโครงสร้าง build ใช้ unsigned IPA ได้ แต่การติดตั้งจริงต้องมี Apple certificate และ provisioning profile

## ติดตั้ง Windows

1. ดาวน์โหลด `phakphum-calendar-windows`
2. แตก artifact แล้วตรวจ `phakphum-calendar-windows.zip`
3. แตก `phakphum-calendar-windows.zip` อีกครั้ง โดยเก็บ `.exe`, `.dll` และโฟลเดอร์ `data` ไว้ด้วยกัน
4. เปิด `phakphum_calendar.exe`

ไฟล์ยังไม่ได้เซ็น Authenticode จึงอาจมีคำเตือน Windows SmartScreen ให้ตรวจ source, workflow run และ SHA-256 ก่อนใช้งาน Google Sign-In native ยังไม่รองรับบน Windows ในเวอร์ชันนี้ ให้กด **Google Login ใช้ผ่าน Web** เพื่อเปิดเว็บแอป

## ติดตั้ง macOS

1. ดาวน์โหลด `phakphum-calendar-macos`
2. ตรวจ SHA-256 แล้วแตก `phakphum-calendar-macos.zip`
3. ย้าย `phakphum_calendar.app` ไปที่ `/Applications`
4. เปิดแอปและอนุญาตสิทธิ์ตามนโยบายของเครื่อง

artifact ยังไม่ได้ notarize/sign สำหรับการแจกจ่ายสาธารณะ macOS อาจป้องกันการเปิด ผู้เผยแพร่ควรลงลายเซ็นด้วย Developer ID และ notarize ก่อนแจกจ่ายให้ผู้ใช้ทั่วไป

## ติดตั้ง Linux

ตัวอย่างสำหรับ Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y libgtk-3-0 libstdc++6
tar -xzf phakphum-calendar-linux.tar.gz
cd bundle
./phakphum_calendar
```

ต้องเก็บ executable, `data` และ `lib` ไว้ในโครงสร้างเดิม ไอคอนแอปอยู่ใน `bundle/data/app_icon.png` Google Sign-In native ยังไม่รองรับบน Linux ในเวอร์ชันนี้ ให้ใช้ Web สำหรับงาน Google

## ตั้งค่า Google Cloud

อ่านภาพรวม OAuth 2.0 ได้จาก [Google Identity OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)

1. สร้างหรือเลือก Google Cloud project
2. เปิด API ต่อไปนี้:
   - Google Sheets API
   - Google Calendar API
   - Google Drive API
3. ตั้ง OAuth consent screen/Google Auth Platform:
   - ใส่ชื่อแอป อีเมลสนับสนุน และอีเมลติดต่อ
   - เลือก Audience ให้ตรงกับการใช้งาน Internal หรือ External
   - ถ้ายังอยู่โหมด Testing ให้เพิ่มทุกบัญชีที่ต้องใช้ใน Test users
   - เพิ่ม scopes ที่แอปใช้และเผยแพร่ consent screen เมื่อพร้อม
4. สร้าง OAuth Client ตามระบบ:
   - Web: เพิ่ม Authorized JavaScript origins เช่น `http://localhost:8080` และ `https://phakphoum38-stack.github.io`
   - Android: package `com.phakphoum.phakphum_calendar` พร้อม SHA-1/SHA-256 ของ signing key
   - iOS: สร้าง Client ชนิด **iOS** ด้วย bundle ID `com.phakphoum.phakphumCalendar`; ห้ามใช้ Web Client ID แทน `GIDClientID`
   - macOS: bundle ID `com.phakphoum.phakphumCalendar` และ URL scheme จาก Reversed Client ID
5. ห้าม commit Client Secret, access token, refresh token, service-account key หรือไฟล์ข้อมูลบัญชีลง repository

Scopes ที่แอปขอ:

- `spreadsheets.readonly` และ `calendar.events.readonly` — อ่านตารางและตรวจรายการซ้ำ
- `drive.metadata.readonly` — ตรวจว่าไฟล์ชีตหลักเป็นของบัญชีที่ล็อกอิน โดยไม่อ่านหรือแก้เนื้อหาไฟล์ผ่าน Drive
- `calendar.events` — สร้างกิจกรรมหลังผู้ใช้ยืนยัน
- `drive` — ค้นหา/สร้างสำเนาต้นฉบับเมื่อเปิดฟังก์ชันเก็บสำเนา
- `spreadsheets` — สร้างสำเนาแท็บเดือนล่วงหน้าเมื่อผู้ใช้กดสั่ง

สิทธิ์ `drive` และ `spreadsheets` มีขอบเขตกว้างและอาจทำให้แอป production ต้องผ่าน OAuth verification ของ Google

## GitHub Secrets สำหรับ OAuth

ตั้งค่าที่ **Repository → Settings → Secrets and variables → Actions**:

- `GOOGLE_WEB_CLIENT_ID`
- `GOOGLE_SERVER_CLIENT_ID` — ไม่บังคับ หากไม่ตั้ง iOS workflow จะใช้ `GOOGLE_WEB_CLIENT_ID`
- `GOOGLE_IOS_CLIENT_ID` — บังคับสำหรับ iOS และต้องสร้างเป็นชนิด **iOS**
- `GOOGLE_REVERSED_CLIENT_ID` — ไม่บังคับ เพราะ workflow คำนวณจาก iOS Client ID ได้
- `GOOGLE_MACOS_CLIENT_ID`
- `GOOGLE_MACOS_REVERSED_CLIENT_ID`

workflow จะนำค่าไปใส่เฉพาะตอน build ไม่มีไฟล์บัญชี ลิงก์ชีต หรือผลลัพธ์เวรถูกอัปโหลดเป็น artifact

สำหรับ iOS ค่าใน IPA ที่ build แล้วต้องเป็นดังนี้:

- `GIDClientID` = iOS OAuth Client ID
- `GIDServerClientID` = Web OAuth Client ID
- `CFBundleURLSchemes` = `REVERSED_CLIENT_ID` ของ iOS Client

ไฟล์ `ios/Runner/Info.plist` ใน repository ใช้ placeholder เพื่อไม่ฝังค่า OAuth
ของบัญชีลง source ส่วน GitHub Actions จะแทนค่าเหล่านี้จาก Secrets ก่อน build
และตรวจซ้ำใน `Runner.app/Info.plist` ก่อนสร้าง IPA

## Build จากซอร์ส

ติดตั้ง Flutter ตาม [Install Flutter](https://docs.flutter.dev/get-started/install) และ toolchain ของระบบ จากนั้นรันขั้นตอนร่วม:

```powershell
git clone https://github.com/phakphoum38-stack/phakphum-calendar.git
cd phakphum-calendar
flutter doctor -v
flutter pub get
flutter analyze
flutter test
```

### Web

```powershell
flutter run -d chrome --web-port=8080 `
  --dart-define=GOOGLE_WEB_CLIENT_ID="YOUR_WEB_CLIENT_ID" `
  --dart-define=GOOGLE_SERVER_CLIENT_ID="YOUR_WEB_CLIENT_ID"

flutter build web --release `
  --dart-define=GOOGLE_WEB_CLIENT_ID="YOUR_WEB_CLIENT_ID" `
  --dart-define=GOOGLE_SERVER_CLIENT_ID="YOUR_WEB_CLIENT_ID"
```

### Android

ต้องมี Android SDK และ JDK 17:

```powershell
flutter devices
flutter run -d DEVICE_ID `
  --dart-define=GOOGLE_SERVER_CLIENT_ID="YOUR_WEB_CLIENT_ID"
flutter build apk --release `
  --dart-define=GOOGLE_SERVER_CLIENT_ID="YOUR_WEB_CLIENT_ID"
```

ดู SHA ของ signing key:

```powershell
cd android
.\gradlew signingReport
```

### iOS

ต้องใช้ macOS, Xcode และ Apple toolchain:

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..

flutter run -d DEVICE_ID \
  --dart-define=GOOGLE_IOS_CLIENT_ID="YOUR_IOS_CLIENT_ID" \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="YOUR_WEB_CLIENT_ID"

flutter build ios --release --no-codesign \
  --dart-define=GOOGLE_IOS_CLIENT_ID="YOUR_IOS_CLIENT_ID" \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="YOUR_WEB_CLIENT_ID"
```

### Windows

ต้องมี Visual Studio พร้อม workload **Desktop development with C++**:

```powershell
flutter config --enable-windows-desktop
flutter run -d windows
flutter build windows --release
```

### macOS

```bash
flutter config --enable-macos-desktop
flutter run -d macos \
  --dart-define=GOOGLE_MACOS_CLIENT_ID="YOUR_MACOS_CLIENT_ID" \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="YOUR_WEB_CLIENT_ID"
flutter build macos --release \
  --dart-define=GOOGLE_MACOS_CLIENT_ID="YOUR_MACOS_CLIENT_ID" \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="YOUR_WEB_CLIENT_ID"
```

### Linux

ตัวอย่าง dependency สำหรับ Ubuntu/Debian ใช้ชุดเดียวกับ CI:

```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev
flutter config --enable-linux-desktop
flutter run -d linux
flutter build linux --release
```

### สร้างไอคอนใหม่

ไฟล์ต้นฉบับอยู่ที่ `assets/app_icon_master.png`:

```powershell
flutter pub get
dart run flutter_launcher_icons
```

คำสั่งนี้สร้างไอคอน Android, iOS, Web, Windows และ macOS ส่วน Linux จะนำไฟล์ต้นฉบับไปไว้ใน bundle ผ่าน CMake

## Workflows

- `Auto Detect CI` — capability detection และ Dart/Flutter quality checks เฉพาะที่จำเป็น
- `Build Windows` — Windows x64 ZIP พร้อม SHA-256
- `Build and Deploy Web` — Web artifact และ GitHub Pages
- `Final Gate` — ตรวจหลักฐานของ Auto Detect CI, Windows และ Web สำหรับ commit เดียวกัน
- `Repair Google Sheets picker` — workflow แก้ไขเฉพาะกิจสำหรับฟิกซ์ที่เกี่ยวข้อง

ทุก workflow รองรับ **Run workflow** และจะทำงานอัตโนมัติเมื่อไฟล์ที่เกี่ยวข้องถูก push เข้า `main`

## ข้อมูลที่เก็บและขอบเขตความปลอดภัย

- ช่องชีต ชื่อ เดือน และปีเริ่มต้นว่าง; ชื่อ/เดือน/ปีที่เลือกใช้เฉพาะรอบใช้งานและไม่ถูกฝังใน build
- URL ชีตที่ตรวจแล้ว, ค่า OAuth ที่กรอกจาก UI, แถบเครื่องมือ, บันทึก และ audit log เก็บใน local storage ของอุปกรณ์/เบราว์เซอร์
- รายการชีตที่บันทึกแยกด้วย Google account ID แบบ opaque และต้องผ่าน `ownedByMe` ไม่บันทึกรหัสผ่านหรือ Google token เอง
- Audit log เก็บสูงสุด 200 รายการในเครื่อง
- เทมเพลตรายเดือน กลุ่มเวร รายชื่อ สถานะ จุดเวรที่ล็อก และบทบาท Admin
  เก็บใน local storage ของอุปกรณ์/เบราว์เซอร์
- ค่า Admin ใน local storage ไม่ใช่ server-enforced authorization และไม่ซิงก์
  ข้ามอุปกรณ์ ต้องใช้ backend identity store ก่อนใช้เป็นระบบสิทธิ์ production
- การลบรายการชีตในแท็บบันทึกไม่ลบไฟล์ Google Sheets
- แอปไม่เพิ่มผู้เข้าร่วม ไม่ส่งคำเชิญ และไม่สร้าง Google Meet
- repository และ build artifacts ต้องมีเฉพาะซอร์ส/ไฟล์แอป ห้ามรวมไฟล์ชีต ผลลัพธ์เวร อีเมล token หรือข้อมูลบัญชี

## Shift Tools production modules

This application now includes the Sprint 6 SCE architecture under `lib/features/` and `lib/core/`:

- Google Drive roster selection
- Google Sheets snapshot and normalization
- Hospital shift parser
- Relationship engine
- Calendar diff engine
- Simulation preview
- Reliable Calendar synchronization
- Durable history and resume
- Workflow dashboard
- `.ai/` project memory, prompts, and templates

The existing application shell remains the active entry point while the production modules are integrated incrementally through `AppController`.

## Version 3.0 SaaS Foundation

Version 3.0 adds multi-tenant isolation, public API contracts, idempotent writes, a plugin SDK foundation and platform administration metrics. See `VERSION_3_0_STATUS.md` and `docs/wiki/VERSION_3_ARCHITECTURE.md`.

## License

Copyright 2026 Phakphum

Licensed under the [Apache License, Version 2.0](LICENSE).
