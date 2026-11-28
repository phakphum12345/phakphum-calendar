import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/google/google_scopes.dart';
import 'google_api_client.dart';

/// Authentication boundary required by the legacy application workflow.
abstract interface class GoogleAuthGateway implements Listenable {
  GoogleSignInAccount? get account;
  String? get idToken;
  bool get isSignedIn;
  bool get initialized;
  bool get signInReady;
  String? get error;
  bool get checkingReadAccess;
  bool get readAccessGranted;
  String get webClientId;
  bool get canConfigureWebOAuth;
  bool get platformSupported;
  String? get oauthUnavailableMessage;
  bool get oauthConfigured;

  bool validateWebClientId(String value);
  Future<void> initialize({String? webClientId});
  Future<void> configureWebClientId(String value);
  Future<void> signIn();
  Future<void> requestReadAccess();
  Future<void> signOut();
  Future<void> disconnect();
  Future<GoogleApiClient> clientFor(
    List<String> scopes, {
    bool promptIfNecessary = true,
  });
  void dispose();
}

class GoogleAuthService extends ChangeNotifier implements GoogleAuthGateway {
  /// Legacy alias retained while existing feature screens migrate to
  /// [GoogleScopes.rosterRead].
  @Deprecated('Use GoogleScopes.rosterRead instead.')
  static const String spreadsheetsReadOnlyScope =
      GoogleScopes.spreadsheetsReadOnly;

  /// Backward-compatible aggregate for the legacy import/review entry point.
  ///
  /// New workflows should request [GoogleScopes.rosterRead] or
  /// [GoogleScopes.calendarRead] at the point of use instead.
  static const readAccessScopes = <String>[
    ...GoogleScopes.rosterRead,
    ...GoogleScopes.calendarRead,
  ];

  static const _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const _macosClientId = String.fromEnvironment(
    'GOOGLE_MACOS_CLIENT_ID',
  );
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  GoogleSignInAccount? _account;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  bool _initialized = false;
  bool _pluginInitialized = false;
  String _runtimeWebClientId = '';
  String? _error;
  bool _checkingReadAccess = false;
  bool _readAccessGranted = false;

  @override
  GoogleSignInAccount? get account => _account;
  @override
  String? get idToken => _account?.authentication.idToken;
  @override
  bool get isSignedIn => _account != null;
  @override
  bool get initialized => _initialized;
  @override
  bool get signInReady => _pluginInitialized;
  @override
  String? get error => _error;
  @override
  bool get checkingReadAccess => _checkingReadAccess;
  @override
  bool get readAccessGranted => _readAccessGranted;
  @override
  String get webClientId =>
      _webClientId.isNotEmpty ? _webClientId : _runtimeWebClientId.trim();
  @override
  bool get canConfigureWebOAuth => false;
  @override
  bool get platformSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  @override
  String? get oauthUnavailableMessage {
    if (!platformSupported) {
      return 'Google Sign-In ยังไม่รองรับ Windows/Linux โดยแพ็กเกจที่ใช้ '
          'กรุณาใช้แอปเวอร์ชันเว็บสำหรับการเชื่อมต่อ Google';
    }
    if (kIsWeb && webClientId.isEmpty) {
      return 'Google Login ยังไม่พร้อมใช้งาน เจ้าของแอปต้องตั้งค่า OAuth Client ID สำหรับ Web ก่อน ผู้ใช้ไม่ต้องกรอกหรือตั้งค่า Client ID เอง';
    }
    return null;
  }

  @override
  bool get oauthConfigured => oauthUnavailableMessage == null;

  static bool isValidWebClientId(String value) {
    final clientId = value.trim();
    return clientId.length >= 30 &&
        RegExp(
          r'^[0-9]+-[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com$',
        ).hasMatch(clientId);
  }

  @override
  bool validateWebClientId(String value) => isValidWebClientId(value);

  @override
  Future<void> initialize({String? webClientId}) async {
    if (_initialized) return;
    _runtimeWebClientId = webClientId?.trim() ?? _runtimeWebClientId;
    final unavailableMessage = oauthUnavailableMessage;
    if (unavailableMessage != null) {
      _error = unavailableMessage;
      _initialized = true;
      notifyListeners();
      return;
    }

    await _initializePlugin();
  }

  @override
  Future<void> configureWebClientId(String value) async {
    final clientId = value.trim();
    if (!kIsWeb) {
      throw StateError('การตั้งค่า Web OAuth ทำได้จากแอปเวอร์ชันเว็บเท่านั้น');
    }
    if (!isValidWebClientId(clientId)) {
      throw const FormatException(
        'รูปแบบ Google Web OAuth Client ID ไม่ถูกต้อง',
      );
    }
    if (_pluginInitialized) {
      if (clientId == webClientId) return;
      throw StateError('กรุณาโหลดหน้าแอปใหม่ก่อนเปลี่ยน OAuth Client ID');
    }
    _runtimeWebClientId = clientId;
    // Runtime configuration is supplied by the application owner, never
    // collected from or persisted in an end-user browser profile.
    _initialized = false;
    _error = null;
    notifyListeners();
    await _initializePlugin();
  }

