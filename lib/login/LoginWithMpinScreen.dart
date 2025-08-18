import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

import '../Helper/Toast.dart'; // Assuming this path is correct
import '../HomeScreen/HomeScreen.dart'; // Assuming this path is correct
import '../SetMPIN/SetNewPinScreen.dart'; // Assuming this path is correct
import '../components/AppNameBold.dart'; // Assuming this path is correct
import '../ulits/ColorsR.dart'; // Assuming this path is correct
import '../ulits/Constents.dart'; // Assuming this path is correct

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
        localizedReason: 'Scan your fingerprint to verify',
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

  void _onSetPinPressed() async {
    final mobileNo = storage.read('mobile');
    if (mobileNo == null || mobileNo.toString().isEmpty) {
      // Use mobileNo directly
      popToast("Mobile number not found", 4, Colors.white, ColorsR.appColorRed);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${Constant.apiEndpoint}send-otp'),
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"mobileNo": int.tryParse(mobileNo)}), // Use mobileNo
      );

      final json = jsonDecode(response.body);

      print("Raw response body: ${response.body}");

      if (response.statusCode == 200 && json['status'] == true) {
        popToast("OTP sent successfully", 2, Colors.white, Colors.green);

        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SetNewPinScreen(mobile: mobileNo),
            ),
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
    }
  }

  /// Login using entered mPIN
  Future<void> _loginWithMpin() async {
    final enteredMpin = mpinController.text.trim();

    if (enteredMpin.isEmpty) {
      _showSnackBar('Please enter your mPIN');
      return;
    }

    // Retrieve registerId and accessToken from GetStorage
    final String registerId = storage.read('registerId');
    final String accessToken = storage.read('accessToken');
    final String deviceId = storage.read('deviceId') ?? '';
    final String deviceName = storage.read('deviceName') ?? '';

    log("Register Id: $registerId");
    log("Access Token: $accessToken");

    if (registerId == null || registerId.isEmpty) {
      _showSnackBar('Registration ID not found. Please re-register.');
      return;
    }

    if (accessToken == null || accessToken.isEmpty) {
      _showSnackBar('Access token not found. Please re-login.');
      return;
    }

    try {
      final url = Uri.parse('${Constant.apiEndpoint}verify-mpin');
      final response = await http.post(
        url,
        headers: {
          'deviceId':
              deviceId, // Replace with actual device ID logic if available
          'deviceName':
              deviceName, // Replace with actual device name logic if available
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          "registerId": registerId,
          "pinNo": int.tryParse(enteredMpin), // MPIN is expected as an integer
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        log("MPIN Verification Response: $responseData");
        // Assuming the API returns a success status or similar
        if (responseData['status'] == true) {
          // Adjust based on actual API response structure
          _showSnackBar('Login successful!');
          await fetchAndSaveUserDetails(
            registerId,
          ); // Fetch user details after successful MPIN verification
          _navigateToHome();
        } else {
          _showSnackBar(
            responseData['message'] ?? 'Incorrect mPIN. Please try again.',
          );
        }
      } else {
        log(
          "❌ MPIN Verification Failed: ${response.statusCode} => ${response.body}",
        );
        _showSnackBar('Failed to verify mPIN. Please try again later.');
      }
    } catch (e) {
      log("❌ Exception during MPIN verification: $e");
      _showSnackBar('An error occurred during mPIN verification: $e');
    }
  }

  /// Validate saved mPIN (used after biometric success)
  Future<void> _validateSavedMpinAndNavigate() async {
    final String? registerId = storage.read('registerId');
    if (registerId == null || registerId.isEmpty) {
      _showSnackBar('Registration ID not found. Please re-register.');
      return;
    }
    await fetchAndSaveUserDetails(registerId);
    _navigateToHome(); // Biometric passed and mPIN exists
  }

  Future<void> fetchAndSaveUserDetails(String registerId) async {
    final storage = GetStorage();
    final url = Uri.parse('${Constant.apiEndpoint}user-details-by-register-id');
    String accessToken = storage.read('accessToken') ?? '';

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

        // Save individual fields to GetStorage, ensuring walletBalance is stored as String
        storage.write('userId', info['userId']);
        storage.write('fullName', info['fullName']);
        storage.write('emailId', info['emailId']);
        storage.write('mobileNo', info['mobileNo']);
        storage.write('mobileNoEnc', info['mobileNoEnc']);
        // FIX: Convert walletBalance to String before saving
        storage.write('walletBalance', info['walletBalance']?.toString());
        storage.write('profilePicture', info['profilePicture']);
        storage.write('accountStatus', info['accountStatus']);
        storage.write('betStatus', info['betStatus']);

        log("✅ User details saved to GetStorage:");
        info.forEach((key, value) => log('$key: $value'));
      } else {
        print(
          "❌ Failed to fetch user details: ${response.statusCode} => ${response.body}",
        );
      }
    } catch (e) {
      print("❌ Exception fetching user details: $e");
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
                  cursorColor: Colors.red,
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
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 3,
                    ),
                    onPressed: _loginWithMpin,
                    child: const Text(
                      "LOGIN",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Forgot mPIN
                GestureDetector(
                  onTap: () {
                    _onSetPinPressed();
                    // The navigation to SetNewPinScreen is already inside _onSetPinPressed
                    // So, remove the duplicate navigation here.
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (_) => SetNewPinScreen(mobile: mobile),
                    //   ),
                    // );
                  },
                  child: const Text(
                    "Forgot M-Pin?",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

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
                  style: TextStyle(color: Colors.blueGrey, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
