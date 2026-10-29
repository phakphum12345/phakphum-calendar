import '../../../models/shift.dart';

/// Compares the legacy parser with the monthly-grid parser and produces a
/// reviewable merge result. Monthly-only records are candidates for recovery;
/// the analyzer does not write to Google Calendar or mutate the source roster.
class SmartRosterAnalysis {
  const SmartRosterAnalysis({
    required this.mergedShifts,
    required this.recoveredShifts,
    required this.possibleDuplicates,
  });

  final List<Shift> mergedShifts;
  final List<Shift> recoveredShifts;
  final List<SmartRosterDuplicate> possibleDuplicates;

  int get recoveredCount => recoveredShifts.length;
}

class SmartRosterDuplicate {
  const SmartRosterDuplicate({
    required this.legacyShift,
    required this.monthlyShift,
  });

  final Shift legacyShift;
  final Shift monthlyShift;
}

/// Analyze → compare → generate recovered candidates → flag possible duplicates.
class SmartRosterAnalyzeGenerator {
  const SmartRosterAnalyzeGenerator();

  SmartRosterAnalysis analyze({
    required Iterable<Shift> legacyShifts,
    required Iterable<Shift> monthlyShifts,
  }) {
    final mergedBySource = <String, Shift>{};
    final legacy = legacyShifts.toList(growable: false);
    for (final shift in legacy) {
      mergedBySource.putIfAbsent(shift.sourceKey, () => shift);
    }

    final recovered = <Shift>[];
    final possibleDuplicates = <SmartRosterDuplicate>[];
    final legacyByDayAndWorker = <String, List<Shift>>{};
    for (final shift in legacy) {
      legacyByDayAndWorker
          .putIfAbsent(_dayWorkerKey(shift), () => <Shift>[])
          .add(shift);
    }

    for (final candidate in monthlyShifts) {
      if (mergedBySource.containsKey(candidate.sourceKey)) continue;

      final sameDayWorker =
          legacyByDayAndWorker[_dayWorkerKey(candidate)] ?? const <Shift>[];
      if (sameDayWorker.isNotEmpty) {
        possibleDuplicates.add(
          SmartRosterDuplicate(
            legacyShift: sameDayWorker.first,
            monthlyShift: candidate,
          ),
        );
      }

      // Keep the monthly candidate visible for review, but never auto-sync it.
      mergedBySource[candidate.sourceKey] = candidate;
      recovered.add(candidate);
    }

    final merged = mergedBySource.values.toList(growable: false)
      ..sort((a, b) => a.start.compareTo(b.start));
    return SmartRosterAnalysis(
      mergedShifts: List.unmodifiable(merged),
      recoveredShifts: List.unmodifiable(recovered),
      possibleDuplicates: List.unmodifiable(possibleDuplicates),
    );
  }

  String _dayWorkerKey(Shift shift) =>
      '${shift.start.year}-${shift.start.month}-${shift.start.day}|'
      '${_normalize(shift.assignedName)}';

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\\s+'), '');
}
