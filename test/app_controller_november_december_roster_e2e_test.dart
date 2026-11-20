import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/controller/app_controller.dart';
import 'package:phakphum_calendar/core/di/app_dependencies.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_repository.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_command.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/calendar_sync_gateway.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/failed_sync_operation.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/failed_sync_repository.dart';
import 'package:phakphum_calendar/features/calendar_engine/domain/managed_calendar_event.dart';
import 'package:phakphum_calendar/features/history/infrastructure/in_memory_sync_history_repository.dart';
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
      final dependencies = AppDependencies(
        syncHistoryRepository: InMemorySyncHistoryRepository(),
        failedSyncRepository: _MemoryFailedSyncRepository(),
        scheduleRepository: _MemoryScheduleRepository(),
      );
      final gateway = _MemoryCalendarSyncGateway();
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
        calendarWorkflowControllerFactory: () async =>
            dependencies.createShiftCalendarWorkflowController(gateway),
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

      expect(controller.pendingAlertCount, 0);
      await controller.prepareCalendarSync();
      await controller.syncCalendar(userConfirmed: true);
      expect(gateway.insertAttempts, 30);
      expect(
        gateway.events.where((event) => event.start.month == 11),
        hasLength(30),
      );
      expect(
        gateway.events.where((event) => event.start.month == 12),
        isEmpty,
      );

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

      expect(controller.pendingAlertCount, 0);
      await controller.prepareCalendarSync();
      await controller.syncCalendar(userConfirmed: true);
      expect(gateway.insertAttempts, 61);
      expect(
        gateway.events.where((event) => event.start.month == 11),
        hasLength(30),
      );
      expect(
        gateway.events.where((event) => event.start.month == 12),
        hasLength(31),
      );
      expect(gateway.events, hasLength(61));

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

      await controller.prepareCalendarSync();
      await controller.syncCalendar(userConfirmed: true);
      expect(gateway.insertAttempts, 61);
      expect(gateway.events, hasLength(61));
      expect(
        gateway.events.where((event) => event.start.month == 11),
        hasLength(30),
      );
      expect(
        gateway.events.where((event) => event.start.month == 12),
        hasLength(31),
      );
    },
  );
}

class _MemoryScheduleRepository implements ScheduleRepository {
  final schedules = <String, Schedule>{};

  @override
  Future<Result<void>> delete(String id) async {
    schedules.remove(id);
    return const Success<void>(null);
  }

  @override
  Future<Result<Schedule?>> findById(String id) async {
    return Success<Schedule?>(schedules[id]);
  }

  @override
  Future<Result<ScheduleMonth?>> loadMonth(
    String scheduleId,
    DateTime month,
  ) async {
    return Success<ScheduleMonth?>(schedules[scheduleId]?.month(month));
  }

  @override
  Future<Result<Schedule>> save(Schedule schedule) async {
    schedules[schedule.id] = schedule;
    return Success<Schedule>(schedule);
  }
}

class _MemoryFailedSyncRepository implements FailedSyncRepository {
  final Map<String, List<FailedSyncOperation>> records = {};

  @override
  Future<void> clearHistory(String historyId) async {
    records.remove(historyId);
  }

  @override
  Future<List<FailedSyncOperation>> listForHistory(String historyId) async {
    return List.unmodifiable(records[historyId] ?? const []);
  }

  @override
  Future<void> replaceForHistory(
    String historyId,
    List<FailedSyncOperation> operations,
  ) async {
    if (operations.isEmpty) {
      records.remove(historyId);
    } else {
      records[historyId] = List.unmodifiable(operations);
    }
  }
}

class _MemoryCalendarSyncGateway implements CalendarSyncGateway {
  final events = <ManagedCalendarEvent>[];
  int insertAttempts = 0;

  @override
  Future<void> delete({
    required String eventId,
    String calendarId = 'primary',
  }) async {
    events.removeWhere((event) => event.eventId == eventId);
  }

  @override
  Future<ManagedCalendarEvent> insert(CalendarSyncCommand command) async {
    insertAttempts++;
    final event = ManagedCalendarEvent(
      eventId: 'event-$insertAttempts',
      syncId: command.syncId,
      title: command.title,
      start: command.start,
      end: command.end,
      description: command.description,
      colorId: command.colorId,
    );
    events.add(event);
    return event;
  }

  @override
  Future<List<ManagedCalendarEvent>> listManagedEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    String calendarId = 'primary',
  }) async {
    return events
        .where(
          (event) =>
              event.start.isBefore(timeMax) && event.end.isAfter(timeMin),
        )
        .toList(growable: false);
  }

  @override
  Future<ManagedCalendarEvent> update({
    required String eventId,
    required CalendarSyncCommand command,
  }) async {
    final event = ManagedCalendarEvent(
      eventId: eventId,
      syncId: command.syncId,
      title: command.title,
      start: command.start,
      end: command.end,
      description: command.description,
      colorId: command.colorId,
    );
    final index = events.indexWhere((item) => item.eventId == eventId);
    if (index >= 0) events[index] = event;
    return event;
  }
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
