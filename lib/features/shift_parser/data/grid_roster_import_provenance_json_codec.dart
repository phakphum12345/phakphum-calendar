import 'dart:convert';

import '../domain/grid_roster_import_provenance.dart';

/// Controlled failure while decoding or encoding import provenance.
class GridRosterProvenanceCodecException extends FormatException {
  const GridRosterProvenanceCodecException(super.message);
}

/// Unsupported provenance envelope schema version.
final class UnsupportedGridRosterProvenanceVersionException
    extends GridRosterProvenanceCodecException {
  const UnsupportedGridRosterProvenanceVersionException(super.message);
}

/// Strict JSON codec for the additive Grid import provenance envelope.
class GridRosterImportProvenanceJsonCodec {
  const GridRosterImportProvenanceJsonCodec();

  String encode(GridRosterImportProvenance value) => jsonEncode({
    'format': GridRosterImportProvenance.format,
    'version': GridRosterImportProvenance.schemaVersion,
    'provenance': {
      'importRunId': value.importRunId,
      'sourceFingerprint': value.sourceFingerprint,
      'parserVersion': value.parserVersion,
      'createdAtUtc': value.createdAtUtc.toIso8601String(),
      'targetScheduleId': value.targetScheduleId,
      'targetScheduleRevision': value.targetScheduleRevision,
      'lifecycle': value.lifecycle.name,
      'acceptedScheduleFingerprint': value.acceptedScheduleFingerprint,
      'sections': [
        for (final section in value.sections)
          {
            'sectionId': section.sectionId,
            'title': section.title,
            'readinessCode': section.readinessCode,
            'startDate': _dateOnly(section.startDate),
            'endDate': _dateOnly(section.endDate),
            'reasonCodes': section.reasonCodes,
          },
      ],
      'assignments': [
        for (final assignment in value.assignments)
          {
            'sourceAssignmentId': assignment.sourceAssignmentId,
            'sectionId': assignment.sectionId,
            'sourceCellReference': assignment.sourceCellReference,
            'assignmentDate': _dateOnly(assignment.assignmentDate),
            'canonicalEmployeeId': assignment.canonicalEmployeeId,
            'shiftTemplateId': assignment.shiftTemplateId,
            'reviewDecision': assignment.reviewDecision.name,
            'shiftRuleKind': assignment.shiftRuleKind.name,
            'reviewerId': assignment.reviewerId,
            'reviewedAtUtc': assignment.reviewedAtUtc?.toUtc().toIso8601String(),
          },
      ],
      'diagnostics': [
        for (final diagnostic in value.diagnostics)
          {
            'code': diagnostic.code,
            'severity': diagnostic.severity.name,
            'sectionId': diagnostic.sectionId,
            'sourceCellReference': diagnostic.sourceCellReference,
          },
      ],
    },
  });

