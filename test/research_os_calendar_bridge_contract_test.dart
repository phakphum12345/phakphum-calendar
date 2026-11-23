import 'package:flutter_test/flutter_test.dart';

import 'package:phakphum_calendar/integration/research_os_calendar_bridge_contract.dart';

void main() {
  test('uses loopback bridge endpoints and bounded request timeout', () {
    expect(
      ResearchOsCalendarBridgeContract.healthUri().toString(),
      'http://127.0.0.1:8765/v1/research-os/health',
    );
    expect(
      ResearchOsCalendarBridgeContract.syncUri().toString(),
      'http://127.0.0.1:8765/v1/research-os/sync',
    );
    expect(ResearchOsCalendarBridgeContract.requestTimeoutSeconds, 20);
  });
}
