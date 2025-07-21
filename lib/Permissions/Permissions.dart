import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:new_sara/Login/LoginWithMpinScreen.dart';
import 'package:new_sara/login/LoginScreen.dart';
import 'package:permission_handler/permission_handler.dart';

import '../components/AppNameBold.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool micGranted = false;
  bool callGranted = false;
  bool notificationGranted = false;
  bool isLoading = true;

  final storage = GetStorage();

  @override
  void initState() {
    super.initState();
    _requestAllPermissions();
  }

  Future<void> _requestAllPermissions() async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Request all 3 permissions initially
    await _requestPermission(Permission.microphone);
    await _requestPermission(Permission.phone);
    await _requestPermission(Permission.notification);

    await _updatePermissionsStatus();

    if (micGranted && callGranted && notificationGranted) {
      _goToNextScreen();
    }

    setState(() => isLoading = false);
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.status;

    if (status.isDenied || status.isRestricted) {
      await permission.request();
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    }

    await _updatePermissionsStatus(); // ✅ Always update after request
  }

  Future<void> _updatePermissionsStatus() async {
    micGranted = await Permission.microphone.isGranted;
    callGranted = await Permission.phone.isGranted;
    notificationGranted = await Permission.notification.isGranted;

    debugPrint('micGranted: $micGranted');
    debugPrint('callGranted: $callGranted');
    debugPrint('notificationGranted: $notificationGranted');

    setState(() {});
  }

  void _goToNextScreen() {
    final isLoggedIn = storage.read('isLoggedIn') ?? false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isLoggedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginWithMpinScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EnterMobileScreen()),
        );
      }
    });
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, size: 40, color: Colors.orange),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.orange,
          ),
        ),
        subtitle: Text(description),
        trailing: Icon(
          granted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: granted ? Colors.green : Colors.grey,
          size: 30,
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    final allGranted = micGranted && callGranted && notificationGranted;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const AppNameBold(),
              const SizedBox(height: 20),

              _buildPermissionTile(
                icon: Icons.mic,
                title: "Microphone",
                description: "Required to send voice to Sara777 support.",
                granted: micGranted,
                onTap: () => _requestPermission(Permission.microphone),
              ),
              _buildPermissionTile(
                icon: Icons.call,
                title: "Call",
                description: "Required to call Sara777 support.",
                granted: callGranted,
                onTap: () => _requestPermission(Permission.phone),
              ),
              _buildPermissionTile(
                icon: Icons.notifications,
                title: "Notification",
                description: "Required to receive important alerts.",
                granted: notificationGranted,
                onTap: () => _requestPermission(Permission.notification),
              ),

              const Spacer(),

              TextButton(
                onPressed: allGranted ? _goToNextScreen : null,
                style: TextButton.styleFrom(
                  backgroundColor: allGranted ? Colors.amber : Colors.grey,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
