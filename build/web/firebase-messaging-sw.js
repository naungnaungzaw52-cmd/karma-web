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
  
  // Worker မှ ပို့လိုက်သော data ထဲမှ title, body နှင့် avatar ကို ဦးစားပေးဖမ်းယူခြင်း
  const notificationTitle = payload.data?.title || payload.notification?.title || 'Karma Myanmar 🌐';
  const notificationBody = payload.data?.body || payload.notification?.body || '';
  const userAvatar = payload.data?.callerAvatar || payload.data?.avatar || '/icons/Icon-192.png';
  
  // click နှိပ်ရင် ဖွင့်မယ့် URL
  const notificationURL = self.location.origin + '/'; 

  const notificationOptions = {
    body: notificationBody,
    icon: userAvatar, // User Avatar ပုံ အမှန်တကယ် ပေါ်လာပါမည်
    badge: '/icons/Icon-192.png',
    data: { url: notificationURL } // URL ကို data ထဲမှာ ထည့်ပေးခြင်း
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Notification ကို နှိပ်လိုက်သည့်အခါ လုပ်ဆောင်မည့် Event
self.addEventListener('notificationclick', (event) => {
  event.notification.close(); // Notification ကို ပိတ်မည်

  const targetUrl = event.notification.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      // ဖွင့်ထားပြီးသား Tab ရှိရင် အဲ့ဒီ Tab ဆီကို သွားမည် (Focus လုပ်မည်)
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i];
        if (client.url === targetUrl && 'focus' in client) {
          return client.focus();
        }
      }
      // မရှိသေးရင် Tab အသစ်နဲ့ ဖွင့်ပေးမည်
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});