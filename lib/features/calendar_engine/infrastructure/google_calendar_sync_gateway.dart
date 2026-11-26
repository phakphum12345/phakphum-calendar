import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;

import '../domain/calendar_sync_command.dart';
import '../domain/calendar_sync_gateway.dart';
import '../domain/managed_calendar_event.dart';

class GoogleCalendarSyncGateway
    implements CalendarSyncGateway, ComparableCalendarEventGateway, ConditionalCalendarSyncGateway {
  GoogleCalendarSyncGateway(
    this._client, {
    this.requestTimeout = defaultRequestTimeout,
  });

  static const String syncIdKey = 'sceSyncId';
  static const String legacySyncIdKey = 'syncId';
  static const String legacyManagedByKey = 'managedBy';
  static const String legacyManagedByValue = 'phakphum-calendar';
  static const String timeZone = 'Asia/Bangkok';
  static const Duration _bangkokOffset = Duration(hours: 7);

  /// Prevent one provider request from leaving the sync Future pending forever.
  /// The sync executor can retry a bounded failure instead of hanging the UI.
  static const Duration defaultRequestTimeout = Duration(seconds: 20);

  final http.Client _client;
  final Duration requestTimeout;

  @override
  Future<List<ManagedCalendarEvent>> listManagedEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    String calendarId = 'primary',
  }) async {
    return _listEvents(
      timeMin: timeMin,
      timeMax: timeMax,
      calendarId: calendarId,
      managedOnly: true,
    );
  }

  @override
  Future<List<ManagedCalendarEvent>> listComparableLegacyEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    String calendarId = 'primary',
  }) {
    return _listEvents(
      timeMin: timeMin,
      timeMax: timeMax,
      calendarId: calendarId,
      managedOnly: false,
    );
  }

  Future<List<ManagedCalendarEvent>> _listEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    required String calendarId,
    required bool managedOnly,
  }) async {
    final api = calendar.CalendarApi(_client);
    final items = <calendar.Event>[];
    String? pageToken;
    do {
      final events = await api.events
          .list(
            calendarId,
            timeMin: _bangkokInstant(timeMin),
            timeMax: _bangkokInstant(timeMax),
            singleEvents: true,
            maxResults: 2500,
            pageToken: pageToken,
          )
          .timeout(requestTimeout);
      items.addAll(events.items ?? const <calendar.Event>[]);
      pageToken = events.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    return items
        .where((event) {
          final managedSyncId = _managedSyncId(event);
          return event.id != null &&
              (managedOnly ? managedSyncId != null : managedSyncId == null) &&
              event.start?.dateTime != null &&
              event.end?.dateTime != null;
        })
        .map(
          (event) => ManagedCalendarEvent(
            eventId: event.id!,
            syncId: _managedSyncId(event) ?? 'legacy:${event.id!}',
            title: event.summary ?? '',
            start: _bangkokWallTime(event.start!.dateTime!),
            end: _bangkokWallTime(event.end!.dateTime!),
            description: _normalizeManagedDescription(event.description),
            colorId: event.colorId,
            etag: event.etag,
            providerSyncId: _managedSyncId(event),
          ),
        )
        .toList(growable: false);
  }

  String? _managedSyncId(calendar.Event event) {
    final privateProperties = event.extendedProperties?.private;
    final currentSyncId = privateProperties?[syncIdKey]?.trim() ?? '';
    if (currentSyncId.isNotEmpty) return currentSyncId;

    if (privateProperties?[legacyManagedByKey]?.trim() !=
        legacyManagedByValue) {
      return null;
    }
    final legacySyncId = privateProperties?[legacySyncIdKey]?.trim() ?? '';
    return legacySyncId.isEmpty ? null : legacySyncId;
  }

  @override
  Future<ManagedCalendarEvent> insert(CalendarSyncCommand command) async {
    final api = calendar.CalendarApi(_client);
    final eventId = _providerEventId(command.syncId);
    try {
      final created = await api.events
          .insert(
            _toEvent(command)..id = eventId,
            command.calendarId,
          )
          .timeout(requestTimeout);
      return _toManaged(created, command.syncId);
    } catch (insertError, stackTrace) {
      calendar.Event existing;
      try {
        existing = await api.events
            .get(command.calendarId, eventId)
            .timeout(requestTimeout);
      } catch (_) {
        Error.throwWithStackTrace(insertError, stackTrace);
      }

      if (_managedSyncId(existing) != command.syncId) {
        throw StateError(
          'A Calendar event with the deterministic ID does not match '
          'sync ID ${command.syncId}.',
        );
      }
      return _toManaged(existing, command.syncId);
    }
  }

  @override
  Future<ManagedCalendarEvent> update({
    required String eventId,
    required CalendarSyncCommand command,
  }) async {
    final existing = await _readEvent(command.calendarId, eventId);
    if (existing == null || existing.etag == null) {
      throw StateError('Calendar event $eventId is missing or has no ETag; refresh the preview.');
    }
    return updateConditionally(
      eventId: eventId,
      expectedEtag: existing.etag!,
      expectedSyncId: _managedSyncId(existing),
      command: command,
    );
  }

  @override
  Future<void> delete({
    required String eventId,
    String calendarId = 'primary',
  }) async {
    final existing = await _readEvent(calendarId, eventId);
    if (existing == null) return;
    if (existing.etag == null) {
      throw StateError('Calendar event $eventId has no ETag; refusing an unguarded delete.');
    }
    await deleteConditionally(
      eventId: eventId,
      calendarId: calendarId,
      expectedEtag: existing.etag!,
      expectedSyncId: _managedSyncId(existing),
    );
  }

  @override
  Future<ManagedCalendarEvent> updateConditionally({
    required String eventId,
    required String expectedEtag,
    required String? expectedSyncId,
    required CalendarSyncCommand command,
  }) async {
    if (expectedEtag.trim().isEmpty) {
      throw StateError('Calendar update requires the ETag captured by preview.');
    }
    final existing = await _readEvent(command.calendarId, eventId);
    if (existing == null) {
      throw StateError('Calendar event $eventId no longer exists; refresh the preview.');
    }
    if (!_matchesExpectedProviderIdentity(existing, expectedSyncId)) {
      throw StateError('Calendar event $eventId is no longer the provider event shown in the preview.');
    }
    if (_matchesCommand(existing, command)) {
      return _toManaged(existing, command.syncId);
    }
    if (existing.etag == null || existing.etag != expectedEtag) {
      throw StateError('Calendar event $eventId changed after preview; refresh before retrying.');
    }

    final request = http.Request('PUT', _eventUri(command.calendarId, eventId))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'If-Match': expectedEtag,
      })
      ..body = jsonEncode(_mergeManagedFields(existing, command, eventId).toJson());
    final response = await _send(request);
    if (response.statusCode == 412) {
      throw StateError('Calendar event $eventId failed the ETag precondition. Refresh the preview.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Conditional Calendar update failed with HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const FormatException('Calendar update response is invalid.');
    return _toManaged(
      calendar.Event.fromJson(Map<String, dynamic>.from(decoded)),
      command.syncId,
    );
  }

  @override
  Future<void> deleteConditionally({
    required String eventId,
    required String calendarId,
    required String expectedEtag,
    required String? expectedSyncId,
  }) async {
    if (expectedEtag.trim().isEmpty) {
      throw StateError('Calendar delete requires the ETag captured by preview.');
    }
    final existing = await _readEvent(calendarId, eventId);
    // A missing event is the desired terminal state for a delete retry.
    if (existing == null) return;
    if (!_matchesExpectedProviderIdentity(existing, expectedSyncId)) {
      throw StateError('Refusing to delete Calendar event $eventId: provider identity changed after preview.');
    }
    if (existing.etag == null || existing.etag != expectedEtag) {
      throw StateError('Calendar event $eventId changed after preview; refusing stale delete.');
    }

    final request = http.Request('DELETE', _eventUri(calendarId, eventId))
      ..headers.addAll({'If-Match': expectedEtag});
    final response = await _send(request);
    if (response.statusCode == 404 || response.statusCode == 410) return;
    if (response.statusCode == 412) {
      throw StateError('Calendar event $eventId failed the ETag precondition; refusing stale delete.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Conditional Calendar delete failed with HTTP ${response.statusCode}.');
    }
  }

  Future<calendar.Event?> _readEvent(String calendarId, String eventId) async {
    final request = http.Request('GET', _eventUri(calendarId, eventId));
    final response = await _send(request);
    if (response.statusCode == 404 || response.statusCode == 410) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Calendar event lookup failed with HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const FormatException('Calendar event response is invalid.');
    return calendar.Event.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<http.Response> _send(http.Request request) async =>
      http.Response.fromStream(await _client.send(request)).timeout(requestTimeout);

  Uri _eventUri(String calendarId, String eventId) => Uri.parse(
    'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(calendarId)}/events/${Uri.encodeComponent(eventId)}',
  );

  calendar.Event _mergeManagedFields(
    calendar.Event existing,
    CalendarSyncCommand command,
    String eventId,
  ) {
    final desired = _toEvent(command);
    final privateProperties = Map<String, String>.from(
      existing.extendedProperties?.private ?? const <String, String>{},
    )..[syncIdKey] = command.syncId;
    existing
      ..id = eventId
      ..summary = desired.summary
      ..description = _preserveTimelineSection(
        desiredDescription: desired.description,
        existingDescription: existing.description,
      )
      ..colorId = desired.colorId
      ..start = desired.start
      ..end = desired.end
      ..extendedProperties = calendar.EventExtendedProperties(
        private: privateProperties,
        shared: existing.extendedProperties?.shared,
      );
    return existing;
  }


  String? _normalizeManagedDescription(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;

    const marker = '--- Timeline ---';
    final markerIndex = normalized.indexOf(marker);
    final rosterDescription = markerIndex < 0
        ? normalized
        : normalized.substring(0, markerIndex).trimRight();
    return rosterDescription.isEmpty ? null : rosterDescription;
  }

  String? _preserveTimelineSection({
    required String? desiredDescription,
    required String? existingDescription,
  }) {
    const marker = '--- Timeline ---';
    final existing = existingDescription?.trimRight() ?? '';
    final markerIndex = existing.indexOf(marker);
    if (markerIndex < 0) return desiredDescription;

    final desired = desiredDescription?.trimRight();
    final desiredMarkerIndex = desired?.indexOf(marker) ?? -1;
    final baseDescription = desired == null || desired.isEmpty
        ? existing.substring(0, markerIndex).trimRight()
        : desiredMarkerIndex < 0
        ? desired
        : desired.substring(0, desiredMarkerIndex).trimRight();
    final timelineSection = existing.substring(markerIndex).trimRight();
    return baseDescription.isEmpty
        ? timelineSection
        : '$baseDescription\\n\\n$timelineSection';
  }

  bool _matchesExpectedProviderIdentity(calendar.Event event, String? expectedSyncId) =>
      _managedSyncId(event) == expectedSyncId;

  bool _matchesCommand(calendar.Event event, CalendarSyncCommand command) {
    final start = event.start?.dateTime;
    final end = event.end?.dateTime;
    return _managedSyncId(event) == command.syncId &&
        event.summary == command.title &&
        _normalizeManagedDescription(event.description) == command.description &&
        event.colorId == command.colorId &&
        start != null && end != null &&
        _bangkokWallTime(start) == command.start &&
        _bangkokWallTime(end) == command.end;
  }

  String _providerEventId(String syncId) {
    final digest = sha256.convert(utf8.encode(syncId));
    return 'sce${digest.toString()}';
  }

  calendar.Event _toEvent(CalendarSyncCommand command) {
    return calendar.Event(
      summary: command.title,
      description: command.description,
      colorId: command.colorId,
      start: calendar.EventDateTime(
        dateTime: _bangkokInstant(command.start),
        timeZone: timeZone,
      ),
      end: calendar.EventDateTime(
        dateTime: _bangkokInstant(command.end),
        timeZone: timeZone,
      ),
      extendedProperties: calendar.EventExtendedProperties(
        private: <String, String>{syncIdKey: command.syncId},
      ),
    );
  }

  ManagedCalendarEvent _toManaged(calendar.Event event, String fallbackSyncId) {
    return ManagedCalendarEvent(
      eventId: event.id ?? '',
      syncId: event.extendedProperties?.private?[syncIdKey] ?? fallbackSyncId,
      title: event.summary ?? '',
      start: event.start?.dateTime == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : _bangkokWallTime(event.start!.dateTime!),
      end: event.end?.dateTime == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : _bangkokWallTime(event.end!.dateTime!),
      description: _normalizeManagedDescription(event.description),
      colorId: event.colorId,
      etag: event.etag,
      providerSyncId: _managedSyncId(event),
    );
  }

  /// Calendar candidates use Bangkok wall-clock values throughout the domain.
  /// Convert explicitly instead of depending on the browser or host timezone.
  static DateTime _bangkokWallTime(DateTime instant) {
    final bangkok = instant.toUtc().add(_bangkokOffset);
    return DateTime(
      bangkok.year,
      bangkok.month,
      bangkok.day,
      bangkok.hour,
      bangkok.minute,
      bangkok.second,
      bangkok.millisecond,
      bangkok.microsecond,
    );
  }

  static DateTime _bangkokInstant(DateTime wallTime) => DateTime.utc(
    wallTime.year,
    wallTime.month,
    wallTime.day,
    wallTime.hour,
    wallTime.minute,
    wallTime.second,
    wallTime.millisecond,
    wallTime.microsecond,
  ).subtract(_bangkokOffset);
}
