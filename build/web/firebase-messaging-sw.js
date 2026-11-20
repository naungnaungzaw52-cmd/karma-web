importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyA19cStdrP3jgW0o4w2UfJ1HXdDSiikOGQ",
  authDomain: "karmaapp-84aca.firebaseapp.com",
  projectId: "karmaapp-84aca",
  storageBucket: "karmaapp-84aca.firebasestorage.app",
  messagingSenderId: "386912084170",
  appId: "1:386912084170:web:fb70d44b1303e431d1d433"
});

const messaging = firebase.messaging();

// Background Message လက်ခံရန်
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  const notificationTitle =
  payload.data?.title || payload.notification?.title || 'Karma Myanmar';
const notificationBody =
  payload.data?.body || payload.data?.message || payload.notification?.body || 'New notification';

  const rawAvatar =
    payload.data?.icon ||
    payload.data?.callerAvatar ||
    payload.data?.avatar ||
    '';

  const hasValidAvatar =
    typeof rawAvatar === 'string' &&
    (rawAvatar.startsWith('https://') || rawAvatar.startsWith('http://'));

  const notificationURL = self.location.origin + '/';

  const notificationOptions = {
    body: notificationBody,
    ...(hasValidAvatar ? { icon: rawAvatar } : { icon: '/icons/Icon-192.png' }),
    badge: '/icons/Icon-192.png',
    data: { url: notificationURL },
  };

  return self.registration.showNotification(
    notificationTitle,
    notificationOptions
  );
});

// Notification ကို နှိပ်လိုက်သည့်အခါ လုပ်ဆောင်မည့် Event
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const targetUrl = event.notification.data?.url || '/';

  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((windowClients) => {
        for (let i = 0; i < windowClients.length; i++) {
          const client = windowClients[i];
          if (client.url === targetUrl && 'focus' in client) {
            return client.focus();
          }
        }
        if (clients.openWindow) {
          return clients.openWindow(targetUrl);
        }
      })
  );
});