import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phakphum_calendar/services/web_push_browser_bridge.dart';
import 'package:phakphum_calendar/services/web_push_subscription_client.dart';

class FakeWebPushBrowserBridge implements WebPushBrowserBridge {
  FakeWebPushBrowserBridge({
    this.subscription = const {
      'endpoint': 'https://fcm.googleapis.com/fcm/send/test-token',
      'keys': {'p256dh': 'public-key', 'auth': 'auth-key'},
      'contentEncoding': 'aes128gcm',
    },
    this.supported = true,
    this.currentPermission = 'default',
  });

  final Map<String, dynamic>? subscription;
  final bool supported;
  final String currentPermission;
  int subscribeCalls = 0;
  int unsubscribeCalls = 0;

  @override
  bool get isSupported => supported;

  @override
  String get permission => currentPermission;

  @override
  Future<Map<String, dynamic>?> currentSubscription() async => subscription;

  @override
  Future<Map<String, dynamic>?> subscribe(String publicKey) async {
    subscribeCalls++;
    return subscription;
  }

  @override
  Future<Map<String, dynamic>?> unsubscribe() async {
    unsubscribeCalls++;
    return subscription;
  }
}

void main() {
  group('WebPushSubscriptionClient', () {
    test('registers the browser subscription with the authenticated API', () async {
      final bridge = FakeWebPushBrowserBridge();
      var requestCount = 0;
      final client = WebPushSubscriptionClient(
        baseUrl: 'https://api.example.test',
        idTokenProvider: () async => 'google-id-token',
        vapidPublicKey: 'public-vapid-key',
        browserBridge: bridge,
        httpClient: MockClient((request) async {
          requestCount++;
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://api.example.test/api/v1/push-subscriptions',
          );
          expect(request.headers['authorization'], 'Bearer google-id-token');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['endpoint'], contains('fcm.googleapis.com'));
          expect(body['keys']['p256dh'], 'public-key');
          return http.Response('{"status":"subscribed"}', 201);
        }),
      );

      expect(client.isConfigured, isTrue);
      await client.subscribe();

      expect(requestCount, 1);
      expect(bridge.subscribeCalls, 1);
    });

    test('unsubscribes the browser subscription from the authenticated API', () async {
      final bridge = FakeWebPushBrowserBridge();
      final client = WebPushSubscriptionClient(
        baseUrl: 'https://api.example.test/',
        idTokenProvider: () async => 'google-id-token',
        vapidPublicKey: 'public-vapid-key',
        browserBridge: bridge,
        httpClient: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.headers['authorization'], 'Bearer google-id-token');
          expect(
            jsonDecode(request.body)['endpoint'],
            'https://fcm.googleapis.com/fcm/send/test-token',
          );
          return http.Response('{"status":"unsubscribed"}', 200);
        }),
      );

      expect(await client.unsubscribe(), isTrue);
      expect(bridge.unsubscribeCalls, 1);
    });

    test('keeps the browser subscription when server unsubscribe fails', () async {
      final bridge = FakeWebPushBrowserBridge();
      final client = WebPushSubscriptionClient(
        baseUrl: 'https://api.example.test',
        idTokenProvider: () async => 'google-id-token',
        vapidPublicKey: 'public-vapid-key',
        browserBridge: bridge,
        httpClient: MockClient((request) async => http.Response('', 503)),
      );

      await expectLater(client.unsubscribe(), throwsA(isA<WebPushApiException>()));
      expect(bridge.unsubscribeCalls, 0);
    });

    test('reports whether a browser subscription is already registered', () async {
      final active = WebPushSubscriptionClient(
        baseUrl: 'https://api.example.test',
        idTokenProvider: () async => 'google-id-token',
        vapidPublicKey: 'public-vapid-key',
        browserBridge: FakeWebPushBrowserBridge(),
      );
      final inactive = WebPushSubscriptionClient(
        baseUrl: 'https://api.example.test',
        idTokenProvider: () async => 'google-id-token',
        vapidPublicKey: 'public-vapid-key',
        browserBridge: FakeWebPushBrowserBridge(subscription: null),
      );

      expect(await active.isSubscribed, isTrue);
      expect(await inactive.isSubscribed, isFalse);
    });

    test('does not call the API when no browser subscription exists', () async {
      final bridge = FakeWebPushBrowserBridge(subscription: null);
      var requestCount = 0;
      final client = WebPushSubscriptionClient(
        baseUrl: 'https://api.example.test',
        idTokenProvider: () async => 'google-id-token',
        vapidPublicKey: 'public-vapid-key',
        browserBridge: bridge,
        httpClient: MockClient((request) async {
          requestCount++;
          return http.Response('', 500);
        }),
      );

      expect(await client.unsubscribe(), isFalse);
      expect(requestCount, 0);
    });

    test('rejects subscription when VAPID public key is not configured', () async {
      final bridge = FakeWebPushBrowserBridge();
      final client = WebPushSubscriptionClient(
        baseUrl: 'https://api.example.test',
        idTokenProvider: () async => 'google-id-token',
        browserBridge: bridge,
      );

      expect(client.isConfigured, isFalse);
      await expectLater(client.subscribe(), throwsStateError);
      expect(bridge.subscribeCalls, 0);
    });

    test('rejects subscription when browser push is unsupported', () async {
      final bridge = FakeWebPushBrowserBridge(supported: false);
      final client = WebPushSubscriptionClient(
        baseUrl: 'https://api.example.test',
        idTokenProvider: () async => 'google-id-token',
        vapidPublicKey: 'public-vapid-key',
        browserBridge: bridge,
      );

      expect(client.isSupported, isFalse);
      await expectLater(client.subscribe(), throwsStateError);
    });
  });
}
