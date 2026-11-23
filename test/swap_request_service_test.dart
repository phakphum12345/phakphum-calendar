import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:phakphum_calendar/models/swap_request.dart';
import 'package:phakphum_calendar/services/swap_request_service.dart';

void main() {
  test('save and load swap request', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SwapRequestService();
    final req = SwapRequest(
      id: 'T1',
      requester: 'A',
      target: 'B',
      shiftRef: 'Shift X',
      reason: 'Because',
      createdAt: DateTime.now(),
    );
    await service.save(req);
    final all = await service.loadAll();
    expect(all, isNotEmpty);
    expect(all.first.id, equals('T1'));
  });
}
