import '../../shift_parser/domain/roster_cell_assignment.dart';
import '../domain/user_shift_change.dart';
import 'roster_comparison_engine.dart';

class UserShiftChangeClassifier {
  const UserShiftChangeClassifier();

  List<UserShiftChange> classify({
    required List<RosterAssignmentChange> changes,
    required Iterable<String> userAliases,
  }) {
    final aliases = userAliases.map(_normalize).where((name) => name.isNotEmpty).toSet();
    final moved = <int, int>{};
    final candidates = <String, ({List<int> removed, List<int> added})>{};

    for (var index = 0; index < changes.length; index++) {
      final change = changes[index];
      final before = change.original;
      final after = change.current;
      final wasUser = before != null && aliases.contains(_normalize(before.workerName));
      final isUser = after != null && aliases.contains(_normalize(after.workerName));

      if (change.type == RosterAssignmentChangeType.removed && wasUser && after == null) {
        final key = _slotIndependentKey(before);
        candidates.putIfAbsent(key, () => (removed: <int>[], added: <int>[])).removed.add(index);
      } else if (change.type == RosterAssignmentChangeType.added && isUser && before == null) {
        final key = _slotIndependentKey(after);
        candidates.putIfAbsent(key, () => (removed: <int>[], added: <int>[])).added.add(index);
      }
    }

    // Pair only a single removal with a single addition in the same
    // date/category/period. Ambiguous groups remain separate changes.
    for (final entry in candidates.entries) {
      final removed = entry.value.removed;
      final added = entry.value.added;
      if (removed.length == 1 && added.length == 1) {
        moved[removed.single] = added.single;
      }
    }

    final consumed = <int>{...moved.keys, ...moved.values};
    final result = <UserShiftChange>[];
    for (var index = 0; index < changes.length; index++) {
      if (consumed.contains(index)) {
        final addedIndex = moved[index];
        if (addedIndex != null) {
          final before = changes[index].original!;
          final after = changes[addedIndex].current!;
          result.add(UserShiftChange(
            type: UserShiftChangeType.movedBetweenSlots,
            positionKey: changes[addedIndex].positionKey,
            before: before,
            after: after,
          ));
        }
        continue;
      }

      final change = changes[index];
      final wasUser = change.original != null &&
          aliases.contains(_normalize(change.original!.workerName));
      final isUser = change.current != null &&
          aliases.contains(_normalize(change.current!.workerName));
      final type = wasUser && isUser
          ? UserShiftChangeType.ownUnchanged
          : !wasUser && isUser
              ? UserShiftChangeType.received
              : wasUser && !isUser
                  ? UserShiftChangeType.givenAway
                  : UserShiftChangeType.unrelated;
      if (type != UserShiftChangeType.unrelated) {
        result.add(UserShiftChange(
          type: type,
          positionKey: change.positionKey,
          before: change.original,
          after: change.current,
        ));
      }
    }
    return result;
  }

  String _slotIndependentKey(RosterCellAssignment item) => [
    item.date.year,
    item.date.month,
    item.date.day,
    _normalize(item.category),
    _normalize(item.period),
  ].join('|');

  String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\\s+'), ' ').toLowerCase();
}
