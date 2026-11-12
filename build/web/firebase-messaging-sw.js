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

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  // Payload ထဲက data (သို့မဟုတ်) notification ထဲပါလာတဲ့ အချက်အလက်များကို ဆွဲထုတ်ခြင်း
  const notificationTitle = payload.notification?.title || payload.data?.title || 'Karma Myanmar';
  const notificationBody = payload.notification?.body || payload.data?.body || '';
  
  // Worker က ပို့လိုက်တဲ့ User Avatar (Image) ကို ဖမ်းယူခြင်း (မပါရင် Default ပုံသုံးမည်)
  const userAvatar = payload.data?.callerAvatar || payload.data?.avatar || '/icons/Icon-192.png';
  
  const notificationURL = self.location.origin + '/'; 

  const notificationOptions = {
    body: notificationBody,
    icon: userAvatar, // User Image ကို ဤနေရာတွင် တိုက်ရိုက် သုံးမည်
    badge: '/icons/Icon-192.png',
    data: { url: notificationURL }
  };

  // တစ်ကြိမ်တည်းသာ သေချာ ထုတ်ပြမည်
  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Notification ကို နှိပ်လိုက်သည့်အခါ App ဆီသို့ ရောက်သွားစေရန်
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