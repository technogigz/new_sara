import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/Login/LoginWithMpinScreen.dart';

import '../../../ulits/ColorsR.dart';
import '../../Helper/Toast.dart';
import '../ulits/Constents.dart';
import 'LoginScreen.dart';

class VerifyMobileScreen extends StatefulWidget {
  const VerifyMobileScreen({super.key});

  @override
  State<VerifyMobileScreen> createState() => _VerifyMobileScreenState();
}

class _VerifyMobileScreenState extends State<VerifyMobileScreen> {
  final TextEditingController otpController = TextEditingController();
  final storage = GetStorage();
  int secondsRemaining = 240;
  Timer? timer;
  bool isResendVisible = false;
  bool isVerifying = false;

  @override
  void initState() {
    super.initState();
    startOtpTimer();
  }

  void startOtpTimer() {
    setState(() {
      secondsRemaining = 240;
      isResendVisible = false;
    });
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (secondsRemaining > 0) {
        setState(() => secondsRemaining--);
      } else {
        timer?.cancel();
        setState(() => isResendVisible = true);
      }
    });
  }

  String formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  Future<void> resendOtp() async {
    final mobile = storage.read('mobile');
    if (mobile == null) {
      print("📛 Mobile number not found in storage.");
      return;
    }

    final Uri url = Uri.parse('${Constant.apiEndpoint}send-otp');
    final Map<String, String> headers = {
      'deviceId': 'qwert',
      'deviceName': 'sm2233',
      'accessStatus': '1',
      'Content-Type': 'application/json',
    };
    final Map<String, dynamic> requestBody = {"mobileNo": mobile};

    print("📤 Sending OTP resend request...");
    print("🔗 URL: $url");
    print("🧾 Headers: $headers");
    print("📦 Body: $requestBody");

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      print("📥 Status Code: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      final json = jsonDecode(response.body);

      if (response.statusCode == 200 && json['status'] == true) {
        popToast("OTP resent successfully", 2, Colors.white, Colors.green);
        startOtpTimer();
      } else {
        final errorMsg = json['message'] ?? "Failed to resend OTP";
        popToast(errorMsg, 4, Colors.white, ColorsR.appColorRed);
        print("❌ Server Error: $errorMsg");
      }
    } catch (e) {
      popToast(
        "Something went wrong: $e",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
      print("❌ Exception: $e");
    }
  }

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();
    if (otp.isEmpty || otp.length != 6) {
      popToast(
        "Please enter a valid 6-digit OTP",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
      return;
    }

    final mobile = storage.read('mobile');
    final name = storage.read('username') ?? 'User';
    final mpin = storage.read('user_mpin');

    print("📦 Storage Values:");
    print("📱 mobile: $mobile");
    print("👤 name: $name");
    print("🔐 mpin: $mpin");

    if (mobile == null ||
        mpin == null ||
        mobile.toString().isEmpty ||
        mpin.toString().isEmpty) {
      popToast(
        "Missing registration data",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
      return;
    }

    final requestBody = {
      "fullName": name,
      "mobileNo": int.tryParse(mobile.toString()),
      "otp": int.tryParse(otp),
      "security_pin": int.tryParse(mpin.toString()),
    };

    print("📤 Sending request to /api/v1/user-register");
    print("🔍 Request Body: $requestBody");

    setState(() => isVerifying = true);

    try {
      final response = await http.post(
        Uri.parse('https://sara777.win/api/v1/user-register'),
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print("📥 Status Code: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      final json = jsonDecode(response.body);
      final status = json['status'];
      final msg = json['message'] ?? json['msg'] ?? "Something went wrong";

      if (status == true) {
        popToast("✅ $msg", 2, Colors.white, Colors.green);
        print("✅ Registration successful. Message: $msg");

        // Navigate to next screen
      } else {
        popToast("❌ $msg", 4, Colors.white, ColorsR.appColorRed);
        print("❌ Registration failed. Message: $msg");

        if (msg.toString().toLowerCase().contains("already registered")) {
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const EnterMobileScreen()),
            );
          });
        } else {
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginWithMpinScreen()),
            );
          });
        }
      }
    } catch (e) {
      popToast(
        "Something went wrong: $e",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
      print("❌ Exception during registration: $e");
    } finally {
      setState(() => isVerifying = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = storage.read('mobile') ?? 'XXXXXXXXXX';

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Container(width: 6, height: 40, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      "VERIFY YOUR MOBILE \nNUMBER",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Image.asset('assets/images/verification_avatar.png', height: 180),
              const SizedBox(height: 30),
              Text(
                "Verification Code",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We have sent the code verification to\nYour Mobile Number",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Text(
                mobile.toString(),
                style: GoogleFonts.poppins(
                  color: Colors.orange.shade800,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  cursorColor: Colors.amber,
                  decoration: const InputDecoration(
                    counterText: "",
                    hintText: "Enter OTP",
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isVerifying ? null : verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: isVerifying
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "VERIFY",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              isResendVisible
                  ? TextButton(
                      onPressed: resendOtp,
                      child: Text(
                        "Resend OTP",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.amber,
                        ),
                      ),
                    )
                  : Text(
                      "Resend OTP in ${formatTime(secondsRemaining)}",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
