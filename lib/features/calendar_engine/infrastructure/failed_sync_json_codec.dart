import 'dart:convert';
import '../domain/calendar_sync_command.dart';
import '../domain/calendar_sync_operation_result.dart';
import '../domain/failed_sync_operation.dart';

class FailedSyncJsonCodec {
  const FailedSyncJsonCodec();

  String encode(List<FailedSyncOperation> values) => jsonEncode(
    values
        .map(
          (value) => <String, Object?>{
            'historyId': value.historyId,
            'type': value.type.name,
            'referenceId': value.referenceId,
            'attempts': value.attempts,
            'eventId': value.eventId,
            'calendarId': value.calendarId,
            'message': value.message,
            'expectedEtag': value.expectedEtag,
            'expectedSyncId': value.expectedSyncId,
            'command': value.command == null
                ? null
                : <String, Object?>{
                    'syncId': value.command!.syncId,
                    'title': value.command!.title,
                    'start': value.command!.start.toIso8601String(),
                    'end': value.command!.end.toIso8601String(),
                    'description': value.command!.description,
                    'colorId': value.command!.colorId,
                    'calendarId': value.command!.calendarId,
                  },
          },
        )
        .toList(growable: false),
  );

  List<FailedSyncOperation> decode(String? source) {
    if (source == null || source.trim().isEmpty) {
      return const <FailedSyncOperation>[];
    }
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('Failed-operation payload must be a list.');
    }
    return decoded
        .map((value) {
          final json = Map<String, Object?>.from(value as Map);
          final commandJson = json['command'] == null
              ? null
              : Map<String, Object?>.from(json['command'] as Map);
          final command = commandJson == null
              ? null
              : CalendarSyncCommand(
                  syncId: commandJson['syncId']! as String,
                  title: commandJson['title']! as String,
                  start: DateTime.parse(commandJson['start']! as String),
                  end: DateTime.parse(commandJson['end']! as String),
                  description: commandJson['description'] as String?,
                  colorId: commandJson['colorId'] as String?,
                  calendarId: commandJson['calendarId'] as String? ?? 'primary',
                );
          return FailedSyncOperation(
            historyId: json['historyId']! as String,
            type: CalendarSyncOperationType.values.byName(
              json['type']! as String,
            ),
            referenceId: json['referenceId']! as String,
            attempts: (json['attempts'] as num?)?.toInt() ?? 0,
            command: command,
            eventId: json['eventId'] as String?,
            calendarId: json['calendarId'] as String? ?? 'primary',
            message: json['message'] as String?,
            expectedEtag: json['expectedEtag'] as String?,
            expectedSyncId: json['expectedSyncId'] as String?,
          );
        })
        .toList(growable: false);
  }
}
