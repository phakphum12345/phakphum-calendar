import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/utils/calendar_event_matcher.dart';
import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/shift_assignment.dart';
import '../../diff_engine/domain/calendar_event_candidate.dart';
import '../../../services/calendar_color_service.dart';

/// Maps canonical schedule assignments to provider-neutral calendar events.
class CanonicalScheduleEventMapper {
  const CanonicalScheduleEventMapper();

  /// Produces deterministic candidates in canonical month, day, and assignment
  /// order. Repeated assignments receive a stable occurrence discriminator.
  List<CalendarEventCandidate> map(Schedule schedule) {
    final candidates = <CalendarEventCandidate>[];
    final occurrences = <String, int>{};

    for (final month in schedule.months) {
      for (final day in month.days) {
        for (final assignment in day.assignments) {
          final identity =
              '${schedule.id}|${_date(day.date)}|'
              '${assignment.employee.id}|${assignment.shift.id}';
          final occurrence = occurrences.update(
            identity,
            (value) => value + 1,
            ifAbsent: () => 0,
          );
          final start = DateTime(
            day.date.year,
            day.date.month,
            day.date.day,
          ).add(assignment.shift.startTime);
          var end = DateTime(
            day.date.year,
            day.date.month,
            day.date.day,
          ).add(assignment.shift.endTime);
          if (!end.isAfter(start)) {
            end = end.add(const Duration(days: 1));
          }

          candidates.add(
            CalendarEventCandidate(
              syncId: _syncId('$identity|$occurrence'),
              title: '${CalendarEventMatcher.calendarTitle(assignment.shift.name)} — ${assignment.employee.fullName}',
              start: start,
              end: end,
              shouldExist: true,
              description: _description(assignment),
                colorId: () {
                  try {
                    final option = CalendarColorService.options.firstWhere(
                      (o) => o.colorValue == assignment.shift.color,
                    );
                    return option.id;
                  } catch (e) {
                    return null;
                  }
                }(),
            ),
          );
        }
      }
    }
    return List.unmodifiable(candidates);
  }

  String _description(ShiftAssignment assignment) {
    final details = <String>[
      'จัดการโดย Shift Tools',
      'ผู้ปฏิบัติงาน: ${assignment.employee.fullName}',
      'แผนก: ${assignment.employee.department.name}',
    ];
    final rel = assignment.remark?.trim() ?? '';
    final location = assignment.location?.trim() ?? '';
    final remark = assignment.remark?.trim() ?? '';
    if (rel.isNotEmpty) details.add('ความสัมพันธ์: $rel');
    if (location.isNotEmpty) details.add('สถานที่: $location');
    if (remark.isNotEmpty) details.add('หมายเหตุ: $remark');
    return details.join('\n');
  }

  String _syncId(String identity) {
    final digest = sha256.convert(utf8.encode(identity));
    return 'sce-${digest.toString().substring(0, 32)}';
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
