import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/result/result.dart';
import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/schedule_month.dart';
import '../../../domain/repositories/schedule_repository.dart';
import 'schedule_json_codec.dart';

/// Minimal storage boundary required by the canonical schedule repository.
abstract interface class ScheduleKeyValueStore {
  /// Reads one string value.
  Future<String?> getString(String key);

  /// Writes one string value.
  Future<void> setString(String key, String value);

  /// Removes one value.
  Future<void> remove(String key);
}

/// Optional capability for stores that can enumerate their own keys.
///
/// Implementations must return keys from the same logical namespace used by
/// [ScheduleKeyValueStore]. Callers must still filter by their reserved prefix.
abstract interface class ScheduleKeyEnumerator {
  Future<Set<String>> getKeys();
}

/// SharedPreferences-backed production schedule key-value store.
class SharedPreferencesScheduleKeyValueStore
    implements ScheduleKeyValueStore, ScheduleKeyEnumerator {
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _instance =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<Set<String>> getKeys() => _instance.getKeys();

  @override
  Future<String?> getString(String key) => _instance.getString(key);

  @override
  Future<void> remove(String key) => _instance.remove(key);

  @override
  Future<void> setString(String key, String value) =>
      _instance.setString(key, value);
}

/// Persists canonical schedules in two alternating SharedPreferences slots.
///
/// A payload is written and decoded from the inactive slot before the active
/// pointer changes. A failed write therefore leaves the last active payload
/// available.
class SharedPreferencesScheduleRepository implements ScheduleRepository {
  /// Creates the production canonical schedule repository.
  SharedPreferencesScheduleRepository({
    ScheduleKeyValueStore? store,
    this.codec = const ScheduleJsonCodec(),
  }) : _store = store ?? SharedPreferencesScheduleKeyValueStore();

  /// Prefix reserved exclusively for canonical schedule schema version 1.
  static const storageKeyPrefix = 'shift_tools.canonical_schedule.v1.';

  final ScheduleKeyValueStore _store;

  /// Codec used for durable payloads.
  final ScheduleJsonCodec codec;

  String _baseKey(String id) =>
      '$storageKeyPrefix${base64Url.encode(utf8.encode(id)).replaceAll('=', '')}';

  String _activeKey(String id) => '${_baseKey(id)}.active';
  String _slotKey(String id, String slot) => '${_baseKey(id)}.slot.$slot';

  @override
  Future<Result<Schedule?>> findById(String id) async {
    try {
      final activeSlot = await _store.getString(_activeKey(id));
      if (activeSlot == null) {
        return const Success(null);
      }
      if (activeSlot != 'a' && activeSlot != 'b') {
        return ValidationFailure(
          'Stored schedule "$id" has an invalid active slot.',
        );
      }
      final payload = await _store.getString(_slotKey(id, activeSlot));
      if (payload == null) {
        return ValidationFailure(
          'Stored schedule "$id" is missing its active payload.',
        );
      }
      final schedule = codec.decode(payload);
      if (schedule.id != id) {
        return ValidationFailure(
          'Stored schedule identity "${schedule.id}" does not match "$id".',
        );
      }
      return Success(schedule);
    } on ScheduleCodecException catch (error, stackTrace) {
      return ValidationFailure(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      return ValidationFailure(
        'Stored schedule "$id" contains malformed JSON.',
        cause: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      return PersistenceFailure(
        'Could not load schedule "$id".',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<ScheduleMonth?>> loadMonth(
    String scheduleId,
    DateTime month,
  ) async {
    final result = await findById(scheduleId);
    return switch (result) {
      Success<Schedule?>(value: final schedule) => Success(
        schedule?.month(month),
      ),
      Failure<Schedule?>() => _copyFailure<Schedule?, ScheduleMonth?>(result),
    };
  }

  @override
  Future<Result<Schedule>> save(Schedule schedule) async {
    late final String payload;
    try {
      payload = codec.encode(schedule);
    } on ScheduleCodecException catch (error, stackTrace) {
      return ValidationFailure(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    final activeKey = _activeKey(schedule.id);
    try {
      final currentSlot = await _store.getString(activeKey);
      if (currentSlot != null && currentSlot != 'a' && currentSlot != 'b') {
        return ValidationFailure(
          'Stored schedule "${schedule.id}" has an invalid active slot.',
        );
      }
      final targetSlot = currentSlot == 'a' ? 'b' : 'a';
      final targetKey = _slotKey(schedule.id, targetSlot);

      await _store.setString(targetKey, payload);
      final stagedPayload = await _store.getString(targetKey);
      if (stagedPayload == null) {
        return PersistenceFailure(
          'The staged schedule payload could not be read back.',
        );
      }
      final stagedSchedule = codec.decode(stagedPayload);
      if (stagedSchedule.id != schedule.id) {
        return ValidationFailure(
          'The staged schedule identity does not match "${schedule.id}".',
        );
      }

      await _store.setString(activeKey, targetSlot);
      return Success(stagedSchedule);
    } on ScheduleCodecException catch (error, stackTrace) {
      return ValidationFailure(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      return ValidationFailure(
        'The staged schedule payload contains malformed JSON.',
        cause: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      return PersistenceFailure(
        'Could not save schedule "${schedule.id}".',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _store.remove(_activeKey(id));
      await _store.remove(_slotKey(id, 'a'));
      await _store.remove(_slotKey(id, 'b'));
      return const Success(null);
    } on Object catch (error, stackTrace) {
      return PersistenceFailure(
        'Could not delete schedule "$id".',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}

Result<TTarget> _copyFailure<TSource, TTarget>(Result<TSource> result) {
  final failure = result as Failure<TSource>;
  return switch (failure) {
    ValidationFailure<TSource>() => ValidationFailure(
      failure.message,
      fieldErrors: failure.fieldErrors,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
    NetworkFailure<TSource>() => NetworkFailure(
      failure.message,
      statusCode: failure.statusCode,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
    ImportFailure<TSource>() => ImportFailure(
      failure.message,
      rowNumber: failure.rowNumber,
      column: failure.column,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
    PersistenceFailure<TSource>() => PersistenceFailure(
      failure.message,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
  };
}
