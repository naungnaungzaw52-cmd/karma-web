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

// 🌟 Cache နာမည်နှင့် ကြိုတင်သိမ်းဆည်းမည့် Core Assets များ
const CACHE_NAME = 'karma-pwa-cache-v1';
const ASSETS_TO_CACHE = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/flutter.js',
  '/manifest.json',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png'
];

// 1. Install Event: Core Assets များကို Cache ထဲသို့ ကြိုတင်သိမ်းဆည်းခြင်း
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[Service Worker] Pre-caching offline assets');
      return cache.addAll(ASSETS_TO_CACHE);
    }).then(() => self.skipWaiting())
  );
});

// 2. Activate Event: Cache ဟောင်းများကို ရှင်းလင်းခြင်း
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            console.log('[Service Worker] Removing old cache:', key);
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// 3. Fetch Event: Cache First & Stale-While-Revalidate Strategy ဖြင့် Loading မြန်စေခြင်း
self.addEventListener('fetch', (event) => {
  // Firebase API သို့မဟုတ် Cloudflare Worker requests များကို Cache မလုပ်ရန် ကျော်သွားမည်
  if (event.request.url.includes('firestore.googleapis.com') || 
      event.request.url.includes('fcm.googleapis.com') || 
      event.request.url.includes('workers.dev')) {
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      // Cache ထဲမှာ ရှိပြီးသားဆိုရင် အဲ့ဒါကို ချက်ချင်းထုတ်ပြမည် (Instant Load)
      if (cachedResponse) {
        // နောက်ကွယ်မှာ ဆာဗာကနေ အသစ်ရှိမရှိ တိတ်တဆိတ် သွားဆွဲပြီး Cache ကို Update တင်မည်
        fetch(event.request).then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200 && networkResponse.type === 'basic') {
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, networkResponse);
            });
          }
        }).catch(() => {});
        
        return cachedResponse;
      }

      // Cache ထဲမှာ မရှိသေးရင် ဆာဗာဆီကနေ သွားဆွဲမည်
      return fetch(event.request).then((networkResponse) => {
        return caches.open(CACHE_NAME).then((cache) => {
          // ပုံမှန် static files များကို cache ထဲ သိမ်းမည်
          if (event.request.method === 'GET' && networkResponse.status === 200) {
            cache.put(event.request, networkResponse.clone());
          }
          return networkResponse;
        });
      }).catch(() => {
        // အင်တာနက်လိုင်း လုံးဝမရှိတော့သည့်အခါ index.html ကို ပြန်ပြပေးမည် (Offline Fallback)
        if (event.request.mode === 'navigate') {
          return caches.match('/index.html');
        }
      });
    })
  );
});

// Background Message လက်ခံရန် (Push Notification)
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.data?.title || payload.data?.callerName || 'Karma Myanmar 🌐';
  const notificationBody = payload.data?.body || '';
  const userAvatar = payload.data?.icon || payload.data?.callerAvatar || payload.data?.avatar || '';
  
  const notificationURL = self.location.origin + '/'; 

  const notificationOptions = {
    body: notificationBody,
    icon: userAvatar,
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