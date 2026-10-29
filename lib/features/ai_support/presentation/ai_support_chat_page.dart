import 'package:flutter/material.dart';

import '../../ai_roster_analyzer/application/ai_roster_analyzer.dart';
import '../../ai_roster_analyzer/domain/roster_analysis_models.dart';

/// A safe, provider-neutral support chat shell.
///
/// Replies are local guidance only. This page does not call an AI service,
/// read roster data, save changes, or sync to Google Calendar.
class AiSupportChatPage extends StatefulWidget {
  const AiSupportChatPage({super.key});

  @override
  State<AiSupportChatPage> createState() => _AiSupportChatPageState();
}

class _AiSupportChatPageState extends State<AiSupportChatPage> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'สวัสดีครับ ผมคือ AI Support รุ่นทดลอง\n'
          'ตอนนี้ช่วยแนะนำขั้นตอนทั่วไปได้ ยังไม่ได้เชื่อมต่อ AI จริง '
          'และจะไม่แก้ไขหรือซิงก์ข้อมูลแทนคุณ',
      fromUser: false,
    ),
  ];

  static const _suggestions = [
    'ช่วยตรวจเวรที่อ่านไม่ครบ',
    'อธิบายรหัสเวร เช้า/บ่าย/ดึก',
    'ต้องตรวจอะไรก่อนซิงก์?',
    'นำเข้า Excel หรือ CSV',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? suggested]) {
    final text = (suggested ?? _input.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _messages.add(_ChatMessage(
        text: _analyzePastedTable(text) ?? _localGuidance(text),
        fromUser: false,
      ));
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Analyze a pasted tabular roster locally; this never writes or syncs data.
  String? _analyzePastedTable(String text) {
    if (!text.contains('\\n')) return null;
    final lines = text
        .split(RegExp(r'\\r?\\n'))
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return null;

    final delimiter = lines.first.contains('\\t') ? '\\t' : ',';
    final columns = _splitDelimitedLine(lines.first, delimiter)
        .map((value) => value.trim())
        .toList();
    if (columns.length < 2) return null;

    final rows = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      final values = _splitDelimitedLine(line, delimiter);
      if (values.every((value) => value.trim().isEmpty)) continue;
      rows.add({
        for (var index = 0; index < columns.length; index++)
          columns[index]: index < values.length ? values[index].trim() : '',
      });
    }
    if (rows.isEmpty) return null;

    final analysis = const AiRosterAnalyzer().analyzeFrames([
      RosterInputFrame(
        source: const RosterAnalysisSource(
          type: RosterAnalysisSourceType.pastedTable,
          name: 'ตารางที่วางใน AI Support',
        ),
        columns: columns,
        rows: rows,
      ),
    ]);
    final unknown = analysis.records
        .where((record) => record.kind == RosterDutyKind.unknown)
        .length;
    final lowConfidence = analysis.records
        .where((record) => record.confidence < 0.85)
        .length;
    final dateWarnings = analysis.records
        .where((record) => record.notes.any((note) => note.contains('วันที่')))
        .length;
    final warnings = <String>[
      ...analysis.warnings,
      if (unknown > 0) 'มีรายการที่ยังจำแนกประเภทเวรไม่ได้ $unknown รายการ',
      if (lowConfidence > 0) 'มีรายการความเชื่อมั่นต่ำกว่า 85% จำนวน $lowConfidence รายการ',
      if (dateWarnings > 0) 'มีรายการที่อ่านวันที่ไม่สำเร็จ $dateWarnings รายการ',
    ];

    return 'ผลตรวจตารางที่วาง (วิเคราะห์ในเครื่อง)\\n'
        '• แถวข้อมูลที่ตรวจพบ: ${rows.length}\\n'
        '• รายการที่วิเคราะห์ได้: ${analysis.records.length}\\n'
        '• รายการที่ต้องตรวจเพิ่ม: ${warnings.length}\\n'
        '${warnings.isEmpty ? 'ไม่พบคำเตือนจากการตรวจเบื้องต้น' : warnings.map((warning) => '• $warning').join('\\n')}'
        '\\n\\nผลนี้เป็นเพียงการคัดกรองเบื้องต้น โปรดเทียบกับต้นฉบับก่อนบันทึก '
        'และไม่มีการแก้ไขหรือซิงก์ข้อมูล';
  }

  List<String> _splitDelimitedLine(String line, String delimiter) {
    final values = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"') {
        if (quoted && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && char == delimiter) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    values.add(buffer.toString());
    return values;
  }

  String _localGuidance(String question) {
    final value = question.toLowerCase();
    if (value.contains('ซิงก์') || value.contains('sync')) {
      return 'ก่อนซิงก์: 1) ตรวจวันและเดือน 2) ตรวจชื่อผู้ปฏิบัติงาน '
          '3) ตรวจรหัสและเวลาเวร 4) ตรวจรายการซ้ำ/รายการที่ขาด '
          '5) ยืนยันรายการที่จะส่งทุกครั้ง\n\n'
          'หน้านี้ยังไม่เริ่มซิงก์ให้ และไม่ได้เปลี่ยนข้อมูลใด ๆ';
    }
    if (value.contains('excel') || value.contains('csv') ||
        value.contains('นำเข้า')) {
      return 'เลือกไฟล์ต้นฉบับผ่านเมนูนำเข้า แล้วตรวจการจับคู่คอลัมน์ '
          'ชื่อบุคลากร วันที่ และรหัสเวร จากนั้นดูตัวอย่างก่อนบันทึก '
          'หากอ่านไม่ตรง ให้หยุดและแก้การจับคู่ก่อนดำเนินการต่อ';
    }
    if (value.contains('รหัสเวร') || value.contains('เช้า') ||
        value.contains('บ่าย') || value.contains('ดึก')) {
      return 'ควรใช้รหัสเวรที่กำหนดไว้ในเทมเพลตของหน่วยงานเป็นหลัก '
          'อย่าเดาเวลาเมื่อรหัสไม่ตรงกัน ให้ตรวจชื่อเวร เวลาเริ่ม-สิ้นสุด '
          'และกรณีข้ามเที่ยงคืน แล้วให้ผู้ใช้ยืนยันค่าที่ถูกต้อง';
    }
    if (value.contains('อ่าน') || value.contains('ไม่ครบ') ||
        value.contains('ผิด')) {
      return 'เพื่อหาสาเหตุ ให้เทียบวัน/เดือน ชื่อคน และรหัสเวรจากต้นฉบับ '
          'กับรายการที่นำเข้า ทำเครื่องหมายรายการที่ขาด ซ้ำ หรือไม่แน่ใจ '
          'อย่าแก้หรือซิงก์รายการที่ยังไม่ได้ตรวจสอบ';
    }
    return 'ผมรับคำถามไว้ในหน้าจอนี้แล้ว แต่ยังไม่มีบริการ AI เชื่อมต่อ '
        'จึงตอบได้เฉพาะแนวทางพื้นฐาน: ตรวจข้อมูลกับต้นฉบับ '
        'และยืนยันทุกค่าที่ไม่แน่ใจก่อนบันทึกหรือซิงก์';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(child: Icon(Icons.support_agent_outlined)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Support'),
                  Text('ผู้ช่วยเรื่องปฏิทินเวร',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: colors.tertiaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('โหมดทดลอง: ยังไม่เชื่อม AI จริง • ไม่มีการบันทึกหรือซิงก์อัตโนมัติ'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  for (final message in _messages)
                    Align(
                      alignment: message.fromUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 620),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: message.fromUser
                              ? colors.primaryContainer
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(message.text),
                      ),
                    ),
                  if (_messages.length == 1) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('ลองถามเรื่องเหล่านี้',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final suggestion in _suggestions)
                          ActionChip(
                            label: Text(suggestion),
                            onPressed: () => _send(suggestion),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('ai-support-input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'พิมพ์คำถามเกี่ยวกับเวร...',
                        prefixIcon: Icon(Icons.chat_bubble_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('ai-support-send'),
                    tooltip: 'ส่งข้อความ',
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.fromUser});
  final String text;
  final bool fromUser;
}
