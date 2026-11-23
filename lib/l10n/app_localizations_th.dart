// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'Shift Tools';

  @override
  String get appSubtitle => 'พื้นที่จัดการตารางเวร';

  @override
  String get switchLanguage => 'เปลี่ยนภาษา';

  @override
  String get home => 'หน้าแรก';

  @override
  String get preview => 'ตัวอย่าง';

  @override
  String get notifications => 'แจ้งเตือน';

  @override
  String get history => 'บันทึก';

  @override
  String get reports => 'รายงาน';

  @override
  String get settings => 'ตั้งค่า';

  @override
  String get tools => 'เครื่องมือ';

  @override
  String get dashboard => 'แดชบอร์ด';

  @override
  String get schedule => 'ตารางเวร';

  @override
  String get employees => 'บุคลากร';

  @override
  String get shiftExchange => 'แลกเวร';

  @override
  String get more => 'เพิ่มเติม';

  @override
  String get clear => 'ล้าง';

  @override
  String get all => 'ทั้งหมด';

  @override
  String get pending => 'รอดำเนินการ';

  @override
  String get approved => 'อนุมัติแล้ว';

  @override
  String get rejected => 'ปฏิเสธ';

  @override
  String get cancelled => 'ยกเลิก';

  @override
  String get employeeDirectoryDescription =>
      'บุคลากรที่อ้างอิงอยู่ในตารางเวรหลักปัจจุบัน';

  @override
  String get searchEmployees => 'ค้นหาจากชื่อ รหัส หรือตำแหน่ง';

  @override
  String get activeEmployeesOnly => 'เฉพาะบุคลากรที่ใช้งาน';

  @override
  String get noEmployeesMatch => 'ไม่พบบุคลากรที่ตรงกับตัวกรอง';

  @override
  String get noEmployeesInSchedule => 'ตารางเวรปัจจุบันยังไม่มีข้อมูลบุคลากร';

  @override
  String get shiftExchangeDescription => 'ตรวจคำขอแลกเวรและสถานะการอนุมัติ';

  @override
  String get noExchangeRequests => 'ยังไม่มีคำขอแลกเวร';

  @override
  String get exchangeApprovalBoundary =>
      'การสร้างและอนุมัติคำขอจะดำเนินการผ่าน workflow ที่มีการตรวจสิทธิ์';

  @override
  String get myNextShift => 'เวรถัดไปของฉัน';

  @override
  String get todaySummary => 'เวรวันนี้';

  @override
  String get tomorrowSummary => 'เวรพรุ่งนี้';

  @override
  String get monthlyAssignments => 'เวรเดือนนี้';

  @override
  String get calendarSyncStatus => 'สถานะปฏิทิน';

  @override
  String get conflictWarning => 'แจ้งเตือนความขัดแย้ง';

  @override
  String get assignmentCount => 'รายการเวร';

  @override
  String get noUpcomingShift => 'ไม่มีเวรถัดไป';

  @override
  String get noScheduleData => 'ไม่มีข้อมูลตารางเวร';

  @override
  String get connected => 'เชื่อมต่อแล้ว';

  @override
  String get notConnected => 'ยังไม่เชื่อมต่อ';

  @override
  String get neverSynced => 'ยังไม่เคยซิงก์';

  @override
  String get noPendingConflicts => 'ไม่มีความขัดแย้งค้าง';

  @override
  String get requiresReview => 'ต้องตรวจสอบ';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get close => 'ปิด';

  @override
  String get confirm => 'ยืนยัน';

  @override
  String get save => 'บันทึก';

  @override
  String get delete => 'ลบ';

  @override
  String get next => 'ถัดไป';

  @override
  String get reset => 'รีเซ็ต';

  @override
  String get retry => 'ลองอีกครั้ง';

  @override
  String get errors => 'ข้อผิดพลาด';

  @override
  String get warnings => 'คำเตือน';

  @override
  String get rules => 'กฎ';

  @override
  String get validationTitle => 'ผลการตรวจสอบกฎ';

  @override
  String get importExcel => 'นำเข้า Excel';

  @override
  String get importSchedule => 'นำเข้าตารางเวร';

  @override
  String get importDescription =>
      'เลือกไฟล์ .xlsx หรือ Google Sheets เพื่อตรวจสอบก่อนเลือกเวิร์กชีต';

  @override
  String get selectExcelFile => 'เลือกไฟล์ Excel';

  @override
  String get loadGoogleSheets => 'โหลด Google Sheets';

  @override
  String get googleSheetsInputLabel => 'URL หรือรหัสสเปรดชีต Google Sheets';

  @override
  String get chooseFromGoogleDrive => 'เลือกจาก Google Drive';

  @override
  String get chooseGoogleSheet => 'เลือก Google Sheet';

  @override
  String get ownedGoogleSheetsOnly =>
      'แสดงเฉพาะสเปรดชีตที่บัญชี Google ซึ่งล็อกอินอยู่เป็นเจ้าของ';

  @override
  String get noOwnedGoogleSheets =>
      'ไม่พบ Google Sheets ที่บัญชีนี้เป็นเจ้าของ';

  @override
  String get columnMapping => 'จับคู่คอลัมน์';

  @override
  String get mapExcelColumns => 'จับคู่คอลัมน์ Excel';

  @override
  String get requiredMappingHelp => 'ต้องจับคู่ฟิลด์ที่จำเป็นก่อนดำเนินการต่อ';

  @override
  String get editColumnMapping => 'แก้ไขการจับคู่คอลัมน์';

  @override
  String get nextColumnMapping => 'ถัดไป: จับคู่คอลัมน์';

  @override
  String get importSummary => 'สรุปการนำเข้า';

  @override
  String get importCompleted => 'นำเข้าเสร็จแล้ว';

  @override
  String importCreatedRecords(int recordCount, int rowCount) {
    return 'สร้างรายการเวร $recordCount รายการ จากข้อมูล $rowCount แถว';
  }

  @override
  String scheduleSaveFailed(String message) {
    return 'ไม่สามารถบันทึกตารางเวรได้: $message';
  }

  @override
  String get viewMonthCalendar => 'ดูปฏิทินรายเดือน';

  @override
  String get issues => 'รายการที่ต้องตรวจสอบ';

  @override
  String get monthCalendar => 'ปฏิทินรายเดือน';

  @override
  String get monthlySchedule => 'ตารางเวรรายเดือน';

  @override
  String get noShiftsThisMonth => 'ไม่มีเวรในเดือนนี้';

  @override
  String get noMatchingAssignments => 'ไม่มีรายการที่ตรงกับตัวกรองที่ใช้งาน';

  @override
  String get previousMonth => 'เดือนก่อนหน้า';

  @override
  String get nextMonth => 'เดือนถัดไป';

  @override
  String get reportEmptySchedule =>
      'ไม่มีข้อมูลตารางเวร สามารถสร้างรายงานเปล่าได้';

  @override
  String get reportPreviewPrompt => 'เลือกตัวกรองแล้วกด “สร้างตัวอย่าง”';

  @override
  String get month => 'เดือน';

  @override
  String get department => 'แผนก';

  @override
  String get allDepartments => 'ทุกแผนก';

  @override
  String get generatePreview => 'สร้างตัวอย่าง';

  @override
  String get print => 'พิมพ์';

  @override
  String get saveSharePdf => 'บันทึก / แชร์ PDF';

  @override
  String get reportDefaultTitle => 'รายงานตารางเวรประจำเดือน';

  @override
  String get reportGeneratedAt => 'จัดทำเมื่อ';

  @override
  String get reportEmployee => 'พนักงาน';

  @override
  String get reportPosition => 'ตำแหน่ง';

  @override
  String get reportNoData => 'ไม่มีข้อมูลตารางเวรในเดือนที่เลือก';

  @override
  String get reportSummary => 'สรุป';

  @override
  String get reportLegend => 'คำอธิบายเวร';

  @override
  String get reportNotes => 'หมายเหตุ';

  @override
  String get reportEmployeeCount => 'จำนวนพนักงาน';

  @override
  String get reportAssignmentCount => 'จำนวนเวร';

  @override
  String get reportPreparedBy => 'ผู้จัดทำ';

  @override
  String get reportCheckedBy => 'ผู้ตรวจสอบ';

  @override
  String get reportApprovedBy => 'ผู้อนุมัติ';

  @override
  String get reportDate => 'วันที่';

  @override
  String get weekdayMondayShort => 'จ.';

  @override
  String get weekdayTuesdayShort => 'อ.';

  @override
  String get weekdayWednesdayShort => 'พ.';

  @override
  String get weekdayThursdayShort => 'พฤ.';

  @override
  String get weekdayFridayShort => 'ศ.';

  @override
  String get weekdaySaturdayShort => 'ส.';

  @override
  String get weekdaySundayShort => 'อา.';

  @override
  String get googleAccessTitle => 'อนุญาตการเข้าถึง Google';

  @override
  String get googleAccessLater => 'ไว้ภายหลัง';

  @override
  String get googleAccessAllow => 'อนุญาตการเข้าถึง';

  @override
  String get googleSyncConfirmTitle => 'ยืนยันการเปลี่ยนแปลงปฏิทิน';

  @override
  String get googleSyncConfirm => 'ยืนยันและทำต่อ';

  @override
  String get googleSyncNoWriteBeforeConfirm =>
      'จะไม่มีการเขียนข้อมูลลง Google Calendar ก่อนยืนยัน';

  @override
  String get unexpectedError => 'เกิดข้อผิดพลาด โปรดลองอีกครั้ง';

  @override
  String get edit => 'แก้ไข';

  @override
  String get deactivate => 'ปิดใช้งาน';

  @override
  String get requiredField => 'จำเป็นต้องกรอกข้อมูลนี้';

  @override
  String get invalidNumber => 'กรุณากรอกตัวเลขตั้งแต่ศูนย์ขึ้นไป';

  @override
  String get addEmployee => 'เพิ่มบุคลากร';

  @override
  String get editEmployee => 'แก้ไขบุคลากร';

  @override
  String get deactivateEmployee => 'ปิดใช้งานบุคลากร';

  @override
  String deactivateEmployeeConfirmation(String name) {
    return 'ปิดใช้งาน $name ใช่หรือไม่ รายการเวรเดิมจะยังคงอยู่';
  }

  @override
  String get employeeCode => 'รหัสพนักงาน';

  @override
  String get firstName => 'ชื่อ';

  @override
  String get lastName => 'นามสกุล';

  @override
  String get nickname => 'ชื่อเล่น';

  @override
  String get position => 'ตำแหน่ง';

  @override
  String get departmentCode => 'รหัสหน่วยงาน';

  @override
  String get departmentName => 'ชื่อหน่วยงาน';

  @override
  String get shiftTemplates => 'แม่แบบเวร';

  @override
  String get shiftTemplatesDescription =>
      'กำหนดรหัส เวลา สี และอัตราของเวรที่นำกลับมาใช้ได้';

  @override
  String get addShiftTemplate => 'เพิ่มแม่แบบเวร';

  @override
  String get editShiftTemplate => 'แก้ไขแม่แบบเวร';

  @override
  String get shiftCode => 'รหัสเวร';

  @override
  String get shiftName => 'ชื่อเวร';

  @override
  String get shortName => 'ชื่อย่อ';

  @override
  String get startTime => 'เวลาเริ่ม';

  @override
  String get endTime => 'เวลาสิ้นสุด';

  @override
  String get workingHours => 'ชั่วโมงทำงาน';

  @override
  String get shiftRate => 'อัตราเงินเวร';

  @override
  String get overnight => 'ข้ามวัน';

  @override
  String get manualRosterEditor => 'จัดตารางเวรด้วยตนเอง';

  @override
  String get addAssignment => 'เพิ่มผู้ปฏิบัติงาน';

  @override
  String get selectDayToEdit => 'เลือกวันที่เพื่อแก้ไขรายการเวร';

  @override
  String get rosterCatalogRequired =>
      'เพิ่มบุคลากรและแม่แบบเวรก่อนสร้างรายการเวร';

  @override
  String get previewChanges => 'ตรวจสอบการเปลี่ยนแปลง';

  @override
  String get deleteAssignment => 'ลบรายการเวร';

  @override
  String deleteAssignmentConfirmation(String employee, String shift) {
    return 'ลบ $employee ออกจากเวร $shift ใช่หรือไม่';
  }

  @override
  String get scheduleSaved => 'บันทึกตารางเวรแล้ว';

  @override
  String get location => 'สถานที่';

  @override
  String get notes => 'หมายเหตุ';

  @override
  String workflowAddedCount(int count) => 'เพิ่ม $count';

  @override
  String workflowUpdatedCount(int count) => 'แก้ไข $count';

  @override
  String workflowDeletedCount(int count) => 'ลบ $count';

  @override
  String workflowUnchangedCount(int count) => 'ไม่เปลี่ยน $count';

  @override
  String workflowWarningCount(int count) => 'เตือน $count';

  @override
  String workflowBlockedCount(int count) => 'บล็อก $count';

    @override
    String get workflowScheduleFailedValidation =>
      'ตารางเวรไม่ผ่านการตรวจสอบ จึงยังไม่สามารถซิงก์ได้';

    @override
    String get workflowReadyToConfirm => 'พร้อมยืนยันการซิงก์';

    @override
    String get workflowWarningsBeforeConfirm =>
      'พบคำเตือน กรุณาตรวจสอบก่อนยืนยันการซิงก์';

    @override
    String get workflowCalendarCheckFailed => 'ตรวจสอบ Google Calendar ไม่สำเร็จ';

    @override
    String get workflowNoValidatedPlan =>
      'ยังไม่มีแผนที่ผ่านการตรวจสอบสำหรับซิงก์';

    @override
    String get workflowNoValidationResult =>
      'ยังไม่มีผลการตรวจสอบสำหรับซิงก์';

    @override
    String get workflowItemsStillBlocked =>
      'ยังมีรายการที่ถูกบล็อก กรุณาตรวจสอบก่อนซิงก์';

    @override
    String get workflowSyncPartialSuccess =>
      'ซิงก์สำเร็จบางส่วน กรุณาตรวจสอบประวัติ';

    @override
    String get workflowSyncSuccessful => 'ซิงก์ Google Calendar สำเร็จ';

    @override
    String get workflowSyncFailed =>
      'ซิงก์ไม่สำเร็จ กรุณาตรวจสอบอินเทอร์เน็ตและสิทธิ์ Google';

  @override
  String get startupTimeout =>
      'เริ่มต้นระบบช้าเกินไป กรุณาตรวจการตั้งค่า Google OAuth หรือรีโหลดหน้าเว็บ';

  @override
  String startupFailed(String error) => 'เริ่มต้นระบบไม่สำเร็จ: $error';
}
