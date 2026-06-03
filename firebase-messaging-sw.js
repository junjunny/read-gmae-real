// FCM 백그라운드 푸시 전용 서비스워커 (앱 캐싱과 무관 — 최신 로드에 영향 없음)
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyALbDTIYzifONaAOf6Vm-HgStxFXIf63_Y',
  authDomain: 'jhss-b6d35.firebaseapp.com',
  projectId: 'jhss-b6d35',
  messagingSenderId: '902175981455',
  appId: '1:902175981455:web:6cde16b67bcdbbedf895fa',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const n = payload.notification || {};
  self.registration.showNotification(n.title || 'JHS', {
    body: n.body || '',
    icon: '/read-gmae-real/icons/Icon-192.png',
    data: { link: (payload.fcmOptions && payload.fcmOptions.link) || 'https://junjunny.github.io/read-gmae-real/' },
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow(event.notification.data?.link || 'https://junjunny.github.io/read-gmae-real/'));
});
