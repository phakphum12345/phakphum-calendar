import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/relationship_engine/application/roster_comparison_engine.dart';
import 'package:phakphum_calendar/features/relationship_engine/application/user_shift_change_classifier.dart';
import 'package:phakphum_calendar/features/relationship_engine/domain/user_shift_change.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/roster_cell_assignment.dart';

void main() {
  const classifier = UserShiftChangeClassifier();

  RosterCellAssignment cell({
    required String worker,
    required String slot,
    String period = 'เช้า',
  }) => RosterCellAssignment(
    spreadsheetId: 'sheet',
    sheetId: 1,
    sheetTitle: 'Roster',
    sourceCell: slot,
    date: DateTime(2026, 11, 16),
    category: 'Portable',
    period: period,
    slot: slot,
    workerName: worker,
  );

  test('pairs one unambiguous same-period removal and addition as a move', () {
    final before = cell(worker: 'ภาคภูมิ', slot: 'P1');
    final after = cell(worker: 'ภาคภูมิ', slot: 'P2');
    final changes = const RosterComparisonEngine().compare(
      original: [before],
      current: [after],
    );

    final result = classifier.classify(changes: changes, userAliases: ['ภาคภูมิ']);

    expect(result, hasLength(1));
    expect(result.single.type, UserShiftChangeType.movedBetweenSlots);
    expect(result.single.before?.slot, 'P1');
    expect(result.single.after?.slot, 'P2');
  });

  test('does not pair ambiguous multiple moves in the same period', () {
    final original = [
      cell(worker: 'ภาคภูมิ', slot: 'P1'),
      cell(worker: 'ภาคภูมิ', slot: 'P2'),
    ];
    final current = [
      cell(worker: 'ภาคภูมิ', slot: 'P3'),
      cell(worker: 'ภาคภูมิ', slot: 'P4'),
    ];
    final changes = const RosterComparisonEngine().compare(
      original: original,
      current: current,
    );

    final result = classifier.classify(changes: changes, userAliases: ['ภาคภูมิ']);

    expect(result, hasLength(4));
    expect(result.where((item) => item.type == UserShiftChangeType.givenAway), hasLength(2));
    expect(result.where((item) => item.type == UserShiftChangeType.received), hasLength(2));
    expect(result.where((item) => item.type == UserShiftChangeType.movedBetweenSlots), isEmpty);
  });

  test('does not pair changes across different periods', () {
    final before = cell(worker: 'ภาคภูมิ', slot: 'P1', period: 'เช้า');
    final after = cell(worker: 'ภาคภูมิ', slot: 'P2', period: 'บ่าย');
    final changes = const RosterComparisonEngine().compare(
      original: [before],
      current: [after],
    );

    final result = classifier.classify(changes: changes, userAliases: ['ภาคภูมิ']);

    expect(result.map((item) => item.type), containsAll([
      UserShiftChangeType.givenAway,
      UserShiftChangeType.received,
    ]));
    expect(result.where((item) => item.type == UserShiftChangeType.movedBetweenSlots), isEmpty);
  });
}
