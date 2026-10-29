import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/ai_support/presentation/ai_support_chat_page.dart';

void main() {
  testWidgets('shows safety notice and suggested questions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiSupportChatPage()));

    expect(find.text('AI Support'), findsOneWidget);
    expect(find.textContaining('ยังไม่เชื่อม AI จริง'), findsOneWidget);
    expect(find.text('ช่วยตรวจเวรที่อ่านไม่ครบ'), findsOneWidget);
    expect(find.text('ต้องตรวจอะไรก่อนซิงก์?'), findsOneWidget);
  });

  testWidgets('analyzes a pasted roster locally without syncing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiSupportChatPage()));

    await tester.enterText(
      find.byKey(const Key('ai-support-input')),
      'วันที่,ชื่อ,เวร\\n2026-10-29,สมชาย,เวรเช้า',
    );
    await tester.tap(find.byKey(const Key('ai-support-send')));
    await tester.pumpAndSettle();

    expect(find.textContaining('ผลตรวจตารางที่วาง'), findsOneWidget);
    expect(find.textContaining('ไม่มีการแก้ไขหรือซิงก์ข้อมูล'), findsOneWidget);
  });

  testWidgets('sending a sync question gives guidance without syncing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiSupportChatPage()));

    await tester.tap(find.text('ต้องตรวจอะไรก่อนซิงก์?'));
    await tester.pumpAndSettle();

    expect(find.text('ต้องตรวจอะไรก่อนซิงก์?'), findsOneWidget);
    expect(find.textContaining('ก่อนซิงก์:'), findsOneWidget);
    expect(find.textContaining('ไม่ได้เปลี่ยนข้อมูลใด ๆ'), findsOneWidget);
  });

  testWidgets('sends typed question and returns local fallback', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiSupportChatPage()));

    await tester.enterText(find.byKey(const Key('ai-support-input')), 'สวัสดี');
    await tester.tap(find.byKey(const Key('ai-support-send')));
    await tester.pumpAndSettle();

    expect(find.text('สวัสดี'), findsOneWidget);
    expect(find.textContaining('ยังไม่มีบริการ AI เชื่อมต่อ'), findsOneWidget);
  });
}
