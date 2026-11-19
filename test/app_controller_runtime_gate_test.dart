import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/di/app_dependencies.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/models/roster_period.dart';

void main() {
  test('Calendar writes require explicit confirmation and a prepared preview', () async {
    final controller = AppDependencies.production().createDemoAppController();
    addTearDown(controller.dispose);

    await expectLater(
      controller.syncCalendar(userConfirmed: false),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      controller.syncCalendar(userConfirmed: true),
      throwsA(isA<StateError>()),
    );
  });

  test('rejects overlapping Calendar operations instead of silently dropping them', () async {
    final controller = AppDependencies.production().createDemoAppController();
    addTearDown(controller.dispose);

    // Simulate a roster read or another exclusive controller operation.
    controller.busy = true;

    await expectLater(
      controller.previewCandidates(const []),
      throwsA(isA<StateError>()),
    );
    expect(controller.busy, isTrue);
  });
  test('blocks Calendar preview when selected months produce an empty schedule', () async {
    final controller = AppDependencies.production().createDemoAppController();
    addTearDown(controller.dispose);

    controller.settings = controller.settings.copyWith(
      periods: const [RosterPeriod(year: 2026, month: 11)],
    );
    await controller.adoptCanonicalSchedule(
      Schedule(id: 'empty-november', name: 'Empty November roster'),
      persist: false,
    );

    await expectLater(
      controller.prepareCalendarSync(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('ไม่พบรายการเวร'),
            contains('11/2569'),
            contains('หยุดก่อนอ่านหรือเขียน Google Calendar'),
          ),
        ),
      ),
    );
  });

}
