import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/roster_grid_axis_mapping.dart';

void main() {
  group('RosterGridAxisMapping', () {
    test('maps horizontal logical offsets to original coordinates', () {
      const mapping = RosterGridAxisMapping(orientation: RosterGridOrientation.datesAcrossColumns);
      expect(mapping.coordinateFor(dateOffset: 2, assignmentOffset: 3, dateAxisOrigin: 4, assignmentAxisOrigin: 7), const RosterGridCoordinate(rowIndex: 10, columnIndex: 6));
    });
    test('maps vertical logical offsets to original coordinates without transposing source data', () {
      const mapping = RosterGridAxisMapping(orientation: RosterGridOrientation.datesDownRows);
      expect(mapping.coordinateFor(dateOffset: 2, assignmentOffset: 3, dateAxisOrigin: 4, assignmentAxisOrigin: 7), const RosterGridCoordinate(rowIndex: 6, columnIndex: 10));
    });
    test('rejects negative offsets and origins', () {
      const mapping = RosterGridAxisMapping(orientation: RosterGridOrientation.datesDownRows);
      expect(() => mapping.coordinateFor(dateOffset: -1, assignmentOffset: 0, dateAxisOrigin: 0, assignmentAxisOrigin: 0), throwsArgumentError);
      expect(() => mapping.coordinateFor(dateOffset: 0, assignmentOffset: 0, dateAxisOrigin: 0, assignmentAxisOrigin: -1), throwsArgumentError);
    });
  });
}
