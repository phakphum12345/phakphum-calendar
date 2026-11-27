/// Describes which worksheet axis advances through calendar dates.
/// This is explicit layout metadata, not a heuristic transpose.
enum RosterGridOrientation { datesAcrossColumns, datesDownRows }

/// Immutable zero-based worksheet coordinate.
class RosterGridCoordinate {
  const RosterGridCoordinate({required this.rowIndex, required this.columnIndex});
  final int rowIndex;
  final int columnIndex;

  @override
  bool operator ==(Object other) => other is RosterGridCoordinate && other.rowIndex == rowIndex && other.columnIndex == columnIndex;
  @override
  int get hashCode => Object.hash(rowIndex, columnIndex);
}

/// Maps logical date/assignment offsets to original worksheet coordinates.
/// It does not parse dates, names, or labels; callers retain source evidence.
class RosterGridAxisMapping {
  const RosterGridAxisMapping({required this.orientation});
  final RosterGridOrientation orientation;

  RosterGridCoordinate coordinateFor({required int dateOffset, required int assignmentOffset, required int dateAxisOrigin, required int assignmentAxisOrigin}) {
    if (dateOffset < 0 || assignmentOffset < 0 || dateAxisOrigin < 0 || assignmentAxisOrigin < 0) {
      throw ArgumentError('Offsets and origins must be zero-based non-negative values.');
    }
    return switch (orientation) {
      RosterGridOrientation.datesAcrossColumns => RosterGridCoordinate(rowIndex: assignmentAxisOrigin + assignmentOffset, columnIndex: dateAxisOrigin + dateOffset),
      RosterGridOrientation.datesDownRows => RosterGridCoordinate(rowIndex: dateAxisOrigin + dateOffset, columnIndex: assignmentAxisOrigin + assignmentOffset),
    };
  }
}
