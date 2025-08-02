import 'dart:developer';
import 'dart:io'; // Import for Platform check

import 'package:device_info_plus/device_info_plus.dart'; // Import device_info_plus
import 'package:flutter/widgets.dart';
import 'package:get_storage/get_storage.dart';

import '../Login/LoginWithMpinScreen.dart';
import 'Login/LoginScreen.dart'; // Assuming EnterMobileScreen is defined here

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final storage =
      GetStorage(); // Use 'storage' as the variable name for consistency

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _getAndSaveDeviceInfo(); // Call the new method to get and save device info

      Future.delayed(const Duration(seconds: 3), () {
        final isLoggedIn = storage.read('isLoggedIn') ?? false;
        final target = isLoggedIn
            ? const LoginWithMpinScreen()
            : const EnterMobileScreen(); // Assuming EnterMobileScreen is the correct class name

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => target,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      });
    });
  }

  Future<void> _getAndSaveDeviceInfo() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    String? deviceId;
    String? deviceName;

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        deviceId = androidInfo.id; // Unique ID for Android device
        deviceName = androidInfo.model; // Model name for Android device
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        deviceId = iosInfo.identifierForVendor; // Unique ID for iOS device
        deviceName = iosInfo.name; // Device name for iOS device
      }
      // You can add more platforms (Linux, Windows, macOS, Web) if needed
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
                  'assets/images/splash_img.jpeg',
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

// import 'package:flutter/widgets.dart';
// import 'package:get_storage/get_storage.dart';
//
// import '../Login/LoginWithMpinScreen.dart';
// import 'Login/LoginScreen.dart';
//
// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});
//
//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }
//
// class _SplashScreenState extends State<SplashScreen> {
//   final storage = GetStorage();
//
//   @override
//   void initState() {
//     super.initState();
//
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       Future.delayed(const Duration(seconds: 3), () {
//         final isLoggedIn = storage.read('isLoggedIn') ?? false;
//         final target = isLoggedIn
//             ? const LoginWithMpinScreen()
//             : const EnterMobileScreen();
//
//         Navigator.of(context).pushReplacement(
//           PageRouteBuilder(
//             pageBuilder: (context, animation, secondaryAnimation) => target,
//             transitionsBuilder:
//                 (context, animation, secondaryAnimation, child) {
//                   return FadeTransition(opacity: animation, child: child);
//                 },
//             transitionDuration: const Duration(milliseconds: 500),
//           ),
//         );
//       });
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Directionality(
//       textDirection: TextDirection.ltr,
//       child: SizedBox.expand(
//         child: Stack(
//           children: [
//             Positioned.fill(
//               child: Image.asset(
//                 'assets/images/splash_img.jpeg',
//                 fit: BoxFit.cover,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
