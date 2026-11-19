import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/models/shift.dart';
import 'package:phakphum_calendar/services/roster_revision_service.dart';
import 'package:phakphum_calendar/services/roster_timeline_generator.dart';

void main() {
  test('builds revision timelines from every sheet and repeated date-first blocks', () {
    final first = RosterRevisionDocument(
      revisionId: 'revision-1',
      modifiedAt: DateTime.utc(2026, 11, 1),
      snapshots: [
        SheetSnapshot(
          title: 'ตารางหลัก',
          rows: [
            ['เวรหลัก ประจำเดือน พฤศจิกายน พ.ศ. 2569'],
            ['วันที่', 1, 2, 3, 4, 5, 6, 7],
            ['P1 เช้า', 'Alice', 'Alice', 'Alice', 'Alice', 'Alice', 'Alice', 'Alice'],
            [],
            ['MRI ประจำเดือน พฤศจิกายน พ.ศ. 2569'],
            ['วันที่', 1, 2, 3, 4, 5, 6, 7],
            ['P2 เช้า', 'Carol', 'Carol', 'Carol', 'Carol', 'Carol', 'Carol', 'Carol'],
          ],
        ),
        SheetSnapshot(
          title: 'คลินิกพิเศษ',
          hidden: true,
          rows: [
            ['GEN ประจำเดือน ธันวาคม พ.ศ. 2569'],
            ['วันที่', 1, 2, 3, 4, 5, 6, 7],
            ['GEN', 'Eve', 'Eve', 'Eve', 'Eve', 'Eve', 'Eve', 'Eve'],
          ],
        ),
      ],
    );
    final second = RosterRevisionDocument(
      revisionId: 'revision-2',
      modifiedAt: DateTime.utc(2026, 11, 2),
      snapshots: [
        SheetSnapshot(
          title: 'ตารางหลัก',
          rows: [
            ['เวรหลัก ประจำเดือน พฤศจิกายน พ.ศ. 2569'],
            ['วันที่', 1, 2, 3, 4, 5, 6, 7],
            ['P1 เช้า', 'Bob', 'Bob', 'Bob', 'Bob', 'Bob', 'Bob', 'Bob'],
            [],
            ['MRI ประจำเดือน พฤศจิกายน พ.ศ. 2569'],
            ['วันที่', 1, 2, 3, 4, 5, 6, 7],
            ['P2 เช้า', 'Dana', 'Dana', 'Dana', 'Dana', 'Dana', 'Dana', 'Dana'],
          ],
        ),
        SheetSnapshot(
          title: 'คลินิกพิเศษ',
          hidden: true,
          rows: [
            ['GEN ประจำเดือน ธันวาคม พ.ศ. 2569'],
            ['วันที่', 1, 2, 3, 4, 5, 6, 7],
            ['GEN', 'Frank', 'Frank', 'Frank', 'Frank', 'Frank', 'Frank', 'Frank'],
          ],
        ),
      ],
    );

    final result = const RosterTimelineGenerator()
        .generateFromDocumentsWithDiagnostics([first, second]);

    expect(result.timelines, hasLength(3));
    final workerChains = result.timelines.values
        .map((timeline) => timeline.workerChain.join(' → '))
        .toSet();
    expect(workerChains, {
      'Alice → Bob',
      'Carol → Dana',
      'Eve → Frank',
    });
    expect(result.warnings, isEmpty);
  });

  test('does not build history from a malformed date block', () {
    final days = [
      ...List<int>.generate(16, (index) => index + 1),
      30,
      ...List<int>.generate(13, (index) => index + 18),
    ];
    final revision = RosterRevisionDocument(
      revisionId: 'revision-malformed',
      modifiedAt: DateTime.utc(2026, 11, 3),
      snapshots: [
        SheetSnapshot(
          title: 'X-OPD',
          rows: [
            ['X-OPD 1 พฤศจิกายน 2569 - 30 พฤศจิกายน 2569'],
            ['วันที่', ...days],
            ['X-OPD', ...List<String>.filled(days.length, 'Alice')],
          ],
        ),
      ],
    );

    final result = const RosterTimelineGenerator()
        .generateFromDocumentsWithDiagnostics([revision]);

    expect(result.timelines, isEmpty);
    expect(result.warnings, isNotEmpty);
    expect(
      result.warnings.join(' '),
      contains('30'),
    );
  });

  test('does not expose a Google Sheets link for synthetic revision metadata', () {
    final shift = Shift(
      code: 'UP1',
      rowLabel: 'P1 เช้า',
      assignedName: 'Alice',
      start: DateTime(2026, 11, 1, 8),
      end: DateTime(2026, 11, 1, 16),
      sheetTitle: 'Historical export',
      cell: 'B3',
      category: ShiftCategory.own,
      sourceSpreadsheetId: '',
      sourceSheetId: 0,
    );

    expect(shift.sourceUrl, isNull);
  });
}
