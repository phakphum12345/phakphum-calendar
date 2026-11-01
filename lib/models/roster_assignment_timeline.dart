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
  });

  final String positionKey;
  final List<RosterAssignmentVersion> versions;

  List<String> get workerChain => [
    for (final version in versions) version.assignedName,
  ];
}

String rosterPositionKey(Shift shift) =>
    '${shift.start.toIso8601String()}|${shift.end.toIso8601String()}|'
    '${shift.code.trim().toLowerCase()}|'
    '${shift.sourceSpreadsheetId ?? ''}|${shift.sourceSheetId ?? ''}|'
    '${shift.sheetTitle.trim().toLowerCase()}|${shift.cell.trim().toUpperCase()}';

Map<String, RosterAssignmentTimeline> buildRosterAssignmentTimelines(
  Iterable<RosterRevisionShifts> revisions,
) {
  final sorted = revisions.toList()
    ..sort((left, right) => left.modifiedAt.compareTo(right.modifiedAt));
  final versionsByPosition = <String, List<RosterAssignmentVersion>>{};

  for (final revision in sorted) {
    final byPosition = <String, Shift>{
      for (final shift in revision.shifts) rosterPositionKey(shift): shift,
    };
    for (final entry in byPosition.entries) {
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
        ),
  };
}

String _normalizedWorker(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
