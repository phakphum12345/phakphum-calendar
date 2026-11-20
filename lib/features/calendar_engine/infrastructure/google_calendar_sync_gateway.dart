import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;

import '../domain/calendar_sync_command.dart';
import '../domain/calendar_sync_gateway.dart';
import '../domain/managed_calendar_event.dart';

class GoogleCalendarSyncGateway
    implements CalendarSyncGateway, ComparableCalendarEventGateway {
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
            description: event.description,
            colorId: event.colorId,
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
    final api = calendar.CalendarApi(_client);
    final updated = await api.events
        .update(
          _toEvent(command),
          command.calendarId,
          eventId,
        )
        .timeout(requestTimeout);

    return _toManaged(updated, command.syncId);
  }

  @override
  Future<void> delete({
    required String eventId,
    String calendarId = 'primary',
  }) async {
    final api = calendar.CalendarApi(_client);
    await api.events.delete(calendarId, eventId).timeout(requestTimeout);
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
      description: event.description,
      colorId: event.colorId,
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
