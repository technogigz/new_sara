import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import 'Splash.dart';

// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
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
