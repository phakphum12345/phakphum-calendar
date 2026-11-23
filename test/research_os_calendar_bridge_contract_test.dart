import 'package:flutter_test/flutter_test.dart';

import 'package:phakphum_calendar/integration/research_os_calendar_bridge_contract.dart';

void main() {
  test('uses loopback endpoints with a caller-supplied runtime port', () {
    const discoveredPort = 49152;

    expect(
      ResearchOsCalendarBridgeContract.healthUri(port: discoveredPort).toString(),
      'http://127.0.0.1:49152/v1/research-os/health',
    );
    expect(
      ResearchOsCalendarBridgeContract.syncUri(port: discoveredPort).toString(),
      'http://127.0.0.1:49152/v1/research-os/sync',
    );
    expect(
      ResearchOsCalendarBridgeContract.syncStatusUri(
        'sync-job_123',
        port: discoveredPort,
      ).toString(),
      'http://127.0.0.1:49152/v1/research-os/sync/sync-job_123',
    );
    expect(ResearchOsCalendarBridgeContract.requestTimeoutSeconds, 20);
  });

  test('rejects invalid discovered ports and unsafe sync IDs', () {
    expect(
      () => ResearchOsCalendarBridgeContract.healthUri(port: 0),
      throwsArgumentError,
    );
    expect(
      () => ResearchOsCalendarBridgeContract.syncUri(port: 65536),
      throwsArgumentError,
    );
    expect(
      () => ResearchOsCalendarBridgeContract.syncStatusUri(
        '../other',
        port: 49152,
      ),
      throwsArgumentError,
    );
  });
}
