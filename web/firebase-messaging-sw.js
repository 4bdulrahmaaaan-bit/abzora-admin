importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDd81xKreHN5nyJiY-xbpMpruuXc9dV8uk",
  authDomain: "abzora-bbed7.firebaseapp.com",
  projectId: "abzora-bbed7",
  storageBucket: "abzora-bbed7.firebasestorage.app",
  messagingSenderId: "473004460649",
  appId: "1:473004460649:web:688a272c89d6e8e902b0f8",
  measurementId: "G-NYSLMQY368"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Background message received:", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/icons/Icon-192.png",
  };

  return self.registration.showNotification(
    notificationTitle,
    notificationOptions
  );
});
