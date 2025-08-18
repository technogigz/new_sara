import 'dart:developer';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';

import 'Login/LoginScreen.dart'; // Assuming this is EnterMobileScreen
import 'Login/LoginWithMpinScreen.dart';
import 'firebase_options.dart'; // Required for Firebase.initializeApp

final storage = GetStorage();
String? fcmToken;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Background FCM handler - Must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  _showFlutterNotification(message);
  log("🔔 Background message received: ${message.messageId}");
}

/// Notification display logic
@pragma('vm:entry-point')
Future<void> _showFlutterNotification(RemoteMessage message) async {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;

  if (notification != null && android != null) {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'default_channel',
          'Default Channel',
          channelDescription: 'This channel is used for default notifications.',
          icon: 'notification_icon', // <- आइकन का नाम
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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAllDependencies();
  }

  Future<void> _initializeAllDependencies() async {
    try {
      log("🚀 Starting all initializations...");

      // 1. Check for internet connectivity first
      if (await hasInternetConnection()) {
        log("✅ Internet connection found.");
      } else {
        log("❌ No internet connection. Skipping Firebase init.");
        // Handle no internet gracefully, e.g., show an error or retry button
        await Future.delayed(const Duration(seconds: 3));
        _navigateToNextScreen();
        return;
      }

      // 2. Initialize Firebase and GetStorage
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await GetStorage.init();
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      log("✅ Firebase and GetStorage initialized.");

      // 3. Request Notification Permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        log('✅ User granted permission.');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        log('✅ User granted provisional permission.');
      } else {
        log('❌ User declined or has not yet accepted permission.');
        // You can handle this case by showing a message to the user
        // or opening app settings for them to enable it manually.
      }

      // 4. Local notification config
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
      );
      await flutterLocalNotificationsPlugin.initialize(initSettings);
      log("✅ Local notifications initialized.");

      // 5. Get FCM token
      fcmToken = await messaging.getToken();
      if (fcmToken != null) {
        log("📲 FCM Token: $fcmToken");
        storage.write('fcmToken', fcmToken);
        await messaging.subscribeToTopic('All');
        log("✅ FCM token retrieved and subscribed to 'All' topic.");
      } else {
        log("❌ FCM Token is null.");
      }

      // 6. Set up FCM listeners
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('📥 Foreground message: ${message.notification?.title}');
        _showFlutterNotification(message);
      });

      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          log('📬 Opened via terminated notification: ${message.messageId}');
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        log('📨 Opened via background notification: ${message.messageId}');
      });
      log("✅ FCM listeners set up.");

      // 7. Get and save device info
      await _getAndSaveDeviceInfo();

      log("🎉 All initializations complete.");
    } catch (e) {
      log("🚨 Fatal error during initialization: $e");
      // Handle fatal errors, e.g., show an error screen
    } finally {
      // Always navigate to the next screen after a delay, regardless of success or failure
      Future.delayed(const Duration(seconds: 3), () {
        _navigateToNextScreen();
      });
    }
  }

  Future<void> _getAndSaveDeviceInfo() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    String? deviceId;
    String? deviceName;

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        deviceId = androidInfo.id;
        deviceName = androidInfo.model;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        deviceId = iosInfo.identifierForVendor;
        deviceName = iosInfo.name;
      }
    } catch (e) {
      log('Error getting device info: $e');
    }

    if (deviceId != null) {
      await storage.write('deviceId', deviceId);
      log('Device ID saved: $deviceId');
    }
    if (deviceName != null) {
      await storage.write('deviceName', deviceName);
      log('Device Name saved: $deviceName');
    }
  }

  void _navigateToNextScreen() {
    final isLoggedIn = storage.read('isLoggedIn') ?? false;
    final target = isLoggedIn
        ? const LoginWithMpinScreen()
        : const EnterMobileScreen(); // Corrected class name as per your import

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => target,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<bool> hasInternetConnection() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SafeArea(
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/splash_img.png',
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
