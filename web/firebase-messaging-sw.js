importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAbUy6RRwZrmJ_jpRfiMpYuoqSRcQbykVQ',
  authDomain: 'powershare-90bd1.firebaseapp.com',
  projectId: 'powershare-90bd1',
  storageBucket: 'powershare-90bd1.firebasestorage.app',
  messagingSenderId: '1079571686030',
  appId: '1:1079571686030:web:2cc375300b2292e6db1fdf',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const title = payload.notification?.title || payload.data?.title || 'إشعار جديد';
  const body = payload.notification?.body || payload.data?.body || '';
  self.registration.showNotification(title, {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  });
});
