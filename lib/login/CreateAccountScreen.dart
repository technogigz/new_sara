import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_sara/SetMPIN/SetPinScreen.dart';

import '../../../../ulits/ColorsR.dart';
import '../../../Helper/Toast.dart';
import '../components/AppNameBold.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final storage = GetStorage();

  String mobile = '';

  @override
  void initState() {
    super.initState();
    mobile = storage.read('mobile') ?? '';
  }

  void _onNextPressed() {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      popToast(
        "Please enter your username",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
    } else {
      storage.write('username', username);
      storage.write('mobile', mobile);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SetPinScreen()),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // <--- Wrap the Padding with SingleChildScrollView here
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 10, height: 50, color: Colors.red),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ENTER YOUR MOBILE', // This text actually seems misplaced on a "Create Account" screen for username
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.4,
                          ),
                        ),
                        Text(
                          'NUMBER', // This text actually seems misplaced on a "Create Account" screen for username
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                Center(child: const AppNameBold()),
                const SizedBox(height: 80),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_circle,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          cursorColor: Colors.red,
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            hintText: 'Enter username',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _onNextPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      "NEXT",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
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

// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:new_sara/SetMPIN/SetPinScreen.dart';
//
// import '../../../../ulits/ColorsR.dart';
// import '../../../Helper/Toast.dart';
// import '../components/AppNameBold.dart';
//
// class CreateAccountScreen extends StatefulWidget {
//   const CreateAccountScreen({super.key});
//
//   @override
//   State<CreateAccountScreen> createState() => _CreateAccountScreenState();
// }
//
// class _CreateAccountScreenState extends State<CreateAccountScreen> {
//   final TextEditingController _usernameController = TextEditingController();
//   final storage = GetStorage();
//
//   String mobile = ''; // ✅ Just declare it here
//
//   @override
//   void initState() {
//     super.initState();
//     // ✅ Read from storage correctly (it's a String)
//     mobile = storage.read('mobile') ?? ''; // fallback to empty string if null
//   }
//
//   void _onNextPressed() {
//     final username = _usernameController.text.trim();
//
//     if (username.isEmpty) {
//       popToast(
//         "Please enter your username",
//         4,
//         Colors.white,
//         ColorsR.appColorRed,
//       );
//     } else {
//       storage.write('username', username);
//       storage.write('mobile', mobile); // no problem writing it again
//
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => SetPinScreen()),
//       );
//     }
//   }
//
//   @override
//   void dispose() {
//     _usernameController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Container(width: 10, height: 50, color: Colors.red),
//                   const SizedBox(width: 8),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'ENTER YOUR MOBILE',
//                         style: GoogleFonts.poppins(
//                           fontSize: 24,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black,
//                           height: 1.4,
//                         ),
//                       ),
//
//                       Text(
//                         'NUMBER',
//                         style: GoogleFonts.poppins(
//                           fontSize: 24,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//
//               const SizedBox(height: 60),
//               Center(child: const AppNameBold()),
//               const SizedBox(height: 80),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[100],
//                   borderRadius: BorderRadius.circular(40),
//                   boxShadow: const [
//                     BoxShadow(
//                       color: Colors.black12,
//                       blurRadius: 6,
//                       offset: Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(8),
//                       decoration: const BoxDecoration(
//                         color: Colors.red,
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(
//                         Icons.account_circle,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: TextField(
//                         cursorColor: Colors.red,
//                         controller: _usernameController,
//                         decoration: const InputDecoration(
//                           hintText: 'Enter username',
//                           border: InputBorder.none,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 40),
//               SizedBox(
//                 width: double.infinity,
//                 height: 50,
//                 child: ElevatedButton(
//                   onPressed: _onNextPressed,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red,
//                     textStyle: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                   ),
//                   child: const Text(
//                     "NEXT",
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 18,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
