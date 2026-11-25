import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:http/http.dart' as http;

import '../../../domain/entities/schedule.dart';
import '../../schedule/data/schedule_json_codec.dart';
import '../domain/grid_roster_import_provenance.dart';
import 'grid_roster_bundle_journal.dart';
import 'grid_roster_import_provenance_json_codec.dart';

/// Remote append-only journal contract used alongside the local two-slot
/// journal. Implementations must fail closed when the backend is configured.
abstract interface class GridRosterImportJournalGateway {
  Future<void> appendPrepared({
    required String scheduleId,
    required GridRosterImportProvenance provenance,
  });

  Future<void> appendCommitted({
    required Schedule schedule,
    required GridRosterImportProvenance provenance,
  });

  Future<GridRosterBundleJournalSnapshot?> recover(String scheduleId);
}

/// Authenticated Laravel gateway for cross-device Grid import recovery.
class BackendGridRosterImportJournalGateway
    implements GridRosterImportJournalGateway {
  BackendGridRosterImportJournalGateway({
    required String baseUrl,
    required this.idTokenProvider,
    http.Client? httpClient,
    this.scheduleCodec = const ScheduleJsonCodec(),
    this.provenanceCodec = const GridRosterImportProvenanceJsonCodec(),
  }) : _baseUri = _normalizeBaseUri(baseUrl),
       _http = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  final Uri _baseUri;
  final Future<String?> Function() idTokenProvider;
  final http.Client _http;
  final bool _ownsHttpClient;
  final ScheduleJsonCodec scheduleCodec;
  final GridRosterImportProvenanceJsonCodec provenanceCodec;

  static Uri _normalizeBaseUri(String value) {
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      throw ArgumentError.value(value, 'baseUrl', 'An absolute HTTP(S) URL is required.');
    }
    final localHttp = parsed.scheme == 'http' &&
        {'localhost', '127.0.0.1', '::1'}.contains(parsed.host);
    if (parsed.scheme != 'https' && !localHttp) {
      throw ArgumentError.value(value, 'baseUrl', 'HTTPS is required outside loopback.');
    }
    return parsed.replace(
      path: parsed.path.endsWith('/') ? parsed.path : '${parsed.path}/',
    );
  }

  @override
  Future<void> appendPrepared({
    required String scheduleId,
    required GridRosterImportProvenance provenance,
  }) async {
    if (provenance.targetScheduleId != scheduleId ||
        provenance.lifecycle != GridRosterImportLifecycle.prepared) {
      throw const FormatException('PREPARED provenance does not match the target Schedule.');
    }
    await _request(
      'POST',
      _journalPath(scheduleId),
      body: _stagePayload(provenance),
    );
  }

  @override
  Future<void> appendCommitted({
    required Schedule schedule,
    required GridRosterImportProvenance provenance,
  }) async {
    if (provenance.targetScheduleId != schedule.id ||
        provenance.lifecycle != GridRosterImportLifecycle.committed ||
        provenance.acceptedScheduleFingerprint == null) {
      throw const FormatException('COMMITTED provenance does not match the Schedule.');
    }
    final scheduleEnvelope = jsonDecode(scheduleCodec.encode(schedule));
    await _request(
      'POST',
      _journalPath(schedule.id),
      body: {
        ..._stagePayload(provenance),
        'accepted_schedule_fingerprint':
            _rawFingerprint(provenance.acceptedScheduleFingerprint!),
        'schedule': scheduleEnvelope,
      },
    );
  }

  @override
  Future<GridRosterBundleJournalSnapshot?> recover(String scheduleId) async {
    final response = await _request('GET', _journalPath(scheduleId));
    final records = response['data'];
    if (records is! List) {
      throw const FormatException('The backend journal response is missing its data list.');
    }

    final candidates = <GridRosterBundleJournalSnapshot>[];
    for (final entry in records) {
      if (entry is! Map) {
        throw const FormatException('The backend returned an invalid journal record.');
      }
      final record = Map<String, dynamic>.from(entry);
      if (record['schedule_id'] != scheduleId ||
          record['lifecycle'] != 'committed') {
        continue;
      }
      if (record['schedule'] is! Map || record['provenance'] is! Map) {
        throw const FormatException('A committed backend journal record is incomplete.');
      }
      final provenancePayload = <String, Object?>{
        'format': GridRosterImportProvenance.format,
        'version': GridRosterImportProvenance.schemaVersion,
        'provenance': Map<String, Object?>.from(record['provenance'] as Map),
      };
      final provenance = provenanceCodec.decode(jsonEncode(provenancePayload));
      final schedule = scheduleCodec.decode(jsonEncode(record['schedule']));
      if (schedule.id != scheduleId ||
          provenance.targetScheduleId != scheduleId ||
          provenance.lifecycle != GridRosterImportLifecycle.committed ||
          provenance.importRunId != record['import_run_id'] ||
          provenance.targetScheduleRevision != record['base_revision'] ||
          provenance.sourceFingerprint !=
              'sha256:${record['source_fingerprint']}' ||
          provenance.acceptedScheduleFingerprint == null ||
          _rawFingerprint(provenance.acceptedScheduleFingerprint!) !=
              record['accepted_schedule_fingerprint']) {
        throw const FormatException('The backend returned inconsistent committed journal data.');
      }
      final actualScheduleFingerprint =
          'sha256:${sha256.convert(utf8.encode(scheduleCodec.encode(schedule)))}';
      if (actualScheduleFingerprint != provenance.acceptedScheduleFingerprint) {
        throw const FormatException('The committed journal Schedule fingerprint is invalid.');
      }
      final journaledAtUtc = DateTime.tryParse(
        record['created_at']?.toString() ?? '',
      )?.toUtc();
      if (journaledAtUtc == null) {
        throw const FormatException('The backend journal record is missing a valid created_at timestamp.');
      }
      candidates.add(
        GridRosterBundleJournalSnapshot(
          schedule: schedule,
          provenance: provenance,
          generation: 0,
          journaledAtUtc: journaledAtUtc,
        ),
      );
    }

    if (candidates.isEmpty) return null;
    candidates.sort(
      (left, right) => left.journaledAtUtc!.compareTo(
        right.journaledAtUtc!,
      ),
    );
    return candidates.last;
  }

  Map<String, Object?> _stagePayload(GridRosterImportProvenance provenance) {
    final envelope = jsonDecode(provenanceCodec.encode(provenance)) as Map;
    final payload = Map<String, Object?>.from(envelope['provenance'] as Map);
    return {
      'import_run_id': provenance.importRunId,
      'lifecycle': provenance.lifecycle.name,
      'base_revision': provenance.targetScheduleRevision,
      'source_fingerprint': _rawFingerprint(provenance.sourceFingerprint),
      'provenance': payload,
    };
  }

  String _rawFingerprint(String value) {
    final raw = value.startsWith('sha256:') ? value.substring(7) : value;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(raw)) {
      throw FormatException('Expected a SHA-256 fingerprint, got "$value".');
    }
    return raw;
  }

  String _journalPath(String scheduleId) {
    if (scheduleId.trim().isEmpty || scheduleId.length > 128 || scheduleId.contains('/')) {
      throw ArgumentError.value(scheduleId, 'scheduleId', 'A valid Schedule ID is required.');
    }
    return 'api/v1/schedules/${Uri.encodeComponent(scheduleId)}/import-journals';
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = await idTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const BackendGridRosterJournalException(
        401,
        'Please sign in with Google again.',
      );
    }
    final uri = _baseUri.resolve(path);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _http.get(uri, headers: headers),
      'POST' => await _http.post(uri, headers: headers, body: encodedBody),
      _ => throw ArgumentError.value(method, 'method', 'Unsupported HTTP method.'),
    };

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw BackendGridRosterJournalException(
        response.statusCode,
        'The backend returned an invalid journal response.',
      );
    }
    if (decoded is! Map) {
      throw BackendGridRosterJournalException(
        response.statusCode,
        'The backend returned an invalid journal response.',
      );
    }
    final result = decoded.map((key, value) => MapEntry(key.toString(), value));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = result['error'];
      final message = error is Map ? error['message']?.toString() : null;
      throw BackendGridRosterJournalException(
        response.statusCode,
        message ?? 'The Grid import journal request failed.',
      );
    }
    return result;
  }

  void close() {
    if (_ownsHttpClient) _http.close();
  }
}

class BackendGridRosterJournalException implements Exception {
  const BackendGridRosterJournalException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'BackendGridRosterJournalException($statusCode): $message';
}
