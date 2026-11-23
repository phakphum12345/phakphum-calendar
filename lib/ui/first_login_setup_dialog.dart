import 'package:flutter/material.dart';

import '../controller/app_controller.dart';
import '../features/edition/domain/app_edition.dart';

class FirstLoginSetupDialog extends StatefulWidget {
  const FirstLoginSetupDialog({
    super.key,
    required this.controller,
    required this.edition,
  });

  final AppController controller;
  final AppEdition edition;

  @override
  State<FirstLoginSetupDialog> createState() => _FirstLoginSetupDialogState();
}

class _FirstLoginSetupDialogState extends State<FirstLoginSetupDialog> {
  late final organization = TextEditingController(
    text: widget.controller.settings.organizationName,
  );
  late final officer = TextEditingController(
    text: widget.controller.settings.officerName,
  );
  late final shiftName = TextEditingController(
    text: widget.controller.settings.defaultShiftName,
  );
  late final color = TextEditingController(
    text: widget.controller.settings.defaultShiftColor,
  );
  late final start = TextEditingController(
    text: widget.controller.settings.defaultShiftStart,
  );
  late final end = TextEditingController(
    text: widget.controller.settings.defaultShiftEnd,
  );
  late final receiver = TextEditingController(
    text: widget.controller.settings.defaultShiftReceiver,
  );
  late final exchange = TextEditingController(
    text: widget.controller.settings.shiftExchangeNote,
  );
  late final cancellation = TextEditingController(
    text: widget.controller.settings.shiftCancellationNote,
  );

  bool saving = false;

  bool get isOrganization => widget.edition == AppEdition.organization;

  @override
  void dispose() {
    for (final controller in [
      organization,
      officer,
      shiftName,
      color,
      start,
      end,
      receiver,
      exchange,
      cancellation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (isOrganization &&
        (organization.text.trim().isEmpty ||
            officer.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกชื่อหน่วยงานและชื่อเจ้าหน้าที่'),
        ),
      );
      return;
    }
    if (shiftName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อเวรเริ่มต้น')),
      );
      return;
    }

    final time = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
    if (!time.hasMatch(start.text.trim()) ||
        !time.hasMatch(end.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุเวลาแบบ HH:MM เช่น 08:00'),
        ),
      );
      return;
    }
    if (!RegExp(r'^#(?:[0-9a-fA-F]{6})$').hasMatch(color.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สีเวรต้องเป็นรหัส HEX เช่น #616161'),
        ),
      );
      return;
    }

    setState(() => saving = true);
    final messenger = ScaffoldMessenger.of(context);
    var timelineFailed = false;

    try {
      final current = widget.controller.settings;
      await widget.controller.updateSettings(
        current.copyWith(
          organizationName: isOrganization
              ? organization.text.trim()
              : current.organizationName,
          officerName: isOrganization
              ? officer.text.trim()
              : current.officerName,
          defaultShiftName: shiftName.text.trim(),
          defaultShiftColor: color.text.trim().toUpperCase(),
          defaultShiftStart: start.text.trim(),
          defaultShiftEnd: end.text.trim(),
          defaultShiftReceiver: receiver.text.trim(),
          shiftExchangeNote: exchange.text.trim(),
          shiftCancellationNote: cancellation.text.trim(),
          setupComplete: true,
        ),
      );

      // Personal edition uses read-only roster/calendar workflows and does
      // not need an organization audit event or Calendar write authorization.
      if (isOrganization) {
        try {
          await widget.controller.recordShiftTimelineEvent(
            action: 'SETUP_COMPLETED',
            summary: 'ตั้งค่าหน่วยงานและเวร',
            details: 'หน่วยงาน: ${organization.text.trim()}\n'
                'เจ้าหน้าที่: ${officer.text.trim()}\n'
                'ชื่อเวร: ${shiftName.text.trim()}\n'
                'สีเวร: ${color.text.trim().toUpperCase()}\n'
                'เวลา: ${start.text.trim()}–${end.text.trim()}\n'
                'ผู้รับเวร: ${receiver.text.trim()}\n'
                'แลกเวร: ${exchange.text.trim()}\n'
                'ยกเวร: ${cancellation.text.trim()}',
          );
        } catch (_) {
          // Settings are already saved; don't trap the user in a modal.
          timelineFailed = true;
        }
      }

      if (mounted) Navigator.of(context).pop();
      if (timelineFailed) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'บันทึกการตั้งค่าแล้ว แต่บันทึก Timeline ไม่สำเร็จ '
              'โปรดตรวจสอบสิทธิ์ Calendar ก่อนบันทึกกิจกรรมครั้งถัดไป',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('บันทึกการตั้งค่าไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('first-login-setup-dialog'),
    title: Text(
      isOrganization
          ? 'ตั้งค่าหน่วยงานและเวรก่อนเข้าหน้าหลัก'
          : 'ตั้งค่าเวรส่วนตัวก่อนเข้าหน้าหลัก',
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isOrganization
                  ? 'กรอกข้อมูลหน่วยงานและเวรเริ่มต้นเพื่อลดขั้นตอนระหว่างใช้งาน'
                  : 'ตั้งค่าเวรเริ่มต้นได้โดยไม่ต้องกรอกข้อมูลหน่วยงานหรือเจ้าหน้าที่',
            ),
            if (isOrganization) ...[
              TextField(
                controller: organization,
                decoration: const InputDecoration(
                  labelText: 'ชื่อหน่วยงาน *',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
              ),
              TextField(
                controller: officer,
                decoration: const InputDecoration(
                  labelText: 'ชื่อเจ้าหน้าที่ *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
            ],
            TextField(
              controller: shiftName,
              decoration: const InputDecoration(
                labelText: 'ชื่อเวรเริ่มต้น *',
                prefixIcon: Icon(Icons.event_outlined),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: start,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'เวลาเริ่ม (HH:MM)',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: end,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'เวลาสิ้นสุด (HH:MM)',
                    ),
                  ),
                ),
              ],
            ),
            TextField(
              controller: color,
              decoration: const InputDecoration(
                labelText: 'สีเวร (HEX)',
                prefixIcon: Icon(Icons.palette_outlined),
              ),
            ),
            TextField(
              controller: receiver,
              decoration: const InputDecoration(
                labelText: 'ชื่อคนรับเวร',
                prefixIcon: Icon(Icons.person_add_alt_1_outlined),
              ),
            ),
            if (isOrganization) ...[
              TextField(
                controller: exchange,
                decoration: const InputDecoration(
                  labelText: 'รายละเอียด/แนวทางแลกเวร',
                  prefixIcon: Icon(Icons.swap_horiz_outlined),
                ),
              ),
              TextField(
                controller: cancellation,
                decoration: const InputDecoration(
                  labelText: 'รายละเอียด/แนวทางยกเวร',
                  prefixIcon: Icon(Icons.event_busy_outlined),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ระบบจะบันทึกผู้ดำเนินการ เวลา และรายละเอียดใน Timeline '
                'ของ Google Calendar',
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'กำลังบันทึก…' : 'บันทึกและเข้าหน้าหลัก'),
      ),
    ],
  );
}
