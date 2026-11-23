import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/entities/shift_template.dart';
import '../../../l10n/l10n.dart';
import '../application/shift_template_controller.dart';

/// Material 3 editor for persistent shift templates.
class ShiftTemplatesPage extends StatefulWidget {
  const ShiftTemplatesPage({required this.controllerFactory, super.key});

  final ShiftTemplateController Function() controllerFactory;

  @override
  State<ShiftTemplatesPage> createState() => _ShiftTemplatesPageState();
}

class _ShiftTemplatesPageState extends State<ShiftTemplatesPage> {
  late final controller = widget.controllerFactory();

  @override
  void initState() {
    super.initState();
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(context.l10n.shiftTemplates)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.loading ? null : () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.addShiftTemplate),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(context.l10n.shiftTemplatesDescription),
          if (controller.loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (controller.error case final error?) ...[
            const SizedBox(height: 12),
            MaterialBanner(
              content: Text(error),
              actions: [
                TextButton(
                  onPressed: controller.load,
                  child: Text(context.l10n.retry),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          for (final template in controller.templates)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(template.color),
                    child: Text(template.code),
                  ),
                  title: Text(template.name),
                  subtitle: Text(
                    '${_time(template.startTime)}–${_time(template.endTime)}'
                    '${template.overnight ? ' • ${context.l10n.overnight}' : ''}'
                    ' • ${_hours(template.workingHours)} h'
                    '${template.location?.trim().isNotEmpty == true ? ' • ${template.location}' : ''}',
                  ),
                  trailing: PopupMenuButton<_TemplateAction>(
                    onSelected: (action) {
                      if (action == _TemplateAction.edit) {
                        unawaited(_edit(template));
                      } else {
                        unawaited(controller.deactivate(template));
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _TemplateAction.edit,
                        child: Text(context.l10n.edit),
                      ),
                      if (template.active)
                        PopupMenuItem(
                          value: _TemplateAction.deactivate,
                          child: Text(context.l10n.deactivate),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> _edit([ShiftTemplate? template]) async {
    final value = await showDialog<ShiftTemplate>(
      context: context,
      builder: (context) => _ShiftTemplateDialog(
        template: template,
        nextOrder: controller.templates.length,
      ),
    );
    if (value != null) await controller.save(value);
  }

  String _time(Duration value) {
    final hours = value.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  String _hours(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}

enum _TemplateAction { edit, deactivate }

class _ShiftTemplateDialog extends StatefulWidget {
  const _ShiftTemplateDialog({this.template, required this.nextOrder});

  final ShiftTemplate? template;
  final int nextOrder;

  @override
  State<_ShiftTemplateDialog> createState() => _ShiftTemplateDialogState();
}

class _ShiftTemplateDialogState extends State<_ShiftTemplateDialog> {
  final formKey = GlobalKey<FormState>();
  late final code = TextEditingController(text: widget.template?.code ?? '');
  late final name = TextEditingController(text: widget.template?.name ?? '');
  late final shortName = TextEditingController(
    text: widget.template?.shortName ?? '',
  );
  late final location = TextEditingController(
    text: widget.template?.location ?? '',
  );
  late final workingHours = TextEditingController(
    text: '${widget.template?.workingHours ?? 8}',
  );
  late final rate = TextEditingController(
    text: '${widget.template?.rate ?? 0}',
  );
  late TimeOfDay start = _timeOfDay(
    widget.template?.startTime ?? const Duration(hours: 8),
  );
  late TimeOfDay end = _timeOfDay(
    widget.template?.endTime ?? const Duration(hours: 16),
  );
  late int color = widget.template?.color ?? 0xFF039BE5;

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    shortName.dispose();
    location.dispose();
    workingHours.dispose();
    rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.template == null
          ? context.l10n.addShiftTemplate
          : context.l10n.editShiftTemplate,
    ),
    content: SizedBox(
      width: 520,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _requiredField(code, context.l10n.shiftCode),
              const SizedBox(height: 12),
              _requiredField(name, context.l10n.shiftName),
              const SizedBox(height: 12),
              _requiredField(shortName, context.l10n.shortName),
              const SizedBox(height: 12),
              TextFormField(
                controller: location,
                decoration: const InputDecoration(
                  labelText: 'สถานที่ / หน่วยงาน (ไม่บังคับ)',
                  helperText: 'ตั้งชื่อเวรและรหัสแยกตามสถานที่ได้',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(true),
                      child: Text(
                        '${context.l10n.startTime}: ${start.format(context)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(false),
                      child: Text(
                        '${context.l10n.endTime}: ${end.format(context)}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: workingHours,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.workingHours,
                ),
                validator: _nonNegativeNumber,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: rate,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.l10n.shiftRate),
                validator: _nonNegativeNumber,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(onPressed: _submit, child: Text(context.l10n.save)),
    ],
  );

  TextFormField _requiredField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: '$label *',
        helperText: label == context.l10n.shiftCode
            ? 'ใช้รหัสไทย อังกฤษ หรือกำหนดเองได้'
            : null,
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? context.l10n.requiredField
          : null,
    );
  }

  String? _nonNegativeNumber(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || number < 0 ? context.l10n.invalidNumber : null;
  }

  Future<void> _pickTime(bool isStart) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? start : end,
    );
    if (selected == null) return;
    setState(() {
      if (isStart) {
        start = selected;
      } else {
        end = selected;
      }
    });
  }

  void _submit() {
    if (!formKey.currentState!.validate()) return;
    final normalizedCode = code.text.trim();
    Navigator.pop(
      context,
      ShiftTemplate(
        id: widget.template?.id ??
            'shift:${location.text.trim().toLowerCase()}:${normalizedCode.toLowerCase()}',
        code: normalizedCode,
        name: name.text.trim(),
        shortName: shortName.text.trim(),
        startTime: Duration(hours: start.hour, minutes: start.minute),
        endTime: Duration(hours: end.hour, minutes: end.minute),
        color: color,
        workingHours: double.parse(workingHours.text),
        rate: double.parse(rate.text),
        location: location.text.trim().isEmpty ? null : location.text.trim(),
        active: widget.template?.active ?? true,
        sortOrder: widget.template?.sortOrder ?? widget.nextOrder,
      ),
    );
  }

  TimeOfDay _timeOfDay(Duration value) {
    return TimeOfDay(
      hour: value.inHours.remainder(24),
      minute: value.inMinutes.remainder(60),
    );
  }
}
