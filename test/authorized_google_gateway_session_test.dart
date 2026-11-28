import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:phakphum_calendar/core/google/authorized_google_gateway_session.dart';

void main() {
  test('authorized gateway session closes its client exactly once', () {
    final client = _CloseTrackingClient();
    final session = AuthorizedGoogleGatewaySession<String>(
      gateway: 'gateway',
      client: client,
      accountId: 'google-account-1',
    );

    expect(session.gateway, 'gateway');
    expect(session.accountId, 'google-account-1');
    expect(session.isClosed, isFalse);

    session.close();
    session.close();

    expect(session.isClosed, isTrue);
    expect(client.closeCalls, 1);
  });
}

class _CloseTrackingClient extends http.BaseClient {
  int closeCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }

  @override
  void close() {
    closeCalls++;
  }
}
