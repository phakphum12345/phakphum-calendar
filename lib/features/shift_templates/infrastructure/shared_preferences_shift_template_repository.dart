import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/result/result.dart';
import '../../../domain/entities/shift_template.dart';
import '../../../domain/repositories/shift_template_repository.dart';
import 'shift_template_json_codec.dart';

/// Production repository for versioned shift-template configuration.
class SharedPreferencesShiftTemplateRepository
    implements ShiftTemplateRepository {
  SharedPreferencesShiftTemplateRepository({
    SharedPreferencesAsync? preferences,
    this.codec = const ShiftTemplateJsonCodec(),
  }) {
    if (preferences != null) _preferences = preferences;
  }

  static const storageKey = 'shift_tools.shift_templates.v1';

  SharedPreferencesAsync? _preferences;
  final ShiftTemplateJsonCodec codec;

  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<Result<void>> delete(String id) async {
    final loaded = await _load();
    if (loaded case Failure<List<ShiftTemplate>>()) {
      return PersistenceFailure(loaded.message, cause: loaded);
    }
    final values = (loaded as Success<List<ShiftTemplate>>).value
        .where((template) => template.id != id)
        .toList();
    final saved = await _saveAll(values);
    return saved.isSuccess
        ? const Success(null)
        : PersistenceFailure((saved as Failure).message, cause: saved);
  }

  @override
  Future<Result<List<ShiftTemplate>>> findAll({bool activeOnly = true}) async {
    final loaded = await _load();
    return switch (loaded) {
      Success<List<ShiftTemplate>>(value: final values) => Success(
        List.unmodifiable(
          values.where((template) => !activeOnly || template.active),
        ),
      ),
      Failure<List<ShiftTemplate>>() => loaded,
    };
  }

  @override
  Future<Result<ShiftTemplate?>> findById(String id) async {
    final loaded = await _load();
    return switch (loaded) {
      Success<List<ShiftTemplate>>(value: final values) => Success(
        values.where((template) => template.id == id).firstOrNull,
      ),
      Failure<List<ShiftTemplate>>() => PersistenceFailure(
        loaded.message,
        cause: loaded,
      ),
    };
  }

  @override
  Future<Result<ShiftTemplate>> save(ShiftTemplate template) async {
    if (template.id.trim().isEmpty ||
        template.code.trim().isEmpty ||
        template.name.trim().isEmpty) {
      return const ValidationFailure('Shift template data is incomplete.');
    }
    final loaded = await _load();
    if (loaded case Failure<List<ShiftTemplate>>()) {
      return PersistenceFailure(loaded.message, cause: loaded);
    }
    final values = List<ShiftTemplate>.of(
      (loaded as Success<List<ShiftTemplate>>).value,
    );
    final normalizedLocation = _normalizeLocation(template.location);
    if (values.any(
      (item) =>
          item.id != template.id &&
          _normalizeLocation(item.location) == normalizedLocation &&
          item.code.trim().toLowerCase() ==
              template.code.trim().toLowerCase(),
    )) {
      return ValidationFailure(
        'Shift code "${template.code}" is already in use.',
      );
    }
    final index = values.indexWhere((item) => item.id == template.id);
    if (index == -1) {
      values.add(template);
    } else {
      values[index] = template;
    }
    final saved = await _saveAll(values);
    return saved.isSuccess
        ? Success(template)
        : PersistenceFailure((saved as Failure).message, cause: saved);
  }

  String _normalizeLocation(String? value) =>
      value?.trim().toLowerCase() ?? '';

  Future<Result<List<ShiftTemplate>>> _load() async {
    try {
      final payload = await _store.getString(storageKey);
      return Success(payload == null ? const [] : codec.decode(payload));
    } on ShiftTemplateCodecException catch (error, stackTrace) {
      return ValidationFailure(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      return PersistenceFailure(
        'Could not load shift templates.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Result<List<ShiftTemplate>>> _saveAll(
    List<ShiftTemplate> values,
  ) async {
    try {
      await _store.setString(storageKey, codec.encode(values));
      final payload = await _store.getString(storageKey);
      if (payload == null) {
        return const PersistenceFailure(
          'The saved shift-template payload could not be read back.',
        );
      }
      return Success(codec.decode(payload));
    } on ShiftTemplateCodecException catch (error, stackTrace) {
      return ValidationFailure(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      return PersistenceFailure(
        'Could not save shift templates.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
