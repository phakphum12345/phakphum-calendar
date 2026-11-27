import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/result/result.dart';
import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/schedule_month.dart';
import '../../../domain/repositories/schedule_repository.dart';
import '../../../domain/repositories/conditional_schedule_writer.dart';
import '../../../domain/repositories/conditional_schedule_deleter.dart';
import '../../../domain/repositories/schedule_revision_source.dart';
import 'schedule_json_codec.dart';

/// Minimal storage boundary required by the canonical schedule repository.
abstract interface class ScheduleKeyValueStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// Optional capability for stores that can enumerate their own keys.
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
/// Conditional writes are serialized within this application process and
/// compare a persisted generation + payload fingerprint. This prevents stale
/// editors from overwriting newer local writes, including ABA changes. It is
/// not a cross-process or cross-device lock; shared multi-device writes must
/// use BackendScheduleRepository and its server-enforced CAS contract.
class SharedPreferencesScheduleRepository
    implements
        ScheduleRepository,
        ScheduleRevisionSource,
        ConditionalScheduleWriter,
        ConditionalScheduleDeleter {
  SharedPreferencesScheduleRepository({
    ScheduleKeyValueStore? store,
    this.codec = const ScheduleJsonCodec(),
  }) : _store = store ?? SharedPreferencesScheduleKeyValueStore();

  static const storageKeyPrefix = 'shift_tools.canonical_schedule.v1.';

  final ScheduleKeyValueStore _store;
  final ScheduleJsonCodec codec;
  final Map<String, String> _revisions = {};
  final Map<String, String> _absentRevisions = {};
  final Map<Schedule, String> _snapshotRevisions =
      Map<Schedule, String>.identity();

  // A static lock coordinates repository instances in this Dart isolate that
  // share the same app-level SharedPreferences namespace.
  static final Map<String, Future<void>> _writeLocks = {};

  String _baseKey(String id) =>
      '$storageKeyPrefix${base64Url.encode(utf8.encode(id)).replaceAll('=', '')}';

  String _activeKey(String id) => '${_baseKey(id)}.active';
  String _generationKey(String id) => '${_baseKey(id)}.generation';
  String _slotKey(String id, String slot) => '${_baseKey(id)}.slot.$slot';

  @override
  String? currentRevisionFor(String scheduleId) => _revisions[scheduleId];

  @override
  String? revisionForSnapshot(Schedule schedule) =>
      _snapshotRevisions[schedule];

  @override
  String? revisionForAbsentSchedule(String scheduleId) =>
      _absentRevisions[scheduleId];

  Future<T> _withScheduleLock<T>(
    String scheduleId,
    Future<T> Function() action,
  ) async {
    final key = _activeKey(scheduleId);
    final previous = _writeLocks[key] ?? Future<void>.value();
    final release = Completer<void>();
    final queued = release.future;
    _writeLocks[key] = queued;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
      if (identical(_writeLocks[key], queued)) {
        _writeLocks.remove(key);
      }
    }
  }

  Future<_StoredScheduleState> _readState(String id) async {
    final rawGeneration = await _store.getString(_generationKey(id));
    final generation = rawGeneration == null ? 0 : int.tryParse(rawGeneration);
    if (generation == null || generation < 0) {
      throw FormatException('Stored schedule "$id" has an invalid generation.');
    }

    final activeSlot = await _store.getString(_activeKey(id));
    if (activeSlot == null) {
      return _StoredScheduleState(
        schedule: null,
        activeSlot: null,
        generation: generation,
        revision: 'absent:$generation',
      );
    }
    if (activeSlot != 'a' && activeSlot != 'b') {
      throw FormatException('Stored schedule "$id" has an invalid active slot.');
    }

    final payload = await _store.getString(_slotKey(id, activeSlot));
    if (payload == null) {
      throw FormatException('Stored schedule "$id" is missing its active payload.');
    }
    final decoded = jsonDecode(payload);
    if (decoded is Map &&
        decoded['format'] == 'shift-tools.schedule-tombstone' &&
        decoded['version'] == 1 &&
        decoded['state'] == 'deleted' &&
        decoded['generation'] == generation) {
      return _StoredScheduleState(
        schedule: null,
        activeSlot: activeSlot,
        generation: generation,
        revision: _deletedRevision(generation),
        isDeleted: true,
        deletedFromRevision: decoded['deleted_from_revision'] is String
            ? decoded['deleted_from_revision'] as String
            : null,
      );
    }
    final schedule = codec.decode(payload);
    if (schedule.id != id) {
      throw FormatException(
        'Stored schedule identity "${schedule.id}" does not match "$id".',
      );
    }
    return _StoredScheduleState(
      schedule: schedule,
      activeSlot: activeSlot,
      generation: generation,
      revision: _liveRevision(generation, payload),
    );
  }

  String _liveRevision(int generation, String payload) =>
      'v$generation:${sha256.convert(utf8.encode(payload))}';

  String _deletedRevision(int generation) =>
      'v$generation:${List.filled(64, '0').join()}';

  void _rememberState(String id, _StoredScheduleState state) {
    _revisions[id] = state.revision;
    if (state.schedule == null) {
      if (state.isDeleted) {
        _absentRevisions.remove(id);
      } else {
        _absentRevisions[id] = state.revision;
      }
      return;
    }
    _absentRevisions.remove(id);
    _rememberSnapshot(state.schedule!, state.revision);
  }

  void _rememberSnapshot(Schedule schedule, String revision) {
    if (!_snapshotRevisions.containsKey(schedule) &&
        _snapshotRevisions.length >= 256) {
      _snapshotRevisions.remove(_snapshotRevisions.keys.first);
    }
    _snapshotRevisions[schedule] = revision;
  }

  @override
  Future<Result<Schedule?>> findById(String id) {
    return _withScheduleLock(id, () async {
      try {
        final state = await _readState(id);
        _rememberState(id, state);
        return Success(state.schedule);
      } on ScheduleCodecException catch (error, stackTrace) {
        return ValidationFailure(
          error.message,
          cause: error,
          stackTrace: stackTrace,
        );
      } on FormatException catch (error, stackTrace) {
        return ValidationFailure(
          'Stored schedule "$id" is malformed.',
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
    });
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
  Future<Result<Schedule>> save(Schedule schedule) {
    final expectedRevision = _snapshotRevisions[schedule];
    if (expectedRevision == null) {
      return Future.value(
        const PersistenceFailure(
          'Cannot save a Schedule without the exact revision captured for this snapshot.',
        ),
      );
    }
    return saveIfRevision(schedule, expectedRevision);
  }

  @override
  Future<Result<Schedule>> saveIfRevision(
    Schedule schedule,
    String expectedRevision,
  ) {
    if (expectedRevision.trim().isEmpty) {
      return Future.value(
        const ValidationFailure('An expected Schedule revision is required.'),
      );
    }
    return _withScheduleLock(schedule.id, () async {
      try {
        final current = await _readState(schedule.id);
        if (current.revision != expectedRevision) {
          _rememberState(schedule.id, current);
          return const ValidationFailure(
            'Schedule revision conflict. Reload the latest Schedule before saving.',
          );
        }
        return await _writeNext(schedule, current);
      } on ScheduleCodecException catch (error, stackTrace) {
        return ValidationFailure(
          error.message,
          cause: error,
          stackTrace: stackTrace,
        );
      } on FormatException catch (error, stackTrace) {
        return ValidationFailure(
          error.message,
          cause: error,
          stackTrace: stackTrace,
        );
      } on Object catch (error, stackTrace) {
        return PersistenceFailure(
          'Could not conditionally save schedule "${schedule.id}".',
          cause: error,
          stackTrace: stackTrace,
        );
      }
    });
  }

  Future<Result<Schedule>> _writeNext(
    Schedule schedule,
    _StoredScheduleState current,
  ) async {
    if (current.isDeleted) {
      return const PersistenceFailure(
        'A deleted Schedule cannot be recreated by a stale save. Create a new Schedule identity or use an explicit restore workflow.',
      );
    }
    final payload = codec.encode(schedule);
    final targetSlot = current.activeSlot == 'a' ? 'b' : 'a';
    final targetKey = _slotKey(schedule.id, targetSlot);

    await _store.setString(targetKey, payload);
    final stagedPayload = await _store.getString(targetKey);
    if (stagedPayload == null) {
      return const PersistenceFailure(
        'The staged schedule payload could not be read back.',
      );
    }
    final stagedSchedule = codec.decode(stagedPayload);
    if (stagedSchedule.id != schedule.id) {
      return ValidationFailure(
        'The staged schedule identity does not match "${schedule.id}".',
      );
    }

    final nextGeneration = current.generation + 1;
    // Advance the generation before switching the active pointer. A crash
    // between these writes invalidates stale editors but leaves the prior
    // active payload recoverable.
    await _store.setString(
      _generationKey(schedule.id),
      nextGeneration.toString(),
    );
    await _store.setString(_activeKey(schedule.id), targetSlot);

    final revision = _liveRevision(nextGeneration, stagedPayload);
    final state = _StoredScheduleState(
      schedule: stagedSchedule,
      activeSlot: targetSlot,
      generation: nextGeneration,
      revision: revision,
    );
    _rememberState(schedule.id, state);
    return Success(stagedSchedule);
  }

  @override
  Future<Result<void>> delete(String id) async => const PersistenceFailure(
    'Unconditional Schedule deletion is disabled. Supply the revision from the exact snapshot being deleted.',
  );

  @override
  Future<Result<void>> deleteIfRevision(
    String id,
    String expectedRevision,
  ) {
    if (expectedRevision.trim().isEmpty) {
      return Future.value(
        const ValidationFailure('An expected Schedule revision is required.'),
      );
    }
    return _withScheduleLock(id, () async {
      try {
        final current = await _readState(id);
        if (current.isDeleted) {
          if (expectedRevision == current.revision ||
              expectedRevision == current.deletedFromRevision) {
            _rememberState(id, current);
            return const Success(null);
          }
          _rememberState(id, current);
          return const ValidationFailure(
            'Schedule revision conflict. Reload the latest Schedule before deleting.',
          );
        }
        if (current.revision != expectedRevision) {
          _rememberState(id, current);
          return const ValidationFailure(
            'Schedule revision conflict. Reload the latest Schedule before deleting.',
          );
        }

        final nextGeneration = current.generation + 1;
        final targetSlot = current.activeSlot == 'a' ? 'b' : 'a';
        final tombstone = jsonEncode({
          'format': 'shift-tools.schedule-tombstone',
          'version': 1,
          'state': 'deleted',
          'generation': nextGeneration,
          'deleted_from_revision': expectedRevision,
        });
        final targetKey = _slotKey(id, targetSlot);
        await _store.setString(targetKey, tombstone);
        final staged = await _store.getString(targetKey);
        if (staged != tombstone) {
          return const PersistenceFailure(
            'The Schedule tombstone could not be read back.',
          );
        }

        // Invalidate old revisions before switching the active slot. A crash
        // here leaves the old payload readable but makes stale writers fail.
        await _store.setString(
          _generationKey(id),
          nextGeneration.toString(),
        );
        await _store.setString(_activeKey(id), targetSlot);
        final verified = await _readState(id);
        if (!verified.isDeleted ||
            verified.generation != nextGeneration ||
            verified.revision != _deletedRevision(nextGeneration) ||
            verified.deletedFromRevision != expectedRevision) {
          return const PersistenceFailure(
            'Schedule tombstone read-back verification failed.',
          );
        }
        _rememberState(id, verified);
        return const Success(null);
      } on Object catch (error, stackTrace) {
        return PersistenceFailure(
          'Could not conditionally delete Schedule "$id".',
          cause: error,
          stackTrace: stackTrace,
        );
      }
    });
  }
}

class _StoredScheduleState {
  const _StoredScheduleState({
    required this.schedule,
    required this.activeSlot,
    required this.generation,
    required this.revision,
    this.isDeleted = false,
    this.deletedFromRevision,
  });

  final Schedule? schedule;
  final String? activeSlot;
  final int generation;
  final String revision;
  final bool isDeleted;
  final String? deletedFromRevision;
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
