(() => {
  const supported = () =>
    'serviceWorker' in navigator &&
    'PushManager' in window &&
    'Notification' in window;

  const decodeKey = (value) => {
    const padding = '='.repeat((4 - (value.length % 4)) % 4);
    const base64 = (value + padding).replace(/-/g, '+').replace(/_/g, '/');
    const raw = atob(base64);
    return Uint8Array.from(raw, (character) => character.charCodeAt(0));
  };

  const serialize = (subscription) => {
    const json = subscription.toJSON();
    return {
      endpoint: json.endpoint,
      keys: {
        p256dh: json.keys && json.keys.p256dh,
        auth: json.keys && json.keys.auth,
      },
      contentEncoding: 'aes128gcm',
    };
  };

  window.shiftToolsPush = Object.freeze({
    isSupported: () => supported(),
    permission: () => supported() ? Notification.permission : 'unsupported',
    async subscribe(publicKey) {
      if (!supported()) throw new Error('Web Push is not supported by this browser.');
      if (!publicKey) throw new Error('Web Push is not configured.');
      const permission = await Notification.requestPermission();
      if (permission !== 'granted') {
        throw new Error('Notification permission was not granted.');
      }
      const workerUrl = new URL(
        'push-scope/service-worker.js',
        document.baseURI,
      );
      const scopeUrl = new URL('push-scope/', document.baseURI);
      const registration = await navigator.serviceWorker.register(
        workerUrl,
        { scope: scopeUrl.pathname },
      );
      const worker = registration.installing || registration.waiting || registration.active;
      if (worker && worker.state !== 'activated') {
        await new Promise((resolve, reject) => {
          worker.addEventListener('statechange', () => {
            if (worker.state === 'activated') resolve();
            if (worker.state === 'redundant') reject(new Error('Push worker activation failed.'));
          });
        });
      }
      let subscription = await registration.pushManager.getSubscription();
      if (!subscription) {
        subscription = await registration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: decodeKey(publicKey),
        });
      }
      return JSON.stringify(serialize(subscription));
    },
    async unsubscribe() {
      if (!supported()) return null;
      const registration = await navigator.serviceWorker.getRegistration(
        new URL('push-scope/', document.baseURI).pathname,
      );
      if (!registration) return null;
      const subscription = await registration.pushManager.getSubscription();
      if (!subscription) return null;
      const result = serialize(subscription);
      await subscription.unsubscribe();
      return JSON.stringify(result);
    },
  });
})();
