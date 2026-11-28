import 'package:google_sign_in/google_sign_in.dart';

import '../../../services/google_auth_service.dart';
import '../domain/authentication_service.dart';
import '../domain/google_user.dart';

/// Compatibility adapter for authentication presentation flows.
///
/// All Google Sign-In, session, and authorization behavior is delegated to
/// the application's single [GoogleAuthGateway]. This adapter never creates
/// a second GoogleSignIn instance or requests data scopes during sign-in.
class GoogleAuthenticationService implements AuthenticationService {
  GoogleAuthenticationService(this._gateway);

  final GoogleAuthGateway _gateway;

  @override
  Future<void> initialize() => _gateway.initialize();

  @override
  Future<GoogleUser?> restoreSession() async {
    await initialize();
    final account = _gateway.account;
    return account == null ? null : _toDomain(account);
  }

  @override
  Future<GoogleUser> signIn() async {
    await initialize();
    await _gateway.signIn();
    final account = _gateway.account;
    if (account == null) {
      throw StateError(
        'Google Sign-In completed without an authenticated account.',
      );
    }
    return _toDomain(account);
  }

  @override
  Future<void> signOut() => _gateway.signOut();

  @override
  Future<void> disconnect() => _gateway.disconnect();

  GoogleUser _toDomain(GoogleSignInAccount account) {
    return GoogleUser(
      id: account.id,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
  }
}
