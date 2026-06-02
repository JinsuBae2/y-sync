importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

// 💡 파이어베이스 웹 앱 자격증명 초기화 (DefaultFirebaseOptions.web과 동일)
firebase.initializeApp({
  apiKey: "AIzaSyCwDB6j1dqGKvatzelm2gWuVGg1po1IpPs",
  authDomain: "y-sync-31c03.firebaseapp.com",
  projectId: "y-sync-31c03",
  storageBucket: "y-sync-31c03.firebasestorage.app",
  messagingSenderId: "286554208893",
  appId: "1:286554208893:web:4aa14d68c67fad602f0f14",
  measurementId: "G-R9W2QECVHM"
});

const messaging = firebase.messaging();

// 💡 백그라운드 메시지 수신 시 알림 노출 처리
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] 백그라운드 메시지 수신: ', payload);
  
  // 💡 payload.notification이 존재하면 Firebase Web SDK가 백그라운드에서 자동으로 알림을 띄우므로,
  // 중복 노출을 차단하기 위해 여기서 수동으로 showNotification을 호출하지 않고 조기 리턴합니다.
  if (payload.notification) {
    return;
  }

  const notificationTitle = 'Y-Sync 알림';
  const notificationOptions = {
    body: payload.data ? payload.data.body || '' : '',
    icon: '/favicon.png', // 파비콘을 아이콘으로 사용
    data: payload.data
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
