import '../../../models/shift.dart';
import '../domain/monthly_roster_section.dart';
import 'monthly_roster_section_parser.dart';

/// Result of converting monthly-grid assignments into calendar shifts.
///
/// Unsupported row labels are kept visible instead of disappearing from the
/// conversion count. This report is diagnostic only and never syncs data.
class MonthlyRosterConversionReport {
  const MonthlyRosterConversionReport({
    required this.shifts,
    required this.unconvertedAssignments,
  });

  final List<Shift> shifts;
  final List<MonthlyRosterAssignment> unconvertedAssignments;

  int get convertedCount => shifts.length;
  int get unconvertedCount => unconvertedAssignments.length;
  bool get hasUnconvertedAssignments => unconvertedAssignments.isNotEmpty;
}

/// Adds a loss-detection pass around the legacy adapter without changing its
/// existing conversion behavior or shift-time rules.
extension MonthlyRosterShiftAdapterDiagnostics on MonthlyRosterShiftAdapter {
  MonthlyRosterConversionReport parseForWorkersWithDiagnostics(
    MonthlyRosterParseReport report, {
    required Iterable<String> targetNames,
  }) {
    final targets = targetNames
        .map(_compact)
        .where((value) => value.length >= 2)
        .toSet();
    if (targets.isEmpty) {
      return const MonthlyRosterConversionReport(
        shifts: [],
        unconvertedAssignments: [],
      );
    }

    final eligible = report.assignments.where((assignment) {
      final worker = _compact(assignment.workerName);
      return worker.isNotEmpty && targets.any(worker.contains);
    }).toList(growable: false);

    final shifts = parseForWorkers(report, targetNames: targetNames);
    final convertedCells = shifts.map((shift) => shift.cell).toSet();
    final unconverted = eligible
        .where((assignment) => !convertedCells.contains(assignment.sourceCell))
        .toList(growable: false);

    return MonthlyRosterConversionReport(
      shifts: List.unmodifiable(shifts),
      unconvertedAssignments: List.unmodifiable(unconverted),
    );
  }

  String _compact(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
}
