import 'dart:developer';

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
  bool showPermissionDeniedMessage = false;

  final storage = GetStorage();

  @override
  void initState() {
    super.initState();
    _requestAllPermissions();
  }

  Future<void> _requestAllPermissions() async {
    await Future.delayed(const Duration(milliseconds: 300));

    await _requestPermission(Permission.microphone, showSnackbar: false);
    await _requestPermission(Permission.phone, showSnackbar: false);
    await _requestPermission(Permission.notification, showSnackbar: false);

    await _updatePermissionsStatus();
    _checkAndNavigateIfAllGranted();

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _requestPermission(
    Permission permission, {
    bool showSnackbar = true,
  }) async {
    final statusBefore = await permission.status;
    log(
      'Permission ${permission.toString()} status before request: $statusBefore',
    );

    if (statusBefore.isDenied || statusBefore.isRestricted) {
      final statusAfterRequest = await permission.request();
      log(
        'Permission ${permission.toString()} status after request: $statusAfterRequest',
      );
      if (statusAfterRequest.isGranted && showSnackbar && mounted) {
        _showGrantedSnackbar(permission);
      }
    } else if (statusBefore.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_getPermissionName(permission)} permission permanently denied. Please enable from app settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          showPermissionDeniedMessage = true;
        });
      }
    }

    await _updatePermissionsStatus();
    _checkAndNavigateIfAllGranted();
  }

  String _getPermissionName(Permission permission) {
    if (permission == Permission.microphone) {
      return 'Record Audio';
    } else if (permission == Permission.phone) {
      return 'Make and Manage Calls';
    } else if (permission == Permission.notification) {
      return 'Notifications';
    }
    return permission.toString();
  }

  void _showGrantedSnackbar(Permission permission) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_getPermissionName(permission)} permission granted!'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _updatePermissionsStatus() async {
    micGranted = await Permission.microphone.isGranted;
    callGranted = await Permission.phone.isGranted;
    notificationGranted = await Permission.notification.isGranted;

    log(
      'Permissions Updated: Mic=$micGranted, Call=$callGranted, Notification=$notificationGranted',
    );

    if (mounted) {
      setState(() {});
    }
  }

  void _checkAndNavigateIfAllGranted() {
    if (micGranted && callGranted && notificationGranted) {
      _goToNextScreen();
    }
  }

  void _goToNextScreen() {
    if (!mounted) return;

    final isLoggedIn = storage.read('isLoggedIn') ?? false;
    log('isLoggedIn: $isLoggedIn');

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
        leading: Icon(icon, size: 40, color: Colors.red),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.red,
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
                title: "Record Audio",
                description:
                    "Required to record and send voice to Sara777 support.",
                granted: micGranted,
                onTap: () => _requestPermission(Permission.microphone),
              ),
              _buildPermissionTile(
                icon: Icons.call,
                title: "Make and Manage Calls",
                description:
                    "Required to directly call Sara777 support from the app.",
                granted: callGranted,
                onTap: () => _requestPermission(Permission.phone),
              ),
              _buildPermissionTile(
                icon: Icons.notifications,
                title: "Notifications",
                description:
                    "Required to receive important alerts and updates.",
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
                child: Text(
                  allGranted ? "Continue" : "Grant All Permissions to Continue",
                  style: const TextStyle(
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

// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:new_sara/Login/LoginWithMpinScreen.dart';
// import 'package:new_sara/login/LoginScreen.dart'; // Assuming EnterMobileScreen is here
// import 'package:permission_handler/permission_handler.dart';
//
// import '../components/AppNameBold.dart'; // Ensure this path is correct based on your project structure
//
// class PermissionScreen extends StatefulWidget {
//   const PermissionScreen({super.key});
//
//   @override
//   State<PermissionScreen> createState() => _PermissionScreenState();
// }
//
// class _PermissionScreenState extends State<PermissionScreen> {
//   bool micGranted = false;
//   bool callGranted = false;
//   bool notificationGranted = false;
//   bool isLoading = true;
//
//   final storage = GetStorage();
//
//   @override
//   void initState() {
//     super.initState();
//
//     // deley to start the permission request and
//     _requestAllPermissions();
//   }
//
//   Future<void> _requestAllPermissions() async {
//     await Future.delayed(const Duration(milliseconds: 300));
//
//     // Request all 3 permissions initially
//     await _requestPermission(
//       Permission.microphone,
//       showSnackbar: false,
//     ); // Don't show snackbar for initial batch
//     await _requestPermission(Permission.phone, showSnackbar: false);
//     await _requestPermission(Permission.notification, showSnackbar: false);
//
//     await _updatePermissionsStatus();
//
//     if (micGranted && callGranted && notificationGranted) {
//       _goToNextScreen();
//     }
//
//     setState(() => isLoading = false);
//   }
//
//   Future<void> _requestPermission(
//     Permission permission, {
//     bool showSnackbar = true,
//   }) async {
//     final statusBefore = await permission.status;
//     bool changedToGranted = false;
//
//     if (statusBefore.isDenied || statusBefore.isRestricted) {
//       final statusAfterRequest = await permission.request();
//       if (statusAfterRequest.isGranted) {
//         changedToGranted = true;
//       }
//     } else if (statusBefore.isPermanentlyDenied) {
//       await openAppSettings();
//       // After returning from settings, we'll check status again below
//     }
//
//     // Always update status after any interaction
//     await _updatePermissionsStatus();
//
//     // Check if permission became granted after this interaction
//     final statusNow = await permission.status;
//     if (showSnackbar && statusNow.isGranted && !statusBefore.isGranted) {
//       String permissionName = '';
//       if (permission == Permission.microphone)
//         permissionName = 'Record Audio';
//       else if (permission == Permission.phone)
//         permissionName = 'Make and Manage Calls';
//       else if (permission == Permission.notification)
//         permissionName = 'Notifications';
//
//       if (mounted) {
//         // Ensure widget is still in tree
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('$permissionName permission granted!'),
//             duration: const Duration(seconds: 2),
//             backgroundColor: Colors.green,
//           ),
//         );
//       }
//     }
//   }
//
//   Future<void> _updatePermissionsStatus() async {
//     micGranted = await Permission.microphone.isGranted;
//     callGranted = await Permission.phone.isGranted;
//     notificationGranted = await Permission.notification.isGranted;
//
//     debugPrint('micGranted: $micGranted');
//     debugPrint('callGranted: $callGranted');
//     debugPrint('notificationGranted: $notificationGranted');
//
//     // Only call setState if the widget is still mounted
//     if (mounted) {
//       setState(() {});
//     }
//   }
//
//   void _goToNextScreen() {
//     // Reads the 'isLoggedIn' value from storage
//     final isLoggedIn = storage.read('isLoggedIn') ?? false;
//
//     // ...
//     if (isLoggedIn) {
//       // If true, navigates to LoginWithMpinScreen
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => const LoginWithMpinScreen()),
//       );
//     } else {
//       // If false, navigates to EnterMobileScreen
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => const EnterMobileScreen()),
//       );
//     }
//   }
//
//   Widget _buildPermissionTile({
//     required IconData icon,
//     required String title,
//     required String description,
//     required bool granted,
//     required VoidCallback onTap,
//   }) {
//     return Card(
//       elevation: 3,
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: ListTile(
//         leading: Icon(icon, size: 40, color: Colors.red),
//         title: Text(
//           title,
//           style: const TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 18,
//             color: Colors.red,
//           ),
//         ),
//         subtitle: Text(description),
//         trailing: Icon(
//           granted ? Icons.check_circle : Icons.radio_button_unchecked,
//           color: granted ? Colors.green : Colors.grey,
//           size: 30,
//         ),
//         onTap: onTap,
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (isLoading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator(color: Colors.amber)),
//       );
//     }
//
//     final allGranted = micGranted && callGranted && notificationGranted;
//
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             children: [
//               const SizedBox(height: 20),
//               // Ensure AppNameBold is correctly imported and exists
//               const AppNameBold(),
//               const SizedBox(height: 20),
//
//               _buildPermissionTile(
//                 icon: Icons.mic,
//                 title: "Record Audio",
//                 description:
//                     "Required to record and send voice to Sara777 support.",
//                 granted: micGranted,
//                 onTap: () => _requestPermission(Permission.microphone),
//               ),
//               _buildPermissionTile(
//                 icon: Icons.call,
//                 title: "Make and Manage Calls",
//                 description:
//                     "Required to directly call Sara777 support from the app.",
//                 granted: callGranted,
//                 onTap: () => _requestPermission(Permission.phone),
//               ),
//               _buildPermissionTile(
//                 icon: Icons.notifications,
//                 title: "Notifications",
//                 description:
//                     "Required to receive important alerts and updates.",
//                 granted: notificationGranted,
//                 onTap: () => _requestPermission(Permission.notification),
//               ),
//
//               const Spacer(),
//
//               TextButton(
//                 onPressed: allGranted ? _goToNextScreen : null,
//                 style: TextButton.styleFrom(
//                   backgroundColor: allGranted ? Colors.amber : Colors.grey,
//                   minimumSize: const Size(double.infinity, 50),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 child: const Text(
//                   "Continue",
//                   style: TextStyle(
//                     color: Colors.black,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//               ),
//
//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
