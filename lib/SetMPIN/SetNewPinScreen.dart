import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/HomeScreen/HomeScreen.dart';

import '../Helper/Toast.dart'; // Assuming this is your popToast
import '../ulits/ColorsR.dart';
import '../ulits/Constents.dart';

class SetNewPinScreen extends StatefulWidget {
  final String mobile;
  const SetNewPinScreen({super.key, required this.mobile});

  @override
  State<SetNewPinScreen> createState() => _SetNewPinScreenState();
}

class _SetNewPinScreenState extends State<SetNewPinScreen> {
  final TextEditingController otpController = TextEditingController();
  final TextEditingController pinController = TextEditingController();
  final storage = GetStorage();

  late Timer _timer;
  int _secondsRemaining = 4 * 60;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  void dispose() {
    _timer.cancel();
    otpController.dispose();
    pinController.dispose();
    super.dispose();
  }

  Future<void> setNewPin() async {
    final mobile = widget.mobile;
    final otp = otpController.text.trim();
    final newPin = pinController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      popToast(
        "Please enter a valid 6-digit OTP",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
      return;
    }

    if (newPin.isEmpty || newPin.length != 4) {
      popToast(
        "Please enter a 4-digit PIN",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
      return;
    }

    setState(() => isLoading = true);

    final body = {
      "mobileNo": int.tryParse(
        mobile,
      ), // Ensure mobile number is parsed as int if API expects it
      "otp": int.tryParse(otp),
      "security_pin": int.tryParse(newPin),
    };

    try {
      final response = await http.post(
        Uri.parse('${Constant.apiEndpoint}reset-mpin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print("📤 Request Body: $body");
      print("📥 Response: ${response.body}");

      final json = jsonDecode(response.body);
      final msg = json['msg'] ?? "Something went wrong";
      final status = json['status'] ?? false;

      if (status == true) {
        final info = json['info'];
        final registerId = info['registerId'];
        final accessToken = info['accessToken'];

        // ✅ Save to GetStorage
        storage.write('user_mpin', newPin);
        storage.write('registerId', registerId);
        storage.write('accessToken', accessToken);

        popToast(msg, 2, Colors.white, Colors.green);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        popToast(msg, 4, Colors.white, ColorsR.appColorRed);
      }
    } catch (e) {
      popToast("❌ Error: $e", 4, Colors.white, ColorsR.appColorRed);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Row(
                children: [
                  Container(width: 10, height: 50, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'SET NEW\nPIN',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60),
              const Text("Enter OTP"),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  cursorColor: Colors.amber,
                  controller: otpController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: "",
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
              ),
              const SizedBox(height: 25),
              const Text("Enter New mPin"),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  cursorColor: Colors.amber,
                  controller: pinController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: "",
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: isLoading ? null : setNewPin,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.amber)
                      : const Text(
                          "SET PIN",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Resend OTP in ${_formatTime(_secondsRemaining)}',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// import 'dart:async';
// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
//
// import '../Helper/Toast.dart'; // Assuming this is your popToast
// import '../Login/LoginWithMpinScreen.dart';
// import '../ulits/ColorsR.dart';
// import '../ulits/Constents.dart';
//
// class SetNewPinScreen extends StatefulWidget {
//   final String mobile;
//   const SetNewPinScreen({super.key, required this.mobile});
//
//   @override
//   State<SetNewPinScreen> createState() => _SetNewPinScreenState();
// }
//
// class _SetNewPinScreenState extends State<SetNewPinScreen> {
//   final TextEditingController otpController = TextEditingController();
//   final TextEditingController pinController = TextEditingController();
//   final storage = GetStorage();
//
//   late Timer _timer;
//   int _secondsRemaining = 4 * 60;
//   bool isLoading = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _startCountdown();
//   }
//
//   void _startCountdown() {
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_secondsRemaining > 0) {
//         setState(() {
//           _secondsRemaining--;
//         });
//       } else {
//         timer.cancel();
//       }
//     });
//   }
//
//   String _formatTime(int seconds) {
//     final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
//     final secs = (seconds % 60).toString().padLeft(2, '0');
//     return '$minutes:$secs';
//   }
//
//   @override
//   void dispose() {
//     _timer.cancel();
//     otpController.dispose();
//     pinController.dispose();
//     super.dispose();
//   }
//
//   // Future<void> setNewPin() async {
//   //   final mobile = widget.mobile;
//   //   final otp = otpController.text.trim();
//   //   final newPin = pinController.text.trim();
//   //
//   //   if (otp.isEmpty || otp.length != 6) {
//   //     popToast("Please enter a valid 6-digit OTP", 4, Colors.white, ColorsR.appColorRed);
//   //     return;
//   //   }
//   //
//   //   if (newPin.isEmpty || newPin.length != 4) {
//   //     popToast("Please enter a 4-digit PIN", 4, Colors.white, ColorsR.appColorRed);
//   //     return;
//   //   }
//   //
//   //   setState(() => isLoading = true);
//   //
//   //   final body = {
//   //     "app_key": GetStorage().read('app_key'),
//   //     "env_type": "Prod",
//   //     "mobile": mobile,
//   //     "otp": int.tryParse(otp),
//   //     "new_security_pin": int.tryParse(newPin),
//   //   };
//   //
//   //   try {
//   //     final response = await http.post(
//   //       Uri.parse('https://app.sara777.co.in/api-set-new-security-pin'),
//   //       headers: {
//   //         'Accept': 'application/json',
//   //         'Content-Type': 'application/json',
//   //       },
//   //       body: jsonEncode(body),
//   //     );
//   //
//   //     print("📤 Request Body: $body");
//   //     print("📥 Response: ${response.body}");
//   //
//   //     final json = jsonDecode(response.body);
//   //     final msg = json['msg'] ?? json['message'] ?? "Something went wrong";
//   //     final status = json['status'] ?? false;
//   //
//   //     if (status == true) {
//   //       storage.write('user_mpin', newPin);
//   //       popToast(msg, 2, Colors.white, Colors.green);
//   //
//   //       Navigator.pushReplacement(
//   //         context,
//   //         MaterialPageRoute(builder: (_) => const LoginWithMpinScreen()),
//   //       );
//   //     } else {
//   //       popToast(msg, 4, Colors.white, ColorsR.appColorRed);
//   //     }
//   //   } catch (e) {
//   //     popToast("❌ Error: $e", 4, Colors.white, ColorsR.appColorRed);
//   //   } finally {
//   //     setState(() => isLoading = false);
//   //   }
//   // }
//
//   Future<void> setNewPin() async {
//     final mobile = widget.mobile;
//     final otp = otpController.text.trim();
//     final newPin = pinController.text.trim();
//
//     if (otp.isEmpty || otp.length != 6) {
//       popToast(
//         "Please enter a valid 6-digit OTP",
//         4,
//         Colors.white,
//         ColorsR.appColorRed,
//       );
//       return;
//     }
//
//     if (newPin.isEmpty || newPin.length != 4) {
//       popToast(
//         "Please enter a 4-digit PIN",
//         4,
//         Colors.white,
//         ColorsR.appColorRed,
//       );
//       return;
//     }
//
//     setState(() => isLoading = true);
//
//     final body = {
//       "mobileNo": int.tryParse(mobile),
//       "otp": int.tryParse(otp),
//       "security_pin": int.tryParse(newPin),
//     };
//
//     try {
//       final response = await http.post(
//         Uri.parse('${Constant.apiEndpoint}reset-mpin'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode(body),
//       );
//
//       print("📤 Request Body: $body");
//       print("📥 Response: ${response.body}");
//
//       final json = jsonDecode(response.body);
//       final msg = json['msg'] ?? "Something went wrong";
//       final status = json['status'] ?? false;
//
//       if (status == true) {
//         final info = json['info'];
//         final registerId = info['registerId'];
//         final accessToken = info['accessToken'];
//
//         // ✅ Save to GetStorage
//         storage.write('user_mpin', newPin);
//         storage.write('registerId', registerId);
//         storage.write('accessToken', accessToken);
//
//         popToast(msg, 2, Colors.white, Colors.green);
//
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => const LoginWithMpinScreen()),
//         );
//       } else {
//         popToast(msg, 4, Colors.white, ColorsR.appColorRed);
//       }
//     } catch (e) {
//       popToast("❌ Error: $e", 4, Colors.white, ColorsR.appColorRed);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 20),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const SizedBox(height: 30),
//               Row(
//                 children: [
//                   Container(width: 10, height: 50, color: Colors.amber),
//                   const SizedBox(width: 8),
//                   Text(
//                     'SET NEW\nPIN',
//                     style: GoogleFonts.poppins(
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 60),
//               const Text("Enter OTP"),
//               const SizedBox(height: 10),
//               Container(
//                 width: double.infinity,
//                 height: 50,
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade200,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: TextField(
//                   cursorColor: Colors.amber,
//                   controller: otpController,
//                   decoration: const InputDecoration(
//                     border: InputBorder.none,
//                     counterText: "",
//                   ),
//                   keyboardType: TextInputType.number,
//                   maxLength: 6,
//                 ),
//               ),
//               const SizedBox(height: 25),
//               const Text("Enter New mPin"),
//               const SizedBox(height: 10),
//               Container(
//                 width: double.infinity,
//                 height: 50,
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade200,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: TextField(
//                   cursorColor: Colors.amber,
//                   controller: pinController,
//                   obscureText: true,
//                   decoration: const InputDecoration(
//                     border: InputBorder.none,
//                     counterText: "",
//                   ),
//                   keyboardType: TextInputType.number,
//                   maxLength: 4,
//                 ),
//               ),
//               const SizedBox(height: 40),
//               SizedBox(
//                 width: double.infinity,
//                 height: 50,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.amber,
//                     elevation: 4,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                   ),
//                   onPressed: isLoading ? null : setNewPin,
//                   child: isLoading
//                       ? const CircularProgressIndicator(color: Colors.amber)
//                       : const Text(
//                           "SET PIN",
//                           style: TextStyle(
//                             fontSize: 16,
//                             color: Colors.black,
//                             letterSpacing: 1.0,
//                           ),
//                         ),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Center(
//                 child: Text(
//                   'Resend OTP in ${_formatTime(_secondsRemaining)}',
//                   style: const TextStyle(fontSize: 14, color: Colors.black87),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
