import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/models/roster_assignment_timeline.dart';
import 'package:phakphum_calendar/models/shift.dart';

void main() {
  test('keeps change-then-change-back worker order', () {
    final timeline = buildRosterAssignmentTimelines([
      _revision('1', DateTime(2026, 8, 1, 9), 'A'),
      _revision('2', DateTime(2026, 8, 1, 10), 'B'),
      _revision('3', DateTime(2026, 8, 1, 11), 'A'),
    ]).values.single;

    expect(timeline.workerChain, ['A', 'B', 'A']);
  });

  test('keeps onward transfer A to B to C', () {
    final timeline = buildRosterAssignmentTimelines([
      _revision('1', DateTime(2026, 8, 1, 9), 'A'),
      _revision('2', DateTime(2026, 8, 1, 10), 'B'),
      _revision('3', DateTime(2026, 8, 1, 11), 'C'),
    ]).values.single;

    expect(timeline.workerChain, ['A', 'B', 'C']);
  });

  test('deduplicates unrelated revisions with the same worker', () {
    final timeline = buildRosterAssignmentTimelines([
      _revision('1', DateTime(2026, 8, 1, 9), 'A'),
      _revision('2', DateTime(2026, 8, 1, 10), ' A '),
      _revision('3', DateTime(2026, 8, 1, 11), 'B'),
      _revision('4', DateTime(2026, 8, 1, 12), 'B'),
    ]).values.single;

    expect(timeline.workerChain, ['A', 'B']);
    expect(timeline.versions.map((version) => version.revisionId), ['1', '3']);
  });

  test('does not emit a timeline when ownership never changed', () {
    final timelines = buildRosterAssignmentTimelines([
      _revision('1', DateTime(2026, 8, 1, 9), 'A'),
      _revision('2', DateTime(2026, 8, 1, 10), 'A'),
    ]);

    expect(timelines, isEmpty);
  });

  test('does not merge identical shift positions from different tabs', () {
    final timelines = buildRosterAssignmentTimelines([
      RosterRevisionShifts(
        revisionId: '1',
        modifiedAt: DateTime(2026, 8, 1, 9),
        shifts: [
          _sourceShift('A', 'Tab A', 11),
          _sourceShift('B', 'Tab B', 22),
        ],
      ),
      RosterRevisionShifts(
        revisionId: '2',
        modifiedAt: DateTime(2026, 8, 1, 10),
        shifts: [
          _sourceShift('C', 'Tab A', 11),
          _sourceShift('D', 'Tab B', 22),
        ],
      ),
    ]);

    expect(timelines, hasLength(2));
    expect(timelines.values.map((item) => item.workerChain).toSet(), {
      ['A', 'C'],
      ['B', 'D'],
    });
  });

  test('keeps timeline semantics across month, year, and century dates', () {
    final dates = <DateTime>[
      DateTime(1900, 2, 28),
      DateTime(2000, 2, 29),
      DateTime(2100, 3, 1),
      DateTime(2200, 12, 31),
      DateTime(2400, 2, 29),
    ];

    for (final shiftDate in dates) {
      final timeline = buildRosterAssignmentTimelines([
        _revision('1', shiftDate.add(const Duration(hours: 9)), 'A', shiftDate),
        _revision(
          '2',
          shiftDate.add(const Duration(hours: 10)),
          'B',
          shiftDate,
        ),
        _revision(
          '3',
          shiftDate.add(const Duration(hours: 11)),
          'A',
          shiftDate,
        ),
      ]).values.single;

      expect(timeline.workerChain, ['A', 'B', 'A'], reason: '$shiftDate');
    }
  });
}

RosterRevisionShifts _revision(
  String id,
  DateTime time,
  String worker, [
  DateTime? shiftDate,
]) {
  final date = shiftDate ?? DateTime(2026, 8, 18);
  return RosterRevisionShifts(
    revisionId: id,
    modifiedAt: time,
    shifts: [
      Shift(
        code: 'UP3',
        rowLabel: 'P3 เช้า',
        assignedName: worker,
        start: DateTime(date.year, date.month, date.day, 8),
        end: DateTime(date.year, date.month, date.day, 16),
        sheetTitle: '16 สค - 15 กย 69',
        cell: 'D11',
        category: ShiftCategory.own,
      ),
    ],
  );
}

Shift _sourceShift(String worker, String tab, int sheetId) => Shift(
  code: 'UP1',
  rowLabel: 'P1 เช้า',
  assignedName: worker,
  start: DateTime(2026, 8, 18, 8),
  end: DateTime(2026, 8, 18, 16),
  sheetTitle: tab,
  cell: 'D11',
  category: ShiftCategory.own,
  sourceSpreadsheetId: 'spreadsheet-1',
  sourceSheetId: sheetId,
);
