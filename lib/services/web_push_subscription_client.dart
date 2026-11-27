import 'dart:convert';

import 'package:http/http.dart' as http;

import 'web_push_browser_bridge.dart'
    if (dart.library.js_interop) 'web_push_browser_bridge_web.dart';

class WebPushApiException implements Exception {
  const WebPushApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'WebPushApiException($statusCode): $message';
}

/// Coordinates browser Push API subscriptions with the authenticated API.
///
/// The browser subscription is persisted server-side; the VAPID private key
/// must remain on the backend and is never included in this client.
class WebPushSubscriptionClient {
  WebPushSubscriptionClient({
    required String baseUrl,
    required this.idTokenProvider,
    String vapidPublicKey = const String.fromEnvironment(
      'WEB_PUSH_VAPID_PUBLIC_KEY',
    ),
    http.Client? httpClient,
    WebPushBrowserBridge? browserBridge,
  }) : _baseUri = _normalizeBaseUri(baseUrl),
       vapidPublicKey = vapidPublicKey.trim(),
       _http = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _browser = browserBridge ?? createWebPushBrowserBridge();

  final Uri? _baseUri;
  final Future<String?> Function() idTokenProvider;
  final String vapidPublicKey;
  final http.Client _http;
  final bool _ownsHttpClient;
  final WebPushBrowserBridge _browser;

  static Uri? _normalizeBaseUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null ||
        !parsed.hasScheme ||
        parsed.host.isEmpty ||
        (parsed.scheme != 'https' && parsed.scheme != 'http')) {
      throw ArgumentError.value(
        value,
        'baseUrl',
        'Must be an absolute HTTP(S) URL.',
      );
    }
    return parsed.replace(
      path: parsed.path.endsWith('/') ? parsed.path : '${parsed.path}/',
    );
  }

  bool get isApiConfigured => _baseUri != null;

  bool get isConfigured =>
      isApiConfigured && vapidPublicKey.isNotEmpty && _browser.isSupported;

  bool get isSupported => _browser.isSupported;

  String get permission => _browser.permission;

  Future<bool> get isSubscribed async =>
      await _browser.currentSubscription() != null;

  Future<void> subscribe() async {
    final uri = _subscriptionUri;
    if (uri == null) throw StateError('Notification API URL is not configured.');
    if (!_browser.isSupported) {
      throw StateError('Web Push is not supported by this browser.');
    }
    if (vapidPublicKey.isEmpty) {
      throw StateError('Web Push public key is not configured.');
    }

    final token = await idTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw StateError('A signed-in Google account is required.');
    }

    final subscription = await _browser.subscribe(vapidPublicKey);
    if (subscription == null) {
      throw StateError('The browser did not return a push subscription.');
    }

    final response = await _http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${token.trim()}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(subscription),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw WebPushApiException(
        response.statusCode,
        _errorMessage(response.body),
      );
    }
  }

  Future<bool> unsubscribe() async {
    final uri = _subscriptionUri;
    if (uri == null) throw StateError('Notification API URL is not configured.');

    final subscription = await _browser.currentSubscription();
    if (subscription == null) return false;

    final token = await idTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw StateError('A signed-in Google account is required.');
    }

    final endpoint = subscription['endpoint'];
    if (endpoint is! String || endpoint.isEmpty) {
      throw const FormatException('The browser subscription has no endpoint.');
    }

    final response = await _http.delete(
      uri,
      headers: {
        'Authorization': 'Bearer ${token.trim()}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'endpoint': endpoint}),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw WebPushApiException(
        response.statusCode,
        _errorMessage(response.body),
      );
    }
    await _browser.unsubscribe();
    return true;
  }

  Uri? get _subscriptionUri => _baseUri?.resolve('api/v1/push-subscriptions');

  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          return error['message'] as String;
        }
        final message = decoded['message'];
        if (message is String) return message;
      }
    } catch (_) {
      // Use a stable fallback instead of surfacing arbitrary server content.
    }
    return 'The notification subscription request failed.';
  }

  void close() {
    if (_ownsHttpClient) _http.close();
  }
}