  Future<void> _initializePlugin() async {
    final signIn = GoogleSignIn.instance;
    _subscription ??= signIn.authenticationEvents.listen(
      (event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            _account = event.user;
            _error = null;
            _readAccessGranted = false;
            _checkingReadAccess = true;
            unawaited(_checkReadAccess(event.user));
          case GoogleSignInAuthenticationEventSignOut():
            _account = null;
            _checkingReadAccess = false;
            _readAccessGranted = false;
        }
        notifyListeners();
      },
      onError: (Object error) {
        _error = _friendlyError(error);
        notifyListeners();
      },
    );

    try {
      final clientId = switch (defaultTargetPlatform) {
        _ when kIsWeb => webClientId,
        TargetPlatform.iOS => _iosClientId,
        TargetPlatform.macOS => _macosClientId,
        _ => null,
      };
      await signIn.initialize(
        clientId: clientId,
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      );
      _pluginInitialized = true;
      _initialized = true;
      _error = null;
      notifyListeners();
    } catch (error) {
      _error = _friendlyError(error);
      _initialized = true;
      notifyListeners();
      return;
    }

    // Do not start a silent/One Tap authentication attempt here. On the web,
    // that can open Google's account verification UI as soon as the app loads.
    // Authentication must only begin after the user presses the Google button.
  }

  @override
  Future<void> signIn() async {
    _error = null;
    notifyListeners();
    try {
      final unavailableMessage = oauthUnavailableMessage;
      if (unavailableMessage != null) {
        throw StateError(unavailableMessage);
      }
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw StateError('กรุณาใช้ปุ่ม Google ที่แสดงบนหน้าเว็บ');
      }
      await GoogleSignIn.instance.authenticate();
    } catch (error) {
      _error = _friendlyError(error);
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    _account = null;
    _checkingReadAccess = false;
    _readAccessGranted = false;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    await GoogleSignIn.instance.disconnect();
    _account = null;
    _checkingReadAccess = false;
    _readAccessGranted = false;
    notifyListeners();
  }

  @override
  Future<void> requestReadAccess() async {
    final current = _account;
    if (current == null) {
      throw StateError('กรุณาเข้าสู่ระบบ Google ก่อน');
    }

    _checkingReadAccess = true;
    _error = null;
    notifyListeners();
    try {
      await current.authorizationClient.authorizeScopes(readAccessScopes);
      _readAccessGranted = true;
    } catch (error) {
      _readAccessGranted = false;
      _error = _friendlyError(error);
      rethrow;
    } finally {
      _checkingReadAccess = false;
      notifyListeners();
    }
  }

  Future<void> _checkReadAccess(GoogleSignInAccount current) async {
    try {
      final authorization = await current.authorizationClient
          .authorizationForScopes(readAccessScopes);
      if (_account?.id == current.id) {
        _readAccessGranted = authorization != null;
      }
    } catch (_) {
      if (_account?.id == current.id) {
        _readAccessGranted = false;
      }
    } finally {
      if (_account?.id == current.id) {
        _checkingReadAccess = false;
        notifyListeners();
      }
    }
  }

  @override
  Future<GoogleApiClient> clientFor(
    List<String> scopes, {
    bool promptIfNecessary = true,
  }) async {
    final current = _account;
    if (current == null) {
      throw StateError('กรุณาเข้าสู่ระบบ Google ก่อน');
    }
    final normalizedScopes = scopes.map((scope) => scope.trim()).toSet();
    if (normalizedScopes.isEmpty || normalizedScopes.any((scope) => scope.isEmpty)) {
      throw ArgumentError.value(scopes, 'scopes', 'ต้องระบุ OAuth scopes ที่ถูกต้อง');
    }
    final headers = await current.authorizationClient.authorizationHeaders(
      normalizedScopes.toList(growable: false),
      promptIfNecessary: promptIfNecessary,
    );
    if (headers == null) {
      throw StateError('ยังไม่ได้อนุญาตสิทธิ์ที่จำเป็น');
    }
    final accountId = current.id;
    return GoogleApiClient.withHeaderProvider(() async {
      final activeAccount = _account;
      if (activeAccount == null || activeAccount.id != accountId) {
        throw StateError(
          'บัญชี Google เปลี่ยนหรือถูกตัดการเชื่อมต่อ กรุณาเชื่อมต่อใหม่',
        );
      }
      final refreshedHeaders = await activeAccount.authorizationClient
          .authorizationHeaders(
            normalizedScopes.toList(growable: false),
            promptIfNecessary: false,
          );
      if (refreshedHeaders == null) {
        throw StateError(
          'สิทธิ์ Google หมดอายุหรือถูกเพิกถอน กรุณาเชื่อมต่อบัญชีและอนุญาตใหม่',
        );
      }
      if (_account?.id != accountId) {
        throw StateError('บัญชี Google เปลี่ยนระหว่างส่งคำขอ กรุณาลองใหม่');
      }
      return refreshedHeaders;
    });
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('clientId') || text.contains('client_id')) {
      return 'ยังไม่ได้ตั้งค่า Google OAuth Client ID';
    }
    return text.replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
