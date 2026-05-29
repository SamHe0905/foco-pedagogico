// Service Worker para FCM push notifications no Flutter Web.
// Firebase inicializa a versão compat (v8) no SW — obrigatório para flutter_firebase_messaging.

importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey:            'AIzaSyBfkQzNw18oRejjQ3wOPq6YxcpG_rDNxI4',
  authDomain:        'foco-pedagogico.firebaseapp.com',
  projectId:         'foco-pedagogico',
  storageBucket:     'foco-pedagogico.firebasestorage.app',
  messagingSenderId: '775783515922',
  appId:             '1:775783515922:web:5871609a2920e4c8d7d5cb',
});

const messaging = firebase.messaging();

// Exibe a notificação quando o app está em background / fechado
messaging.onBackgroundMessage(function(payload) {
  const title   = payload.notification?.title ?? 'Foco Pedagógico';
  const options = {
    body: payload.notification?.body ?? '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
  };
  self.registration.showNotification(title, options);
});

// Abre o app ao clicar na notificação
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const demandaId = event.notification.data?.demanda_id;
  const url = demandaId ? `/#/professor/demanda/${demandaId}` : '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(list) {
      for (const client of list) {
        if ('focus' in client) return client.focus();
      }
      return clients.openWindow(url);
    })
  );
});
