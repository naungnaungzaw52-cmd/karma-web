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
  
  // Worker မှ ပို့လိုက်သော data ထဲမှ အချက်အလက်များကို ဖမ်းယူခြင်း
  const notificationTitle = payload.data?.title || payload.notification?.title || 'Karma Myanmar 🌐';
  const notificationBody = payload.data?.body || payload.notification?.body || '';
  
  // User ၏ Profile ပုံ (သို့မဟုတ် Avatar) ကို payload ထဲမှ သေချာထုတ်ယူခြင်း
  // 🌟 နောက်က Default ပုံလင့်ခ်ကြီးကို ဖြုတ်ပြီး '' (အလွတ်) သို့မဟုတ် null ထားလိုက်ပါ
  const userAvatar = payload.data?.icon || payload.data?.callerAvatar || payload.data?.avatar || '';
  
  const notificationURL = self.location.origin + '/'; 

  const notificationOptions = {
    body: notificationBody,
    icon: userAvatar,   // 🌟 ဒီနေရာမှာ User ရဲ့ တကယ့် Profile ပုံ (Avatar) ကို ထည့်ပေးခြင်း
    badge: '/icons/Icon-192.png',
    data: { url: notificationURL }
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Notification ကို နှိပ်လိုက်သည့်အခါ လုပ်ဆောင်မည့် Event
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const targetUrl = event.notification.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
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