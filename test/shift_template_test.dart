import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/shift_template.dart';
import 'package:phakphum_calendar/domain/repositories/shift_template_repository.dart';
import 'package:phakphum_calendar/features/shift_templates/application/shift_template_controller.dart';
import 'package:phakphum_calendar/features/shift_templates/infrastructure/shift_template_json_codec.dart';

void main() {
  const template = ShiftTemplate(
    id: 'night',
    code: 'N',
    name: 'เวรดึก',
    shortName: 'ดึก',
    description: 'Night duty',
    startTime: Duration(hours: 20),
    endTime: Duration(hours: 8),
    color: 0xFF4527A0,
    workingHours: 12,
    location: 'CT',
    defaultCalendarId: 'calendar-1',
    reminderMinutes: 30,
    rate: 900,
    sortOrder: 2,
  );

  test('shift-template codec round-trips all configurable fields', () {
    const codec = ShiftTemplateJsonCodec();

    final decoded = codec.decode(codec.encode(const [template])).single;

    expect(decoded.id, template.id);
    expect(decoded.code, template.code);
    expect(decoded.name, template.name);
    expect(decoded.shortName, template.shortName);
    expect(decoded.description, template.description);
    expect(decoded.startTime, template.startTime);
    expect(decoded.endTime, template.endTime);
    expect(decoded.color, template.color);
    expect(decoded.workingHours, template.workingHours);
    expect(decoded.location, template.location);
    expect(decoded.defaultCalendarId, template.defaultCalendarId);
    expect(decoded.reminderMinutes, template.reminderMinutes);
    expect(decoded.rate, template.rate);
    expect(decoded.sortOrder, template.sortOrder);
  });

  test('shift-template codec rejects unsupported versions', () {
    const codec = ShiftTemplateJsonCodec();

    expect(
      () => codec.decode('{"formatVersion":2,"templates":[]}'),
      throwsA(isA<ShiftTemplateCodecException>()),
    );
  });

  test(
    'controller seeds editable defaults only for an empty repository',
    () async {
      final repository = _MemoryShiftTemplateRepository();
      final controller = ShiftTemplateController(repository: repository);
      addTearDown(controller.dispose);

      await controller.load();
      final seededIds = controller.templates.map((value) => value.id).toList();
      await controller.load();

      expect(seededIds, [
        'shift:morning',
        'shift:day',
        'shift:evening',
        'shift:night',
      ]);
      expect(
        controller.templates.map((value) => value.code),
        ['ช', 'พัก', 'บ', 'ด'],
      );
      expect(
        controller.templates.map((value) => value.shortName),
        ['ช', 'พัก', 'บ', 'ด'],
      );
      expect(controller.templates.map((value) => value.id), seededIds);
      expect(repository.values, hasLength(4));
      final lunchBreak = controller.templates.singleWhere(
        (value) => value.id == 'shift:day',
      );
      expect(lunchBreak.name, 'ช่วงพักกลางวัน');
      expect(lunchBreak.startTime, const Duration(hours: 12));
      expect(lunchBreak.endTime, const Duration(hours: 13));
      expect(lunchBreak.workingHours, 0);
      expect(lunchBreak.rate, 0);
    },
  );

  test('template converts to a canonical shift type', () {
    final shift = template.toShiftType();

    expect(shift.id, template.id);
    expect(shift.code, template.code);
    expect(shift.startTime, template.startTime);
    expect(shift.endTime, template.endTime);
    expect(shift.workingHours, template.workingHours);
  });
}

class _MemoryShiftTemplateRepository implements ShiftTemplateRepository {
  final values = <String, ShiftTemplate>{};

  @override
  Future<Result<void>> delete(String id) async {
    values.remove(id);
    return const Success(null);
  }

  @override
  Future<Result<List<ShiftTemplate>>> findAll({bool activeOnly = true}) async {
    return Success(
      values.values
          .where((value) => !activeOnly || value.active)
          .toList(growable: false),
    );
  }

  @override
  Future<Result<ShiftTemplate?>> findById(String id) async =>
      Success(values[id]);

  @override
  Future<Result<ShiftTemplate>> save(ShiftTemplate template) async {
    values[template.id] = template;
    return Success(template);
  }
}
