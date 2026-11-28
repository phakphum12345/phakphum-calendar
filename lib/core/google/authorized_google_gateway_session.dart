import 'package:http/http.dart' as http;

/// Owns one Google API client and the gateway built around that client.
///
/// The caller must close the session when the feature operation or controller
/// is finished. Each session is created from the currently signed-in account
/// and a feature-specific OAuth scope set.
class AuthorizedGoogleGatewaySession<T> {
  AuthorizedGoogleGatewaySession({
    required this.gateway,
    required http.Client client,
    required this.accountId,
  }) : _client = client;

  final T gateway;
  final String accountId;
  final http.Client _client;
  bool _closed = false;

  bool get isClosed => _closed;

  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }
}
