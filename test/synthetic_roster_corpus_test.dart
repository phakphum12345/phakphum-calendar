import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/normalized_cell.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/roster_layout_profile.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/shift_parser_input.dart';

void main() {
  final corpus = jsonDecode(
    File('test/fixtures/synthetic_rosters/corpus.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final scenarios = corpus['scenarios'] as List<dynamic>;

  for (final rawScenario in scenarios) {
    final scenario = rawScenario as Map<String, dynamic>;
    test('synthetic roster: ${scenario['name']}', () {
      final rows = scenario['rows'] as List<dynamic>;
      final cells = <NormalizedCell>[];
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final values = rows[rowIndex] as List<dynamic>;
        for (var columnIndex = 0; columnIndex < values.length; columnIndex++) {
          final value = values[columnIndex];
          if (value == null) continue;
          cells.add(
            NormalizedCell(
              sheetId: 1,
              sheetTitle: 'Synthetic',
              a1: '',
              rowIndex: rowIndex,
              columnIndex: columnIndex,
              text: value is String ? value : null,
              rawValue: value,
            ),
          );
        }
      }

      final input = ShiftParserInput(
        spreadsheetId: 'synthetic-fixture',
        spreadsheetTitle: 'Synthetic roster corpus',
        sheetId: 1,
        sheetTitle: scenario['sheetTitle'] as String,
        timeZone: 'Asia/Bangkok',
        cells: cells,
      );
      final rawProfile = scenario['profile'] as Map<String, dynamic>?;
      final profile = rawProfile == null
          ? null
          : RosterLayoutProfile(
              profileId: scenario['id'] as String,
              profileName: 'Synthetic profile',
              dateHeaderRows:
                  (rawProfile['dateHeaderRows'] as List<dynamic>).cast<int>(),
              nameColumns:
                  (rawProfile['nameColumns'] as List<dynamic>).cast<int>(),
              shiftLabelColumns:
                  (rawProfile['shiftLabelColumns'] as List<dynamic>).cast<int>(),
              dataStartRow: rawProfile['dataStartRow'] as int,
              dataEndRow: rawProfile['dataEndRow'] as int?,
            );

      final report = MonthlyRosterSectionParser(
        layoutProfile: profile,
      ).parse(input);

      final expected = scenario['expected'] as List<dynamic>;
      expect(report.assignments, hasLength(expected.length));
      for (var index = 0; index < expected.length; index++) {
        final item = expected[index] as Map<String, dynamic>;
        final actual = report.assignments[index];
        expect(actual.rowLabel, item['rowLabel']);
        expect(actual.workerName, item['workerName']);
        expect(actual.date.toIso8601String().substring(0, 10), item['date']);
        expect(actual.sourceCell, item['sourceCell']);
      }

      for (final fragment in scenario['warningContains'] as List<dynamic>) {
        expect(report.warnings.join('\n'), contains(fragment));
      }
    });
  }
}
