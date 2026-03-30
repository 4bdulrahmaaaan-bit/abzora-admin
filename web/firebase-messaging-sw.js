importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDMXyII9XqX8lMvFrObqFoVPD9RMO29Qis",
  authDomain: "abzio-d99f9.firebaseapp.com",
  projectId: "abzio-d99f9",
  storageBucket: "abzio-d99f9.firebasestorage.app",
  messagingSenderId: "886864255867",
  appId: "1:886864255867:web:8c6f95135c1a8f5b72fbde",
  measurementId: "G-4C2J7FVZME"
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
