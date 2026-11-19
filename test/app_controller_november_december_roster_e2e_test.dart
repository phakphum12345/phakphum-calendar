import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/controller/app_controller.dart';
import 'package:phakphum_calendar/core/di/app_dependencies.dart';
import 'package:phakphum_calendar/models/app_settings.dart';
import 'package:phakphum_calendar/models/roster_period.dart';
import 'package:phakphum_calendar/models/shift.dart';
import 'package:phakphum_calendar/services/local_roster_file_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'AppController keeps the full import and switches November/December filters',
    () async {
      final dependencies = AppDependencies.production();
      final controller = AppController.demo(
        auth: dependencies.googleAuthService,
        settingsService: dependencies.legacySettingsService,
        sheetsService: dependencies.legacySheetsService,
        parser: dependencies.shiftParser,
        alertService: dependencies.shiftAlertService,
        calendarService: dependencies.legacyCalendarService,
        archiveService: dependencies.driveArchiveService,
        ownershipService: dependencies.driveOwnershipService,
        localFileService: _FixtureLocalRosterSource(
          LocalRosterDocument(
            extension: 'xlsx',
            snapshots: [_novemberDecemberSnapshot()],
          ),
        ),
        scheduleRepository: dependencies.scheduleRepository,
        shiftTemplateRepository: dependencies.shiftTemplateRepository,
        legacyScheduleAdapter: dependencies.legacyScheduleAdapter,
        calendarWorkflowControllerFactory:
            dependencies.createAuthorizedCalendarWorkflowController,
      );
      addTearDown(controller.dispose);

      const november = RosterPeriod(year: 2026, month: 11);
      const december = RosterPeriod(year: 2026, month: 12);
      await controller.updateSettings(
        AppSettings.defaults().copyWith(
          targetName: 'นาย ทดสอบ',
          periods: const [november, december],
        ),
      );

      await controller.importLocalRosterFile();
      await controller.flushSchedulePersistence();

      expect(controller.loadedRosterShiftCount, 61);
      expect(controller.filteredRosterShiftCount, 61);
      expect(controller.monthlyRoster.assignments, hasLength(61));
      expect(controller.shifts, hasLength(61));
      expect(controller.syncRangeStart, DateTime(2026, 11, 1));
      expect(controller.syncRangeEnd, DateTime(2026, 12, 31));

      await controller.updateSettings(
        controller.settings.copyWith(periods: const [november]),
      );
      await controller.flushSchedulePersistence();

      expect(controller.loadedRosterShiftCount, 61);
      expect(controller.filteredRosterShiftCount, 30);
      expect(controller.monthlyRoster.assignments, hasLength(30));
      expect(controller.shifts, hasLength(30));
      expect(controller.shifts.first.start, DateTime(2026, 11, 1, 8));
      expect(controller.shifts.last.start, DateTime(2026, 11, 30, 8));
      expect(controller.syncRangeStart, DateTime(2026, 11, 1));
      expect(controller.syncRangeEnd, DateTime(2026, 11, 30));

      await controller.updateSettings(
        controller.settings.copyWith(periods: const [december]),
      );
      await controller.flushSchedulePersistence();

      expect(controller.loadedRosterShiftCount, 61);
      expect(controller.filteredRosterShiftCount, 31);
      expect(controller.monthlyRoster.assignments, hasLength(31));
      expect(controller.shifts, hasLength(31));
      expect(controller.shifts.first.start, DateTime(2026, 12, 1, 8));
      expect(controller.shifts.last.start, DateTime(2026, 12, 31, 8));
      expect(controller.syncRangeStart, DateTime(2026, 12, 1));
      expect(controller.syncRangeEnd, DateTime(2026, 12, 31));

      await controller.updateSettings(
        controller.settings.copyWith(periods: const [november, december]),
      );
      await controller.flushSchedulePersistence();

      expect(controller.loadedRosterShiftCount, 61);
      expect(controller.filteredRosterShiftCount, 61);
      expect(controller.monthlyRoster.assignments, hasLength(61));
      expect(controller.shifts, hasLength(61));
      expect(controller.shifts.first.start, DateTime(2026, 11, 1, 8));
      expect(controller.shifts.last.start, DateTime(2026, 12, 31, 8));
    },
  );
}

class _FixtureLocalRosterSource implements LocalRosterSource {
  const _FixtureLocalRosterSource(this.document);

  final LocalRosterDocument document;

  @override
  Future<LocalRosterDocument?> pickAndRead() async => document;
}

SheetSnapshot _novemberDecemberSnapshot() {
  const title = 'ตารางเวร พฤศจิกายน-ธันวาคม 2569';
  return SheetSnapshot(
    title: title,
    rows: [
      [
        'เวรหลัก 1 พฤศจิกายน 2569 - 15 พฤศจิกายน 2569',
      ],
      ['วันที่', ...List<int>.generate(15, (index) => index + 1)],
      ['ER', ...List<String>.filled(15, 'นาย ทดสอบ')],
      [],
      [
        'เวรเสริม 16 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569',
      ],
      ['วันที่', ...List<int>.generate(15, (index) => index + 16)],
      ['ER', ...List<String>.filled(15, 'นาย ทดสอบ')],
      [],
      [
        'เวรหลัก 1 ธันวาคม 2569 - 15 ธันวาคม 2569',
      ],
      ['วันที่', ...List<int>.generate(15, (index) => index + 1)],
      ['ER', ...List<String>.filled(15, 'นาย ทดสอบ')],
      [],
      [
        'เวรเสริม 16 ธันวาคม 2569 - 31 ธันวาคม 2569',
      ],
      ['วันที่', ...List<int>.generate(16, (index) => index + 16)],
      ['ER', ...List<String>.filled(16, 'นาย ทดสอบ')],
    ],
  );
}
