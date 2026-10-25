# Shift Tools — Phakphum Calendar

แอป Flutter สำหรับนำเข้าตารางเวรจาก Google Sheets หรือไฟล์ในเครื่อง ตรวจสอบและแก้ไขข้อมูลก่อนบันทึก แล้วเลือกซิงก์รายการที่ยืนยันแล้วไปยัง Google Calendar

> **Repository หลัก:** [phakphum12345/phakphum-calendar](https://github.com/phakphum12345/phakphum-calendar)  
> **Web app:** [เปิด Phakphum Calendar](https://phakphum12345.github.io/phakphum-calendar/)  
> **ภาษา:** ไทย / English

## สารบัญ

- [เริ่มใช้งานอย่างรวดเร็ว](#เริ่มใช้งานอย่างรวดเร็ว)
- [ติดตั้งสำหรับผู้ใช้งานทั่วไป](#ติดตั้งสำหรับผู้ใช้งานทั่วไป)
- [ติดตั้งจากซอร์สโค้ดสำหรับนักพัฒนา](#ติดตั้งจากซอร์สโค้ดสำหรับนักพัฒนา)
- [วิธีใช้งานแอป](#วิธีใช้งานแอป)
- [นำเข้าตารางเวร](#นำเข้าตารางเวร)
- [ตั้งค่าแม่แบบเวร](#ตั้งค่าแม่แบบเวร)
- [เชื่อมต่อ Google](#เชื่อมต่อ-google)
- [แพลตฟอร์มที่รองรับ](#แพลตฟอร์มที่รองรับ)
- [แก้ปัญหาเบื้องต้น](#แก้ปัญหาเบื้องต้น)
- [เอกสารเพิ่มเติม](#เอกสารเพิ่มเติม)

## เริ่มใช้งานอย่างรวดเร็ว

หากต้องการใช้งานโดยไม่ติดตั้งเครื่องมือพัฒนา:

1. เปิด [Phakphum Calendar Web](https://phakphum12345.github.io/phakphum-calendar/)
2. เลือกเวอร์ชัน **บุคคลทั่วไป** หรือ **องค์กร** ตามลักษณะงาน
3. หากต้องใช้ Google Sheets หรือ Google Calendar ให้เข้าสู่ระบบ Google และอนุญาตสิทธิ์ที่แอปแสดง
4. นำเข้าตารางเวร ตรวจสอบผลลัพธ์ แล้วบันทึกหรือซิงก์เฉพาะรายการที่ตรวจแล้ว

หากหน้าเว็บเปิดไม่ได้ ให้ตรวจสถานะล่าสุดที่ [GitHub Actions](https://github.com/phakphum12345/phakphum-calendar/actions) และลองเปิดใหม่หลัง workflow deploy สำเร็จ

## ติดตั้งสำหรับผู้ใช้งานทั่วไป

### Windows

1. เปิดหน้า [GitHub Actions](https://github.com/phakphum12345/phakphum-calendar/actions)
2. เลือก workflow **Build Windows** ที่สำเร็จล่าสุดจาก branch `main`
3. เปิดรายการ workflow run แล้วเลื่อนลงไปที่ **Artifacts**
4. ดาวน์โหลด artifact ของ Windows และแตกไฟล์ ZIP
5. เก็บ executable พร้อมโฟลเดอร์ประกอบ เช่น `data` และ `lib` ไว้ในตำแหน่งเดิม แล้วเปิดไฟล์แอป

หากไม่พบ artifact ให้ตรวจว่า workflow run สำเร็จและยังไม่หมดอายุ หากต้องใช้ Google Sign-In แต่เวอร์ชัน Windows ที่ดาวน์โหลดยังไม่รองรับ native OAuth ให้ใช้ Web app แทน

### Android

1. เปิด [GitHub Actions](https://github.com/phakphum12345/phakphum-calendar/actions)
2. เปิด workflow run ที่สำเร็จล่าสุด แล้วดาวน์โหลด artifact `phakphum-calendar-android-apk` หากมี
3. แตกไฟล์และติดตั้ง APK ที่ได้จากแหล่งที่เชื่อถือได้เท่านั้น
4. Android อาจขออนุญาตติดตั้งจากแหล่งภายนอก ให้ตรวจสอบแหล่งไฟล์ก่อนอนุญาต

### iPhone / iPad (iOS)

iOS artifact ที่สร้างจาก CI อาจเป็น **unsigned IPA** ซึ่งยังติดตั้งตรงบนอุปกรณ์ทั่วไปไม่ได้ ต้องมีการลงนามและ provisioning profile ที่ถูกต้องด้วย Apple Developer tooling ก่อนติดตั้ง อย่าถือว่าไฟล์ unsigned IPA พร้อมใช้งานทันที

### macOS และ Linux

ดาวน์โหลด artifact ของแพลตฟอร์มที่ตรงกับ workflow run ที่สำเร็จ แล้วทำตามไฟล์ README หรือคำแนะนำที่แนบมากับ artifact หากแพ็กเกจไม่มีลายเซ็นหรือ notarization ให้ตรวจแหล่งที่มาและนโยบายความปลอดภัยของระบบก่อนเปิดใช้งาน

> ชื่อและอายุของ artifact ขึ้นกับผลการ build ล่าสุด ไม่ควรดาวน์โหลดจาก run ที่ล้มเหลวหรือจาก branch ที่ไม่รู้จัก

## ติดตั้งจากซอร์สโค้ดสำหรับนักพัฒนา

### สิ่งที่ต้องมี

- Git
- Flutter SDK และ Dart SDK ตามข้อกำหนดใน `pubspec.yaml`
- Android Studio / Android SDK สำหรับ Android
- Visual Studio พร้อม workload **Desktop development with C++** สำหรับ Windows desktop
- macOS และ Xcode สำหรับ build iOS/macOS
- toolchain ของ Linux เช่น Clang, CMake, Ninja และ GTK development libraries สำหรับ Linux desktop

ตรวจสอบเครื่องมือก่อนเริ่ม:

```bash
flutter doctor -v
git --version
```

### ดาวน์โหลดและตรวจสอบโปรเจกต์

```bash
git clone https://github.com/phakphum12345/phakphum-calendar.git
cd phakphum-calendar
flutter pub get
flutter analyze
flutter test
```

หากต้องการเปิดแอปบนเครื่องที่รองรับ:

```bash
# Web
flutter run -d chrome --web-port=8080

# Windows (เปิด Windows desktop support ใน Flutter ก่อน หากจำเป็น)
flutter config --enable-windows-desktop
flutter run -d windows

# Android: ตรวจ device ID ด้วย flutter devices ก่อน
flutter devices
flutter run -d DEVICE_ID
```

Build release:

```bash
# Web
flutter build web --release

# Android APK
flutter build apk --release

# Windows
flutter build windows --release
```

สำหรับ iOS/macOS ต้อง build บน macOS พร้อม Xcode และ signing configuration ที่ถูกต้อง ส่วน Google Sign-In ต้องตั้งค่า OAuth ให้ตรงกับแพลตฟอร์มก่อนใช้งานฟังก์ชัน Google

### ตั้งค่า OAuth สำหรับ Web

1. เปิด Google Cloud project ที่คุณควบคุม และตั้งค่า OAuth consent screen
2. เปิด Google APIs ที่แอปต้องใช้ตาม [คู่มือตั้งค่า Google](docs/GOOGLE_SETUP.md)
3. สร้าง OAuth Client ชนิด **Web application**
4. เพิ่ม Authorized JavaScript origin สำหรับ local development เช่น `http://localhost:8080` และสำหรับ production คือ `https://phakphum12345.github.io`
5. กำหนด Client ID ผ่าน build-time Dart defines หรือตาม workflow configuration ของ repository

ตัวอย่างสำหรับ local web:

```bash
flutter run -d chrome --web-port=8080 \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_SERVER_CLIENT_ID
```

ใช้ Client ID ที่ลงท้ายด้วย `.apps.googleusercontent.com` ไม่ใช่ URL หรือ Client Secret ห้ามใส่ OAuth client secret, access token, refresh token หรือ private key ลงในซอร์สโค้ดหรือ commit เข้า Git

## วิธีใช้งานแอป

### 1. เลือกเวอร์ชันการใช้งาน

เมื่อเปิดครั้งแรก เลือกเวอร์ชันที่ตรงกับงาน:

- **บุคคลทั่วไป** — สำหรับจัดการตารางเวรส่วนตัว ตรวจปฏิทิน และรายงาน
- **องค์กร** — เพิ่มเครื่องมือสำหรับรายชื่อบุคลากร การแลกเวร บทบาท และ Admin Console

สามารถเปลี่ยนเวอร์ชันภายหลังได้จาก **ตั้งค่า → เวอร์ชันการใช้งาน** ตามเมนูที่แอปแสดง

### 2. ตั้งค่าแม่แบบเวร

1. เปิด **ตั้งค่า → แม่แบบเวร**
2. ระบุสถานที่หรือหน่วยงาน เพื่อแยกกฎของแต่ละพื้นที่ทำงาน
3. กำหนดรหัสเวรสั้น ๆ ชื่อเวร เวลาเริ่ม–สิ้นสุด สี ชั่วโมงทำงาน และอัตราเงินเวรตามที่ต้องการ
4. บันทึกแม่แบบ และตรวจสอบว่าเวลาและสถานที่ถูกต้องก่อนนำไปใช้

มีรหัสเริ่มต้นภาษาไทย ได้แก่ **ช** (เช้า), **ก** (กลางวัน), **บ** (บ่าย) และ **ด** (ดึก) ผู้ใช้สามารถปรับชื่อและรหัสให้ตรงกับระบบของสถานที่ทำงานได้ รหัสซ้ำกันได้เมื่ออยู่คนละสถานที่ แต่ไม่ควรซ้ำภายในสถานที่เดียวกัน

### 3. นำเข้าตารางเวรจาก Excel/CSV/TSV/TXT

1. เปิดหน้า **นำเข้า Excel** หรือเมนูนำเข้าที่แอปแสดง
2. เลือกไฟล์จากอุปกรณ์ หรือเลือก worksheet ที่ต้องการ
3. แอปจะพยายามตรวจจับคอลัมน์ภาษาไทยและภาษาอังกฤษ และสร้างผลนำเข้าแบบร่างให้อัตโนมัติ
4. ตรวจสอบการจับคู่คอลัมน์ เช่น วันที่ เวร ผู้ปฏิบัติงาน แผนก สถานที่ และหมายเหตุ หากตรวจจับผิดให้แก้ mapping ด้วยตนเอง
5. อ่านจำนวนรายการที่นำเข้าได้ รายการที่ข้าม ข้อผิดพลาด และคำเตือน
6. ตรวจหน้า Preview / สรุปให้ครบ แล้วกด **ยืนยันและบันทึกตารางเวร** เพื่อบันทึกข้อมูลจริง

**สำคัญ:** การวิเคราะห์อัตโนมัติเป็นเพียงร่างสำหรับตรวจสอบ ไม่ควรข้าม Preview และการยืนยันก่อนบันทึก

### 4. นำเข้าจาก Google Sheets

1. กด **เข้าสู่ระบบด้วย Google** และเลือกบัญชีที่มีสิทธิ์เข้าถึงชีต
2. เลือก Google Sheets หรือวาง URL/Spreadsheet ID ตามช่องที่แอปมีให้
3. เลือก worksheet และเดือน/ปีที่ต้องการอ่าน
4. ตรวจชื่อผู้ปฏิบัติงานและข้อมูลเวรใน Preview
5. ยืนยันการนำเข้าเมื่อข้อมูลถูกต้อง

การอ่านข้อมูลไม่ควรแก้ไขชีตต้นฉบับ การเข้าถึงไฟล์ขึ้นกับบัญชี Google และสิทธิ์ที่ได้รับ

### 5. ตรวจตารางเวรและซิงก์ Google Calendar

1. เปิดมุมมองตารางเวรหรือปฏิทิน แล้วตรวจวัน เวลา สถานที่ และชื่อผู้ปฏิบัติงาน
2. ตรวจคำเตือนและรายการเวรที่ชนกับกิจกรรมเดิม
3. เปิด workflow ซิงก์ Google Calendar และตรวจรายการที่จะเพิ่มหรือเปลี่ยนแปลง
4. แก้ blocking errors และตรวจคำเตือนให้ครบ
5. ยืนยันการซิงก์เมื่อ Preview ถูกต้องเท่านั้น
6. หากมีข้อผิดพลาดบางส่วน ให้ตรวจประวัติและตัวเลือก Retry/Resume ก่อนเริ่มงานใหม่ เพื่อหลีกเลี่ยงรายการซ้ำ

การซิงก์ Calendar ต้องได้รับสิทธิ์ Google ที่เกี่ยวข้อง แอปควรขอสิทธิ์เมื่อจำเป็นและแสดงรายการให้ตรวจสอบก่อนเขียนข้อมูล

### 6. รายงานและเครื่องมือองค์กร

- **รายงาน:** เลือกเดือน/แผนก สร้าง Preview แล้วพิมพ์หรือบันทึก/แชร์ PDF หากเมนูนี้เปิดให้ใช้
- **บุคลากร:** จัดการรายชื่อและสถานะบุคลากรในรุ่นองค์กร
- **แลกเวร / Admin:** ใช้ตามบทบาทและตัวเลือกที่เปิดใช้งานในรุ่นปัจจุบัน

การตั้งค่าบางประเภทเก็บไว้ในอุปกรณ์หรือเบราว์เซอร์นั้น ๆ การกำหนด Admin ใน local storage ไม่ใช่การบังคับสิทธิ์ฝั่งเซิร์ฟเวอร์ และไม่ควรใช้แทนระบบ authorization ฝั่ง backend ใน production

## แพลตฟอร์มที่รองรับ

| แพลตฟอร์ม | สถานะและข้อควรทราบ |
| --- | --- |
| Web | ใช้งานผ่าน GitHub Pages; Google Sign-In ต้องตั้ง Web OAuth |
| Android | มี workflow build APK; Google Sign-In ต้องตั้งค่า Android OAuth |
| iOS | workflow อาจสร้าง unsigned IPA; ต้อง signing/provisioning ก่อนติดตั้ง |
| Windows | มี workflow build desktop; ตรวจข้อจำกัด Google Sign-In native ในแพ็กเกจที่ใช้ |
| macOS | ต้องใช้ macOS/Xcode; Google OAuth และ signing อาจต้องตั้งค่าเพิ่ม |
| Linux | มี workflow build desktop; Google Sign-In native อาจมีข้อจำกัด ให้ใช้ Web หากจำเป็น |

## แก้ปัญหาเบื้องต้น

- **Google Login เปิดแล้วปิดทันที / origin mismatch:** ตรวจ OAuth Client ID, Authorized JavaScript origins, bundle/package ID และ OAuth client ที่ตรงกับแพลตฟอร์ม
- **ไม่พบ Google Sheets:** ตรวจว่าล็อกอินบัญชีถูกต้องและบัญชีนั้นมีสิทธิ์เข้าถึงไฟล์
- **จับคู่คอลัมน์ผิด:** เปิดแก้ Column Mapping และตรวจ Preview ก่อนยืนยัน
- **ข้อมูลหายหรือข้ามหลายแถว:** ดูจำนวน imported/skipped/errors/warnings ในหน้าสรุป และตรวจรูปแบบวันที่/ชื่อคอลัมน์
- **ซิงก์ Calendar ซ้ำหรือชนกิจกรรมเดิม:** หยุดก่อนยืนยัน ตรวจ Preview และประวัติการซิงก์
- **แอปไม่เปิดหรือ build ล้มเหลว:** รัน `flutter doctor -v`, `flutter pub get`, `flutter analyze` และตรวจ log ของ workflow ที่ล้มเหลว

## ความปลอดภัยและความเป็นส่วนตัว

- ตรวจข้อมูลตารางเวรก่อนบันทึกหรือส่งไปยัง Google Calendar
- อย่า commit ตารางเวรจริง ชื่อพนักงาน ข้อมูลส่วนบุคคล token, secret หรือ key
- เก็บ OAuth credentials ใน configuration ที่เหมาะสม เช่น GitHub Actions Secrets สำหรับ workflow ที่จำเป็น
- ตรวจสิทธิ์ Google ที่แอปขอทุกครั้ง และอนุญาตเฉพาะสิทธิ์ที่ต้องใช้
- การตั้งค่าที่เก็บใน local storage ไม่ได้ซิงก์ข้ามอุปกรณ์โดยอัตโนมัติ

## เอกสารเพิ่มเติม

- [คู่มือติดตั้งและใช้งานฉบับสมบูรณ์](docs/INSTALLATION_AND_USER_GUIDE.md)
- [การตั้งค่า Google Cloud และ OAuth](docs/GOOGLE_SETUP.md)
- [การรองรับแพลตฟอร์ม](docs/PLATFORM_SUPPORT.md)
- [SCE 3.0 System Design](docs/SCE_3_0_SYSTEM_DESIGN.md)
- [SCE 3.0 Implementation Map](docs/SCE_3_0_IMPLEMENTATION_MAP.md)
- [Project Wiki](docs/wiki/README.md)
- [Laravel API](backend/README.md)
- [GitHub Actions](https://github.com/phakphum12345/phakphum-calendar/actions)

## License

Copyright 2026 Phakphum. Licensed under the [Apache License 2.0](LICENSE).
