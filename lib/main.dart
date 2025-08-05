import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import 'Splash.dart';

void main() async {
  // Ensure that Flutter bindings are initialized before any plugin calls
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  // The app now starts directly with the SplashScreen
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sara777',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // The home screen is now the SplashScreen, which handles all initialization
      home: const SplashScreen(),
    );
  }
}

// import 'dart:developer';
//
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:get_storage/get_storage.dart';
//
// import 'Splash.dart';
// import 'firebase_options.dart';
//
// final storage = GetStorage();
// String? fcmToken;
//
// // Local Notification Plugin
// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//     FlutterLocalNotificationsPlugin();
//
// /// Background FCM handler
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   _showFlutterNotification(message);
//   log("🔔 Background message received: ${message.messageId}");
// }
//
// /// Notification display logic
// Future<void> _showFlutterNotification(RemoteMessage message) async {
//   RemoteNotification? notification = message.notification;
//   AndroidNotification? android = message.notification?.android;
//
//   if (notification != null && android != null) {
//     const AndroidNotificationDetails androidDetails =
//         AndroidNotificationDetails(
//           'default_channel',
//           'Default Channel',
//           channelDescription: 'This channel is used for default notifications.',
//           icon: 'ic_launcher',
//           importance: Importance.max,
//           priority: Priority.high,
//           playSound: true,
//         );
//
//     const NotificationDetails platformDetails = NotificationDetails(
//       android: androidDetails,
//     );
//
//     await flutterLocalNotificationsPlugin.show(
//       notification.hashCode,
//       notification.title,
//       notification.body,
//       platformDetails,
//     );
//   }
// }
//
// /// App Initialization Logic
// Future<void> initializeApp() async {
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   await GetStorage.init();
//
//   // Local notification config
//   const AndroidInitializationSettings androidInit =
//       AndroidInitializationSettings('ic_launcher');
//   const InitializationSettings initSettings = InitializationSettings(
//     android: androidInit,
//   );
//   await flutterLocalNotificationsPlugin.initialize(initSettings);
//
//   // iOS permission
//   await FirebaseMessaging.instance.requestPermission(
//     alert: true,
//     badge: true,
//     sound: true,
//   );
//
//   // Get FCM token
//   fcmToken = await FirebaseMessaging.instance.getToken();
//   if (fcmToken != null) {
//     log("📲 FCM Token: $fcmToken");
//
//     storage.write('fcmToken', fcmToken);
//
//     await FirebaseMessaging.instance.subscribeToTopic('All');
//     // Optionally:
//     // await FirebaseMessaging.instance.subscribeToTopic('game');
//     // await FirebaseMessaging.instance.subscribeToTopic('jackpot');
//     // await FirebaseMessaging.instance.subscribeToTopic('starline');
//   }
// }
//
// /// Check for internet connectivity.
// Future<bool> hasInternetConnection() async {
//   final connectivityResult = await (Connectivity().checkConnectivity());
//   return !connectivityResult.contains(ConnectivityResult.none);
// }
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//
//   await initializeApp();
//   runApp(const MyApp());
// }
//
// class MyApp extends StatefulWidget {
//   const MyApp({super.key});
//
//   @override
//   State<MyApp> createState() => _MyAppState();
// }
//
// class _MyAppState extends State<MyApp> {
//   @override
//   void initState() {
//     super.initState();
//
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       log('📥 Foreground message: ${message.notification?.title}');
//       _showFlutterNotification(message);
//     });
//
//     FirebaseMessaging.instance.getInitialMessage().then((message) {
//       if (message != null) {
//         log('📬 Opened via terminated notification: ${message.messageId}');
//       }
//     });
//
//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//       log('📨 Opened via background notification: ${message.messageId}');
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Sara777',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//         useMaterial3: true,
//       ),
//       home: const SplashScreen(),
//     );
//   }
// }
