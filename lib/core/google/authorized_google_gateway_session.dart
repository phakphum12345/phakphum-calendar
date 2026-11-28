import 'package:googleapis_auth/googleapis_auth.dart' as auth;

/// Owns one Google API client and the gateway built around that client.
///
/// The caller must close the session when the feature operation or controller
/// is finished. Each session is created from the currently signed-in account
/// and a feature-specific OAuth scope set.
class AuthorizedGoogleGatewaySession<T> {
  AuthorizedGoogleGatewaySession({
    required this.gateway,
    required auth.AuthClient client,
    required this.accountId,
  }) : _client = client;

  final T gateway;
  final String accountId;
  final auth.AuthClient _client;
  bool _closed = false;

  bool get isClosed => _closed;

  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }
}
