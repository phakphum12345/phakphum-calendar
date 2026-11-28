import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/shift_parser/data/grid_roster_import_provenance_json_codec.dart';
import 'package:phakphum_calendar/features/shift_parser/domain/grid_roster_import_provenance.dart';

void main() {
  const codec = GridRosterImportProvenanceJsonCodec();

  GridRosterImportProvenance fixture({
    GridRosterImportLifecycle lifecycle = GridRosterImportLifecycle.prepared,
    String? sourceRevisionId = 'drive-revision-17',
  }) {
    return GridRosterImportProvenance(
      importRunId: 'run-001',
      sourceFingerprint: 'sha256:source',
      parserVersion: 'grid-parser/1',
      createdAtUtc: DateTime.utc(2026, 11, 24, 10),
      targetScheduleId: 'schedule-1',
      targetScheduleRevision: 'revision-7',
      lifecycle: lifecycle,
      acceptedScheduleFingerprint:
          lifecycle == GridRosterImportLifecycle.committed ? 'sha256:accepted' : null,
      sourceRevisionId: sourceRevisionId,
      sections: [
        GridRosterProvenanceSection(
          sectionId: 'section-portable',
          title: 'PORTABLE',
          readinessCode: 'ready',
          startDate: DateTime.utc(2026, 11, 16),
          endDate: DateTime.utc(2026, 12, 15),
          reasonCodes: const [],
        ),
      ],
      assignments: [
        GridRosterAssignmentProvenance(
          sourceAssignmentId: 'section-portable:B12',
          sectionId: 'section-portable',
          sourceCellReference: 'B12',
          assignmentDate: DateTime.utc(2026, 11, 16),
          canonicalEmployeeId: 'employee-42',
          shiftTemplateId: 'template-day',
          shiftRuleKind: GridRosterShiftRuleKind.configuredTemplate,
          reviewDecision: GridRosterReviewDecision.include,
          reviewerId: 'reviewer-1',
          reviewedAtUtc: DateTime.utc(2026, 11, 24, 10, 5),
        ),
        GridRosterAssignmentProvenance(
          sourceAssignmentId: 'section-portable:C12',
          sectionId: 'section-portable',
          reviewDecision: GridRosterReviewDecision.exclude,
          shiftRuleKind: GridRosterShiftRuleKind.builtInRule,
          reviewerId: 'reviewer-1',
          reviewedAtUtc: DateTime.utc(2026, 11, 24, 10, 6),
        ),
      ],
      diagnostics: [
        GridRosterProvenanceDiagnostic(
          code: 'identity_ambiguous',
          severity: GridRosterDiagnosticSeverity.warning,
          sectionId: 'section-portable',
          sourceCellReference: 'B13',
        ),
      ],
    );
  }

  test('round-trips section, assignment, review and diagnostic evidence', () {
    final original = fixture();
    final decoded = codec.decode(codec.encode(original));

    expect(decoded.importRunId, original.importRunId);
    expect(decoded.sourceRevisionId, original.sourceRevisionId);
    expect(decoded.createdAtUtc, original.createdAtUtc);
    expect(decoded.sections.single.startDate, DateTime.utc(2026, 11, 16));
    expect(decoded.assignments.map((item) => item.reviewDecision), [
      GridRosterReviewDecision.include,
      GridRosterReviewDecision.exclude,
    ]);
    expect(decoded.assignments.first.canonicalEmployeeId, 'employee-42');
    expect(decoded.assignments.first.shiftTemplateId, 'template-day');
    expect(decoded.diagnostics.single.code, 'identity_ambiguous');
  });

  test('committed lifecycle requires accepted schedule fingerprint', () {
    final committed = fixture(lifecycle: GridRosterImportLifecycle.committed);
    expect(
      codec.decode(codec.encode(committed)).acceptedScheduleFingerprint,
      'sha256:accepted',
    );
  });

  test('decodes older schema-one envelopes without a source revision id', () {
    final json = jsonDecode(codec.encode(fixture())) as Map<String, Object?>;
    final provenance = json['provenance']! as Map<String, Object?>;
    provenance.remove('sourceRevisionId');

    final decoded = codec.decode(jsonEncode(json));

    expect(decoded.sourceRevisionId, isNull);
  });

  test('unsupported schema versions fail explicitly', () {
    final json = jsonDecode(codec.encode(fixture())) as Map<String, Object?>;
    json['version'] = 2;
    expect(
      () => codec.decode(jsonEncode(json)),
      throwsA(isA<UnsupportedGridRosterProvenanceVersionException>()),
    );
  });

  test('missing required fields fail explicitly', () {
    final json = jsonDecode(codec.encode(fixture())) as Map<String, Object?>;
    final provenance = json['provenance']! as Map<String, Object?>;
    provenance.remove('sourceFingerprint');
    expect(
      () => codec.decode(jsonEncode(json)),
      throwsA(isA<GridRosterProvenanceCodecException>()),
    );
  });

  test('unknown enum values fail closed', () {
    final json = jsonDecode(codec.encode(fixture())) as Map<String, Object?>;
    final provenance = json['provenance']! as Map<String, Object?>;
    provenance['lifecycle'] = 'maybe';
    expect(
      () => codec.decode(jsonEncode(json)),
      throwsA(isA<GridRosterProvenanceCodecException>()),
    );
  });

  test('serialized envelope does not contain workbook bytes or raw cell values', () {
    final encoded = codec.encode(fixture());
    expect(encoded, isNot(contains('workbookBytes')));
    expect(encoded, isNot(contains('rawCellValue')));
    expect(encoded, isNot(contains('สมชาย')));
    expect(encoded, contains('sourceCellReference'));
  });

  test('final review decisions require reviewer evidence', () {
    expect(
      () => GridRosterAssignmentProvenance(
        sourceAssignmentId: 'a1',
        sectionId: 's1',
        reviewDecision: GridRosterReviewDecision.include,
        shiftRuleKind: GridRosterShiftRuleKind.builtInRule,
      ),
      throwsArgumentError,
    );
  });

  test('committed envelope cannot omit accepted fingerprint', () {
    expect(
      () => GridRosterImportProvenance(
        importRunId: 'run',
        sourceFingerprint: 'source',
        parserVersion: '1',
        createdAtUtc: DateTime.utc(2026),
        targetScheduleId: 'schedule',
        targetScheduleRevision: 'rev',
        lifecycle: GridRosterImportLifecycle.committed,
        sections: const [],
        assignments: const [],
        diagnostics: const [],
      ),
      throwsArgumentError,
    );
  });

  test('included assignments require canonical identity and resolved rule', () {
    expect(
      () => GridRosterAssignmentProvenance(
        sourceAssignmentId: 'a2',
        sectionId: 's1',
        reviewDecision: GridRosterReviewDecision.include,
        shiftRuleKind: GridRosterShiftRuleKind.builtInRule,
        reviewerId: 'reviewer',
        reviewedAtUtc: DateTime.utc(2026, 11, 24),
      ),
      throwsArgumentError,
    );
    expect(
      () => GridRosterAssignmentProvenance(
        sourceAssignmentId: 'a3',
        sectionId: 's1',
        canonicalEmployeeId: 'employee',
        reviewDecision: GridRosterReviewDecision.include,
        shiftRuleKind: GridRosterShiftRuleKind.ambiguousTemplate,
        reviewerId: 'reviewer',
        reviewedAtUtc: DateTime.utc(2026, 11, 24),
      ),
      throwsArgumentError,
    );
  });

  test('committed envelope cannot retain pending assignments', () {
    expect(
      () => GridRosterImportProvenance(
        importRunId: 'run',
        sourceFingerprint: 'source',
        parserVersion: '1',
        createdAtUtc: DateTime.utc(2026),
        targetScheduleId: 'schedule',
        targetScheduleRevision: 'rev',
        lifecycle: GridRosterImportLifecycle.committed,
        acceptedScheduleFingerprint: 'accepted',
        sections: [
          GridRosterProvenanceSection(
            sectionId: 's1',
            title: 'Section',
            readinessCode: 'ready',
            reasonCodes: const [],
          ),
        ],
        assignments: [
          GridRosterAssignmentProvenance(
            sourceAssignmentId: 'a1',
            sectionId: 's1',
            reviewDecision: GridRosterReviewDecision.pending,
            shiftRuleKind: GridRosterShiftRuleKind.unresolved,
          ),
        ],
        diagnostics: const [],
      ),
      throwsArgumentError,
    );
  });

}
