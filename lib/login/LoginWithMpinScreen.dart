import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

import '../HomeScreen/HomeScreen.dart';
import '../SetMPIN/SetNewPinScreen.dart';
import '../components/AppNameBold.dart';
import '../ulits/Constents.dart';

class LoginWithMpinScreen extends StatefulWidget {
  const LoginWithMpinScreen({super.key});

  @override
  State<LoginWithMpinScreen> createState() => _LoginWithMpinScreenState();
}

class _LoginWithMpinScreenState extends State<LoginWithMpinScreen> {
  final TextEditingController mpinController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  final GetStorage storage = GetStorage();
  late String mobile;

  @override
  void initState() {
    super.initState();
    Future.delayed(
      Duration.zero,
      _tryBiometricAuth,
    ); // Attempt biometric on launch
    mobile = GetStorage().read('mobile') ?? '';
  }

  /// Try biometric authentication
  Future<void> _tryBiometricAuth() async {
    try {
      final isAvailable = await auth.canCheckBiometrics;
      final isDeviceSupported = await auth.isDeviceSupported();
      final biometrics = await auth.getAvailableBiometrics();

      if (!isAvailable || !isDeviceSupported || biometrics.isEmpty) {
        log("Biometric not available or supported");
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: 'Scan your fingerprint to login',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        _validateSavedMpinAndNavigate();
      } else {
        _showSnackBar('Biometric authentication failed');
      }
    } catch (e) {
      log("Biometric error: $e");
      _showSnackBar('Biometric error: $e');
    }
  }

  /// Login using entered mPIN
  Future<void> _loginWithMpin() async {
    final savedMpin = storage.read('user_mpin');
    final enteredMpin = mpinController.text.trim();

    if (enteredMpin.isEmpty) {
      _showSnackBar('Please enter your mPIN');
      return;
    }

    if (savedMpin == null) {
      _showSnackBar('No mPIN found. Please set a new mPIN.');
      return;
    }

    if (savedMpin != enteredMpin) {
      _showSnackBar('Incorrect mPIN. Please try again.');
    } else {
      _navigateToHome();
    }
  }

  /// Validate saved mPIN (used after biometric success)
  Future<void> _validateSavedMpinAndNavigate() async {
    final savedMpin = storage.read('user_mpin');

    if (savedMpin == null || savedMpin.isEmpty) {
      _showSnackBar('No mPIN set. Please create one.');
      return;
    }
    String registerId = storage.read('registerId') ?? '';
    fetchAndSaveUserDetails(registerId);
    _navigateToHome(); // Biometric passed and mPIN exists
  }

  Future<void> fetchAndSaveUserDetails(String registerId) async {
    final storage = GetStorage();
    final url = Uri.parse('${Constant.apiEndpoint}user-details-by-register-id');
    String accessToken = storage.read('accessToken');

    log("Register Id: $registerId");
    log("Access Token: $accessToken");

    try {
      final response = await http.post(
        url,
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({"registerId": registerId}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final info = responseData['info'];
        log("User details: $info");

        // Save individual fields to GetStorage
        storage.write('userId', info['userId']);
        storage.write('fullName', info['fullName']);
        storage.write('emailId', info['emailId']);
        storage.write('mobileNo', info['mobileNo']);
        storage.write('mobileNoEnc', info['mobileNoEnc']);
        storage.write('walletBalance', info['walletBalance']);
        storage.write('profilePicture', info['profilePicture']);
        storage.write('accountStatus', info['accountStatus']);
        storage.write('betStatus', info['betStatus']);

        log("✅ User details saved to GetStorage:");
        info.forEach((key, value) => log('$key: $value'));
      } else {
        print("❌ Failed: ${response.statusCode} => ${response.body}");
      }
    } catch (e) {
      print("❌ Exception: $e");
    }
  }

  /// Navigate to Home screen
  void _navigateToHome() {
    storage.write('is_logged_in', true); // Set login status
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  /// Show SnackBar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [AppNameBold()],
                ),
                const SizedBox(height: 60),

                // MPIN Field
                TextField(
                  controller: mpinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  cursorColor: Colors.amber,
                  decoration: InputDecoration(
                    hintText: "Login with mPIN",
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // LOGIN Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9B233),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 3,
                    ),
                    onPressed: _loginWithMpin,
                    child: const Text(
                      "LOGIN",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Forgot mPIN
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SetNewPinScreen(mobile: mobile),
                      ),
                    );
                  },
                  child: const Text(
                    "Forgot M-Pin?",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Fingerprint Icon
                GestureDetector(
                  onTap: _tryBiometricAuth,
                  child: const Icon(
                    Icons.fingerprint,
                    size: 50,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Use fingerprint to login",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
