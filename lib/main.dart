import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';

import 'Splash.dart';
import 'firebase_options.dart';

final storage = GetStorage();
String? fcmToken;

// Local Notification Plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Background FCM handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  _showFlutterNotification(message); // Show notification in background
  log("🔔 Background message received: ${message.messageId}");
}

/// Notification display logic
Future<void> _showFlutterNotification(RemoteMessage message) async {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;

  if (notification != null && android != null) {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'default_channel', // must match channel ID
          'Default Channel',
          channelDescription: 'This channel is used for default notifications.',
          icon: 'ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformDetails,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await GetStorage.init();

    // Local notification config
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // iOS permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      log("📲 FCM Token: $fcmToken");
      storage.write('fcmToken', fcmToken);

      // Subscribe to topics
      await FirebaseMessaging.instance.subscribeToTopic('All');
      // await FirebaseMessaging.instance.subscribeToTopic('game');
      // await FirebaseMessaging.instance.subscribeToTopic('jackpot');
      // await FirebaseMessaging.instance.subscribeToTopic('starline');
    }

    runApp(const MyApp());
  } catch (e) {
    log("❌ Init error: $e");
    runApp(ErrorApp(errorMessage: "Failed to initialize: $e"));
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // Foreground notification handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('📥 Foreground message: ${message.notification?.title}');
      _showFlutterNotification(message); // Show native notification
    });

    // App launched from notification (terminated)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        log('📬 Opened via terminated notification: ${message.messageId}');
      }
    });

    // App resumed from background notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('📨 Opened via background notification: ${message.messageId}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sara777',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String errorMessage;
  const ErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    log('❗ Startup error:\n$errorMessage');
    return MaterialApp(
      title: 'Sara777',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '❗ Startup error:\n$errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

/*
*  Coded by Me
* */

// import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:new_sara/Splash.dart'; // Ensure Splash.dart exists and has visible content
//
// import 'firebase_options.dart'; // Import the generated Firebase options
//
// final storage = GetStorage();
// // Make fcmToken nullable and initialize it later
// String? fcmToken;
//
// void main() async {
//   // Ensure Flutter widgets are initialized before any Flutter-specific calls
//   WidgetsFlutterBinding.ensureInitialized();
//
//   try {
//     // 1. Initialize Firebase first. This is crucial for all Firebase services.
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     );
//
//     // 2. Initialize GetStorage. This can happen after Firebase.
//     await GetStorage.init();
//
//     // 3. Now that Firebase is initialized, safely get the FCM token.
//     // Handle the possibility of getToken() returning null by providing a default or checking.
//     fcmToken = await FirebaseMessaging.instance.getToken();
//     if (fcmToken != null) {
//       log("FCM Token: $fcmToken"); // For debugging: log the token
//       // You might want to store this token or send it to your backend here
//       storage.write('fcmToken', fcmToken); // Example of storing it
//     } else {
//       log(
//         "FCM Token is null. Check Firebase Messaging setup and permissions.",
//       );
//     }
//
//     // Run the app after all essential initializations are complete
//     runApp(const MyApp());
//   } catch (e) {
//     // Catch any errors during initialization and log them for debugging
//     log("Error during app initialization: $e");
//     // Optionally, show an error screen instead of a blank one
//     runApp(ErrorApp(errorMessage: "Failed to initialize: $e"));
//   }
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Sara777',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//         useMaterial3: true, // Recommended for modern Flutter apps
//       ),
//       home: const SplashScreen(),
//     );
//   }
// }
//
// // A simple error widget to display if initialization fails
// class ErrorApp extends StatelessWidget {
//   final String errorMessage;
//   const ErrorApp({super.key, required this.errorMessage});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text('Error')),
//         body: Center(
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Text(
//               'An error occurred during startup:\n$errorMessage',
//               textAlign: TextAlign.center,
//               style: const TextStyle(color: Colors.red, fontSize: 16),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

/*
*  Code Provided by Raushan Sir
* */
// in this we have to setup the background Notification
//
// import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:new_sara/Splash.dart'; // Ensure Splash.dart exists and has visible content
//
// import 'firebase_options.dart'; // Import the generated Firebase options
//
// final storage = GetStorage();
// // Make fcmToken nullable and initialize it later
// String? fcmToken;
//
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// }
//
// void main() async {
//   // Ensure Flutter widgets are initialized before any Flutter-specific calls
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // try {
//   //   // 1. Initialize Firebase first. This is crucial for all Firebase services.
//   //   await Firebase.initializeApp(
//   //     options: DefaultFirebaseOptions.currentPlatform,
//   //   );
//   //
//   //   // 2. Initialize GetStorage. This can happen after Firebase.
//   //   await GetStorage.init();
//   //
//   //   // 3. Now that Firebase is initialized, safely get the FCM token.
//   //   // Handle the possibility of getToken() returning null by providing a default or checking.
//   //   fcmToken = await FirebaseMessaging.instance.getToken();
//   //   if (fcmToken != null) {
//   //     log("FCM Token: $fcmToken"); // For debugging: log the token
//   //     // You might want to store this token or send it to your backend here
//   //     storage.write('fcmToken', fcmToken); // Example of storing it
//   //   } else {
//   //     log(
//   //       "FCM Token is null. Check Firebase Messaging setup and permissions.",
//   //     );
//   //   }
//
//   // Run the app after all essential initializations are complete
//   runApp(const MyApp());
//   // } catch (e) {
//   //   // Catch any errors during initialization and log them for debugging
//   //   log("Error during app initialization: $e");
//   //   // Optionally, show an error screen instead of a blank one
//   //   runApp(ErrorApp(errorMessage: "Failed to initialize: $e"));
//   // }
// }
//
//
// Future<void> initialize(BuildContext context) async {
//   AndroidNotificationChannel channel = const AndroidNotificationChannel(
//     'high_importance_channel', // id
//     'High Importance Notifications', // title
//     importance: Importance.high,
//   );
//
//   await FlutterLocalNotificationsPlugin()
//       .resolvePlatformSpecificImplementation<
//       AndroidFlutterLocalNotificationsPlugin>()
//       ?.createNotificationChannel(channel);
// }
//
// void display(RemoteMessage message) async {
//   try {
//     log("&rex& notification location ${message.notification!.body}");
//     if (message.notification != null && message.notification!.body != null) {
//       RegExp regExp =
//       RegExp(r'latitute:\s*(-?\d+\.\d+),\s*longitude:\s*(-?\d+\.\d+)');
//       Iterable<Match> matches =
//       regExp.allMatches('${message.notification!.body}');
//       if (matches.isNotEmpty) {
//         Match match = matches.first;
//         String? latitude = match.group(1);
//         String? longitude = match.group(2);
//         if (latitude != null && longitude != null) {
//           final controllerRideDetails = Get.put(RideDetailsController());
//           controllerRideDetails.updateCameraPosition(latitude, longitude);
//         }
//       } else {
//         final newController = Get.put(NewRideController());
//         newController.getStatus();
//       }
//     }
//
//     final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
//     const NotificationDetails notificationDetails = NotificationDetails(
//         android: AndroidNotificationDetails(
//           "01",
//           "Cranes24",
//           importance: Importance.max,
//           priority: Priority.high,
//           icon: '@mipmap/ic_launcher',
//         ));
//
//     await FlutterLocalNotificationsPlugin().show(
//       id,
//       message.notification!.title,
//       message.notification!.body,
//       notificationDetails,
//       payload: jsonEncode(message.data),
//     );
//   } on Exception catch (e) {
//     debuglog(e.toString());
//   }
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   Future<void> setupInteractedMessage(BuildContext context) async {
//     initialize(context);
//     RemoteMessage? initialMessage =
//     await FirebaseMessaging.instance.getInitialMessage();
//     if (initialMessage != null) {
//       debuglog(
//           'Message also contained a notification: ${initialMessage.notification!.body}');
//     }
//
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       if (message.notification != null) {
//         display(message);
//       }
//     });
//
//     @override
//     Widget build(BuildContext context) {
//       return MaterialApp(
//         title: 'Sara777',
//         debugShowCheckedModeBanner: false,
//         theme: ThemeData(
//           colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//           useMaterial3: true, // Recommended for modern Flutter apps
//         ),
//         home: const SplashScreen(),
//       );
//     }
//   }
//
// // A simple error widget to display if initialization fails
//   class ErrorApp extends StatelessWidget {
//   final String errorMessage;
//   const ErrorApp({super.key, required this.errorMessage});
//
//   @override
//   Widget build(BuildContext context) {
//   return MaterialApp(
//   home: Scaffold(
//   appBar: AppBar(title: const Text('Error')),
//   body: Center(
//   child: Padding(
//   padding: const EdgeInsets.all(16.0),
//   child: Text(
//   'An error occurred during startup:\n$errorMessage',
//   textAlign: TextAlign.center,
//   style: const TextStyle(color: Colors.red, fontSize: 16),
//   ),
//   ),
//   ),
//   ),
//   );
//   }
//   }
//
// // import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
// // import 'package:firebase_messaging/firebase_messaging.dart';
// // import 'package:flutter/material.dart';
// // import 'package:get_storage/get_storage.dart';
// // import 'package:new_sara/Splash.dart';
// //
// // import 'firebase_options.dart'; // Import the generated Firebase options
// //
// // final storage = GetStorage();
// // late final String fcmToken;
// //
// // void main() async {
// //   WidgetsFlutterBinding.ensureInitialized();
// //   // Get and store FCM token
// //   fcmToken = (await FirebaseMessaging.instance.getToken())!;
// //   // Initialize Firebase here
// //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// //
// //   await GetStorage.init(); // 🔥 THIS IS REQUIRED
// //   runApp(const MyApp());
// // }
// //
// // class MyApp extends StatelessWidget {
// //   const MyApp({super.key});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return MaterialApp(
// //       title: 'Sara777',
// //       debugShowCheckedModeBanner: false,
// //       theme: ThemeData(
// //         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
// //       ),
// //       home: const SplashScreen(),
// //     );
// //   }
// // }
