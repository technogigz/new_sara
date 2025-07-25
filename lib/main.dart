import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:new_sara/Splash.dart'; // Ensure Splash.dart exists and has visible content

import 'firebase_options.dart'; // Import the generated Firebase options

final storage = GetStorage();
// Make fcmToken nullable and initialize it later
String? fcmToken;

void main() async {
  // Ensure Flutter widgets are initialized before any Flutter-specific calls
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Initialize Firebase first. This is crucial for all Firebase services.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. Initialize GetStorage. This can happen after Firebase.
    await GetStorage.init();

    // 3. Now that Firebase is initialized, safely get the FCM token.
    // Handle the possibility of getToken() returning null by providing a default or checking.
    fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      print("FCM Token: $fcmToken"); // For debugging: print the token
      // You might want to store this token or send it to your backend here
      storage.write('fcmToken', fcmToken); // Example of storing it
    } else {
      print(
        "FCM Token is null. Check Firebase Messaging setup and permissions.",
      );
    }

    // Run the app after all essential initializations are complete
    runApp(const MyApp());
  } catch (e) {
    // Catch any errors during initialization and print them for debugging
    print("Error during app initialization: $e");
    // Optionally, show an error screen instead of a blank one
    runApp(ErrorApp(errorMessage: "Failed to initialize: $e"));
  }
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
        useMaterial3: true, // Recommended for modern Flutter apps
      ),
      home: const SplashScreen(),
    );
  }
}

// A simple error widget to display if initialization fails
class ErrorApp extends StatelessWidget {
  final String errorMessage;
  const ErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'An error occurred during startup:\n$errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

// import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:new_sara/Splash.dart';
//
// import 'firebase_options.dart'; // Import the generated Firebase options
//
// final storage = GetStorage();
// late final String fcmToken;
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   // Get and store FCM token
//   fcmToken = (await FirebaseMessaging.instance.getToken())!;
//   // Initialize Firebase here
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//
//   await GetStorage.init(); // 🔥 THIS IS REQUIRED
//   runApp(const MyApp());
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
//       ),
//       home: const SplashScreen(),
//     );
//   }
// }
