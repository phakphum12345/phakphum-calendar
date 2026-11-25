import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/entities/shift_template.dart';
import 'package:phakphum_calendar/features/shift_parser/application/monthly_roster_section_parser.dart';

void main() {
  const adapter = MonthlyRosterShiftAdapter();

  test('identifies an exact active template and exposes its canonical ID', () {
    final result = adapter.resolveRuleForLabel(
      'NIGHT',
      shiftTemplates: [_template(id: 'night-template', code: 'NIGHT')],
    );

    expect(result.status, MonthlyRosterShiftRuleStatus.configuredTemplate);
    expect(result.isResolved, isTrue);
    expect(result.templateId, 'night-template');
    expect(result.code, 'NIGHT');
    expect(result.startTime, const Duration(hours: 20));
    expect(result.endTime, const Duration(hours: 8));
    expect(result.requiresHumanConfirmation, isTrue);
    expect(result.canCommit, isFalse);
  });

  test('does not choose between active templates sharing an alias', () {
    final result = adapter.resolveRuleForLabel(
      'NIGHT',
      shiftTemplates: [
        _template(id: 'night-a', code: 'NIGHT', name: 'Night A'),
        _template(id: 'night-b', code: 'NIGHT', name: 'Night B'),
      ],
    );

    expect(result.status, MonthlyRosterShiftRuleStatus.ambiguousTemplate);
    expect(result.isResolved, isFalse);
    expect(result.templateId, isNull);
    expect(result.canCommit, isFalse);
  });

  test('identifies legacy built-in mapping without calling it a template', () {
    final result = adapter.resolveRuleForLabel('P1 เช้า');

    expect(result.status, MonthlyRosterShiftRuleStatus.builtInRule);
    expect(result.isResolved, isTrue);
    expect(result.templateId, isNull);
    expect(result.code, 'UP1');
    expect(result.startTime, const Duration(hours: 8));
    expect(result.endTime, const Duration(hours: 16));
  });

  test('keeps unsupported labels visible', () {
    final result = adapter.resolveRuleForLabel('เวรพิเศษที่ไม่รู้จัก');

    expect(result.status, MonthlyRosterShiftRuleStatus.unsupportedLabel);
    expect(result.isResolved, isFalse);
    expect(result.code, isNull);
  });

  test('reports an empty label explicitly', () {
    final result = adapter.resolveRuleForLabel('   ');

    expect(result.status, MonthlyRosterShiftRuleStatus.emptyLabel);
    expect(result.isResolved, isFalse);
  });

  test('does not use inactive templates as configured mappings', () {
    final result = adapter.resolveRuleForLabel(
      'NIGHT',
      shiftTemplates: [
        _template(id: 'night-template', code: 'NIGHT', active: false),
      ],
    );

    expect(result.status, MonthlyRosterShiftRuleStatus.unsupportedLabel);
  });
}

ShiftTemplate _template({
  required String id,
  required String code,
  String? name,
  bool active = true,
}) {
  return ShiftTemplate(
    id: id,
    code: code,
    name: name ?? code,
    shortName: code,
    startTime: const Duration(hours: 20),
    endTime: const Duration(hours: 8),
    color: 0xFF123456,
    workingHours: 12,
    active: active,
  );
}
