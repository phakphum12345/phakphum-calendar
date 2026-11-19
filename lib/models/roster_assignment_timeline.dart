import 'shift.dart';

class RosterRevisionShifts {
  const RosterRevisionShifts({
    required this.revisionId,
    required this.modifiedAt,
    required this.shifts,
  });

  final String revisionId;
  final DateTime modifiedAt;
  final List<Shift> shifts;
}

class RosterAssignmentVersion {
  const RosterAssignmentVersion({
    required this.revisionId,
    required this.modifiedAt,
    required this.assignedName,
  });

  final String revisionId;
  final DateTime modifiedAt;
  final String assignedName;
}

class RosterAssignmentTimeline {
  const RosterAssignmentTimeline({
    required this.positionKey,
    required this.versions,
    this.start,
    this.end,
    this.shiftCode,
    this.sheetTitle,
    this.rowLabel,
    this.column,
  });

  final String positionKey;
  final List<RosterAssignmentVersion> versions;
  final DateTime? start;
  final DateTime? end;
  final String? shiftCode;
  final String? sheetTitle;
  final String? rowLabel;
  final String? column;

  List<String> get workerChain => [
    for (final version in versions) version.assignedName,
  ];
}

String rosterPositionKey(Shift shift) {
  // Drive XLSX revision exports do not carry Google sheet IDs. Use the
  // worksheet title and section label (not the mutable row number) so the
  // archived and live snapshots still resolve to the same roster position.
  final column = RegExp(r'^[A-Za-z]+').firstMatch(shift.cell)?.group(0) ??
      shift.cell.trim().toUpperCase();
  return '${shift.start.toIso8601String()}|${shift.end.toIso8601String()}|'
      '${shift.code.trim().toLowerCase()}|'
      '${shift.sheetTitle.trim().toLowerCase()}|'
      '${shift.rowLabel.trim().toLowerCase()}|${column.toUpperCase()}';
}

Map<String, RosterAssignmentTimeline> buildRosterAssignmentTimelines(
  Iterable<RosterRevisionShifts> revisions,
) {
  final sorted = revisions.toList()
    ..sort((left, right) => left.modifiedAt.compareTo(right.modifiedAt));
  final versionsByPosition = <String, List<RosterAssignmentVersion>>{};
  final firstShiftByPosition = <String, Shift>{};

  for (final revision in sorted) {
    final byPosition = <String, Shift>{
      for (final shift in revision.shifts) rosterPositionKey(shift): shift,
    };
    for (final entry in byPosition.entries) {
      firstShiftByPosition.putIfAbsent(entry.key, () => entry.value);
      final assignedName = entry.value.assignedName.trim();
      if (assignedName.isEmpty) continue;
      final versions = versionsByPosition.putIfAbsent(entry.key, () => []);
      if (versions.isNotEmpty &&
          _normalizedWorker(versions.last.assignedName) ==
              _normalizedWorker(assignedName)) {
        continue;
      }
      versions.add(
        RosterAssignmentVersion(
          revisionId: revision.revisionId,
          modifiedAt: revision.modifiedAt,
          assignedName: assignedName,
        ),
      );
    }
  }

  return {
    for (final entry in versionsByPosition.entries)
      if (entry.value.length > 1)
        entry.key: RosterAssignmentTimeline(
          positionKey: entry.key,
          versions: List.unmodifiable(entry.value),
          start: firstShiftByPosition[entry.key]!.start,
          end: firstShiftByPosition[entry.key]!.end,
          shiftCode: firstShiftByPosition[entry.key]!.code,
          sheetTitle: firstShiftByPosition[entry.key]!.sheetTitle,
          rowLabel: firstShiftByPosition[entry.key]!.rowLabel,
          column: RegExp(r'^[A-Za-z]+')
              .firstMatch(firstShiftByPosition[entry.key]!.cell)
              ?.group(0),
        ),
  };
}

String _normalizedWorker(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
