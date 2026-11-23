abstract interface class WebPushBrowserBridge {
  bool get isSupported;
  String get permission;

  Future<Map<String, dynamic>?> subscribe(String publicKey);
  Future<Map<String, dynamic>?> unsubscribe();
}

class UnsupportedWebPushBrowserBridge implements WebPushBrowserBridge {
  const UnsupportedWebPushBrowserBridge();

  @override
  bool get isSupported => false;

  @override
  String get permission => 'unsupported';

  @override
  Future<Map<String, dynamic>?> subscribe(String publicKey) async => null;

  @override
  Future<Map<String, dynamic>?> unsubscribe() async => null;
}

WebPushBrowserBridge createWebPushBrowserBridge() =>
    const UnsupportedWebPushBrowserBridge();
