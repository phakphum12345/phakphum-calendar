import 'dart:convert';
import 'dart:js_interop';

import 'web_push_browser_bridge.dart';

@JS('shiftToolsPush.isSupported')
external JSBoolean _isSupported();

@JS('shiftToolsPush.permission')
external JSString _permission();

@JS('shiftToolsPush.subscribe')
external JSPromise<JSString> _subscribe(JSString publicKey);

@JS('shiftToolsPush.unsubscribe')
external JSPromise<JSString?> _unsubscribe();

class WebPushBrowserBridgeImpl implements WebPushBrowserBridge {
  const WebPushBrowserBridgeImpl();

  @override
  bool get isSupported {
    try {
      return _isSupported().toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  String get permission {
    try {
      return _permission().toDart;
    } catch (_) {
      return 'unsupported';
    }
  }

  @override
  Future<Map<String, dynamic>?> subscribe(String publicKey) async {
    final result = await _subscribe(publicKey.toJS).toDart;
    final decoded = jsonDecode(result.toDart);
    if (decoded is! Map) {
      throw const FormatException('Invalid browser push subscription.');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  @override
  Future<Map<String, dynamic>?> unsubscribe() async {
    final result = await _unsubscribe().toDart;
    if (result == null) return null;
    final decoded = jsonDecode(result.toDart);
    if (decoded is! Map) {
      throw const FormatException('Invalid browser push subscription.');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
}

WebPushBrowserBridge createWebPushBrowserBridge() =>
    const WebPushBrowserBridgeImpl();
