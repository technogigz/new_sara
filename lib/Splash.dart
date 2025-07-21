import 'dart:convert';
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

import '../login/LoginScreen.dart';
import '../Login/LoginWithMpinScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final storage = GetStorage();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await hitApi();

      Future.delayed(const Duration(seconds: 3), () {
        final isLoggedIn = storage.read('is_logged_in') ?? false;
        final target = isLoggedIn ? const LoginWithMpinScreen() : const EnterMobileScreen();

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => target,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
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
    );
  }

  Future<void> hitApi() async {
    final url = Uri.parse("https://sara777.win/api-get-app-key");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"env_type": "Prod"}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final appKey = json['app_key'];

        log("✅ App Key: $appKey");
        storage.write('app_key', appKey);

        log("✅ API Response: $json");
      } else {
        log("❌ API Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      log("⚠️ Exception while calling API: $e");
    }
  }
}


// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:new_sara/Login/LoginWithMpinScreen.dart';
// import '../login/LoginScreen.dart';
// import 'package:http/http.dart' as http;
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
//
//       await hitApi();
//
//       Future.delayed(const Duration(seconds: 3), () {
//         final isLoggedIn = storage.read('is_logged_in') ?? false;
//
//         if (isLoggedIn) {
//           // Navigate to home screen if user is already logged in
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (_) => const LoginWithMpinScreen()),
//           );
//         } else {
//           // Navigate to mobile screen for login
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (_) => const EnterMobileScreen()),
//           );
//         }
//       });
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: LayoutBuilder(
//         builder: (context, constraints) {
//           final height = constraints.maxHeight;
//           final width = constraints.maxWidth;
//
//           return Stack(
//             children: [
//               // 🔥 Full-screen background image
//               Positioned.fill(
//                 child: Image.asset(
//                   'assets/images/splash_img.jpeg', // Change this path as needed
//                   fit: BoxFit.cover,
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
//
//   Future<void> hitApi() async {
//       final url = Uri.parse("https://app.sara777.co.in/api-get-app-key");
//
//       try {
//         final response = await http.post(
//           url,
//           headers: {"Content-Type": "application/json"},
//           body: jsonEncode({"env_type": "Prod"}),
//         );
//
//         if (response.statusCode == 200) {
//           final json = jsonDecode(response.body);
//           final appKey = json['app_key'];
//
//           log("✅ App Key: $appKey");
//           storage.write('app_key', appKey);
//
//           log("✅ API Response: $json");
//         } else {
//           log("❌ API Error: ${response.statusCode} - ${response.body}");
//         }
//       } catch (e) {
//         log("⚠️ Exception while calling API: $e");
//       }
//   }
//
// }
