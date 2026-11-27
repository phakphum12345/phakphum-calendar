/// Describes which worksheet axis advances through calendar dates.
///
/// This is an explicit source-layout fact, not a heuristic inferred by
/// transposing a parsed roster. The parser must retain original coordinates
/// when applying this mapping.
enum RosterGridOrientation {
  /// Dates advance left-to-right; assignment rows advance top-to-bottom.
  datesAcrossColumns,

  /// Dates advance top-to-bottom; assignment columns advance left-to-right.
  datesDownRows,
}

/// Immutable zero-based worksheet coordinate.
class RosterGridCoordinate {
  const RosterGridCoordinate({required this.rowIndex, required this.columnIndex});

  final int rowIndex;
  final int columnIndex;

  @override
  bool operator ==(Object other) =>
      other is RosterGridCoordinate &&
      other.rowIndex == rowIndex &&
      other.columnIndex == columnIndex;

  @override
  int get hashCode => Object.hash(rowIndex, columnIndex);
}

/// Maps logical date/assignment offsets to original worksheet coordinates.
///
/// The mapping deliberately does not parse dates, names, or shift labels. It
/// only makes orientation explicit so higher-level parsers can resolve each
/// axis independently and keep provenance tied to the original grid.
class RosterGridAxisMapping {
  const RosterGridAxisMapping({required this.orientation});

  final RosterGridOrientation orientation;

  RosterGridCoordinate coordinateFor({
    required int dateOffset,
    required int assignmentOffset,
    required int dateAxisOrigin,
    required int assignmentAxisOrigin,
  }) {
    if (dateOffset < 0 || assignmentOffset < 0) {
      throw ArgumentError('Axis offsets must be zero-based non-negative values.');
    }
    if (dateAxisOrigin < 0 || assignmentAxisOrigin < 0) {
      throw ArgumentError('Axis origins must be zero-based non-negative values.');
    }

    return switch (orientation) {
      RosterGridOrientation.datesAcrossColumns => RosterGridCoordinate(
          rowIndex: assignmentAxisOrigin + assignmentOffset,
          columnIndex: dateAxisOrigin + dateOffset,
        ),
      RosterGridOrientation.datesDownRows => RosterGridCoordinate(
          rowIndex: dateAxisOrigin + dateOffset,
          columnIndex: assignmentAxisOrigin + assignmentOffset,
        ),
    };
  }
}
