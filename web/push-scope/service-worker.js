/* Web Push worker kept in its own scope to avoid replacing Flutter's worker. */
self.addEventListener('push', (event) => {
  let payload = {};
  if (event.data) {
    try {
      payload = event.data.json();
    } catch (_) {
      payload = { body: event.data.text() };
    }
  }

  const title = typeof payload.title === 'string' && payload.title.trim()
    ? payload.title
    : 'Shift Tools';
  const options = {
    body: typeof payload.body === 'string' ? payload.body : '',
    icon: '../icons/Icon-192.png',
    badge: '../icons/Icon-192.png',
    tag: typeof payload.tag === 'string' ? payload.tag : 'shift-tools-notification',
    data: {
      url: typeof payload.url === 'string' ? payload.url : '../',
    },
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const requested = event.notification.data && event.notification.data.url;
  const target = new URL(
    typeof requested === 'string' ? requested : '../',
    self.registration.scope,
  );

  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    for (const client of windows) {
      if (client.url.startsWith(self.location.origin) && 'focus' in client) {
        await client.focus();
        if ('navigate' in client && client.url !== target.href) {
          await client.navigate(target.href);
        }
        return;
      }
    }
    await self.clients.openWindow(target.href);
  })());
});
