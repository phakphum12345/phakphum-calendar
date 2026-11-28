import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/features/schedule/data/legacy_schedule_adapter.dart';
import 'package:phakphum_calendar/models/shift.dart';

void main() {
  test('rebinding a saved Schedule retains legacy source metadata', () {
    final source = Shift(
      code: 'CLINIC',
      rowLabel: 'Clinic',
      assignedName: 'Employee A',
      start: DateTime(2026, 11, 1, 8),
      end: DateTime(2026, 11, 1, 16),
      sheetTitle: 'November OPD',
      cell: 'C12',
      category: ShiftCategory.clinic,
      excluded: true,
      generated: true,
      linkedShiftKey: 'linked-shift-12',
      sourceColorValue: 0xFFF6BF26,
      customTitle: 'Special Clinic',
      calendarColorId: '5',
      relationshipComment: 'Accepted transfer',
    );
    const adapter = LegacyScheduleAdapter();
    final conversion = adapter.toCanonical(
      [source],
      id: 'runtime-schedule',
      name: 'November',
    );
    final saved = Schedule(
      id: conversion.schedule.id,
      name: 'November (saved)',
      months: conversion.schedule.months,
    );

    final rebound = conversion.withSchedule(saved);
    final projected = rebound.toLegacyShifts().single;

    expect(rebound.schedule, same(saved));
    expect(projected.sheetTitle, source.sheetTitle);
    expect(projected.cell, source.cell);
    expect(projected.category, source.category);
    expect(projected.excluded, source.excluded);
    expect(projected.generated, source.generated);
    expect(projected.linkedShiftKey, source.linkedShiftKey);
    expect(projected.sourceColorValue, source.sourceColorValue);
    expect(projected.customTitle, source.customTitle);
    expect(projected.calendarColorId, source.calendarColorId);
    expect(projected.relationshipComment, source.relationshipComment);
  });

  test('rebinding cannot change the canonical Schedule identity', () {
    final conversion = const LegacyScheduleAdapter().toCanonical(
      const [],
      id: 'runtime-schedule',
      name: 'November',
    );

    expect(
      () => conversion.withSchedule(
        Schedule(id: 'different-schedule', name: 'November'),
      ),
      throwsArgumentError,
    );
  });
}