  GridRosterImportProvenance decode(String source) {
    final root = _object(jsonDecode(source), r'$');
    if (_string(root, 'format', r'$.format') !=
        GridRosterImportProvenance.format) {
      throw const GridRosterProvenanceCodecException(
        'Unsupported Grid provenance format.',
      );
    }
    final version = _integer(root, 'version', r'$.version');
    if (version != GridRosterImportProvenance.schemaVersion) {
      throw UnsupportedGridRosterProvenanceVersionException(
        'Unsupported Grid provenance schema version $version.',
      );
    }
    final json = _object(root['provenance'], r'$.provenance');
    final sections = _array(json, 'sections', r'$.provenance.sections')
        .asMap()
        .entries
        .map((entry) {
          final path = r'$.provenance.sections[]';
          final item = _object(entry.value, path);
          final start = _optionalDate(item, 'startDate', path);
          final end = _optionalDate(item, 'endDate', path);
          return GridRosterProvenanceSection(
            sectionId: _string(item, 'sectionId', '$path.sectionId'),
            title: _string(item, 'title', '$path.title'),
            readinessCode: _string(item, 'readinessCode', '$path.readinessCode'),
            startDate: start,
            endDate: end,
            reasonCodes: _stringList(item, 'reasonCodes', '$path.reasonCodes'),
          );
        })
        .toList(growable: false);
    final assignments = _array(
      json,
      'assignments',
      r'$.provenance.assignments',
    ).map((entry) {
      const path = r'$.provenance.assignments[]';
      final item = _object(entry, path);
      return GridRosterAssignmentProvenance(
        sourceAssignmentId: _string(item, 'sourceAssignmentId', '$path.sourceAssignmentId'),
        sectionId: _string(item, 'sectionId', '$path.sectionId'),
        sourceCellReference: _optionalString(item, 'sourceCellReference', path),
        assignmentDate: _optionalDate(item, 'assignmentDate', path),
        canonicalEmployeeId: _optionalString(item, 'canonicalEmployeeId', path),
        shiftTemplateId: _optionalString(item, 'shiftTemplateId', path),
        reviewDecision: _enumValue(
          GridRosterReviewDecision.values,
          _string(item, 'reviewDecision', '$path.reviewDecision'),
          '$path.reviewDecision',
        ),
        shiftRuleKind: _enumValue(
          GridRosterShiftRuleKind.values,
          _string(item, 'shiftRuleKind', '$path.shiftRuleKind'),
          '$path.shiftRuleKind',
        ),
        reviewerId: _optionalString(item, 'reviewerId', path),
        reviewedAtUtc: _optionalTimestamp(item, 'reviewedAtUtc', path),
      );
    }).toList(growable: false);
    final diagnostics = _array(
      json,
      'diagnostics',
      r'$.provenance.diagnostics',
    ).map((entry) {
      const path = r'$.provenance.diagnostics[]';
      final item = _object(entry, path);
      return GridRosterProvenanceDiagnostic(
        code: _string(item, 'code', '$path.code'),
        severity: _enumValue(
          GridRosterDiagnosticSeverity.values,
          _string(item, 'severity', '$path.severity'),
          '$path.severity',
        ),
        sectionId: _optionalString(item, 'sectionId', path),
        sourceCellReference: _optionalString(item, 'sourceCellReference', path),
      );
    }).toList(growable: false);

    return GridRosterImportProvenance(
      importRunId: _string(json, 'importRunId', r'$.provenance.importRunId'),
      sourceFingerprint: _string(json, 'sourceFingerprint', r'$.provenance.sourceFingerprint'),
      parserVersion: _string(json, 'parserVersion', r'$.provenance.parserVersion'),
      createdAtUtc: _timestamp(json, 'createdAtUtc', r'$.provenance.createdAtUtc'),
      targetScheduleId: _string(json, 'targetScheduleId', r'$.provenance.targetScheduleId'),
      targetScheduleRevision: _string(json, 'targetScheduleRevision', r'$.provenance.targetScheduleRevision'),
      lifecycle: _enumValue(
        GridRosterImportLifecycle.values,
        _string(json, 'lifecycle', r'$.provenance.lifecycle'),
        r'$.provenance.lifecycle',
      ),
      acceptedScheduleFingerprint: _optionalString(
        json,
        'acceptedScheduleFingerprint',
        r'$.provenance',
      ),
      sections: sections,
      assignments: assignments,
      diagnostics: diagnostics,
    );
  }
}

String? _dateOnly(DateTime? value) => value == null
    ? null
    : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map) throw GridRosterProvenanceCodecException('$path must be an object.');
  try {
    return Map<String, Object?>.from(value);
  } on Object {
    throw GridRosterProvenanceCodecException('$path must have string keys.');
  }
}

List<Object?> _array(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value is! List) throw GridRosterProvenanceCodecException('$path must be a list.');
  return List<Object?>.from(value);
}

String _string(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value is! String) throw GridRosterProvenanceCodecException('$path must be a string.');
  return value;
}

String? _optionalString(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw GridRosterProvenanceCodecException('$path.$key must be a string or null.');
  return value;
}

int _integer(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value is! int) throw GridRosterProvenanceCodecException('$path must be an integer.');
  return value;
}

List<String> _stringList(Map<String, Object?> json, String key, String path) {
  final values = _array(json, key, path);
  if (values.any((value) => value is! String)) {
    throw GridRosterProvenanceCodecException('$path must contain only strings.');
  }
  return values.cast<String>();
}

DateTime _timestamp(Map<String, Object?> json, String key, String path) {
  final value = _string(json, key, path);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !value.endsWith('Z')) {
    throw GridRosterProvenanceCodecException('$path must be a valid UTC timestamp.');
  }
  return parsed.toUtc();
}

DateTime? _optionalTimestamp(Map<String, Object?> json, String key, String path) {
  if (json[key] == null) return null;
  return _timestamp(json, key, path);
}

DateTime? _optionalDate(Map<String, Object?> json, String key, String path) {
  final value = _optionalString(json, key, path);
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
    throw GridRosterProvenanceCodecException('$path.$key must be an ISO calendar date.');
  }
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

T _enumValue<T extends Enum>(List<T> values, String name, String path) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw GridRosterProvenanceCodecException('$path has unknown value "$name".');
}
