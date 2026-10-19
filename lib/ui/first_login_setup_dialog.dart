import 'package:flutter/material.dart';
import '../controller/app_controller.dart';

class FirstLoginSetupDialog extends StatefulWidget {
  const FirstLoginSetupDialog({super.key, required this.controller});
  final AppController controller;
  @override State<FirstLoginSetupDialog> createState() => _FirstLoginSetupDialogState();
}
class _FirstLoginSetupDialogState extends State<FirstLoginSetupDialog> {
  late final organization=TextEditingController(text:widget.controller.settings.organizationName);
  late final officer=TextEditingController(text:widget.controller.settings.officerName);
  late final shiftName=TextEditingController(text:widget.controller.settings.defaultShiftName);
  late final color=TextEditingController(text:widget.controller.settings.defaultShiftColor);
  late final start=TextEditingController(text:widget.controller.settings.defaultShiftStart);
  late final end=TextEditingController(text:widget.controller.settings.defaultShiftEnd);
  late final receiver=TextEditingController(text:widget.controller.settings.defaultShiftReceiver);
  late final exchange=TextEditingController(text:widget.controller.settings.shiftExchangeNote);
  late final cancellation=TextEditingController(text:widget.controller.settings.shiftCancellationNote);
  bool saving=false;
  @override void dispose(){for(final c in [organization,officer,shiftName,color,start,end,receiver,exchange,cancellation]){c.dispose();}super.dispose();}
  Future<void> save() async {
    if(organization.text.trim().isEmpty||officer.text.trim().isEmpty||shiftName.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('กรุณากรอกชื่อหน่วยงาน ชื่อเจ้าหน้าที่ และชื่อเวร')));return;}
    final time=RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
    if(!time.hasMatch(start.text.trim())||!time.hasMatch(end.text.trim())){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('กรุณาระบุเวลาแบบ HH:MM เช่น 08:00')));return;}
    if(!RegExp(r'^#(?:[0-9a-fA-F]{6})$').hasMatch(color.text.trim())){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('สีเวรต้องเป็นรหัส HEX เช่น #616161')));return;}
    setState(()=>saving=true);
    try { final current=widget.controller.settings; await widget.controller.updateSettings(current.copyWith(organizationName:organization.text.trim(),officerName:officer.text.trim(),defaultShiftName:shiftName.text.trim(),defaultShiftColor:color.text.trim().toUpperCase(),defaultShiftStart:start.text.trim(),defaultShiftEnd:end.text.trim(),defaultShiftReceiver:receiver.text.trim(),shiftExchangeNote:exchange.text.trim(),shiftCancellationNote:cancellation.text.trim(),setupComplete:true));
      await widget.controller.recordShiftTimelineEvent(action:'SETUP_COMPLETED',summary:'ตั้งค่าหน่วยงานและเวร',details:'หน่วยงาน: ${organization.text.trim()}\nเจ้าหน้าที่: ${officer.text.trim()}\nชื่อเวร: ${shiftName.text.trim()}\nสีเวร: ${color.text.trim().toUpperCase()}\nเวลา: ${start.text.trim()}–${end.text.trim()}\nผู้รับเวร: ${receiver.text.trim()}\nแลกเวร: ${exchange.text.trim()}\nยกเวร: ${cancellation.text.trim()}');
      if(mounted)Navigator.of(context).pop();
    } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('บันทึกไม่สำเร็จ: $e')));} finally {if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context)=>AlertDialog(key:const Key('first-login-setup-dialog'),title:const Text('ตั้งค่าก่อนเข้าหน้าหลัก'),content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Text('กรอกข้อมูลเริ่มต้นเพื่อลดขั้นตอนระหว่างใช้งาน'),
    TextField(controller:organization,decoration:const InputDecoration(labelText:'ชื่อหน่วยงาน *',prefixIcon:Icon(Icons.apartment_outlined))),
    TextField(controller:officer,decoration:const InputDecoration(labelText:'ชื่อเจ้าหน้าที่ *',prefixIcon:Icon(Icons.badge_outlined))),
    TextField(controller:shiftName,decoration:const InputDecoration(labelText:'ชื่อเวรเริ่มต้น *',prefixIcon:Icon(Icons.event_outlined))),
    Row(children:[Expanded(child:TextField(controller:start,keyboardType:TextInputType.datetime,decoration:const InputDecoration(labelText:'เวลาเริ่ม (HH:MM)'))),const SizedBox(width:10),Expanded(child:TextField(controller:end,keyboardType:TextInputType.datetime,decoration:const InputDecoration(labelText:'เวลาสิ้นสุด (HH:MM)')))]),
    TextField(controller:color,decoration:const InputDecoration(labelText:'สีเวร (HEX)',prefixIcon:Icon(Icons.palette_outlined))),
    TextField(controller:receiver,decoration:const InputDecoration(labelText:'ชื่อคนรับเวร',prefixIcon:Icon(Icons.person_add_alt_1_outlined))),
    TextField(controller:exchange,decoration:const InputDecoration(labelText:'รายละเอียด/แนวทางแลกเวร',prefixIcon:Icon(Icons.swap_horiz_outlined))),
    TextField(controller:cancellation,decoration:const InputDecoration(labelText:'รายละเอียด/แนวทางยกเวร',prefixIcon:Icon(Icons.event_busy_outlined))),
    const SizedBox(height:8),const Text('ระบบจะบันทึกผู้ดำเนินการ เวลา และรายละเอียดใน Timeline ของ Google Calendar'),
  ]))),actions:[FilledButton(onPressed:saving?null:save,child:Text(saving?'กำลังบันทึก…':'บันทึกและเข้าหน้าหลัก'))]);
}
