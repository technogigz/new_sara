import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/login/VerifyMobileScreen.dart'; // Ensure this import path is correct

import '../../../ulits/ColorsR.dart'; // Ensure this import path is correct
import '../../Helper/Toast.dart'; // Ensure this import path is correct
import '../ulits/Constents.dart'; // Ensure this import path is correct

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final TextEditingController mpinController = TextEditingController();
  final storage = GetStorage();
  bool isLoading = false;

  void _onSetPinPressed() async {
    final pin = mpinController.text.trim();

    if (pin.isEmpty || pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      popToast(
        "Please enter a valid 4-digit PIN",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
      return;
    }

    final mobile = storage.read('mobile');
    if (mobile == null || mobile.toString().isEmpty) {
      popToast("Mobile number not found", 4, Colors.white, ColorsR.appColorRed);
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${Constant.apiEndpoint}send-otp'),
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"mobileNo": int.tryParse(mobile)}),
      );

      final json = jsonDecode(response.body);

      print("Raw response body: ${response.body}");

      if (response.statusCode == 200 && json['status'] == true) {
        /// Store PIN temporarily for verification screen
        storage.write('user_mpin', pin);

        popToast("OTP sent successfully", 2, Colors.white, Colors.green);

        // It's generally better to navigate after the toast disappears or immediately
        // if the toast is non-blocking. A Future.delayed of 500ms is fine for UX.
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VerifyMobileScreen()),
          );
        });
      } else {
        popToast(
          json['message'] ?? "Failed to send OTP",
          4,
          Colors.white,
          ColorsR.appColorRed,
        );
      }
    } catch (e) {
      popToast(
        "Something went wrong: $e",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    mpinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // <--- Add SingleChildScrollView here
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 6, height: 40, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      "SET YOUR\nPIN",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Center(
                  child: Image.asset(
                    'assets/images/set_mpin_avatar.png',
                    height: 200,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  "Enter New mPin",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: mpinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  cursorColor: Colors.red,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    counterText:
                        '', // Remove the character counter below the TextField
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _onSetPinPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors
                          .white, // Changed from Colors.black to white for better contrast with amber background
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text(
                            "SET PIN",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
